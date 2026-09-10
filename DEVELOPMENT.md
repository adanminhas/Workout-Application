# SetFlow — development notes

**SetFlow** is a local-first Flutter workout builder + guided workout timer.
Offline, no account, no backend. Create exercises/stretches, group them into
workout "days," then get guided through every set (Done button for reps,
countdown timers for timed/held work, auto rest timers, completion summary).

This file is the detailed stage-by-stage plan, progress log, architecture map,
and build reference. For a feature overview see [README.md](README.md).

---

## Plan & progress

### General plan

Build a local-first workout app in 7 planned phases (data → editing → media →
history → polish), then layer on extra features (offline generator, online
media fetch, AI assistant with server and on-device backends). Ship on Android
throughout; export to iOS at the end. Everything stays offline / no-account
except two opt-in network features (wger media fetch, AI assistant) — and the
assistant can run fully on-device.

### Stages

| Stage | Scope | Status |
|---|---|---|
| P1 Foundations | models, hardcoded program, guided player, 3 tabs | ✅ done |
| P2 Database | Drift/SQLite, seed, sessions tables | ✅ done |
| P3 Exercise editing | CRUD + reactive library | ✅ done |
| P4 Workout builder | workout/item CRUD, reorder, reactive screens | ✅ done |
| P5 Media | attach image/video, schema v2, player display | ✅ done |
| P6 History | record sessions, calendar tab, delete/clear | ✅ done |
| P7 Polish | wakelock/sound/haptics ✅ · **backup/export ⬜** | 🚧 in progress |
| X1 Generator | offline workout generator (✨) | ✅ done |
| X2 Online media | wger "Find online" (keyless, CC) | ✅ done |
| X3 AI assistant | chat tab, proposal cards, server backend, model mgmt | ✅ done |
| X4 On-device AI | flutter_gemma backend, in-app model catalog | ✅ done (verified on a physical phone) |
| X5 iOS export | build/sign on a Mac (needs macOS) | ⬜ not started |

### Checklist (user-facing features)

- [x] Create/edit/delete exercises & stretches (+ demo image/video)
- [x] Create/edit/reorder/delete workouts with per-item targets
- [x] Guided player (timers, rest, undo, cues, keep-awake)
- [x] History calendar + session detail + delete/clear
- [x] Theme chooser + high-contrast B&W mode
- [x] Offline workout generator
- [x] "Find online" exercise media (wger)
- [x] AI assistant: chat → workout/exercise proposal → Save
- [x] AI knows its capabilities + reads library AND workouts
- [x] Model management in-app (server pull/switch)
- [x] On-device AI verified end-to-end on a phone (Qwen 2.5 1.5B, ~45s/reply)
- [ ] Backup/export (last planned P7 item)
- [ ] iOS build

### Progress

**~93%** of currently-agreed scope (7 phases + extras X1–X4).
Remaining: backup/export, iOS export.

### Next actions

1. Backup/export (finishes Phase 7) — decide whether media files are bundled.
2. Later: iOS export on a Mac (X5).

---

## What's built

- ✅ **P1:** hardcoded Day A/B/C + stretch routine, working guided player,
  3 tabs (Today / Workouts / Exercises). No DB, no media.
- ✅ **Player polish:** 2-second safety window before Done / Finish-early can be
  tapped (with a visible countdown), and an undo/back button in the player.
- ✅ **Theme chooser:** Settings tab with light/dark/system + accent color
  (palette + custom hue slider) + a **high-contrast black & white mode**,
  persisted via `shared_preferences`.
- ✅ **P2: Drift/SQLite (on-device DB).** Tables for exercises, workouts,
  workout_items (+ workout_sessions / completed_sets created here, written in
  P6). Seeded from `SampleData` on first launch; `app_flutter/setflow.sqlite`
  lives in the app sandbox.
- ✅ **P3: editable exercise library.** Create / edit / delete exercises (name,
  tracking type, muscle group, form cues, instructions) via
  `ExerciseFormScreen`. The Exercises tab reads a Drift `watchExercises()`
  stream so edits show live. Delete warns when the exercise is used in workouts
  and cascades the removal of those workout items. (`isStretch` is **derived**
  from the tracking type being `stretch` — there is no separate toggle.)
- ✅ **P4: workout builder.** Create / rename / delete whole workouts, and add /
  edit / reorder (drag) / remove their items with per-item overrides (sets,
  rep/time range, rest, finisher, notes) via `WorkoutBuilderScreen` +
  `WorkoutItemFormScreen` + an exercise picker. Today / Workouts / Detail are
  **reactive** (`watchWorkouts()` / `watchWorkout(id)` — a Drift join over
  workouts+items+exercises); the startup snapshot was removed entirely.
  `WorkoutItem` gained an `id` so individual rows are addressable (no schema
  change — it maps from the existing row id).
- ✅ **P5: exercise demo media.** Attach an image or video to an exercise
  (picked from the gallery via `image_picker`, copied into app storage by
  `MediaStore` — **file paths, never blobs**). Shown in the exercise form and,
  during a guided workout, at the top of each exercise step (videos autoplay
  muted + loop, tap to pause) via the reusable `ExerciseMediaView`. First
  **schema migration v1 → v2** (added `mediaPath` + `mediaType` columns to
  exercises; `onUpgrade` runs `addColumn`) — verified upgrading an existing v1
  DB with no data loss.
- ✅ **P6: history + calendar.** Finishing a guided workout records a
  `WorkoutSession` + its `CompletedSets`. New **History tab**: a
  dependency-free month `MonthCalendar` marks days with workouts (browse months,
  tap a day → its sessions; empty days handled), a session detail shows the sets
  grouped by exercise, and you can **delete a single log** (⋮ on a session, or
  in its detail) or **clear all history** (the sweep icon). Repository:
  `recordSession`, `watchSessions` (reactive, joined set-count),
  `getSessionSets`, `deleteSession`, `clearAllSessions`.
- 🚧 **P7: polish (in progress).** During a guided workout: **keep screen
  awake** (`wakelock_plus`), **sound** cues (bundled WAV: countdown ticks in the
  last 3s + a finish chime, via `audioplayers`), and **haptics**
  (`HapticFeedback`). All three are toggles in **Settings → Workout**, persisted
  via `WorkoutPrefs`. **Still TODO: backup/export.**
- ✅ **Workout generator (extra).** ✨ icon in the Workouts app bar →
  `GenerateWorkoutScreen`: pick muscle-bucket chips + target length + cooldown
  toggle, preview, regenerate, save as a normal editable workout. Pure Dart
  (`WorkoutGenerator.generate` — **offline, no AI/network**): round-robin across
  muscle buckets, per-tracking-type set/rep defaults, reserves a max-reps
  **finisher**, ends with a stretch cooldown **capped at the number of work
  items**. Deterministic under a seed (tested).
- ✅ **wger "Find online" (opt-in network).** In the exercise form: Find online
  → `WgerSearchScreen` searches the wger.de catalog (**open source, CC media,
  no key/account**) and downloads the picked demo image into `MediaStore`,
  optionally filling empty Instructions from the (HTML-stripped) description.
  wger ≥2.7 has no server-side search, so the client loads a session catalog
  once (image index + English translation pages, a few MB) and searches the
  ~260 imaged exercises in memory.
- ✅ **AI assistant (extra, opt-in network).** Its own **Assistant tab** in the
  bottom nav (it creates workouts AND exercises) → `AssistantScreen`: a
  streaming chat that designs **workouts and new exercises**. Backend = any
  **OpenAI-compatible** endpoint (Settings → AI assistant, or ⚙ in the chat).
  The system prompt carries the user's library + existing workouts + a strict
  JSON contract; replies with a fenced json block become a **proposal card**
  (workout items + new-exercise chips) that only writes to the DB on Save
  (`applyProposal` → normal repository calls). Robustness against small-model
  sloppiness, all regression-tested against real small-model replies:
  `_fuzzyTargets` keyword-classifies invented numeric field names
  (`minRepsEachSide`, `holdDurationSeconds`…); `resolveExerciseRef` +
  `canonicalExerciseName` match annotated/plural/hyphenated refs
  ("push-up (chest/…)" → Push-Up) and dedupe proposed exercises against the
  library; resolution is all-or-nothing BEFORE anything is created. No model or
  key ships with the app. The ⬇ **Models sheet** manages a server's models from
  the phone (list / pull / switch active — for servers that support it).
- ✅ **On-device AI (X4).** The Models sheet's **On-device** segment downloads
  models that run **inside the app** via `flutter_gemma` +
  `flutter_gemma_litertlm` (engine registered in `main()`:
  `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])`; requires
  **minSdk 24**). Curated, ungated catalog (litert-community, no account/token):
  Qwen 2.5 1.5B (recommended), Qwen 3 0.6B (small), DeepSeek R1 1.5B — all
  `.litertlm`, 4096-context variants where available (the system prompt needs
  >1280). `LlmSettings.backend` routes `LlmClient.chatStream` to `LocalLlm`
  (model cached in memory across turns; a fresh `openChat` per turn replays
  history; "thinking" traces are skipped). **Verified end-to-end on a physical
  phone** with Qwen 2.5 1.5B: in-app download (~1.6 GB) → chat → proposal card →
  Save, plus a multi-turn edit. First reply ≈100s (one-time model load +
  prefill), warm replies ≈45s.
  - **Gotcha:** `installModel()` defaults `fileType:` to `ModelFileType.task`,
    so a clean install stored the spec as `.task` and the LiteRT-LM engine
    refused to load it ("No inference engine can handle this model"); both
    install call sites in `local_llm.dart` now pass
    `fileType: ModelFileType.litertlm` explicitly. (An emulator run had masked
    this — always verify model load on a clean install.)

`flutter analyze` is clean and the tests pass (18): widget smoke test,
`test/history_test.dart`, `test/generator_test.dart` (incl. the stretch-balance
cap), `test/assistant_test.dart` (fenced-json extraction, lenient tracking types
+ fuzzy targets, applyProposal against an in-memory DB, unknown-ref rejection),
`test/wger_test.dart` (catalog assembly, HTML stripping). All back the app with
an in-memory `NativeDatabase`.

> **Widget-test gotcha (P3):** a screen that shows a `CircularProgressIndicator`
> while a Drift stream loads will hang `pumpAndSettle()` forever (indeterminate
> animation never settles), and a live Drift stream leaves a pending timer at
> teardown. The smoke test uses bounded `pump()` + `runAsync` to let the
> query/timer run, then pumps an empty tree so the subscription is cancelled
> before the in-memory DB closes.

---

## Architecture

### Source map (`lib/`)

```
main.dart                          app entry; opens DB, seeds, builds MaterialApp
models/
  tracking_type.dart               TrackingType enum (drives player UI)
  exercise.dart                    Exercise (library item; isStretch; media path/type) + MediaType
  workout.dart                     Workout + WorkoutItem (per-workout overrides; item has id)
  workout_session.dart             WorkoutSessionSummary + CompletedSetRecord (history)
data/
  sample_data.dart                 SEED source: library + Day A/B/C + stretch routine
  workout_repository.dart          seedIfEmpty(); watch* streams + workout/item CRUD + sessions
  media_store.dart                 copies picked media / writes downloaded bytes into app storage
  workout_prefs.dart               static SharedPreferences holder: sound / haptics / keepAwake
  workout_generator.dart           offline generator: buckets, defaults, finisher, cooldown
  wger_api.dart                    wger.de client (keyless): session catalog + image download
  llm_client.dart                  LlmSettings (prefs, backend routing) + OpenAI-compatible client + server admin
  local_llm.dart                   on-device backend: model catalog + flutter_gemma wrapper
  assistant_actions.dart           system prompt (capabilities+library+workouts), parser, applyProposal
  db/
    app_database.dart              Drift tables + AppDatabase (schema v2: exercise media columns)
    app_database.g.dart            GENERATED (build_runner) — do not edit by hand
player/
  player_step.dart                 expandWorkout(): workout -> ordered PlayerStep list (carries media)
  workout_player_screen.dart       the guided player (timers, rest, 2s guard, undo, media, cues)
widgets/
  exercise_media_view.dart         shows an exercise image/video (video autoplays muted + loops)
  month_calendar.dart              dependency-free month grid with day markers (History)
screens/
  home_shell.dart                  bottom-nav shell (Today/Workouts/Exercises/Assistant/History/Settings)
  today_screen.dart                reactive A->B->C rotation + weekly plan
  workouts_screen.dart             reactive workout list + create/rename/delete + ✨ generate
  generate_workout_screen.dart     offline generator UI: chips/length/cooldown, preview, save
  assistant_screen.dart            AI chat: streaming bubbles + proposal card + Save
  llm_settings_dialog.dart         endpoint dialog (URL/model/key), owns its controllers
  wger_search_screen.dart          search the wger catalog, download a demo image
  workout_detail_screen.dart       reactive workout preview + Start + edit entry
  workout_builder_screen.dart      edit a workout's items (drag-reorder/add/remove/meta)
  workout_item_form_screen.dart    create/edit a WorkoutItem; pops with the WorkoutItem
  exercise_picker_screen.dart      pick a library exercise to add to a workout
  workout_meta_dialog.dart         shared name/focus dialog (create + rename workout)
  exercises_screen.dart            exercise library (reactive watch + add/edit/delete)
  exercise_form_screen.dart        create/edit an exercise (+ pick demo media); pops with the Exercise
  history_screen.dart              History tab: calendar + selected-day sessions + clear-all
  session_detail_screen.dart       one session's sets (grouped by exercise) + delete
  workout_complete_screen.dart     post-workout summary
  settings_screen.dart             appearance + workout toggles + AI endpoint
theme/
  theme_controller.dart            ChangeNotifier; persists themeMode + seed + highContrast

assets/sounds/                     tick.wav + done.wav (bundled workout cues, P7)
```

### Dependencies (pubspec)

- `shared_preferences` — theme / workout / AI settings persistence
- `drift` + `drift_flutter` — on-device SQLite (drift_flutter bundles
  `sqlite3_flutter_libs` + `path_provider`). Dev: `drift_dev` + `build_runner`.
- `wakelock_plus` + `audioplayers` — keep screen awake + play the bundled
  `assets/sounds/*.wav` cues (P7). Haptics use the built-in `HapticFeedback`.
- `image_picker` + `video_player` + `path_provider` — P5 media (`path_provider`
  is a direct dep, used by `MediaStore`).
- `http` — the only networked features: wger search/download + the AI
  assistant's chat endpoint + model downloads.
- `flutter_gemma` + `flutter_gemma_litertlm` — on-device AI backend; engine is
  registered in `main()`; **requires minSdk 24** (set in `build.gradle.kts`).
- Riverpod is **planned but NOT added yet** — add per phase.

**Codegen:** after touching `lib/data/db/app_database.dart`, regenerate with
`dart run build_runner build --delete-conflicting-outputs` (the `.g.dart` is
committed). `analyze`/`test` will fail against a stale `.g.dart`. Schema is at
**v2** — bump `schemaVersion` and add an `onUpgrade` step for any new change.

---

## Build & run

The dev toolchain (Flutter, JDK 17, Android SDK) can live under `~/development`
to avoid system packages. Export the env before building in a non-login shell:

```bash
export JAVA_HOME="$HOME/development/jdk"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

```bash
flutter pub get              # after cloning (regenerates .dart_tool)
flutter analyze             # lint (keep clean)
flutter test                # widget + unit tests (mocks SharedPreferences)
flutter run -d linux        # fast desktop iteration
flutter run                 # run on a connected device / emulator
flutter build apk --debug   # APK at build/app/outputs/flutter-apk/app-debug.apk
```

`build/`, `.dart_tool/`, and IDE folders are gitignored — run `flutter pub get`
after cloning. Application id / launch package: `com.setflow.setflow`.

Build timing: first APK is slow (downloads Gradle/AGP/CMake); incremental
builds are ~45–150s. Flutter's `install` defaults to a **release** build, which
isn't configured for signing — install the debug APK directly with
`adb install -r build/app/outputs/flutter-apk/app-debug.apk`, or use
`flutter run` for hot reload.

### Android emulator

A KVM-accelerated AVD (API 35, `medium_phone`) with `hw.keyboard=yes` supports
every feature (photo picker, video, sound), unlike the Linux desktop target.

```bash
flutter emulators --launch <avd>
flutter run -d emulator-5554
```

The emulator's gallery starts empty — drag an image onto its window to test the
media picker. From the emulator, an OpenAI-compatible server on the host is
reachable at `http://10.0.2.2:<port>`.

### AI assistant backends

The assistant talks to a **user-configured** endpoint (`LlmSettings` in prefs)
— no model, key, or endpoint is bundled. Any OpenAI-compatible server works
(Ollama, LM Studio, llama.cpp, on-device Termux). Alternatively pick an
**on-device** model in the Models sheet and it runs entirely in the app after a
one-time download. Larger models give noticeably better plans than the small
on-device ones.

### iOS export

iOS builds need macOS + Xcode + CocoaPods. The `ios/` folder already exists. On
a Mac: `flutter pub get`, set signing/bundle id in Xcode, then
`flutter build ipa`. Develop on Linux/Windows; use the Mac only to export.

---

## Conventions & gotchas

- **Material 3**, default teal seed `0xFF00897B`. Theme comes from
  `ThemeController` (light/dark/system + custom seed + a high-contrast flag),
  persisted in prefs. **High-contrast mode** is a hand-built pure black/white
  `ColorScheme` (all surfaces forced to `#000`/`#FFF`, `surfaceTint`
  transparent so M3 elevation doesn't grey them, cards get a hard border) — the
  `DynamicSchemeVariant.monochrome` variant renders greys, not true white.
- **State:** plain `setState` + a `ChangeNotifier` (ThemeController) for now.
  Riverpod is planned for later phases — do NOT add it preemptively.
- **`TrackingType`** drives the player: `isTimed` → countdown, else Done button;
  `isEachSide` → split a set into left/right steps. Step expansion lives in
  `lib/player/player_step.dart` (`expandWorkout`).
- **Stretches** are just exercises with `isStretch: true`. The exercise form
  **derives** `isStretch` from the tracking type being `TrackingType.stretch`
  (no separate toggle). Don't build a separate stretch system.
- **WorkoutItem overrides** the exercise defaults (sets/reps/seconds/rest) —
  the same exercise can appear in different workouts with different targets.
- **Media (P5):** picked image/video is copied into the app's documents dir
  (`exercise_media/`) by `MediaStore`; the DB stores that **file path**, never a
  blob. `image_picker` gallery pick needs no runtime permission on Android 13+
  (Photo Picker). Known limitation: replacing/removing media leaves the old file
  as a harmless orphan (no GC yet). Media lives in app data, so it's cleared on
  uninstall like the rest of the local-first state.
- **Online media (wger):** strictly opt-in. wger.de is keyless with CC media —
  do NOT reintroduce a key-gated source. Downloads go through
  `MediaStore.saveBytes` as `MediaType.image` (`Image.file` also animates GIFs).
  wger ≥2.7 has **no server-side search** — keep the session-catalog +
  client-side filter approach; identify the app via the User-Agent header.
- **AI assistant:** talks to a user-configured OpenAI-compatible endpoint —
  never bundle a model, key, or endpoint. Nothing writes to the DB except
  `applyProposal` after an explicit Save, and it must stay all-or-nothing
  (resolve every item before creating anything). Small local models invent JSON
  field names — extend `_fuzzyTargets`/`parseTrackingType` rather than trusting
  the schema, and keep the real-reply regression test green. Dispose dialog
  `TextEditingController`s via a StatefulWidget's `dispose` (doing it right after
  `showDialog` returns crashes during the route's exit animation).
- **Workout generator** is pure Dart and must stay offline — no AI/network in
  `WorkoutGenerator`. Tests pin its invariants (finisher before cooldown,
  cooldown ≤ work items, bucket filter, seeded determinism); keep them green
  when tuning defaults.
- Flutter deprecated `Color.value`; use **`color.toARGB32()`** (already used in
  ThemeController/settings).
- **`setState(() => someAsyncCall())` crashes** ("callback argument returned a
  Future") — an arrow closure returns the Future. Use braces:
  `setState(() { _f = load(); });`.
- Package name is `setflow` (the repo dir isn't a valid Dart package name, so
  `flutter create --project-name setflow --org com.setflow`).
- **Per-machine debug signature:** the debug APK is signed with the local
  `~/.android/debug.keystore`, which differs on each machine. Installing this
  machine's build over one from a *different* machine fails with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — `adb uninstall com.setflow.setflow`
  first, then install (clears app data).
