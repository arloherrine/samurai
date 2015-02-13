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

  bool connected = false;

  ClientInterface interface;
  Game game;

  Client() {
    querySelector('#start_button').onClick.listen(connect);
  }

  void connect(Event e) {
    if (connected) {
      webSocket.send("start");
    } else {
      connected = true;
      String gameId = querySelector('#gameId').value;
      String playerName = querySelector('#playerName').value;
      querySelector('#start_button').text = 'Start Game';
      connectPending = false;
      webSocket = new WebSocket('ws://${Uri.base.host}:${Uri.base.port}/ws?game=${gameId}&name=$playerName');
      interface = new ClientInterface(playerName, webSocket);
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
  }

  void onConnected() {
    setStatus('Connected');
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
}

class ClientInterface extends Interface {

  final WebSocket webSocket;
  final String localPlayerName;
  int localPlayer;

  DivElement contentElement = querySelector('#content');
  DivElement statusElement = querySelector('#status');

  Game game;
  RootDisplayElement displayElement;

  String startCommand;

  ClientInterface(this.localPlayerName, this.webSocket) {
    webSocket.onMessage.listen((e) {
      String command = e.data;
      List<String> tokens = command.split(" ");
      switch (tokens[1]) {
        case 'start':
          startCommand = command;
          game.play();

          displayElement = new RootDisplayElement(game, localPlayer);
          contentElement.append(displayElement.element);

          querySelector('#connection_div').hidden = true;
          querySelector('#command_div').hidden = false;
          querySelector('#command_button').onClick.listen((e) {
            String command = querySelector('#command_input').value;
            webSocket.send(command);
          });

          displayElement.draw();
          break;
        case 'alert':
          alert(localPlayer, command); break;
        default:
          this.closureQueue.removeFirst().closure(command);
      }
    });
  }

  Map<String, Function> _commandDoers;

  void gameStart() {
    List<String> tokens = startCommand.split(" ");
    if (tokens.length < 3) {
      alert(-1, "Not enough arguments: " + startCommand);
      return;
    }
    if (tokens[0] != "-1") {
      alert(-1, "Invalid start command: " + startCommand);
      return;
    }
    if (tokens[1] != "start") {
      alert(-1, "Expecting start command but received: " + startCommand);
      return;
    }
    try {
      int seed = int.parse(tokens[2]);
      this.random = new Random(seed);
    } on FormatException {
      alert(-1, "seed must be int: " + startCommand);
    }

    for (String name in tokens.getRange(3, tokens.length)) {
      if (name == localPlayerName) {
        localPlayer = game.players.length;
      }
      game.players.add(new Player(name));
    }
  }

  List<Stream<String>> getCommandStreams() {
    return new List.from(new Iterable.generate(game.players.length, (x) => webSocket));
  }

  List<String> rolls = new List();

  void update(String command) {
    statusElement.innerHtml = '';
    Element history = querySelector('#command_history');
    history.appendHtml("$command<br />");
    for (String roll in rolls) {
      history.appendHtml("$roll<br />");
    }
    rolls.clear();
    history.scrollTop = history.scrollHeight;
    displayElement.draw();
  }

  void alert(int playerIndex, String msg) {
    if (playerIndex == localPlayer) {
      statusElement.innerHtml = msg;
    }
  }

  Iterable<int> roll(int playerIndex, int dice) {
    Iterable<int> result = super.roll(playerIndex, dice);
    rolls.add(result.map((x) => x.toString()).fold('$playerIndex roll ', (String a, b) => '$a $b'));
    return result;
  }

}

void main() {
  var client = new Client();
}

abstract class GameDisplayElement {
  final Element element;
  GameDisplayElement(this.element);
  void draw();
  // TODO add update method to avoid re-drawing everything
}

class RootDisplayElement extends GameDisplayElement {

  final Game game;
  final int localPlayerIndex;
  final List<PlayerElement> otherPlayers = new List();
  final LocalPlayerElement localPlayer;

  RootDisplayElement(game, localPlayerIndex)
      : super(new DivElement()),
        this.game = game,
        this.localPlayerIndex = localPlayerIndex,
        localPlayer = new LocalPlayerElement(localPlayerIndex, game) {
    for (int i = (localPlayerIndex + 1) % game.players.length; i != localPlayerIndex; i = (i + 1) % game.players.length) {
      otherPlayers.add(new PlayerElement(i, game));
    }
  }

  void draw() {
    element.children.clear(); // TODO update instead of full re-draw
    if (!game.players.any((p) => p.isShogun)) {
      element.appendText("Nobody is Shogun");
    }

    // TODO purely decorative stuff like the deck and discard pile (with stack heights maybe?)

    DivElement otherPlayerDiv = new DivElement();
    element.append(otherPlayerDiv);
    for (PlayerElement e in otherPlayers) {
      otherPlayerDiv.append(e.element);
      e.draw();
    }
    DivElement clearDiv = new DivElement();
    clearDiv.classes.add("clear");
    otherPlayerDiv.append(clearDiv);

    element.append(localPlayer.element);
    localPlayer.draw();
  }
}


class PlayerElement extends GameDisplayElement {
  final int playerIndex;
  final Game game;

  final HouseElement daimyo;
  final HouseElement samurai;

  PlayerElement(playerIndex, game)
      : super(new DivElement()),
        this.playerIndex = playerIndex,
        this.game = game,
        daimyo = new HouseElement(game.players[playerIndex], true),
        samurai = new HouseElement(game.players[playerIndex], false);

  void draw() {
    element.children.clear(); // TODO update instead of full re-draw
    element.style.float = 'left';
    element.style.borderStyle = 'solid';

    Player player = game.players[playerIndex];

    HeadingElement nameEl = new HeadingElement.h2();
    nameEl.appendText(player.name);
    element.append(nameEl);


    DivElement infoDiv = new DivElement();
    element.append(infoDiv);

    SpanElement honorSpan = new SpanElement();
    honorSpan.style.padding = "5px";
    honorSpan.appendText('Honor: ${player.honor}');
    infoDiv.append(honorSpan);


    if (player.isShogun) {
      SpanElement shogunSpan = new SpanElement();
      shogunSpan.style.padding = "5px";
      shogunSpan.appendText('Shogun');
      infoDiv.append(shogunSpan);
    }

    if (player.ally != null) {
      SpanElement allySpan = new SpanElement();
      allySpan.style.padding = "5px";
      allySpan.appendText(player.daimyo == null
          ? 'Second samurai to ${player.ally.name}'
          : 'Second samurai: ${player.ally.name}');
      infoDiv.append(allySpan);
    }

    if (!(this is LocalPlayerElement)) {
      infoDiv.appendText('Hand size: ${player.hand.length.toString()}');
    }

    DivElement daimyoLabel = new DivElement();
    element.append(daimyoLabel);
    daimyoLabel.appendText('Daimyo House: ');
    element.append(daimyo.element);
    daimyo.draw();
    DivElement clearDiv1 = new DivElement();
    clearDiv1.classes.add("clear");
    element.append(clearDiv1);

    DivElement samuraiLabel = new DivElement();
    element.append(samuraiLabel);
    samuraiLabel.appendText('Samurai House: ');
    element.append(samurai.element);
    samurai.draw();
    DivElement clearDiv2 = new DivElement();
    clearDiv2.classes.add("clear");
    element.append(clearDiv2);

    bool isTurn = game.playerIndex() == playerIndex;
    bool isActive = game.interface.closureQueue.first.playerIndex == playerIndex;

    if (isTurn) {
      element.style.borderColor = 'green';
      element.style.borderWidth = isActive ? '6px' : '2px';

      DivElement activeDiv = new DivElement();
      element.append(activeDiv);

      SpanElement actionsSpan = new SpanElement();
      actionsSpan.style.padding = "5px";
      actionsSpan.appendText('Remaining actions: ${game.remainingActions()}');
      activeDiv.append(actionsSpan);

      SpanElement declarationSpan = new SpanElement();
      declarationSpan.style.padding = "5px";
      declarationSpan.appendText(game.hasMadeDeclaration ? 'Declaration done' : 'Declaration available');
      activeDiv.append(declarationSpan);
    } else if (isActive) {
      element.style.borderColor = 'orange';
      element.style.borderWidth = '6px';
    } else {
      element.style.borderColor = 'gray';
      element.style.borderWidth = '2px';
    }
  }
}



class LocalPlayerElement extends PlayerElement {

  LocalPlayerElement(playerIndex, game) : super(playerIndex, game);

  void draw() {
    super.draw();
    element.style.float = 'none';

    Player player = game.players[playerIndex];
    element.appendText('Hand: ');

    DivElement handDiv = new DivElement();
    handDiv.style.height = '4em';

    element.append(handDiv);
    if (player.hand.isEmpty) {
      handDiv.appendText('<Empty>');
    }
    for (Card c in player.hand) {
      CardElement card = new CardElement(c);
      handDiv.append(card.element);
      card.draw();
    }
    DivElement clearDiv = new DivElement();
    clearDiv.classes.add("clear");
    handDiv.append(clearDiv);
  }

  }

class HouseElement extends GameDisplayElement {
  final Player player;
  final bool daimyo;

  HouseElement(this.player, this.daimyo) : super(new DivElement());

  void draw() {
    element.children.clear(); // TODO update instead of full re-draw

    House house = daimyo ? player.daimyo : player.samurai;
    if (house == null) {
      element.appendText('<Empty>');
      return;
    }

    DivElement cardsDiv = new DivElement();
    element.style.height = '4em';
    element.append(cardsDiv);

    CardElement head = new CardElement(house.head);
    cardsDiv.append(head.element);
    head.draw();
    for (Card c in house.contents) {
      CardElement card = new CardElement(c);
      cardsDiv.append(card.element);
      card.draw();
    }
    DivElement clearDiv = new DivElement();
    clearDiv.classes.add("clear");
    element.append(clearDiv);
  }
}

class CardElement extends GameDisplayElement {
  final Card card;
  CardElement(this.card) : super(new DivElement());

  void draw() {
    element.style..width = '8em'
                 ..height = '4em'
                 ..borderStyle = 'inset'
                 ..borderWidth = '2px'
                 ..float = 'left'
                 ..position = 'relative';

    DivElement nameDiv = new DivElement();
    nameDiv.style.textAlign = 'center';
    nameDiv.appendText(card.name);
    element.append(nameDiv);
    // TODO instructions for non-stat cards
    if (card is StatCard) {
      StatCard card = this.card;

      DivElement statWrapper = new DivElement();
      statWrapper.style..position = 'absolute'
                       ..bottom = '0'
                       ..width = '100%';
      element.append(statWrapper);

      DivElement statDiv = new DivElement();
      statDiv.style..display = 'table'
                   ..margin = '0 auto';
      statDiv.appendText('${card.honor} ${card.ki} ${card.strength}');
      statWrapper.append(statDiv);
    }
  }

}