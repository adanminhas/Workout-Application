# SetFlow

A **local-first workout builder and guided workout timer** for Android (and iOS
once exported). Build your own exercises and stretches, group them into workout
"days," then get walked through every single set — a Done button for rep work,
countdown timers for timed/held work, automatic rest timers in between, and a
completion summary at the end.

Everything runs **offline with no account and no backend**. Your library,
workouts, media, and history all live on the device. The only two features that
ever touch the network are strictly opt-in (fetching exercise media, and the AI
assistant) — and even the AI assistant can run fully on-device.

---

## Features

### 🏋️ Guided workout player
- Walks you through a workout set by set, expanding each item into individual
  steps based on how it's tracked.
- Handles every tracking type: **reps**, **reps each side**, **timed**, **timed
  each side**, **hold**, **max-reps finisher**, and **stretch** — rep work shows
  a Done button, timed/held work shows a countdown, and each-side work splits
  into left/right steps.
- **Automatic rest timers** between sets (skip, or adjust ±15s).
- A **2-second safety window** with a visible countdown before Done / Finish-early
  can be tapped, so you can't accidentally skip a step, plus an **undo/back**
  button to step back.
- Shows the exercise's **demo image or video** at the top of each step (videos
  autoplay muted and loop; tap to pause).
- Optional **sound cues** (tick in the last 3 seconds + a finish chime),
  **haptics**, and **keep-screen-awake** during a workout — each toggleable.

### 💪 Exercise library
- Create, edit, and delete your own exercises and stretches (name, tracking
  type, muscle group, form cues, instructions).
- **Stretches are just exercises** with the stretch tracking type — no separate
  system to manage.
- Attach a **demo image or video** from your gallery; it's copied into app
  storage (file paths, never blobs).
- The library is **reactive** — edits show up live everywhere.
- Deleting an exercise that's used in workouts warns you and cleanly cascades.

### 📋 Workout builder
- Create, rename, and delete whole workouts.
- Add, **drag-to-reorder**, edit, and remove items, each with **per-item
  overrides** (sets, rep/time range, rest, finisher flag, notes) — the same
  exercise can appear in different workouts with different targets.
- The **Today** tab rotates through your workouts and shows a weekly plan;
  **Workouts** and the detail view are all reactive.

### ✨ Offline workout generator
- Generate a balanced workout from muscle-group chips + a target length +
  optional cooldown, then preview, regenerate, and save it as a normal editable
  workout.
- **Pure Dart, fully offline** (no AI, no network): round-robins across muscle
  buckets, applies sensible per-tracking-type set/rep defaults, reserves a
  max-reps finisher, and ends with a stretch cooldown capped at the number of
  work items.

### 📅 History & calendar
- Finishing a guided workout records the session and every completed set.
- A **month calendar** marks the days you worked out (browse months, tap a day
  to see its sessions).
- **Session detail** shows the sets grouped by exercise.
- Delete a single log, or clear all history.

### 🤖 AI assistant
- Its own chat tab that designs **workouts and new exercises** from a plain
  conversation.
- Replies that contain a plan become an interactive **proposal card** (workout
  items + new-exercise chips) that only writes to your database when you tap
  **Save** — and it's all-or-nothing (every item resolves before anything is
  created).
- The assistant knows its own capabilities and reads **both your library and
  your existing workouts**, so it self-describes accurately and reuses what you
  already have.
- Robust against small local models inventing sloppy JSON (fuzzy field-name
  classification, plural/hyphenated/annotated exercise-name matching, dedupe
  against the library).
- **Two backends, your choice** (Settings → AI assistant, or ⚙ in the chat):
  - **On-device** — download a model that runs entirely inside the app via
    `flutter_gemma` (MediaPipe LiteRT). Curated, ungated catalog: **Qwen 2.5
    1.5B** (recommended), **Qwen 3 0.6B** (small & fast), **DeepSeek R1 1.5B**
    (reasoning). No account, token, server, or network after the one-time
    download. Verified end-to-end on a Pixel 8a.
  - **Server** — any **OpenAI-compatible** endpoint (e.g. Ollama on your LAN
    with `qwen2.5:7b`), configured in-app. No model or key ships with the app.
- A ⬇ **Models sheet** manages models from the phone: download on-device models,
  or (for an Ollama server) list, pull, and switch the active model remotely.

### 🌐 "Find online" exercise media (opt-in)
- From the exercise form, search the **wger.de** open catalog and download a
  demo image, optionally filling empty instructions from the description.
- **Keyless, no account, CC-licensed media.** wger has no server-side search, so
  the app loads the catalog once and filters locally.

### 🎨 Appearance & theming
- Light / dark / system theme, a curated **accent-color palette** plus a custom
  hue slider, and a **high-contrast black & white mode** — all persisted.

---

## How it works

- **Local-first.** All data lives in an on-device **Drift/SQLite** database
  (schema v2), seeded from a sample program on first launch. Screens read
  reactive `watch*` streams so edits appear live. Media is stored as **files in
  the app sandbox**, with only the path in the database — so it's all cleared on
  uninstall, like the rest of the local-first state.
- **State** is plain `setState` + a `ChangeNotifier` for theming.
- **Material 3** throughout, default teal seed.
- The only networked code paths are the wger media fetch and the AI assistant's
  chat/model endpoints — nothing else leaves the device.

### Project layout

```
lib/
  main.dart                    app entry; opens DB, seeds, registers the on-device engine
  models/                      TrackingType, Exercise (+ media), Workout/WorkoutItem, session records
  data/
    sample_data.dart           seed: library + Day A/B/C + stretch routine
    workout_repository.dart     reactive watch* streams + workout/item/session CRUD
    media_store.dart            copies picked / downloaded media into app storage
    workout_prefs.dart          sound / haptics / keep-awake toggles
    workout_generator.dart      offline generator
    wger_api.dart               keyless wger.de client (catalog + image download)
    llm_client.dart             settings + OpenAI-compatible client + Ollama admin
    local_llm.dart              on-device backend: model catalog + flutter_gemma wrapper
    assistant_actions.dart      system prompt, proposal parser, applyProposal
    db/                         Drift tables + generated code (schema v2)
  player/                       expandWorkout() + the guided WorkoutPlayerScreen
  widgets/                      ExerciseMediaView, MonthCalendar
  screens/                      the six tabs + builder/forms/pickers/dialogs
theme/theme_controller.dart     themeMode + seed + high-contrast, persisted
assets/sounds/                  bundled tick.wav + done.wav workout cues
```

The app is a **six-tab shell**: Today · Workouts · Exercises · Assistant ·
History · Settings.

### Tech stack

- **Flutter** (Dart SDK ^3.12), **Material 3**
- **drift** + **drift_flutter** — on-device SQLite (with `drift_dev` +
  `build_runner` for codegen)
- **shared_preferences** — theme / workout / AI settings
- **image_picker** + **video_player** + **path_provider** — exercise demo media
- **wakelock_plus** + **audioplayers** — keep-awake + sound cues (haptics use the
  built-in `HapticFeedback`)
- **http** — wger fetch + AI chat/model endpoints (the only networked deps)
- **flutter_gemma** + **flutter_gemma_litertlm** — on-device AI (requires
  **Android API 24+**)

---

## Running & building

The dev toolchain lives under `~/development` (not system packages). A login
shell already has the right env; in a fresh non-login shell, export it first:

```bash
export JAVA_HOME="$HOME/development/jdk"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

Then:

```bash
flutter pub get              # after cloning (regenerates .dart_tool)
flutter analyze             # lint
flutter test                # widget + unit tests
flutter run -d linux        # fast desktop iteration
flutter run                 # run on a connected device / emulator
flutter build apk --debug   # Android APK
```

After editing `lib/data/db/app_database.dart`, regenerate the Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Application id / launch package: `com.setflow.setflow`.

> **Full setup, build, emulator, and the detailed plan live in
> [DEVELOPMENT.md](DEVELOPMENT.md).**

### Tests

`flutter test` covers a widget smoke test plus unit tests for history, the
offline generator (including the stretch-balance cap), the AI assistant
(fenced-JSON extraction, lenient tracking types, `applyProposal` against an
in-memory database, unknown-ref rejection), and the wger catalog. All run
against an in-memory database.

---

## Privacy

SetFlow is offline and account-free by design. The **only** network activity is:

1. **"Find online" media** — fetches CC-licensed images from wger.de when you
   ask it to.
2. **AI assistant** — talks to whichever backend you configure. Choose the
   on-device model and it never leaves the phone after the one-time download;
   choose a server and it talks only to the endpoint you set.

Nothing else is sent anywhere, and no model, key, or endpoint ships with the app.

---

## Status

Phases 1–7 are essentially complete (foundations → database → exercise editing →
workout builder → media → history → polish), plus post-plan extras: the offline
generator, wger media, the AI assistant, and on-device AI (verified on a Pixel
8a). Roughly **93%** of the agreed scope.

**Remaining:**
- Backup / export (the last polish item)
- iOS build (the `ios/` folder exists; building/signing an IPA needs macOS +
  Xcode — develop here, then `flutter build ipa` on a Mac)

See [DEVELOPMENT.md](DEVELOPMENT.md) for the detailed stage-by-stage plan and
progress log.
