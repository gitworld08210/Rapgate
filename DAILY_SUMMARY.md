# Daily Scan Summary

**Date:** 2025-07-18

---

## What Was Fixed (Committed)

### Commit 1 (`89f61b1`): `fix: remove firebase_auth dependency, add AuthServiceException, clean stale constants`

- Removed `import 'package:firebase_auth/firebase_auth.dart'` from settings_screen.dart (firebase_auth is NOT a project dependency - the project uses Supabase exclusively)
- Fixed `_confirmDeleteAccount` to use generic `catch (e)` instead of `on FirebaseAuthException catch (e)` which could never be caught
- Added `AuthServiceException` class to auth_service.dart (following FineException pattern) - replaces throwing raw Strings
- Removed 20+ stale Firestore/Firebase constants from constants.dart (collection paths, functionsRegion, Cloud Function endpoint names) that are no longer used since Supabase migration

### Commit 2 (`64afc5b`): `feat: add onboarding input validation and water tracker motivational message`

- Added input validation to onboarding body stats: age 13-120, weight 20-300 kg, height 100-250 cm
- Invalid values show inline error text and prevent progression
- Added motivational hydration message to water tracker screen - changes based on progress (5 tiers from "Start your hydration" to "Goal reached")

---

## Items That Need Your Attention (Not Auto-Fixed)

- **Stale midnight subscriptions** (health_provider.dart `_subscribeToStreams`) - if app stays in memory past midnight, food/water streams still query yesterday
- **Reports month-view chart only shows last 7 days** in a 30-day bucket
- **UPI placeholder credentials** in constants.dart (`upiId = 'yourname@upi'`) - must be replaced before production
- **Push-up anti-cheat thresholds are hardcoded** - tuning should be data-driven after real-user testing
- **Notification tap navigation not implemented** - `_onNotificationTapped` in notification_service.dart only does `debugPrint`

---

## Suggested Improvements (For Future Cycles)

1. Implement notification tap navigation (route to pushup_screen, fine_screen, etc. based on payload)
2. Add a midnight refresh timer to re-subscribe health streams when the date changes
3. Make the 3L daily water target customizable per user (currently hardcoded in AppConstants)
4. Add dark mode testing - several screens use hardcoded AppColors without checking brightness
5. Add loading/error states to the Reports screen when data fetch fails

---

## Summary Stats

- **Files modified:** 5 (settings_screen.dart, auth_service.dart, constants.dart, onboarding_screen.dart, water_tracker_screen.dart)
- **Bugs fixed:** 3 (firebase_auth crash risk, raw String throws, stale constants)
- **Features added:** 2 (onboarding validation, water motivation)
- **Risk level:** Low (no database schema, payment logic, or anti-cheat changes)
