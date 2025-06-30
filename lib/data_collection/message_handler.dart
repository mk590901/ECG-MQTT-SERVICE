import 'dart:async';

class MessageHandler<T> {
  final _controller = StreamController.broadcast();

  // Send message
  void sendMessage(T message) {
    _controller.add(message);
  }

  // Receive message
  Stream get messages => _controller.stream;

  void dispose() {
    _controller.close();
  }
}