part of samurai_server;

abstract class BiDirectionalStream {
  Stream<String> get stream;
  void add(String);
}

class ClientWebSocket extends BiDirectionalStream {
  final WebSocket ws;
  ClientWebSocket(this.ws);

  Stream<String> get stream => ws;

  void add(String data) => ws.add(data);
}

class ServerInterface extends Interface {

  final String gameId;

  ServerInterface(this.gameId);

  Map<String, int> playerNameMap = new Map();
  List<String> playerNameList = new List();
  List<BiDirectionalStream> sockets = new List();
  bool gameStarted = false;

  bool addPlayer(String name, WebSocket ws) {
    ClientWebSocket stream = new ClientWebSocket(ws);
    if (playerNameMap.containsKey(name)) {
      if (sockets[playerNameMap[name]] == null) {
        sockets[playerNameMap[name]] = stream;
        setupSocket(playerNameMap[name]);
        return true;
      } else {
        return false;
      }
    } else if (!gameStarted) {
      playerNameMap[name] = playerNameList.length;
      playerNameList.add(name);
      sockets.add(stream);
      setupSocket(playerNameMap[name]);
      return true;
    } else {
      return false;
    }
  }

  bool addAi() {
    if (gameStarted) {
      return false;
    } else {
      AiStream stream = new AiStream(games[gameId], playerNameList.length, this);
      String name = 'Computer 0x' + new Random().nextInt(0xffff).toRadixString(16);
      playerNameMap[name] = playerNameList.length;
      playerNameList.add(name);
      sockets.add(stream);
      setupSocket(playerNameMap[name]);
    }
  }

  void gameStart() {
    int seed = new DateTime.now().millisecondsSinceEpoch;
    this.random = new Random(seed);
    gameStarted = true;
    String startCommand = "-1 start 0x${seed.toRadixString(16)}";
    for (int i = 0; i < sockets.length; i++) {
      startCommand += ' ${playerNameList[i]}';
    }
    update(startCommand);
  }

  void update(String command) {
    sockets.forEach((socket) => socket.add(command));
  }

  void alert(int playerIndex, String msg) {
    sockets[playerIndex].add('-1 alert $msg');
  }

  void setupSocket(int i) {
    sockets[i].stream.listen((String command) {
      if (!gameStarted) {
        if (command == 'start') {
          if (sockets.length < 3) {
            alert(i, "Need at least 3 players, but only have ${sockets.length}");
          } else {
            games[gameId].play();
          }
        } else {
          alert(i, "Game not yet started");
        }
      } else {
        if (this.closureQueue.isEmpty) {
          alert(i, "Please wait for your turn");
        } else {
          InterfaceCallback cb = this.closureQueue.removeFirst();
          if (i != cb.playerIndex) {
            alert(i, "Please wait for your turn");
            this.closureQueue.addFirst(cb);
          } else {
            cb.closure(command);
          }
        }
      }
    },
    onDone: () {
      if (!gameStarted) {
        sockets.removeAt(i);
        String name = playerNameList.removeAt(i);
        playerNameMap.remove(name);
      } else {
        sockets[i] = null;
      }
      if (sockets.isEmpty || sockets.every((s) => s == null)) {
        games.remove(gameId);
      }
    });
  }
}
