# SetFlow

A **local-first workout builder and guided workout timer**. Create exercises and
stretches, group them into workout "days," then get guided through every set with
a Done button for rep work, countdown timers for timed/held work, and automatic
rest timers in between. No account, no backend, works fully offline.

## Status — Phase 1 (prototype)

The current build is the hardcoded prototype that proves the workout experience:

- 3 tabs: **Today**, **Workouts**, **Exercises**
- The rotating ab program is hardcoded: **Day A / Day B / Day C** + a reusable
  cooldown stretch routine
- A working **workout player** supporting `reps`, `timed`, `hold`, `maxReps`,
  `timedEachSide`, `repsEachSide`, rest timers (skip / ±15s), and a completion summary

No database or media yet — those arrive in later phases (see the project plan).

## Project layout

```
lib/
  main.dart                 # app entry + theme
  models/                   # Exercise, Workout/WorkoutItem, TrackingType
  data/sample_data.dart     # hardcoded Day A/B/C + stretch routine
  player/                   # step expansion + WorkoutPlayerScreen
  screens/                  # Today / Workouts / Exercises / detail / complete
```

## Running

The dev toolchain is installed under `~/development` (not via system packages).
A login shell already has the right env (added to `~/.bashrc`). In a fresh
non-login shell, export:

```bash
export JAVA_HOME="$HOME/development/jdk"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

Then:

```bash
flutter run                 # run on a connected device / emulator
flutter run -d linux        # fast desktop iteration
flutter test                # widget tests
flutter build apk --debug   # Android APK
```

## iOS

The `ios/` folder exists, but building/signing an IPA requires macOS + Xcode.
Develop here, push to git, then build on a Mac (`flutter build ipa`).
