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

  void alert(String msg) {

  }

  DishonorResponse getDishonorResponse() {

  }

  bool getTakeCastle() {

  }

  int getSaveFace() {

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
          games[game] = new Game();
        }
        Stream broadcast = webSocket.asBroadcastStream(onCancel: (StreamSubscription ss) => ss.cancel());
        broadcast.handleError((error) => log.warning('Bad WebSocket request'));
        games[game].players.add(new Player(new ServerHuman(broadcast)));
        if (games[game].players.length > 2) {
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