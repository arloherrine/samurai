part of samurai;

final int WINNING_HONOR = 400;
final List<int> SHOGUN_HONOR = [0, 10, 30, 60, 100, 150];
final int MAX_HAND_SIZE = 7;

class Game {

  final List<Player> players = new List();
  int currentTurn = 0;
  int currentActions = 0;
  bool isAnyoneShogun = false;
  List<Card> deck;
  List<Card> discard = new List();
  List<String> commandHistory = new List();

  bool doTurn() {
    Player player = players[currentTurn % players.length];

    player.honor += player.calculateHonorGain();
    if (player.isShogun) {
      player.honor += SHOGUN_HONOR[players.length];
    }
    if (player.honor >= WINNING_HONOR) {
      return true;
    }

    while (currentActions < 5) {
      Action action = player.human.getAction();
      if (action.playerIndex != currentTurn % players.length) {
        player.human.alert("You can only submit moves for yourself!");
      } else {
        try {
          currentActions += action.perform(deck, discard, players, (player.getKi() ~/ 3) - currentActions);
          // TODO now that we know command is valid, update command history list and update players
        } on InvalidActionException catch (e) {
          player.human.alert(e.msg);
        }
      }
      if (deck.isEmpty) {
        var tmp = deck;
        deck = discard;
        discard = tmp;
        deck.shuffle();
      }
    }

    currentActions = 0;
    currentTurn++;
    return false;
  }


  void play() {
    List<Card> daimyos = createDaimyos();
    Random rand = new Random();
    for (Player player in players) {
      player.daimyo = new House.daimyo(daimyos.removeAt(rand.nextInt(daimyos.length)));
    }

    deck = createDeck(daimyos);

    for (var i = 0; i < 7; i++) {
      for (Player player in players) {
        player.hand.add(deck.removeLast());
      }
    }

    //TODO put initial state into command history

    while(!doTurn());

    for (Player player in players) {
      player.human.alert("Game over, player " + (currentTurn % players.length).toString() + " wins! Thanks for playing");
    }
  }
}
