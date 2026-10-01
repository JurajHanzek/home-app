# HomeHub — Development Review

## Current phase
Phase 1 — Auth / Household / Security (Phase 0 complete on 2026-10-01).

## Implemented
- Created an Android-only Flutter app with feature-oriented `app`, `core`, and `features` folders.
- Added Material 3 Dark and Flower themes with a Riverpod theme toggle; Dark is the initial theme.
- Added go_router navigation for Home, Tasks, Meals, Calendar, and Shopping. Expenses is reachable from Home.
- Added optional Supabase initialization from `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` Dart defines. The app remains runnable without backend config; no credentials are committed.
- Added a reusable loading/error/retry widget and widget coverage for it, navigation, and theme switching.
- Added Android internet permission and app label, and set the app version to 0.0.1.
- Disabled Kotlin incremental compilation in the Android Gradle project to avoid a Windows cross-drive cache failure between the `C:` Pub cache and `D:` workspace.

## Verification
- `dart format .`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed (4 widget tests).
- `gradlew assembleDebug --console=plain`: passed; Android debug APK assembled.
- No Android emulator/device was attached (`adb devices` was empty), so an installed-device launch smoke check was unavailable.
- database/RLS checks: not applicable in Phase 0; no schema or backend policies added.
- No Git metadata was present in the provided workspace, so Git status/cleanliness could not be verified.

## Security and known issues
- Supabase remains unconfigured until client-safe project URL and publishable key are supplied at build time. Auth, migrations, and RLS begin in Phase 1.
- Android/Gradle emitted deprecation and Android SDK metadata warnings from the installed toolchain and dependencies; the debug APK build succeeded.
- The Windows Kotlin incremental compilation workaround trades build speed for successful cross-drive builds.

## Questions still requiring product review
1. Final Expenses navigation placement.
2. Initial expense category seed list.
3. Exact storage warning thresholds (count, MB, or both).
4. Whether Done tasks stay until manual archive or later gain configurable auto-archive.
5. Default reminder timing for tasks/events/missing ingredients.
6. Whether notification history and activity are combined or separate views.

## Phase handoff format
Agent must update this with: phase completed, concise summary, architecture/schema deviations, migrations, verification results, security/RLS notes, known issues and only material product questions.
