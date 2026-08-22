import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';

/// یک اتاق بازی آنلاین در Firestore
/// ساختار سند:
/// rooms/{roomId}
///   board: [null, 0, 1, ...]   (9 عضو)
///   pieces: [{owner, cell, previousCell}, ...]
///   currentPlayer: 0|1
///   phase: 'placement' | 'movement' | 'gameOver'
///   winner: null | 0 | 1
///   isDraw: bool
///   remainingToPlace: {'0': int, '1': int}
///   players: { '0': {uid, name, lastSeen}, '1': {...} }
///   createdAt: timestamp
class RoomRepository {
  static final _rooms = FirebaseFirestore.instance.collection('rooms');

  /// یک کد ۶ رقمی ساده برای اتاق (برای وارد کردن دستی هم راحت باشد)
  static String generateRoomCode() {
    final code = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    return code;
  }

  static Future<void> createRoom({
    required String roomId,
    required String myUid,
    required String myName,
  }) async {
    final state = GameState();
    await _rooms.doc(roomId).set({
      'board': state.board,
      'pieces': <Map<String, dynamic>>[],
      'currentPlayer': 0,
      'phase': 'placement',
      'winner': null,
      'isDraw': false,
      'remainingToPlace': {'0': 3, '1': 3},
      'players': {
        '0': {'uid': myUid, 'name': myName, 'lastSeen': FieldValue.serverTimestamp()},
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> joinRoom({
    required String roomId,
    required String myUid,
    required String myName,
  }) async {
    final ref = _rooms.doc(roomId);
    return FirebaseFirestore.instance.runTransaction<String?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return 'not_found';
      final data = snap.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      if (players.containsKey('1')) return 'full';
      if (players['0']?['uid'] == myUid) return null; // خودش صاحب اتاق است
      players['1'] = {'uid': myUid, 'name': myName, 'lastSeen': FieldValue.serverTimestamp()};
      tx.update(ref, {'players': players});
      return null; // بدون خطا
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots();
  }

  static Future<void> updateHeartbeat(String roomId, int myIndex, String myUid) async {
    await _rooms.doc(roomId).update({
      'players.$myIndex.lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> pushState(String roomId, GameState state) async {
    await _rooms.doc(roomId).update({
      'board': state.board,
      'pieces': state.pieces
          .map((p) => {'owner': p.owner, 'cell': p.cell, 'previousCell': p.previousCell})
          .toList(),
      'currentPlayer': state.currentPlayer,
      'phase': state.phase.name,
      'winner': state.winner,
      'isDraw': state.isDraw,
      'remainingToPlace': {
        '0': state.remainingToPlace[0],
        '1': state.remainingToPlace[1],
      },
    });
  }

  static Future<void> declareWinnerByDisconnect(String roomId, int winner) async {
    await _rooms.doc(roomId).update({
      'phase': 'gameOver',
      'winner': winner,
      'endReason': 'opponent_disconnected',
    });
  }

  static Future<void> deleteRoom(String roomId) async {
    await _rooms.doc(roomId).delete();
  }

  /// تبدیل سند Firestore به GameState محلی برای رسم روی صفحه
  static GameState stateFromDoc(Map<String, dynamic> data) {
    final state = GameState();
    state.board = List<int?>.from(data['board'] ?? List<int?>.filled(9, null));
    state.pieces = (data['pieces'] as List<dynamic>? ?? [])
        .map((p) => Piece(
              owner: p['owner'] as int,
              cell: p['cell'] as int,
              previousCell: p['previousCell'] as int?,
            ))
        .toList();
    state.currentPlayer = data['currentPlayer'] as int? ?? 0;
    final phaseStr = data['phase'] as String? ?? 'placement';
    state.phase = GamePhase.values.firstWhere((e) => e.name == phaseStr,
        orElse: () => GamePhase.placement);
    state.winner = data['winner'] as int?;
    state.isDraw = data['isDraw'] as bool? ?? false;
    final remaining = Map<String, dynamic>.from(data['remainingToPlace'] ?? {'0': 3, '1': 3});
    state.remainingToPlace = {
      0: remaining['0'] as int? ?? 0,
      1: remaining['1'] as int? ?? 0,
    };
    return state;
  }
}
