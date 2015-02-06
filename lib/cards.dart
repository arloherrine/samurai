part of samurai;


abstract class Card {
  String name;
  Card(this.name);
}

class StatCard extends Card {
  int honor;
  int ki;
  int strength;

  StatCard(name, this.honor, this.ki, this.strength) : super(name);

  bool isNinjaProof() => false;
}

class Daimyo extends StatCard implements ActionCard {
  Daimyo(int honor, int ki, int strength) : super ("Daimyo", honor, ki, strength);

  int actionCost() => 1;

  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List args) {
    if (args.length != 1) {
      throw new InvalidActionException("Daimyo only takes a player index argument");
    }
    if (!(args[0] is int)) {
      throw new InvalidActionException("Invalid player index arg");
    }
    Player target = players[args[0]];
    if (player == target) {
      if (player.daimyo = null) {
        player.daimyo = new House.daimyo(this);
      } else {
        throw new InvalidActionException("You can only have one daimyo!");
      }
    } else if (player.ally == target && target.daimyo == null) {
      target.daimyo = new House.daimyo(this);
      target.ally = null;
      player.ally = null;
    } else {
      throw new InvalidActionException("You can't play a daimyo on that player");
    }
  }
}

class Okugata extends StatCard {
  Okugata(int honor, int ki) : super ("Okugata", honor, ki, 0);
  bool isNinjaProof() => true;
}

abstract class ActionCard extends Card {
  ActionCard(String name) : super(name);
  int actionCost() => 1;
  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List args);
}

final int NINJA_HONOR_LOSS = 25;

class NinjaSpy extends ActionCard {
  NinjaSpy() : super("Ninja Spy");
  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List args) {
    if (args.length != 4) {
      throw new InvalidActionException("Ninja spy takes target player, house, card, and desination args");
    }
    var targetIndex = args[0];
    var daimyo = args[1];
    var cardIndex = args[2];
    var destinationIndex = args[3];

    if (!(targetIndex is int && daimyo is bool && cardIndex is int && destinationIndex is int)) {
      throw new InvalidActionException("Invalid arg types");
    }
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      throw new InvalidActionException("Target player doesn't have a daimyo to steal from");
    }

    player.validateSteal(house, cardIndex, destinationIndex);
    player.doSteal(house, cardIndex, destinationIndex, discard);
    player.honor -= NINJA_HONOR_LOSS;
  }
}

class EliteNinjaSpy extends ActionCard {
  EliteNinjaSpy() : super("Elite Ninja Spy");
  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List args) {
    if (args.length != 6) {
      throw new InvalidActionException("Elite Ninja spy takes target player, house, 2 card, and 2 desination args");
    }
    var targetIndex = args[0];
    var daimyo = args[1];
    var cardIndex1 = args[2];
    var cardIndex2 = args[3];
    var destinationIndex1 = args[4];
    var destinationIndex2 = args[5];

    if (!(targetIndex is int && daimyo is bool && cardIndex1 is int && destinationIndex1 is int && cardIndex2 is int && destinationIndex2 is int)) {
      throw new InvalidActionException("Invalid arg types");
    }
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      throw new InvalidActionException("Target player doesn't have a daimyo to steal from");
    }

    player.validateSteal(house, cardIndex1, destinationIndex1);
    player.validateSteal(house, cardIndex2, destinationIndex2);
    player.doSteal(house, cardIndex1, destinationIndex1, discard);
    player.doSteal(house, cardIndex2, destinationIndex2, discard);
    player.honor -= NINJA_HONOR_LOSS;
  }
}

class NinjaAssassin extends ActionCard {
  NinjaAssassin() : super("Ninja Assassin");
  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List args) {
    if (args.length != 2) {
      throw new InvalidActionException("Elite Ninja spy takes target player, house, 2 card, and 2 desination args");
    }
    var targetIndex = args[0];
    var daimyo = args[1];
    if (!(targetIndex is int && daimyo is bool)) {
      throw new InvalidActionException("Invalid arg types");
    }
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      throw new InvalidActionException("Target player doesn't have a daimyo to assassinate");
    }
    HouseGuard guard = house.contents.firstWhere((card) => card is HouseGuard);
    int killRoll;
    if (guard == null) {
      killRoll = 1;
    } else {
      killRoll = 3;
      house.contents.remove(guard);
      discard.add(guard);
    }

    player.honor -= NINJA_HONOR_LOSS;
    if (!daimyo && player.daimyo == null && player.ally == target) {
      player.honor -= NINJA_HONOR_LOSS;
    }

    if (new Random().nextInt(5) > killRoll) {
      target.killHouse(daimyo);
      if (!daimyo && player.ally == target) {
        player.ally = null;
        target.ally = null;
      }
    }
  }
}

class HouseGuard extends Card {
  HouseGuard() : super("House Guard");
}

class Castle extends StatCard {
  Castle(String name, int honor, int ki, int strength) : super (name, honor, ki, strength);
  bool isNinjaProof() => true;
}

class Dishonor extends ActionCard {
  static final int LOST_HONOR = 75;
  static final int SF_LOST_HONOR = 30;
  Dishonor() : super("Disnohor");

  int actionCost() => 2;

  void perform(Player player, List<Card> deck, List<Card> discard, List<Player> players, List targetIndexList) {
    if (targetIndexList.length != 1) {
      throw new InvalidActionException("Dishonor only takes a player index argument");
    }
    if (!(targetIndexList[0] is int)) {
      throw new InvalidActionException("Invalid player index arg");
    }
    Player target = players[targetIndexList[0]];
    DishonorResponse response = getResponse(target);
    if (response is SaveFaceDishonorResponse) {
      discard.add(target.hand.removeAt(response.cardIndex));
      target.honor -= SF_LOST_HONOR;
    } else {
      if (response is SepukuDishonorResponse) {
        discard.addAll(target.killHouse(response.daimyo));
      } else {
        target.honor -= LOST_HONOR;
      }
      if (target.daimyo == null && target.ally != null) {
        target.ally.ally = null;
        target.ally = null;
      }
    }
  }

  DishonorResponse getResponse(Player target) {
    DishonorResponse response = target.human.getDishonorResponse();
    if (response is SaveFaceDishonorResponse) {
      Card card = target.hand[response.cardIndex];
      if (card is SaveFace) {
        return response;
      } else {
        target.human.actionFailed("Can only play save face card when dishonored");
        return getResponse(target);
      }
    } else if (response is SepukuDishonorResponse && response.daimyo && target.daimyo == null) {
      target.human.actionFailed("Nonexistant daimyo cannot commit sepuku");
      return getResponse(target);
    } else {
      return response;
    }
  }
}

class SaveFace extends Card {
  SaveFace() : super("Save Face");
}

class Army extends StatCard {
  Army(int ki, int strength) : super ("Army", 0, ki, strength);
}

List<Daimyo> createDaimyos() {
  return [
      new Daimyo(30, 1, 3),
      new Daimyo(20, 1, 5),
      new Daimyo(15, 3, 2),
      new Daimyo(15, 1, 3),
      new Daimyo(10, 0, 2),
      new Daimyo(10, 0, 2),
      new Daimyo(10, 0, 2),
      new Daimyo(5, 0, 1),
      new Daimyo(5, 0, 1),
      new Daimyo(5, 0, 1),
  ];
}

List<Card> createDeck() {
  // TODO do this after daimyo distribution
  var deck = createDaimyos();

  deck.addAll(new Iterable.generate(5, (x) => new Okugata(10, 3)));
  deck.addAll(new Iterable.generate(5, (x) => new Okugata(5, 4)));

  deck.addAll(new Iterable.generate(8, (x) => new NinjaSpy()));
  deck.addAll(new Iterable.generate(3, (x) => new EliteNinjaSpy()));
  deck.addAll(new Iterable.generate(5, (x) => new NinjaAssassin()));

  deck.add(new Castle("Odawara Castle", 5, 0, 3));
  deck.add(new Castle("Osaka Castle", 10, 1, 4));
  deck.add(new Castle("Castle of the Great While Heron", 15, 2, 5));

  deck.addAll(new Iterable.generate(5, (x) => new Dishonor()));
  deck.addAll(new Iterable.generate(17, (x) => new SaveFace()));

  deck.addAll(new Iterable.generate(12, (x) => new Army(0, 1)));
  deck.addAll(new Iterable.generate(8, (x) => new Army(0, 2)));
  deck.addAll(new Iterable.generate(4, (x) => new Army(0, 3)));
  deck.addAll(new Iterable.generate(8, (x) => new Army(1, 1)));

  deck.add(new StatCard("Ancestor's No-Dachi", 5, 1, 3));
  deck.add(new StatCard("Ancestor's Daisho", 10, 1, 1));
  deck.add(new StatCard("Swordsmith Masamune", 10, 1, 4));
  deck.add(new StatCard("Gunpowder Weapons", -20, -2, 6));
  deck.add(new StatCard("Noh Theater", 20, 3, 0));

  deck.shuffle();
  return deck;
}