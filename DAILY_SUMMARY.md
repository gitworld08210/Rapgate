# Daily Scan Summary - 2025-01-27

**Branch:** `daily/2025-01-27-maintenance` (3 commits)

---

## What Was Fixed

### 1. Critical: `firebase_auth` import causing compile failure
**File:** `lib/screens/settings/settings_screen.dart`
**Risk:** CRITICAL - prevents the app from compiling

The settings screen still imported `package:firebase_auth/firebase_auth.dart` and caught `FirebaseAuthException` in the delete-account flow. This package was removed from `pubspec.yaml` during the Supabase migration, so the app would not compile.

**Fix:** Removed the import and replaced the typed exception catch with a generic `catch (e)` that strips the "Exception: " prefix and displays the error in a SnackBar.

### 2. Dead code cleanup: Firebase/Firestore constants
**File:** `lib/utils/constants.dart`
**Risk:** LOW - dead code only, no runtime impact

Removed 33 lines of unused constants left from the Firebase era:
- 10 Firestore collection path constants
- `functionsRegion` and its comment block
- 8 Cloud Function endpoint constants

All verified with grep to have zero references anywhere in the codebase.

---

## What Was Improved

### 3. Midnight date refresh for food/water streams
**File:** `lib/providers/health_provider.dart`
**Risk:** LOW - self-contained timer addition

The `HealthProvider` subscribed to today's food and water streams at startup, but if the app stayed open past midnight, the dashboard would show yesterday's data until an app restart. Added a `Timer` that fires at midnight+1s and re-subscribes all streams with the new date. Timer is properly cancelled on logout/dispose.

---

## Needs Your Attention

1. **`FirestoreService` naming** - The file `lib/services/firestore_service.dart` is actually backed by Supabase Postgres, not Firestore. The name is confusing. Consider renaming to `database_service.dart` or `data_service.dart` when you have time. This is a cosmetic issue, not a bug.

2. **UPI settings are hardcoded placeholders** - `constants.dart` has `upiId = 'yourname@upi'` and `upiPayeeName = 'RepGate'`. The fine payment screen does fetch dynamic settings from `AppSettingsService` and falls back to these constants, so this works once configured server-side. But if the edge function is not set up, users see a placeholder QR.

3. **No tests exist** - The project has `flutter_test` in dev dependencies but zero test files. Consider adding at least model unit tests for `FoodLogModel.fromMap()`, `FineModel.fromMap()`, etc. to catch regressions.

---

## Suggested Next Steps

- **Rename `FirestoreService`** to something Supabase-appropriate
- **Add unit tests** for model serialization (fromMap/toMap round-trip)
- **Add food log deletion UI** - `FirestoreService.deleteFoodLog()` exists but there's no swipe-to-delete or delete button visible on the food log screen
- **Reports chart improvement** - The month view in reports_screen.dart currently only shows the last 7 days (noted with a TODO comment). Consider weekly aggregation or a scrollable chart.
