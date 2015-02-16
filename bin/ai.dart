part of samurai_server;

List<List<AiScoreRule>> ruleSets =
    new Directory('ai_rulesets')
      .listSync()
      .where((ent) => ent is File)
      .map((File f) => f.readAsLinesSync().map((line) => new AiScoreRule(line)));

class AiStream extends BiDirectionalStream {
  final Game game;
  final int playerIndex;
  final Interface interface;
  final AiPlayer ai;
  final StreamController<String> streamController;

  AiStream(Game game, int playerIndex, Interface interface)
      : this.game = game,
        this.playerIndex = playerIndex,
        streamController = createStreamController(interface),
        interface = interface,
        ai = new AiPlayer(game, playerIndex, ruleSets[new Random().nextInt(ruleSets.length)]);

  static StreamController<String> createStreamController(Interface interface) {
    StreamController<String> sc = new StreamController();
    // TODO
    return sc;
}

  Stream<String> get stream => streamController.stream;

  void add(String command) {
    if (interface.closureQueue.first.playerIndex == playerIndex) {
      Future<String> nextMove;
      if (game.playerIndex() == playerIndex) {
        nextMove = ai.getNextMove(true); // TODO figure out what to expect
      } else {
        nextMove = ai.getNextMove(false); // TODO figure out what to expect
      }
      nextMove.then((m) => streamController.add(m));
    }
  }
}

class TmpInterface extends Interface {
  final Completer<Map<String, double>> _completer = new Completer();
  final Game game;
  final int playerIndex;
  TmpInterface(this.game, this.playerIndex);

  void gameStart() {}

  void update(String command) {
    _completer.complete(calculateGameStateVars(game, playerIndex));
  }

  void alert(int playerIndex, String msg) {
    _completer.complete(null);
  }

  Future<Map<String, double>> getResultingGameState() {
    return _completer.future;
  }
}

class MoveScorePair {
  final String move;
  final double score;
  MoveScorePair(this.move, this.score);
}

class AiPlayer {
  final Game game;
  final int playerIndex;
  final List<AiScoreRule> rules;

  Map<String, double> gameStateVars;

  AiPlayer(this.game, this.playerIndex, this.rules) {
    gameStateVars = calculateGameStateVars(game, playerIndex);
  }

  Future<double> evaluateMove(String command) {
    Game lazyGame; // TODO implement this
    Function callback = lazyGame.executeAction;
    TmpInterface tmpInterface = new TmpInterface(lazyGame, playerIndex);
    tmpInterface.doAction(playerIndex, lazyGame.players, game.remainingActions(), game.hasMadeDeclaration, callback, command);

    return tmpInterface.getResultingGameState().then((Map<String, double> gameState) {
      if (gameState == null) {
        return double.NEGATIVE_INFINITY;
      }
      double gameVar(String key) => gameState.containsKey(key) ? gameState[key] : 0.0;
      return rules.fold(0, (int score, AiScoreRule rule) {
        return score + rule.score(gameVar);
      });
    });
  }

  Future<String> getNextMove(bool isOurTurn) {
    List<String> moves;
    if (isOurTurn) {
      moves = generateActionMoves();
    } else {
      moves = new List();
      moves.add("$playerIndex dishonored nothing");
      moves.add("$playerIndex dishonored save");
      moves.add("$playerIndex dishonored sepuku daimyo");
      moves.add("$playerIndex dishonored sepuku samurai");
    }

    moves.add("$playerIndex save save");
    moves.add("$playerIndex save dont");

    moves.add("$playerIndex castle take");
    moves.add("$playerIndex castle burn");

    /* TODO only try moves for the expected command
    switch (expectedCommand) {
      case "action":
        moves = generateActionMoves();
        break;
      case "dishonored": // TODO
        break;
      case "save": // TODO
        break;
      case "castle": // TODO
        break;
      default:
        throw new Exception(); // TODO improve error handling
    }
    */

    List<Future<MoveScorePair>> futures = moves.map((m) => evaluateMove(m).then((score) => new MoveScorePair(m, score)));
    return Future.wait(futures)
        .then((pairs) => pairs.reduce((a, b) => a.score - b.score > 0 ? a : b).move);
  }

  List<String> generateActionMoves() {
    List<String> moves = new List();
    if (game.remainingActions() == 0) {
      moves.add("done");
      return moves;
    }
    moves.add("draw");
    moves.add("shogun");

    Player player = game.players[playerIndex];
    bool hasDaimyo = player.daimyo != null;
    String allyOrAttack = hasDaimyo ? "attack" : "ally";
    for (int i = 0; i < game.players.length; i++) {
      moves.add("$allyOrAttack $i");
    }
    if (!hasDaimyo && player.ally != null) {
      moves.add("dissolve");
    }

    for (int i = 0; i < player.hand.length; i++) {
      Card c = player.hand[i];
      if (c is ActionCard) {
        bool justPlayer = c is Daimyo || c is Dishonor;
        bool isAssassin = c is NinjaAssassin;
        bool isNormalSpy = c is NinjaSpy;
        String basePrefix = "play $i";
        for (int j = 0; j < game.players.length; j++) {
          String withTargetPlayer = "$basePrefix $j";
          if (justPlayer) {
            moves.add(withTargetPlayer);
          } else { // need target house
            for (String house in ['samurai', 'daimyo']) {
              String withTargetHouse = "$withTargetPlayer $house";
              if (isAssassin) {
                moves.add(withTargetHouse);
              } else { // ninja spy
                for (int targetCard1 = 0; targetCard1 < 7; targetCard1++) { // TODO could actually check how many cards target house has
                  for (String dest1 in ['daimyo', 'samurai', 'discard']) {
                    String withOneSteal = "$withTargetHouse $targetCard1 $dest1";
                    if (isNormalSpy) {
                      moves.add(withOneSteal);
                    } else { // elite spy
                      for (int targetCard2 = 0; targetCard2 < 7; targetCard2++) { // TODO could actually check how many cards target house has
                        for (String dest2 in ['daimyo', 'samurai', 'discard']) {
                          moves.add("$withOneSteal $targetCard2 $dest2");
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else if (!(player.hand[i] is SaveFace)) {
        if (hasDaimyo) {
          moves.add("put $i daimyo");
        }
        moves.add("put $i samurai");
      }
    }

    return moves.map((c) => "$playerIndex action $c");
  }

}

Map<String, double> calculateGameStateVars(Game game, int playerIndex) {
  Map<String, int> result = new Map();
  Player thisPlayer = game.players[playerIndex];
  for (Card c in thisPlayer.hand) {
  result['CARD_' + reflect(c).type.simpleName.toString()] += 1;
  }

  for (int i = 0; i < game.players.length; i++) {
  String prefix = 'PLAYER_$i';
  Player player = game.players[i];
  result['${prefix}_TOTAL_HONOR'] = player.honor;
  int honorRate = player.calculateHonorGain();
  result['${prefix}_HONOR_RATE'] = honorRate;
  result['${prefix}_HONOR_SEPARATION'] = (honorRate - player.samurai.getHonor()).abs();

  int totalKi = player.getKi();
  result['${prefix}_ACTIONS'] = min(totalKi ~/ 3, 5);
  result['${prefix}_REMAINDER_KI'] = totalKi > 15 ? 0 : totalKi % 3;
  result['${prefix}_EXCESS_KI'] = max(totalKi - 15, 0);
  result['${prefix}_KI_SEPARATION'] = totalKi - player.samurai.getKi();

  result['${prefix}_ATTACK_STRENGTH'] = player.getStrength(true);
  result['${prefix}_DEFEND_STRENGTH'] = player.getStrength(false);
  result['${prefix}_STRENGH_SEPARATION'] = player.getStrength(false) - player.samurai.getStrength();
  }
  return new Map.fromIterables(result.keys, result.values.map((int v) => v.toDouble()));
}

class AiScoreRule {

  /* TODO validation of rules
  static final Set<String> VAR_NAMES = new Set.from([
    "CARD_Army1",
    "CARD_Okugata5",
    ...,
    "PLAYER_THIS_TOTAL_HONOR",
    "PLAYER_SECOND_TOTAL_HONOR",
    "PLAYER_LORD_TOTAL_HONOR",
    "PLAYER_OTHER_TOTAL_HONOR",
    ...
  ]);
  */

  Function calculator;

  AiScoreRule(String rule) {
    List<String> tokens = rule.split(" ");
    double weight = double.parse(tokens[0]);
    calculator = (Map<String, double> gameVars) => weight;
    for (int i = 1; i < tokens.length; i+=2) {
      if (tokens[i] == '*') {
        calculator = (double gameVar(String)) => calculator(gameVar) * gameVar(tokens[i+1]);
      } else if (tokens[i] == '/') {
        calculator = (double gameVar(String)) => calculator(gameVar) / gameVar(tokens[i+1]);
      } else {
        throw new Exception(); // TODO better error handling
      }
    }
  }

  double score(double gameVar(String)) {
    return calculator(gameVar);
  }
}
