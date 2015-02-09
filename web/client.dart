import 'dart:async';
import 'dart:html';
import 'package:samurai/main.dart';
import 'dart:math';


class Client {
  static const Duration RECONNECT_DELAY = const Duration(milliseconds: 500);

  bool connectPending = false;
  String mostRecentSearch = null;
  WebSocket webSocket;
  final DivElement log = new DivElement();
  DivElement contentElement = querySelector('#content');
  DivElement statusElement = querySelector('#status');

  ClientInterface interface;
  Game game;

  Client() {
    querySelector('#start_button').onClick.listen(connect);
  }

  void connect(Event e) {
    String gameId = querySelector('#gameId').text;
    String rawPlayerIndex = querySelector('#playerId').text;
    int playerIndex;
    try {
      playerIndex = int.parse(rawPlayerIndex);
    } on FormatException {
      setStatus("Invalid Player index");
      return;
    }
    querySelector('#start_button')..disabled = true
                                  ..text = 'Connected';
    connectPending = false;
    webSocket = new WebSocket('ws://${Uri.base.host}:${Uri.base.port}/ws?game=${gameId}');
    interface = new ClientInterface(playerIndex, webSocket);
    game = new Game(interface);
    interface.game = game;
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
//    webSocket.onMessage.listen((e) {
//      handleMessage(e.data);
//    });
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

class ClientInterface extends Interface {

  final WebSocket webSocket;
  final int localPlayer;

  DivElement contentElement = querySelector('#content');
  DivElement statusElement = querySelector('#status');

  Game game;

  ClientInterface(this.localPlayer, this.webSocket);

  Map<String, Function> _commandDoers;

  void setSeed(String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 2) {
      alert(playerIndex, "Not enough arguments: " + command);
      return;
    }
    if (tokens[0] != "seed") {
      alert(playerIndex, "Expecting seed command but received: " + command);
      return;
    }
    try {
      int seed = int.parse(tokens[1]);
      this.random = new Random(seed);
    } on FormatException {
      alert(playerIndex, "seed must be int: " + command);
    }
    game.play();
  }

  void init() {
    webSocket.onMessage.listen((e) {
      String command = e.data;
      List<String> tokens = command.split(" ");
      switch (tokens[0]) {
        case 'seed':
          setSeed(command); break;
        case 'alert':
          alert(localPlayer, command); break;
        case 'action':
          doAction(command); break;
        case 'dishonored':
          doDishonorResponse(command); break;
        case 'castle':
          doTakeCastle(command); break;
        case 'save':
          doSaveFace(command); break;
        default:
          alert(localPlayer, "Unrecognized command?");
      }
    });
  }

  void initRandomSeed() {
    this.expectedCommand = 'seed';
  }

  List<Stream<String>> getCommandStreams() {
    return new List.from(new Iterable.generate(3, (x) => webSocket)); // TODO get number of players from somewhere
  }

  void update(String command) {
    // TODO update actual UI
  }

  void alert(int playerIndex, String msg) {
    if (playerIndex == localPlayer) {
      statusElement.innerHtml = msg;
    }
  }


}


void main() {
  var client = new Client();
}