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

  String validate(Player player, List<Player> players, List<String> args) {
    if (args.length != 1) {
      return "Daimyo only takes a player index argument";
    }
    int targetIndex;
    try {
      targetIndex = int.parse(args[0]);
    } on FormatException {
      return "Invalid target index arg";
    }
    Player target = players[targetIndex];

    if (target.daimyo != null) {
      return "A player can only have one daimyo!";
    } else if (target != player.ally && target != player) {
        return "You can't play a daimyo on that player";
    }
    return null;
  }

  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List<String> args) {
    Player player = players[playerIndex];
    Player target = players[int.parse(args[0])];
    if (player == target && player.daimyo == null) {
      player.daimyo = new House.daimyo(this);
    } else if (player.ally == target && target.daimyo == null) {
      target.daimyo = new House.daimyo(this);
      target.ally = null;
      player.ally = null;
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
  String validate(Player player, List<Player> players, List<String> args);
  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List args);
}

final int NINJA_HONOR_LOSS = 25;

class NinjaSpy extends ActionCard {
  NinjaSpy() : super("Ninja Spy");

  String validate(Player player, List<Player> players, List<String> args) {
    if (args.length != 4) {
      return "Ninja spy takes target player, house, card, and desination args";
    }

    int targetIndex;
    try {
      targetIndex = int.parse(args[0]);
    } on FormatException {
      return "Invalid target index arg";
    }
    bool daimyo;
    switch (args[1]) {
      case 'daimyo': daimyo = true; break;
      case 'samurai': daimyo = false; break;
      default:
        return "Invalid house arg";
    }
    int cardIndex;
    try {
      cardIndex = int.parse(args[2]);
    } on FormatException {
      return "Invalid card index arg";
    }
    int destinationIndex;
    switch (args[3]) {
      case 'daimyo': destinationIndex = 0; break;
      case 'samurai': destinationIndex = 1; break;
      case 'discard': destinationIndex = 2; break;
      default:
        return "Invalid destination arg";
    }

    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      return "Target player doesn't have a daimyo to steal from";
    }
    return player.validateSteal(house, cardIndex, destinationIndex);
  }

  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List<String> args) {
    int targetIndex = int.parse(args[0]);
    bool daimyo = args[1] == 'daimyo';
    int cardIndex = int.parse(args[2]);
    int destinationIndex = args[3] == 'daimyo' ? 0 : args[3] == 'samurai' ? 1 : 2;

    Player player = players[playerIndex];
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;

    Card card = house.contents.removeAt(cardIndex);
    List<Card> toPlace = [player.daimyo.contents, player.samurai.contents, discard][destinationIndex];
    toPlace.add(card);
    player.honor -= NINJA_HONOR_LOSS;
  }
}

class EliteNinjaSpy extends ActionCard {
  EliteNinjaSpy() : super("Elite Ninja Spy");

  String validate(Player player, List<Player> players, List<String> args) {
    if (args.length != 6) {
      return "Elite Ninja spy takes target player, house, 2 card, and 2 desination args";
    }
    int targetIndex;
    try {
      targetIndex = int.parse(args[0]);
    } on FormatException {
      return "Invalid target index arg";
    }
    bool daimyo;
    switch (args[1]) {
      case 'daimyo': daimyo = true; break;
      case 'samurai': daimyo = false; break;
      default:
        return "Invalid house arg";
    }
    int cardIndex1;
    try {
      cardIndex1 = int.parse(args[2]);
    } on FormatException {
      return "Invalid card index arg";
    }
    int cardIndex2;
    try {
      cardIndex2 = int.parse(args[3]);
    } on FormatException {
      return "Invalid card index arg";
    }
    int destinationIndex1;
    switch (args[4]) {
      case 'daimyo': destinationIndex1 = 0; break;
      case 'samurai': destinationIndex1 = 1; break;
      case 'discard': destinationIndex1 = 2; break;
      default:
        return "Invalid destination arg";
    }
    int destinationIndex2;
    switch (args[5]) {
      case 'daimyo': destinationIndex2 = 0; break;
      case 'samurai': destinationIndex2 = 1; break;
      case 'discard': destinationIndex2 = 2; break;
      default:
        return "Invalid destination arg";
    }

    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      return "Target player doesn't have a daimyo to steal from";
    }

    String error = player.validateSteal(house, cardIndex1, destinationIndex1);
    if (error == null) {
      error = player.validateSteal(house, cardIndex2, destinationIndex2);
    }
    return error;
  }

  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List<String> args) {
    int targetIndex = int.parse(args[0]);
    bool daimyo = args[1] == 'daimyo';
    int cardIndex1 = int.parse(args[2]);
    int cardIndex2 = int.parse(args[3]);
    int destinationIndex1 = args[4] == 'daimyo' ? 0 : args[4] == 'samurai' ? 1 : 2;
    int destinationIndex2 = args[5] == 'daimyo' ? 0 : args[5] == 'samurai' ? 1 : 2;

    Player player = players[playerIndex];
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;

    Card card1 = house.contents[cardIndex1];
    Card card2 = house.contents.removeAt(cardIndex2);
    house.contents.remove(card1);

    List<List<Card>> dests = [player.daimyo.contents, player.samurai.contents, discard];
    dests[destinationIndex1].add(card1);
    dests[destinationIndex2].add(card2);

    player.honor -= NINJA_HONOR_LOSS;
  }
}

class NinjaAssassin extends ActionCard {
  NinjaAssassin() : super("Ninja Assassin");

  String validate(Player player, List<Player> players, List<String> args) {
    if (args.length != 2) {
      return "Ninja assassin takes target player and house args";
    }
    int targetIndex;
    try {
      targetIndex = int.parse(args[0]);
    } on FormatException {
      return "Invalid target index arg";
    }
    bool daimyo;
    switch (args[1]) {
      case 'daimyo': daimyo = true; break;
      case 'samurai': daimyo = false; break;
      default:
        return "Invalid house arg";
    }
    if (!(targetIndex is int && daimyo is bool)) {
      return "Invalid arg types";
    }
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    if (house == null) {
      return "Target player doesn't have a daimyo to assassinate";
    }
    return null;
  }

  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List args) {
    Player player = players[playerIndex];
    int targetIndex = int.parse(args[0]);
    bool daimyo = args[1] == 'daimyo';
    Player target = players[targetIndex];
    House house = daimyo ? target.daimyo : target.samurai;
    HouseGuard guard = house.contents.firstWhere((card) => card is HouseGuard, orElse: () => null);
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

    if (interface.roll(playerIndex, 1).first > killRoll) {
      discard.addAll(target.killHouse(daimyo));
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
  Dishonor() : super("Dishonor");

  int actionCost() => 2;

  String validate(Player player, List<Player> players, List<String> args) {
    if (args.length != 1) {
      return "Dishonor only takes a player index argument";
    }
    int targetIndex;
    try {
      targetIndex = int.parse(args[0]);
    } on FormatException {
      return "Invalid target index arg";
    }
  }

  void perform(int playerIndex, List<Card> discard, List<Player> players, Interface interface, List<String> args) {
    Player player = players[playerIndex];
    int targetIndex = int.parse(args[0]);
    Player target = players[targetIndex];

    SaveFace saveFaceCard = target.hand.firstWhere((c) => c is SaveFace, orElse:() => null);
    interface.requestDishonorResponse(targetIndex, target.daimyo != null, saveFaceCard != null, (String resp) {
      switch (resp) {
        case "SAVE_FACE":
          target.hand.remove(saveFaceCard);
          discard.add(saveFaceCard);
          target.honor -= SF_LOST_HONOR;
          break;
        case "NOTHING":
          target.honor -= LOST_HONOR; break;
        case "DAIMYO_SEPUKU":
          discard.addAll(target.killHouse(true)); break;
        case "SAMURAI_SEPUKU":
          discard.addAll(target.killHouse(false)); break;
      }
    });
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

List<Card> createDeck(List<Card> remainingDaimyos) {
  List<Card> deck = new List();
  deck.addAll(remainingDaimyos);

  deck.addAll(new Iterable.generate(5, (x) => new Okugata(10, 3)));
  deck.addAll(new Iterable.generate(5, (x) => new Okugata(5, 4)));

  deck.addAll(new Iterable.generate(8, (x) => new NinjaSpy()));
  deck.addAll(new Iterable.generate(3, (x) => new EliteNinjaSpy()));
  deck.addAll(new Iterable.generate(5, (x) => new NinjaAssassin()));

  deck.add(new Castle("Odawara Castle", 5, 0, 3));
  deck.add(new Castle("Osaka Castle", 10, 1, 4));
  deck.add(new Castle("Castle of the While Heron", 15, 2, 5)); // TODO *Great* While Heron, once card display can handle it

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

  return deck;
}