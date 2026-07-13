import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'llm_client.dart';

/// A downloadable on-device model. All catalog entries are public
/// (ungated) LiteRT conversions from huggingface.co/litert-community —
/// no account or token needed.
class LocalModelInfo {
  const LocalModelInfo({
    required this.name,
    required this.url,
    required this.modelType,
    required this.sizeLabel,
    required this.note,
  });

  final String name;
  final String url;
  final ModelType modelType;
  final String sizeLabel;
  final String note;

  String get fileName => url.substring(url.lastIndexOf('/') + 1);
}

/// Curated, known-good models for phone-class hardware. 4096-token context
/// variants are chosen where available — the assistant's system prompt
/// (library + workouts) plus a plan needs more than the 1280-token files.
const List<LocalModelInfo> localModelCatalog = [
  LocalModelInfo(
    name: 'Qwen 2.5 1.5B',
    url:
        'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    modelType: ModelType.qwen,
    sizeLabel: '~1.6 GB',
    note: 'Recommended — best plans of the small models',
  ),
  LocalModelInfo(
    name: 'Qwen 3 0.6B',
    url:
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/qwen3_0_6b_mixed_int4.litertlm',
    modelType: ModelType.qwen3,
    sizeLabel: '~0.5 GB',
    note: 'Small & fast — weaker plans',
  ),
  LocalModelInfo(
    name: 'DeepSeek R1 1.5B',
    url:
        'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
    modelType: ModelType.deepSeek,
    sizeLabel: '~1.7 GB',
    note: 'Reasoning model — thinks before answering (slower)',
  ),
];

LocalModelInfo? localModelByName(String name) {
  for (final m in localModelCatalog) {
    if (m.name == name) return m;
  }
  return null;
}

/// On-device inference via flutter_gemma (MediaPipe LiteRT). The model runs
/// entirely on the phone — no server, no network after the one-time download.
class LocalLlm {
  LocalLlm._();

  static InferenceModel? _model;
  static String? _loadedModelName;

  /// Downloads (or verifies) a catalog model and marks it active on the
  /// plugin side. Emits live progress 0–100 and closes when done.
  static Stream<int> download(LocalModelInfo info) {
    final controller = StreamController<int>();
    // fileType must be explicit: installModel defaults to ModelFileType.task,
    // and the LiteRT-LM engine refuses a spec marked .task at load time.
    FlutterGemma.installModel(
            modelType: info.modelType, fileType: ModelFileType.litertlm)
        .fromNetwork(info.url)
        .withProgress((p) {
          if (!controller.isClosed) controller.add(p);
        })
        .install()
        .then((_) {
      if (!controller.isClosed) {
        controller.add(100);
        controller.close();
      }
    }, onError: (Object e) {
      if (!controller.isClosed) {
        controller
          ..addError(LlmException('Download failed: $e'))
          ..close();
      }
    });
    return controller.stream;
  }

  /// True when the catalog model's file is installed on this device.
  static Future<bool> isInstalled(LocalModelInfo info) async {
    try {
      final installed = await FlutterGemma.listInstalledModels();
      return installed.any((f) => f.contains(info.fileName));
    } catch (_) {
      return false;
    }
  }

  /// Streams a reply for [messages] from the selected on-device model.
  static Stream<String> chatStream(List<ChatMessage> messages) async* {
    final info = localModelByName(LlmSettings.localModelName);
    if (info == null) {
      throw const LlmException(
          'No on-device model selected — pick one in ⬇ Models.');
    }
    if (!await isInstalled(info)) {
      throw LlmException(
          '${info.name} is not downloaded yet — get it in ⬇ Models.');
    }

    try {
      // (Re)load only when the selection changed; keeping the model in
      // memory makes follow-up messages much faster.
      if (_model == null || _loadedModelName != info.name) {
        await _model?.close();
        _model = null;
        await FlutterGemma.installModel(
                modelType: info.modelType, fileType: ModelFileType.litertlm)
            .fromNetwork(info.url)
            .install(); // marks it active; no re-download when present
        _model = await FlutterGemma.getActiveModel(maxTokens: 4096);
        _loadedModelName = info.name;
      }
      final model = _model!;

      // Fresh chat per turn: replay history so behavior matches the
      // stateless remote path. System prompt rides in natively.
      final system = messages
          .where((m) => m.role == 'system')
          .map((m) => m.content)
          .join('\n');
      final chat = await model.openChat(
        systemInstruction: system.isEmpty ? null : system,
      );
      try {
        for (final m in messages.where((m) => m.role != 'system')) {
          await chat.addQueryChunk(
              Message.text(text: m.content, isUser: m.role == 'user'));
        }
        await for (final part in chat.generateChatResponseAsync()) {
          // Skip "thinking" traces (DeepSeek/Qwen3); surface only the answer.
          if (part is TextResponse) yield part.token;
        }
      } finally {
        await chat.session.close();
      }
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException('On-device model failed: $e');
    }
  }
}
