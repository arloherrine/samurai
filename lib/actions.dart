part of samurai;

abstract class Action {
  int playerIndex;
  Action(this.playerIndex);

  String validate(List<Player> players, int remainingActions);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface);
}

class EndTurn extends Action {
  EndTurn(int playerIndex) : super(playerIndex);

  String validate(players, remainingActions) => null;

  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    return 5;
  }
}

abstract class Declaration extends Action {
  Declaration(int playerIndex) : super(playerIndex);
  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface);
  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    performDeclaration(deck, discard, players, interface);
    return 0;
  }
}

class ShogunDeclaration extends Declaration {
  ShogunDeclaration(int playerIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (player.isShogun) {
      return "You're already shogun!";
    }
    if (players.any((p) => p.isShogun)) {
      return "The title of shogun has already been claimed";
    }
    return null;
  }

  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    players[playerIndex].isShogun = true;
  }
}

class AttackDeclaration extends Declaration {
  int targetIndex;
  AttackDeclaration(int playerIndex, this.targetIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    Player target = players[targetIndex];

    if (player.daimyo == null) {
      return "You can't attack without a daimyo";
    }
    if (!target.isShogun && !target.daimyo.contents.any((card) => card is Castle)) {
      return "You can only attack the shogun or a castle";
    }
    return null;
  }


  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    int result;
    do {
      result = roll(playerIndex, players, interface) - roll(targetIndex, players, interface);
      if (result > 0) {
        endBattle(playerIndex, targetIndex, players, discard, interface);
      } else if (result < 0) {
        endBattle(targetIndex, playerIndex, players, discard, interface);
      }
    } while (result == 0);
  }

  static int roll(int playerIndex, List<Player> players, Interface interface) =>
      interface.roll(playerIndex, players[playerIndex].getStrength() ~/ 3).fold(0, (a,b) => a+b);

  void endBattle(int winnerIndex, int loserIndex, List<Player> players, List<Card> discard, Interface interface) {
    Player winner = players[winnerIndex];
    Player loser = players[loserIndex];

    Castle castle = loser.daimyo.contents.firstWhere((c) => c is Castle, orElse: () => null);
    if (castle != null) {
      loser.daimyo.contents.remove(castle);
      interface.requestTakeCastle(winnerIndex, (bool tookCastle) {
        if (tookCastle) {
          Castle oldCastle = winner.daimyo.contents.firstWhere((c) => c is Castle, orElse: () => null);
          if (oldCastle != null) {
            winner.daimyo.contents.remove(oldCastle);
            discard.add(oldCastle);
          }
          winner.daimyo.contents.add(castle);
        } else {
          discard.add(castle);
        }
      });
    }

    if (loser.isShogun) {
      loser.killHouse(true);
    } else {
      SaveFace saveFaceCard = players[loserIndex].hand.firstWhere((c) => c is SaveFace, orElse:() => null);
      if (saveFaceCard == null) {
        loser.killHouse(true);
      }
      interface.requestSaveFace(loserIndex, (bool saved) {
        if (saved) {
          players[loserIndex].hand.remove(saveFaceCard);
          discard.add(saveFaceCard);
        } else {
          loser.killHouse(true);
        }
      });
    }

    winner.isShogun = loser.isShogun;
    loser.isShogun = false;
  }
}

class AllyDeclaration extends Declaration {
  int targetIndex;
  AllyDeclaration(int playerIndex, this.targetIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (playerIndex == targetIndex) {
      return "You can't ally with yourself";
    }
    if (player.daimyo != null) {
      return "You can't ally when you have a living daimyo";
    }

    Player target = players[targetIndex];
    if (target.daimyo == null) {
      return "You can't ally with a dead daimyo";
    }
    if (target.ally != null) {
      return "That daimyo already has a second samurai";
    }
    return null;
  }

  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    Player player = players[playerIndex];
    Player target = players[targetIndex];
    player.ally = target;
    target.ally = player;
  }
}

class DissolveDeclaration extends Declaration {
  final int HONOR_LOSS = 25;

  DissolveDeclaration(int playerIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (player.daimyo != null || player.ally == null) {
      "You don't have an alliance to dissolve";
    }
  }

  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    Player player = players[playerIndex];
    player.ally.ally = null;
    player.ally = null;
    player.honor -= HONOR_LOSS;
  }
}

class DrawAction extends Action {
  DrawAction(int playerIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    if (players[playerIndex].hand.length >= MAX_HAND_SIZE) {
      return "You can have at most " + MAX_HAND_SIZE.toString() + " cards in your hand";
    }
  }

  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    players[playerIndex].hand.add(deck.removeLast());
    return 0;
  }
}

class DiscardAction extends Action {
  int cardIndex;
  DiscardAction(int playerIndex, this.cardIndex) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (player.hand.isEmpty) {
      return "You don't have anything to discard";
    }
    if (cardIndex >= player.hand.length) {
      return "Invalid discard index";
    }
  }

  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    discard.add(players[playerIndex].hand.removeAt(cardIndex));
    return 1;
  }
}

class PutInHouseAction extends Action {
  int cardIndex;
  bool daimyo;
  PutInHouseAction(int playerIndex, this.cardIndex, this.daimyo) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (player.hand.isEmpty) {
      return "You don't any cards to play";
    }
    if (cardIndex >= player.hand.length) {
      return "Invalid card index";
    }
    Card card = player.hand[cardIndex];
    if (!(card is StatCard) && !(card is HouseGuard)) {
      return "Can't put that into a house";
    }

    House house;
    if (!daimyo) {
      house = player.samurai;
    } else if (player.daimyo != null) {
      house = player.daimyo;
    } else if (player.ally != null) {
      house = player.ally.daimyo;
    } else {
      return "You don't have a daimyo to put that on.";
    }
    return house.validatePutInHouse(card);
  }

  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    Player player = players[playerIndex];
    Card card = player.hand[cardIndex];

    House house;
    if (!daimyo) {
      house = player.samurai;
    } else if (player.daimyo != null) {
      house = player.daimyo;
    } else if (player.ally != null) {
      house = player.ally.daimyo;
    }

    house.contents.add(card);
    player.hand.removeAt(cardIndex);

    return 1;
  }
}

class PlayOnAction extends Action {
  int cardIndex;
  List args;

  PlayOnAction(int playerIndex, this.cardIndex, this.args) : super(playerIndex);

  String validate(players, remainingActions) {
    Player player = players[playerIndex];
    if (player.hand.isEmpty) {
      return "You don't any cards to play";
    }
    if (cardIndex >= player.hand.length) {
      return "Invalid card index";
    }

    var card = player.hand[cardIndex];
    if (!(card is ActionCard)) {
      return "Invalid use of card";
    }

    if (remainingActions < card.actionCost()) {
      return "Not enough remaining ki for that action";
    }
    return card.validate(player, players, args);
  }

  int perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    var player = players[playerIndex];
    ActionCard card = player.hand[cardIndex];
    card.perform(player, discard, players, interface, args);
    discard.add(player.hand.removeAt(cardIndex));
    return card.actionCost();
  }
}
