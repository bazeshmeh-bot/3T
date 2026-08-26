import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';

/// سرویس بازی نزدیک: از پکیج Google Nearby Connections استفاده می‌کند که
/// خودش تصمیم می‌گیرد بین بلوتوث یا وای‌فای مستقیم کدام را استفاده کند.
class NearbyService {
  static const String serviceId = 'ir.tic3.smart.nearby';
  final Nearby _nearby = Nearby();

  String? connectedEndpointId;
  void Function(Map<String, dynamic> data)? onDataReceived;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(String endpointId, String name)? onEndpointFound;

  Future<void> startAdvertising(String userName) async {
    await _nearby.startAdvertising(
      userName,
      Strategy.P2P_POINT_TO_POINT,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnectedInternal,
      serviceId: serviceId,
    );
  }

  Future<void> startDiscovery(String userName) async {
    await _nearby.startDiscovery(
      userName,
      Strategy.P2P_POINT_TO_POINT,
      onEndpointFound: (id, name, foundServiceId) {
        onEndpointFound?.call(id, name);
      },
      onEndpointLost: (id) {},
      serviceId: serviceId,
    );
  }

  Future<void> requestConnection(String userName, String endpointId) async {
    await _nearby.requestConnection(
      userName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnectedInternal,
    );
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // به‌طور خودکار درخواست اتصال را می‌پذیریم (بدون تأیید دستی کد)
    _nearby.acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) {
        if (payload.bytes != null) {
          try {
            final str = utf8.decode(payload.bytes!);
            final map = jsonDecode(str) as Map<String, dynamic>;
            onDataReceived?.call(map);
          } catch (_) {
            // داده‌ی نامعتبر - نادیده گرفته می‌شود
          }
        }
      },
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      connectedEndpointId = id;
      _nearby.stopAdvertising();
      _nearby.stopDiscovery();
      onConnected?.call();
    }
  }

  void _onDisconnectedInternal(String id) {
    connectedEndpointId = null;
    onDisconnected?.call();
  }

  Future<void> sendData(Map<String, dynamic> data) async {
    if (connectedEndpointId == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    await _nearby.sendBytesPayload(connectedEndpointId!, bytes);
  }

  Future<void> stopAll() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      if (connectedEndpointId != null) {
        await _nearby.disconnectFromEndpoint(connectedEndpointId!);
      }
    } catch (_) {
      // در صورت نبودن اتصال فعال، خطا را نادیده بگیر
    }
  }
}
