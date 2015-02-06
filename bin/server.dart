library dartiverse_search;

import 'dart:io';
import 'dart:async';

import 'package:http_server/http_server.dart' as http_server;
import 'package:route/server.dart' show Router;
import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'package:samurai/main.dart';


final Logger log = new Logger('SamuraiServer');


class ServerHuman extends Human {
  Stream inputStream;

  ServerHuman(this.inputStream);

  Action getAction() {

  }

  void updateDisplay(Game game) {

  }

  void actionFailed(String msg) {

  }

  DishonorResponse getDishonorResponse() {

  }

  bool getTakeCastle() {

  }

  int getSaveFace() {

  }
}

Map<String, Stream> lobby = new Map();
Map<String, StreamSubscription> gameStartSubscriptions = new Map();
Map<int, Game> games = new Map();

/**
 * Handle an established [WebSocket] connection.
 *
 * The WebSocket can send search requests as JSON-formatted messages,
 * which will be responded to with a series of results and finally a done
 * message.
 */
void handleWebSocket(WebSocket webSocket) {
  log.info('New WebSocket connection');

  webSocket.handleError((error) => log.warning('Bad WebSocket request'));
  Stream broadcast = webSocket.asBroadcastStream(onCancel: (StreamSubscription ss) => ss.cancel());
  broadcast.first.then((String command) {
    List<String> parts = command.split(" ");
    if (parts.length != 2 || parts[0] != "name") {
      webSocket.close(-1, "name command must be first command");
    } else {
      lobby[parts[1]] = broadcast;
      gameStartSubscriptions[parts[1]] = broadcast.listen((String command) {
        List<String> parts = command.split(" ");
        if (parts[0] != "start") {
          webSocket.add("Only valid command is 'start'");
        } else {
          List<String> names = parts.getRange(1, parts.length);
          Map<String, Stream> streams = new Map();
          for (String name in names) {
            streams[name] = lobby.remove(name);
            gameStartSubscriptions[name].cancel();
            gameStartSubscriptions.remove(name);
          }
          // TODO create game from name/stream pairs
        }
      });
    }
  });

  new ServerHuman(broadcast);
}

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
    .transform(new WebSocketTransformer())
    .listen(handleWebSocket);

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