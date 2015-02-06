part of samurai;

final int WINNING_HONOR = 400;
final List<int> SHOGUN_HONOR = [0, 10, 30, 60, 100, 150];
final int MAX_HAND_SIZE = 7;

class Game {

  List<Player> players;
  int currentTurn;
  int currentActions;
  bool isAnyoneShogun = false;
  List<Card> deck;
  List<Card> discard;

  bool doTurn() {
    var player = players[currentTurn % players.length];

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
        player.human.actionFailed("You can only submit moves for yourself!");
      } else {
        try {
          currentActions += action.perform(deck, discard, players, (player.getKi() / 3) - currentActions);
        } on InvalidActionException catch (e) {
          player.human.actionFailed(e.msg);
        }
      }
      if (deck.isEmpty) {
        var tmp = deck;
        deck = discard;
        discard = tmp;
        deck.shuffle();
      }
    }

    currentTurn++;
    return false;
  }


}
