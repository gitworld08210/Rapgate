# Daily Summary

**Date:** 2026-08-23

---

## What Was Fixed (Committed)

### Bug Fixes

| File | Issue | Fix |
|------|-------|-----|
| `lib/screens/settings/settings_screen.dart` | Build-breaking `import 'package:firebase_auth/firebase_auth.dart'` - package not in pubspec after Supabase migration. | Removed the import and replaced `on FirebaseAuthException` with generic `catch (e)` handling. |
| `lib/services/auth_service.dart` | `_handleAuthException` returned a raw `String` that was thrown directly; catching as `on Exception` would never work. | Added `AuthException` class (similar to `FineException`). All throw sites now wrap properly. |
| `lib/screens/profile/onboarding_screen.dart` | No input validation on onboarding fields - any value (including nonsense) was accepted. | Added range validation: age 1-120, weight 20-500 kg, height 50-300 cm. |
| `lib/utils/constants.dart` | Comments still referenced Firebase Cloud Functions despite full Supabase migration. | Updated comments to reference Supabase Edge Functions. |

### Features Added

| Feature | Details |
|---------|---------|
| Food log deletion feedback | `food_log_screen.dart` now shows a SnackBar ("Food log removed") after deletion instead of silently removing the entry. |
| Water log swipe-to-delete | `water_tracker_screen.dart` water log entries can be swiped end-to-start to delete, with red background + delete icon and SnackBar confirmation. |
| HealthProvider delete methods | Added `deleteFoodLog(logId)` and `deleteWaterLog(logId)` to `health_provider.dart` for cleaner architecture (screens no longer call FirestoreService directly for deletions). |

---

## Items That Need Your Attention (Not Auto-Fixed)

| Issue | Location | Why It Was Left |
|-------|----------|-----------------|
| **Stale midnight subscriptions** | `health_provider.dart` `_subscribeToStreams()` | If the app stays in memory past midnight, food/water streams still query yesterday. Fixing requires lifecycle/timer changes. |
| **Reports month-view chart** | `reports_screen.dart` | Only shows last 7 days in month mode. Needs a UX decision: scrollable chart, weekly aggregation, or different visualization. |
| **UPI placeholder credentials** | `constants.dart` `upiId = 'yourname@upi'` | Still has placeholder UPI ID. Must be replaced before production use. |
| **Push-up anti-cheat thresholds** | `constants.dart` / Cloud Functions | Thresholds are hardcoded. Any tuning should be data-driven after real-user testing. |
| **Notification tap navigation TODOs** | `notification_service.dart` | `_handleMessageOpenedApp` and `_onNotificationTapped` have TODO stubs - tapping a notification goes nowhere. |

---

## Suggestions for Next Cycle

1. **Implement notification tap navigation** - Users who tap a push notification currently go nowhere. Wire up the route parsing logic in `notification_service.dart`.

2. **Add a midnight refresh timer** - A simple `Timer` that cancels and re-subscribes streams at midnight would solve the stale-date bug cleanly.

3. **Add custom water goal** - The 3L daily target is hardcoded in `AppConstants`. Adding it to the user profile would be a small but valuable personalization.

4. **Dark mode audit** - The dark theme is defined but several screens use hardcoded `AppColors.white` and `AppColors.ink` without checking brightness. Some widgets may look incorrect in dark mode.

---

## Summary Stats

- **Bugs fixed:** 4 (1 build-breaking import, 1 exception handling, 1 missing validation, 1 stale comments)
- **Features added:** 3 (food log deletion feedback, water log swipe-to-delete, HealthProvider delete methods)
- **Risk level:** Low (no database schema, payment logic, or anti-cheat changes)
