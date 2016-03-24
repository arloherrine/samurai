part of samurai;

final int WINNING_HONOR = 400;
final List<int> SHOGUN_HONOR = [0, 10, 30, 60, 100, 150];
final int MAX_HAND_SIZE = 7;

class Game {

  final List<Player> players = new List();
  final Interface interface;
  int currentTurn = 0;
  int currentActions = 0;
  bool hasMadeDeclaration = false;
  List<Card> deck;
  List<Card> discard = new List();

  Game(this.interface);

  void doTurn() {
    Player player = players[currentTurn % players.length];

    player.honor += player.calculateHonorGain();
    if (player.isShogun) {
      player.honor += SHOGUN_HONOR[players.length];
    }
    if (player.honor >= WINNING_HONOR) {
      interface.update("-1 win " + (currentTurn % players.length).toString());
      return;
    }
    scheduleAction();
  }

  void scheduleAction() {
    interface.requestAction(playerIndex(), players, remainingActions(), hasMadeDeclaration, executeAction);
  }

  int playerIndex() => currentTurn % players.length;

  int remainingActions() {
    int actions = 0;
    if (currentActions < 5) {
      actions = (players[playerIndex()].getKi() ~/ 3) - currentActions;
      if (actions < 0) {
        actions = 0;
      }
    }
    return actions;
  }

  void executeAction(Action action) {
    action.perform(deck, discard, players, interface);
    currentActions += action.actions;
    if (action is Declaration) {
      hasMadeDeclaration = true;
    }
    if (deck.isEmpty) {
      var tmp = deck;
      deck = discard;
      discard = tmp;
      deck.shuffle(interface.random);
    }

    if (action is EndTurn) {
      currentActions = 0;
      currentTurn++;
      hasMadeDeclaration = false;
      doTurn();
    } else {
      scheduleAction();
    }
  }

  CommandPart getCommandTree() {
    return new CommandToken.root(playerIndex(), players, remainingActions(), hasMadeDeclaration);
  }

  void play() {
    interface.gameStart();
    List<Card> daimyos = createDaimyos();
    for (Player player in players) {
      player.daimyo = new House.daimyo(daimyos.removeAt(interface.random.nextInt(daimyos.length)));
    }

    deck = createDeck(daimyos);
    deck.shuffle(interface.random);

    for (var i = 0; i < 7; i++) {
      for (Player player in players) {
        player.hand.add(deck.removeLast());
      }
    }

    doTurn();
  }
}
