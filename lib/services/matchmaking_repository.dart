import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_repository.dart';

/// صف بازی خودکار: بازیکن اگه بزنه «بازی خودکار»، یا به یه بازیکنِ منتظرِ
/// دیگه وصل می‌شه، یا خودش منتظر می‌مونه تا نفر بعدی پیداش کنه.
/// این جدا از سیستم «چالش/دوئل» است که در آن کاربر یک بازیکن خاص را انتخاب می‌کند.
class MatchmakingRepository {
  static final _queue = FirebaseFirestore.instance.collection('matchmaking_queue');

  /// اگر بازیکن منتظری پیدا شود، اتاق را می‌سازد و roomId را برمی‌گرداند
  /// (یعنی من بازیکن ۱ هستم). اگر کسی نبود، خودم را به صف اضافه می‌کنم و
  /// null برمی‌گردانم (یعنی باید منتظر بمانم).
  static Future<String?> tryQuickMatch({required String myUid, required String myName}) async {
    final snap = await _queue.where('status', isEqualTo: 'waiting').orderBy('createdAt').limit(10).get();

    QueryDocumentSnapshot<Map<String, dynamic>>? found;
    for (final d in snap.docs) {
      if (d.id != myUid) {
        found = d;
        break;
      }
    }

    if (found != null) {
      final otherUid = found.id;
      final otherName = (found.data()['name'] ?? '?').toString();
      final roomId = RoomRepository.generateRoomCode();
      await RoomRepository.createRoom(roomId: roomId, myUid: otherUid, myName: otherName);
      await RoomRepository.joinRoom(roomId: roomId, myUid: myUid, myName: myName);
      await _queue.doc(otherUid).update({'status': 'matched', 'roomId': roomId});
      await _queue.doc(myUid).delete().catchError((_) {});
      return roomId;
    }

    await _queue.doc(myUid).set({
      'uid': myUid,
      'name': myName,
      'status': 'waiting',
      'roomId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyQueueEntry(String myUid) {
    return _queue.doc(myUid).snapshots();
  }

  static Future<void> cancelQueue(String myUid) async {
    try {
      await _queue.doc(myUid).delete();
    } catch (_) {}
  }
}
