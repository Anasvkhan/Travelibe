import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketClient {
  io.Socket? _socket;
  static const String wsUrl = 'http://localhost:9000';

  // Callbacks
  void Function(Map<String, dynamic> message)? onMessageReceived;
  void Function(String userId, String status)? onPresenceUpdated;
  void Function(String userId, bool isTyping)? onUserTyping;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      print('[WebSocketClient] Cannot connect: missing auth token.');
      return;
    }

    _socket = io.io(wsUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .build()
    );

    _socket?.onConnect((_) {
      print('[WebSocketClient] Connected to gateway.');
    });

    _socket?.onDisconnect((_) {
      print('[WebSocketClient] Disconnected from gateway.');
    });

    // Message events
    _socket?.on('new_message', (data) {
      if (onMessageReceived != null && data is Map<String, dynamic>) {
        onMessageReceived!(data);
      }
    });

    // Presence events
    _socket?.on('presence_update', (data) {
      if (onPresenceUpdated != null && data is Map) {
        onPresenceUpdated!(data['userId'], data['status']);
      }
    });

    // Typing indicators
    _socket?.on('user_typing', (data) {
      if (onUserTyping != null && data is Map) {
        onUserTyping!(data['userId'], data['isTyping']);
      }
    });

    _socket?.connect();
  }

  void sendMessage(String conversationId, String text, {String type = 'TEXT', List<Map<String, dynamic>>? attachments}) {
    if (_socket == null || !_socket!.connected) {
      print('[WebSocketClient] Cannot send message: client offline.');
      return;
    }

    _socket?.emit('send_message', {
      'conversationId': conversationId,
      'text': text,
      'messageType': type,
      'attachments': attachments,
    });
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
