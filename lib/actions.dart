part of samurai;

abstract class Action {
  final int playerIndex;
  int actions;
  Action(this.playerIndex, this.actions);

  String validate(List<Player> players, int remainingActions) {
    String msg = validateImpl(players);
    if (msg != null) {
      return msg;
    } else if (actions > remainingActions) {
      return "Need $actions actions for that, but only have $remainingActions remaining;";
    } else {
      return null;
    }
  }


  String validateImpl(List<Player> players);
  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface);
}

class EndTurn extends Action {
  EndTurn(int playerIndex) : super(playerIndex, 0);

  String validateImpl(players) => null;

  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {}
}

abstract class Declaration extends Action {
  Declaration(int playerIndex) : super(playerIndex, 0);
  void performDeclaration(List<Card> deck, List<Card> discard, List<Player> players, Interface interface);
  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    performDeclaration(deck, discard, players, interface);
  }
}

class ShogunDeclaration extends Declaration {
  ShogunDeclaration(int playerIndex) : super(playerIndex);

  String validateImpl(players) {
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

  String validateImpl(players) {
    if (playerIndex == targetIndex) {
      return "You can't attack yourself";
    }

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
      result = roll(playerIndex, players, true, interface) - roll(targetIndex, players, false, interface);
      if (result > 0) {
        endBattle(playerIndex, targetIndex, players, discard, interface);
      } else if (result < 0) {
        endBattle(targetIndex, playerIndex, players, discard, interface);
      }
    } while (result == 0);
  }

  static int roll(int playerIndex, List<Player> players, bool attacking, Interface interface) =>
      interface.roll(playerIndex, players[playerIndex].getStrength(attacking) ~/ 3).fold(0, (a,b) => a+b);

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
      discard.addAll(loser.killHouse(true));
    } else {
      SaveFace saveFaceCard = players[loserIndex].hand.firstWhere((c) => c is SaveFace, orElse:() => null);
      if (saveFaceCard == null) {
        discard.addAll(loser.killHouse(true));
      } else {
        interface.requestSaveFace(loserIndex, (bool saved) {
          if (saved) {
            players[loserIndex].hand.remove(saveFaceCard);
            discard.add(saveFaceCard);
          } else {
            discard.addAll(loser.killHouse(true));
          }
        });
      }
    }

    winner.isShogun = winner.isShogun || loser.isShogun;
    loser.isShogun = false;
  }
}

class AllyDeclaration extends Declaration {
  int targetIndex;
  AllyDeclaration(int playerIndex, this.targetIndex) : super(playerIndex);

  String validateImpl(players) {
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

  String validateImpl(players) {
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
  DrawAction(int playerIndex) : super(playerIndex, 1);

  String validateImpl(players) {
    if (players[playerIndex].hand.length >= MAX_HAND_SIZE) {
      return "You can have at most " + MAX_HAND_SIZE.toString() + " cards in your hand";
    }
  }

  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    players[playerIndex].hand.add(deck.removeLast());
  }
}

class DiscardAction extends Action {
  int cardIndex;
  DiscardAction(int playerIndex, this.cardIndex) : super(playerIndex, 1);

  String validateImpl(players) {
    Player player = players[playerIndex];
    if (player.hand.isEmpty) {
      return "You don't have anything to discard";
    }
    if (cardIndex >= player.hand.length) {
      return "Invalid discard index";
    }
  }

  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    discard.add(players[playerIndex].hand.removeAt(cardIndex));
  }
}

class PutInHouseAction extends Action {
  int cardIndex;
  bool daimyo;
  PutInHouseAction(int playerIndex, this.cardIndex, this.daimyo) : super(playerIndex, 1);

  String validateImpl(players) {
    Player player = players[playerIndex];
    if (player.hand.isEmpty) {
      return "You don't any cards to play";
    }
    if (cardIndex >= player.hand.length) {
      return "Invalid card index";
    }
    Card card = player.hand[cardIndex];
    if (card is ActionCard || card is SaveFace) {
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

  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
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
  }
}

class PlayOnAction extends Action {
  int cardIndex;
  List args;

  PlayOnAction(int playerIndex, this.cardIndex, this.args) : super(playerIndex, -1);

  String validateImpl(players) {
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

    this.actions = card.actionCost();

    return card.validate(player, players, args);
  }

  void perform(List<Card> deck, List<Card> discard, List<Player> players, Interface interface) {
    Player player = players[playerIndex];
    ActionCard card = player.hand[cardIndex];
    card.perform(playerIndex, discard, players, interface, args);
    discard.add(player.hand.removeAt(cardIndex));
  }
}
