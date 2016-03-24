library dartiverse_search;

import 'dart:io';
import 'dart:async';

import 'package:http_server/http_server.dart' as http_server;
import 'package:route/server.dart' show Router;
import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'package:samurai/main.dart';
import 'dart:math';


final Logger log = new Logger('SamuraiServer');

class ServerInterface extends Interface {

  final String gameId;

  ServerInterface(this.gameId);

  Map<String, int> playerNameMap = new Map();
  List<String> playerNameList = new List();
  List<WebSocket> sockets = new List();
  bool gameStarted = false;

  List<Stream<String>> getCommandStreams() => sockets;

  bool addPlayer(String name, WebSocket ws) {
    if (playerNameMap.containsKey(name)) {
      if (sockets[playerNameMap[name]] == null) {
        sockets[playerNameMap[name]] = ws;
        setupSocket(playerNameMap[name]);
        return true;
      } else {
        return false;
      }
    } else if (!gameStarted) {
      playerNameMap[name] = playerNameList.length;
      playerNameList.add(name);
      sockets.add(ws);
      setupSocket(playerNameMap[name]);
      return true;
    } else {
      return false;
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
    sockets[i].listen((String command) {
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

Map<String, Game> games = new Map();

void main() {
  // Set up logger.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var buildPath = Platform.script.resolve('../build/web').toFilePath();
  if (!new Directory(buildPath).existsSync()) {
    log.severe("The 'build/' directory was not found. Please run 'pub build'.");
    return;
  }

  int port = 9223;  // TODO use args from command line to set this

  HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port).then((server) {
    log.info("Samurai server is running on "
    "'http://${server.address.address}:$port/'");
    var router = new Router(server);

    // The client will connect using a WebSocket. Upgrade requests to '/ws' and
    // forward them to 'handleWebSocket'.
    router.serve('/ws')
    .listen((HttpRequest request) {
      String game = request.uri.queryParameters['game'];
      String player = request.uri.queryParameters['name'];

      WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
        if (!games.containsKey(game)) {
          games[game] = new Game(new ServerInterface(game));
        }
        webSocket.handleError((error) => log.warning('Bad WebSocket request'));
        // TODO if player is already in game, don't duplicate
        // TODO else if game is in progress, fail (can't add players to in progress game)
        games[game].players.add(new Player(player));
        (games[game].interface as ServerInterface).addPlayer(player, webSocket);
      });
    });

    // Set up default handler. This will serve files from our 'build' directory.
    var virDir = new http_server.VirtualDirectory(buildPath);
    // Disable jail root, as packages are local symlinks.
    virDir.jailRoot = false;
    virDir.allowDirectoryListing = true;
    virDir.directoryHandler = (dir, request) {
      // Redirect directory requests to index.html files.
      var indexUri = new Uri.file(dir.path).resolve('index.html');
      virDir.serveFile(new File(indexUri.toFilePath()), request);
    };

    // Add an error page handler.
    virDir.errorPageHandler = (HttpRequest request) {
      log.warning("Resource not found: ${request.uri.path}");
      request.response.statusCode = HttpStatus.NOT_FOUND;
      request.response.close();
    };

    // Serve everything not routed elsewhere through the virtual directory.
    virDir.serve(router.defaultStream);

    // Special handling of client.dart. Running 'pub build' generates
    // JavaScript files but does not copy the Dart files, which are
    // needed for the Dartium browser.
    router.serve("/client.dart").listen((request) {
      Uri clientScript = Platform.script.resolve("../web/client.dart");
      virDir.serveFile(new File(clientScript.toFilePath()), request);
    });
  });
}