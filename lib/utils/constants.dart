/// App-wide constants
class AppConstants {
  // Push-up configuration
  static const int defaultPushupTarget = 10;
  static const int maxPushupTarget = 25;
  static const int pushupTargetIncrementPerWeek = 1;
  static const int unlockDurationHours = 24;

  // Anti-cheat thresholds
  static const double minElbowAngleFlexed = 60.0; // degrees
  static const double maxElbowAngleExtended = 160.0; // degrees
  static const double faceVisibilityThreshold = 0.90; // 90% of frames
  static const double minTimePerRepMs = 800; // minimum 0.8s per rep
  static const double maxTimePerRepMs = 8000; // maximum 8s per rep
  static const double motionVarianceThreshold = 0.01; // reject if < this

  // Fine configuration
  static const int defaultFineAmountPaise = 5000; // ₹50 in paise
  static const String currency = 'INR';

  // ---------------- Manual UPI settlement ----------------
  // Fines are settled by UPI transfer and verified manually by an admin.
  // TODO(BEFORE_PRODUCTION): Replace placeholder UPI ID with actual payment details.
  // TODO: replace with your real UPI details before use.
  static const String upiId = 'yourname@upi';
  static const String upiPayeeName = 'HealthPush';

  /// Optional: bundle a static QR image at this path and it will be shown
  /// instead of the generated one. Leave null to render the QR from `upiId`.
  static const String? upiQrAssetPath = null; // e.g. 'assets/images/upi_qr.png'

  /// UTR / UPI reference numbers are 12 digits for most banks, but some
  /// PSPs return alphanumeric refs, so we validate loosely.
  static const int utrMinLength = 8;
  static const int utrMaxLength = 24;

  static const int maxScreenshotBytes = 5 * 1024 * 1024; // 5 MB

  // Water tracking
  static const int dailyWaterTargetMl = 3000;
  static const List<int> waterQuickAddOptions = [250, 500, 750, 1000];

  // Emergency unlock limits
  static const int maxEmergencyUnlocksPerWeek = 2;

  // Default allowlisted packages (essential apps that should never be blocked)
  static const List<String> defaultAllowlistPackages = [
    'com.android.dialer',
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.whatsapp', // debatable - user can remove from allowlist
    'net.one97.paytm',
    'com.phonepe.app',
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.android.settings',
    'com.android.systemui',
    'com.android.launcher',
    'com.android.launcher3',
    'com.google.android.dialer',
    'com.google.android.contacts',
    'com.android.emergency',
  ];

  // Common social/entertainment apps to suggest for blocking
  static const Map<String, String> suggestedBlockApps = {
    'com.instagram.android': 'Instagram',
    'com.twitter.android': 'X (Twitter)',
    'com.facebook.katana': 'Facebook',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok (Alt)',
    'com.google.android.youtube': 'YouTube',
    'com.reddit.frontpage': 'Reddit',
    'com.snapchat.android': 'Snapchat',
    'com.linkedin.android': 'LinkedIn',
    'com.pinterest': 'Pinterest',
    'tv.twitch.android.app': 'Twitch',
    'com.netflix.mediaclient': 'Netflix',
    'com.amazon.avod.thirdpartyclient': 'Prime Video',
    'in.startv.hotstar': 'Disney+ Hotstar',
    'com.jio.media.ondemand': 'JioCinema',
  };

  // Firestore collection paths
  static const String usersCollection = 'users';
  static const String foodLogsSubcollection = 'food_logs';
  static const String waterLogsSubcollection = 'water_logs';
  static const String weightLogsSubcollection = 'weight_logs';
  static const String pushupSessionsSubcollection = 'pushup_sessions';
  static const String blockedAppsConfigDoc = 'blocked_apps_config';
  static const String streaksDoc = 'streaks';
  static const String finesSubcollection = 'fines';
  static const String emergencyUnlocksSubcollection = 'emergency_unlocks';
  static const String accountabilityLinksCollection = 'accountability_links';

  /// Region the Cloud Functions are deployed to.
  ///
  /// MUST match `RUNTIME.region` in firebase/functions/src/config.ts.
  /// `FirebaseFunctions.instance` defaults to us-central1, so calling a
  /// function deployed elsewhere fails with `[not-found] NOT_FOUND` — always
  /// go through `FirebaseFunctions.instanceFor(region: functionsRegion)`.
  static const String functionsRegion = 'asia-south1';

  // Cloud Function endpoints
  static const String cfScanFoodImage = 'scanFoodImage';
  static const String cfSearchFoodByBarcode = 'searchFoodByBarcode';
  static const String cfStartPushupSession = 'startPushupSession';
  static const String cfSubmitPushupFrameBatch = 'submitPushupFrameBatch';

  // Manual UPI fine settlement
  static const String cfSubmitFineProof = 'submitFineProof';
  static const String cfReviewFine = 'reviewFine';
  static const String cfClaimAdminRole = 'claimAdminRole';

  // Accountability
  static const String cfSetAccountabilityContact = 'setAccountabilityContact';
}
