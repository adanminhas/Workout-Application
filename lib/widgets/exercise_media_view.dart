import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/exercise.dart';

/// Displays an exercise's demo media: an image (`Image.file`) or a video
/// (`video_player`). Videos autoplay muted and loop by default, with a tap to
/// pause/resume.
///
/// When used in a list/player where the source changes (e.g. advancing steps),
/// give it `key: ValueKey(path)` so a new controller is created — though it also
/// recovers via didUpdateWidget if reused.
class ExerciseMediaView extends StatelessWidget {
  const ExerciseMediaView({
    super.key,
    required this.path,
    required this.type,
    this.height = 200,
    this.borderRadius = 16,
    this.autoplay = true,
    this.loop = true,
    this.muted = true,
  });

  final String path;
  final MediaType type;
  final double height;
  final double borderRadius;
  final bool autoplay;
  final bool loop;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    if (!File(path).existsSync()) {
      return _MissingMedia(height: height, borderRadius: radius);
    }
    final Widget child = type == MediaType.video
        ? _VideoView(
            path: path,
            height: height,
            autoplay: autoplay,
            loop: loop,
            muted: muted,
          )
        : SizedBox(
            height: height,
            width: double.infinity,
            child: Image.file(File(path), fit: BoxFit.cover),
          );
    return ClipRRect(borderRadius: radius, child: child);
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({
    required this.path,
    required this.height,
    required this.autoplay,
    required this.loop,
    required this.muted,
  });

  final String path;
  final double height;
  final bool autoplay;
  final bool loop;
  final bool muted;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(_VideoView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _failed = false;
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.loop);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (widget.autoplay) await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      return _MissingMedia(
        height: widget.height,
        borderRadius: BorderRadius.zero,
      );
    }
    final c = _controller;
    if (!_ready || c == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
            if (!c.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia({required this.height, required this.borderRadius});

  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(Icons.broken_image_outlined,
          size: 48, color: theme.colorScheme.outline),
    );
  }
}
