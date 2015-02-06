import 'dart:async';
import 'dart:html';
import 'package:samurai/main.dart';


class Client {
  static const Duration RECONNECT_DELAY = const Duration(milliseconds: 500);

  bool connectPending = false;
  String mostRecentSearch = null;
  WebSocket webSocket;
  final DivElement log = new DivElement();
  DivElement contentElement = querySelector('#content');
  DivElement statusElement = querySelector('#status');

  Client() {
    connect();
  }

  void connect() {
    connectPending = false;
    webSocket = new WebSocket('ws://${Uri.base.host}:${Uri.base.port}/ws');
    webSocket.onOpen.first.then((_) {
      onConnected();
      webSocket.onClose.first.then((_) {
        print("Connection disconnected to ${webSocket.url}.");
        onDisconnected();
      });
    });
    webSocket.onError.first.then((_) {
      print("Failed to connect to ${webSocket.url}. "
      "Run bin/server.dart and try again.");
      onDisconnected();
    });
  }

  void onConnected() {
    setStatus('');
    webSocket.onMessage.listen((e) {
      handleMessage(e.data);
    });
  }

  void onDisconnected() {
    if (connectPending) return;
    connectPending = true;
    setStatus('Disconnected. Start \'bin/server.dart\' to continue.');
    new Timer(RECONNECT_DELAY, connect);
  }

  void setStatus(String status) {
    statusElement.innerHtml = status;
  }


  void handleMessage(data) {
    // TODO
  }
}


void main() {
  var client = new Client();
}