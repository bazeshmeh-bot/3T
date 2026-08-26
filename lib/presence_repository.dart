import 'package:cloud_firestore/cloud_firestore.dart';

/// مدیریت حضور آنلاین بازیکنان (برای نمایش لیست «چه کسی الان آنلاینه»)
/// و سیستم چالش/دوئل مستقیم بین دو بازیکن.
class PresenceRepository {
  static final _presence = FirebaseFirestore.instance.collection('presence');
  static final _challenges = FirebaseFirestore.instance.collection('challenges');

  static Future<void> goOnline(String uid, String name) async {
    final ref = _presence.doc(uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'name': name,
        'lastSeen': FieldValue.serverTimestamp(),
        'inGame': false,
      });
    } else {
      await ref.set({
        'uid': uid,
        'name': name,
        'wins': 0,
        'gamesPlayed': 0,
        'lastSeen': FieldValue.serverTimestamp(),
        'inGame': false,
      });
    }
  }

  static Future<void> heartbeat(String uid) async {
    try {
      await _presence.doc(uid).update({'lastSeen': FieldValue.serverTimestamp()});
    } catch (_) {
      // اگر سند حذف شده بود، نادیده بگیر
    }
  }

  static Future<void> setInGame(String uid, bool inGame) async {
    try {
      await _presence.doc(uid).update({'inGame': inGame});
    } catch (_) {}
  }

  static Future<void> goOffline(String uid) async {
    try {
      await _presence.doc(uid).delete();
    } catch (_) {}
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchOnlinePlayers() {
    return _presence.orderBy('lastSeen', descending: true).limit(50).snapshots();
  }

  static Future<void> recordResult(String uid, {required bool won}) async {
    try {
      await _presence.doc(uid).update({
        'gamesPlayed': FieldValue.increment(1),
        if (won) 'wins': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  // ---------------- چالش / دوئل ----------------

  static Future<void> sendChallenge({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String roomId,
  }) async {
    await _challenges.doc(toUid).set({
      'roomId': roomId,
      'fromUid': fromUid,
      'fromName': fromName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyChallenge(String myUid) {
    return _challenges.doc(myUid).snapshots();
  }

  static Future<void> clearChallenge(String myUid) async {
    try {
      await _challenges.doc(myUid).delete();
    } catch (_) {}
  }
}
