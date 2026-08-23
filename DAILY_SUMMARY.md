# Daily Summary

**Date:** 2025-07-20 automated scan and fix cycle

---

## What Was Fixed (Committed)

### Commit 1: `fix: remove stale firebase_auth import and dead Firebase constants`

| File | Issue | Fix |
|------|-------|-----|
| `lib/screens/settings/settings_screen.dart` | `import 'package:firebase_auth/firebase_auth.dart'` was present but `firebase_auth` is not in `pubspec.yaml`. This causes a compile-breaking error. | Removed the stale import entirely. |
| `lib/screens/settings/settings_screen.dart` | `_confirmDeleteAccount` caught `on FirebaseAuthException` which no longer exists after the Supabase migration. | Replaced with generic exception handling that works with the current Supabase backend. |
| `lib/utils/constants.dart` | 18 dead Firebase/Firestore constants remained (collection paths like `usersCollection`, `foodLogCollection`; Cloud Function endpoints like `identifyProductFn`; `functionsRegion`). | Removed all 18 unused constants. Code now only references Supabase equivalents. |

### Commit 2: `feat: add onboarding validation and migrate deprecated withOpacity calls`

| File | Issue | Fix |
|------|-------|-----|
| `lib/screens/profile/onboarding_screen.dart` | No bounds checking on age, weight, or height inputs. Users could enter 0, negative, or absurdly large values that would propagate to health calculations. | Added validation: age 10-120, weight 20-300 kg, height 80-250 cm. `_canProceed()` now checks numeric ranges, not just non-empty fields. |
| `lib/screens/profile/onboarding_screen.dart` | Silent fallback defaults (e.g., `int.tryParse(val) ?? 0`) masked invalid input without user feedback. | Removed fallback defaults so invalid entries are caught by validation instead of silently stored. |
| `lib/screens/settings/settings_screen.dart` | `.withOpacity()` calls deprecated in Flutter 3.32. | Migrated to `.withValues(alpha:)` syntax. |
| `lib/screens/pushup/pushup_session_screen.dart` | `.withOpacity()` calls deprecated in Flutter 3.32. | Migrated to `.withValues(alpha:)` syntax. |
| `lib/widgets/floating_nav_bar.dart` | `.withOpacity()` calls deprecated in Flutter 3.32. | Migrated to `.withValues(alpha:)` syntax. |

---

## Items That Need Your Attention (Not Auto-Fixed)

| Issue | Location | Why It Was Left |
|-------|----------|-----------------|
| **Stale midnight subscriptions** | `health_provider.dart` `_subscribeToStreams()` | Streams query today's date at subscribe-time. If the app stays alive past midnight, food/water data won't update. Fixing requires lifecycle/timer changes that could introduce regressions. |
| **Reports month-view chart** | `reports_screen.dart` | Only shows last 7 days in month mode (has a TODO comment). Needs a UX decision: scrollable chart, weekly aggregation, or different visualization. |
| **UPI placeholder credentials** | `constants.dart` `upiId = 'yourname@upi'` | Still has placeholder UPI ID. Must be replaced before production use. |
| **Notification TODOs** | `notification_service.dart` | `_onNotificationTapped` is a no-op (just `debugPrint`). Users who tap a notification go nowhere. |
| **Remaining withOpacity calls** | `app_theme.dart`, `scanner_overlay.dart`, other widget files | Additional `.withOpacity()` deprecation warnings remain. Deferred to a future pass to keep this cycle's diff focused. |

---

## Suggested Improvements (For Future Cycles)

1. **Implement notification tap navigation** - Route to the correct screen based on notification payload instead of the current no-op `debugPrint`.

2. **Add a midnight refresh timer** - A `Timer` that cancels and re-subscribes health_provider streams at midnight would solve the stale-date bug properly.

3. **Water goal customization per user** - The 3L daily target is hardcoded in `AppConstants`. Adding it to the user profile would be a small but valuable personalization.

4. **Dark mode audit** - Some screens use hardcoded colors (`AppColors.white`, `AppColors.ink`) without checking brightness. These widgets may render incorrectly in dark mode.

5. **Add unit tests** - No tests exist yet. Start with helper functions, models (`fromMap`/`toMap` round-trips), and service classes for easy coverage wins.

6. **Migrate remaining withOpacity calls** - `app_theme.dart`, `scanner_overlay.dart`, and several widget files still use the deprecated API. A batch migration would clear the warnings.

---

## Summary Stats

- **Files modified:** 7
- **Bugs fixed:** 3 (1 compile-breaking import, 1 dead exception type, 18 dead constants)
- **Features added:** 2 (onboarding input validation with bounds checking, withOpacity deprecation migration)
- **Risk level:** Low (no database schema, payment logic, or anti-cheat changes)
