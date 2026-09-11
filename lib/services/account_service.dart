import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'prayer_store.dart';

/// Signs the user in with their Google account and keeps the log in step with
/// a copy held under that account.
///
/// Everything here is optional: if Firebase cannot start, or the sign-in is
/// refused, the app carries on exactly as it did before with the log stored on
/// the device. Losing the sync must never cost anyone their prayer log.
class AccountService extends ChangeNotifier {
  AccountService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: <String>['email']);

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final GoogleSignIn _googleSignIn;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  bool _isAvailable = false;
  bool _isBusy = false;
  String? _error;
  DateTime? _lastSyncedAt;

  /// Whether signing in is possible at all on this build and device.
  bool get isAvailable => _isAvailable;
  bool get isBusy => _isBusy;
  String? get error => _error;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  User? get user => _auth?.currentUser;
  bool get isSignedIn => user != null;
  String? get email => user?.email;
  String? get displayName => user?.displayName;
  String? get photoUrl => user?.photoURL;

  /// How long to wait on Firebase before deciding the app runs without it.
  static const Duration _startupTimeout = Duration(seconds: 15);

  /// Brings Firebase up. Safe to call when it is not configured.
  Future<void> init({PrayerStore? store}) async {
    try {
      if (_injectedAuth == null && Firebase.apps.isEmpty) {
        // A bounded wait: an unreachable Firebase should cost the account, not
        // the app.
        await Firebase.initializeApp().timeout(_startupTimeout);
      }
      _auth = _injectedAuth ?? FirebaseAuth.instance;
      _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
      _isAvailable = true;
    } catch (error) {
      // No google-services.json, an unsupported platform, or no network on a
      // cold start: the app stays entirely usable without an account.
      _isAvailable = false;
      _error = '$error';
      notifyListeners();
      return;
    }

    if (isSignedIn && store != null) {
      await sync(store);
    }
    notifyListeners();
  }

  /// Signs in with Google and merges the two logs together.
  ///
  /// Returns false when the user backed out or the sign-in failed.
  Future<bool> signIn(PrayerStore store) async {
    if (!_isAvailable) return false;

    _setBusy(true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // Dismissed the picker — not an error worth showing.
        _setBusy(false);
        return false;
      }

      final auth = await account.authentication;
      await _auth!.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        ),
      );

      await sync(store);
      _error = null;
      _setBusy(false);
      return true;
    } catch (error) {
      _error = '$error';
      _setBusy(false);
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_isAvailable) return;
    _setBusy(true);
    try {
      await _googleSignIn.signOut();
      await _auth!.signOut();
      _lastSyncedAt = null;
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    _setBusy(false);
  }

  /// Pulls the stored copy down, merges it with what is on the device, and
  /// writes the result back.
  ///
  /// Merging both ways rather than picking a winner means a day logged on
  /// either phone survives, which matters more here than being clever.
  Future<void> sync(PrayerStore store) async {
    final uid = user?.uid;
    if (!_isAvailable || uid == null) return;

    try {
      final document = _firestore!.collection('users').doc(uid);
      final snapshot = await document.get();
      final remote = snapshot.data()?['records'];
      if (remote is Map) {
        await store.mergeRecords(
          remote.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      await document.set(<String, dynamic>{
        'records': store.exportRecords(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _lastSyncedAt = DateTime.now();
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
