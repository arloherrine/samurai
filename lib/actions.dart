part of samurai;

abstract class Action {
  int playerIndex;
  Action(this.playerIndex);

  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions);
}

class EndTurn extends Action {
  EndTurn(int playerIndex) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    return 5;
  }
}

class ShogunDeclaration extends Action {
  ShogunDeclaration(int playerIndex) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    Player player = players[playerIndex];
    if (player.isShogun) {
      throw new InvalidActionException("You're already shogun!");
    }
    if (players.any((p) => p.isShogun)) {
      throw new InvalidActionException("The title of shogun has already been claimed");
    }
    player.isShogun = true;

    return 0;
  }
}

class AttackDeclaration extends Action {
  int targetIndex;
  AttackDeclaration(int playerIndex, this.targetIndex) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    Player player = players[playerIndex];
    Player target = players[targetIndex];

    if (player.daimyo == null) {
      throw new InvalidActionException("You can't attack without a daimyo");
    }
    if (!target.isShogun && !target.daimyo.contents.any((card) => card is Castle)) {
      throw new InvalidActionException("You can only attack the shogun or a castle");
    }

    Random die = new Random();
    int result;
    do {
      result = roll(player, die) - roll(target, die);
      if (result > 0) {
        endBattle(player, target, discard);
      } else if (result < 0) {
        endBattle(target, player, discard);
      }
    } while (result == 0);

    return 0;
  }

  static int roll(Player player, Random die) =>
      new Iterable.generate(player.getStrength() ~/ 3, (x) => die.nextInt(5)).fold(0, (a,b) => a+b);

  void endBattle(Player winner, Player loser, List<Card> discard) {
    Castle castle = loser.daimyo.contents.firstWhere((c) => c is Castle, orElse: () => null);
    if (castle != null) {
      loser.daimyo.contents.remove(castle);
      if (winner.human.getTakeCastle()) {
        Castle oldCastle = winner.daimyo.contents.firstWhere((c) => c is Castle, orElse: () => null);
        if (oldCastle != null) {
          winner.daimyo.contents.remove(oldCastle);
          discard.add(oldCastle);
        }
        winner.daimyo.contents.add(castle);
      } else {
        discard.add(castle);
      }
    }

    if (loser.isShogun || !saveFace(loser, discard)) {
      loser.killHouse(true);
    }

    winner.isShogun = loser.isShogun;
    loser.isShogun = false;
  }

  bool saveFace(Player loser, List<Card> discard) {
    int saveFaceIndex = loser.human.getSaveFace();
    if (saveFaceIndex == -1) {
      return false;
    }

    if (saveFaceIndex >= loser.hand.length) {
      loser.human.alert("Invalid card index");
      return saveFace(loser, discard);
    }

    Card card = loser.hand[saveFaceIndex];
    if (card is SaveFace) {
      loser.hand.removeAt(saveFaceIndex);
      discard.add(card);
      return true;
    } else {
      loser.human.alert("Only save face card can be played after defeat in battle");
      return saveFace(loser, discard);
    }
  }
}

class AllyDeclaration extends Action {
  int targetIndex;
  AllyDeclaration(int playerIndex, this.targetIndex) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    Player player = players[playerIndex];
    if (playerIndex == targetIndex) {
      throw new InvalidActionException("You can't ally with yourself");
    }
    if (player.daimyo != null) {
      throw new InvalidActionException("You can't ally when you have a living daimyo");
    }

    Player target = players[targetIndex];
    if (target.daimyo == null) {
      throw new InvalidActionException("You can't ally with a dead daimyo");
    }
    if (target.ally != null) {
      throw new InvalidActionException("That daimyo already has a second samurai");
    }
    player.ally = target;
    target.ally = player;

    return 0;
  }
}

class DissolveDeclaration extends Action {
  final int HONOR_LOSS = 25;

  DissolveDeclaration(int playerIndex) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    Player player = players[playerIndex];
    if (player.daimyo != null || player.ally == null) {
      throw new InvalidActionException("You don't have an alliance to dissolve");
    }
    player.ally.ally = null;
    player.ally = null;
    player.honor -= HONOR_LOSS;

    return 0;
  }
}

class DrawAction extends Action {
  DrawAction(int playerIndex) : super(playerIndex);

  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    var player = players[playerIndex];
    if (player.hand.length >= MAX_HAND_SIZE) {
      throw new InvalidActionException("You can have at most " + MAX_HAND_SIZE.toString() + " cards in your hand");
    }
    player.hand.add(deck.removeLast());
    return 0;
  }
}

class DiscardAction extends Action {
  int cardIndex;
  DiscardAction(int playerIndex, this.cardIndex) : super(playerIndex);

  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    var player = players[playerIndex];
    if (player.hand.isEmpty) {
      throw new InvalidActionException("You don't have anything to discard");
    }
    if (cardIndex >= player.hand.length) {
      throw new InvalidActionException("Invalid discard index");
    }
    discard.add(player.hand.removeAt(cardIndex));
    return 1;
  }
}

class PutInHouseAction extends Action {
  int cardIndex;
  bool daimyo;
  PutInHouseAction(int playerIndex, this.cardIndex, this.daimyo) : super(playerIndex);

  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    var player = players[playerIndex];
    if (player.hand.isEmpty) {
      throw new InvalidActionException("You don't any cards to play");
    }
    if (cardIndex >= player.hand.length) {
      throw new InvalidActionException("Invalid card index");
    }
    Card card = player.hand[cardIndex];
    if (!(card is StatCard) && !(card is HouseGuard)) {
      throw new InvalidActionException("Can't put that into a house");
    }

    House house;
    if (!daimyo) {
      house = player.samurai;
    } else if (player.daimyo != null) {
      house = player.daimyo;
    } else if (player.ally != null) {
      house = player.ally.daimyo;
    } else {
      throw new InvalidActionException("You don't have a daimyo to put that on.");
    }

    house.putInHouse(card);
    player.hand.removeAt(cardIndex);

    return 1;
  }
}

class PlayOnAction extends Action {
  int cardIndex;
  List targetList;
  PlayOnAction(int playerIndex, this.cardIndex, this.targetList) : super(playerIndex);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, int remainingActions) {
    var player = players[playerIndex];
    if (player.hand.isEmpty) {
      throw new InvalidActionException("You don't any cards to play");
    }
    if (cardIndex >= player.hand.length) {
      throw new InvalidActionException("Invalid card index");
    }
    var card = player.hand[cardIndex];

    if (!(card is ActionCard)) {
      throw new InvalidActionException("Invalid use of card");
    }

    if (remainingActions < card.actionCost()) {
      throw new InvalidActionException("Not enough remaining ki for that action");
    }

    card.perform(player, deck, discard, players, targetList);
    discard.add(player.hand.removeAt(cardIndex));
    return card.actionCost();
  }
}

class InvalidActionException implements Exception {
  final String msg;
  InvalidActionException(this.msg);
  String toString() => "Invalid Action: " + msg;
}