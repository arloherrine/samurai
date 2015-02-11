import 'dart:io';
import 'dart:async';
import 'dart:math';

//import 'package:http_server/http_server.dart' as http_server;
//import 'package:route/server.dart' show Router;
import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'package:bushido/main.dart';
import 'package:appengine/appengine.dart';


final Logger log = new Logger('SamuraiServer');

class ServerInterface extends Interface {

  List<WebSocket> sockets = new List();

  List<Stream<String>> getCommandStreams() => sockets;

  void initRandomSeed() {
    int seed = new DateTime.now().millisecondsSinceEpoch;
    this.random = new Random(seed);
    update("-1 seed 0x" + seed.toRadixString(16));
  }

  void update(String command) {
    sockets.forEach((socket) => socket.add(command));
  }

  void alert(int playerIndex, String msg) {
    sockets[playerIndex].add('-1 alert $msg');
  }

  void init() {
    for (int i = 0; i < sockets.length; i++) {
      sockets[i].listen((String command) {
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
      });
    }
  }

}

Map<String, Game> games = new Map();

void main() {
  File logFile = new File('/var/log/app_engine/custom_logs/bushido.log');
  var sink = logFile.openWrite();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    sink.write('${rec.level.name}: ${rec.time}: ${rec.message}');
    sink.flush();
  });

  runAppEngine(requestHandler);
}

void requestHandler(HttpRequest request) {
  if (request.method == 'GET') {
    handleGetRequest(request);
  } else {
    request.response
      ..statusCode = HttpStatus.METHOD_NOT_ALLOWED
      ..write('Unsupported HTTP request method: ${request.method}.')
      ..close();
  }
}

handleGetRequest(HttpRequest request) {
  HttpResponse response = request.response;
  if (request.uri.path == '/ws') {
    String game = request.uri.queryParameters['game'];
//      String player = request.uri.queryParameters['name'];

    WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
      if (!games.containsKey(game)) {
        games[game] = new Game(new ServerInterface());
      }
      webSocket.handleError((error) => log.warning('Bad WebSocket request'));
      games[game].players.add(new Player('Player ' + games[game].players.length.toString()));
      games[game].interface.sockets.add(webSocket);
      if (games[game].players.length > 2) {
        games[game].interface.init();
        games[game].play();
      }
    });
  } else if (request.uri.path == '/') {
    request.response.redirect(Uri.parse('/index.html'));
  } else {
    context.assets.serve();
  }
}

/*
void main_old() {
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
//      String player = request.uri.queryParameters['name'];

      WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
        if (!games.containsKey(game)) {
          games[game] = new Game(new ServerInterface());
        }
        webSocket.handleError((error) => log.warning('Bad WebSocket request'));
        games[game].players.add(new Player('Player ' + games[game].players.length.toString()));
        games[game].interface.sockets.add(webSocket);
        if (games[game].players.length > 2) {
          games[game].interface.init();
          games[game].play();
        }
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
*/