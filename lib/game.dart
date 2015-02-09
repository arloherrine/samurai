part of samurai;

final int WINNING_HONOR = 400;
final List<int> SHOGUN_HONOR = [0, 10, 30, 60, 100, 150];
final int MAX_HAND_SIZE = 7;

class Game {

  final List<Player> players = new List();
  final Interface interface;
  int currentTurn = 0;
  int currentActions = 0;
  bool isAnyoneShogun = false;
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
      interface.update("win " + (currentTurn % players.length).toString());
      return;
    }
    scheduleAction();
  }

  void scheduleAction() {
    int playerIndex = currentTurn % players.length;
    interface.requestAction(playerIndex, players, (players[playerIndex].getKi() ~/ 3) - currentActions, executeAction);
  }


  void executeAction(Action action) {
    currentActions += action.perform(deck, discard, players, interface);
    if (deck.isEmpty) {
      var tmp = deck;
      deck = discard;
      discard = tmp;
      deck.shuffle(interface.random);
    }

    if (currentActions < 5) {
      scheduleAction();
    } else {
      currentActions = 0;
      currentTurn++;
      doTurn();
    }
  }


  void play() {
    interface.initRandomSeed();
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
