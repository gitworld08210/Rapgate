// Legacy re-export: the service was renamed from FirestoreService to
// DatabaseService since the app now uses Supabase Postgres, not Firestore.
// This file exists only to prevent breakage in files that still import
// 'firestore_service.dart'. New code should import 'database_service.dart'.
import 'database_service.dart';

export 'database_service.dart';

/// @deprecated Use [DatabaseService] instead.
typedef FirestoreService = DatabaseService;
