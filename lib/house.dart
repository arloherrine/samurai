part of samurai;

class House {
  final List<Card> contents = new List();
  int armies = 0;
  bool hasOkugata = false;
  StatCard head;

  House.samurai() {
    head = new StatCard("Samurai", 0, 6, 0);
  }

  House.daimyo(Daimyo daimyo) {
    head = daimyo;
  }

  int getHonor() {
    return contents.map((card) => card.honor).fold(head.honor, (a,b) => a+b);
  }

  int getKi() {
    return contents.map((card) => card.ki).fold(head.ki, (a,b) => a+b);
  }

  int getStrength() {
    return contents.map((card) => card.strength).fold(head.strength, (a,b) => a+b);
  }

  void putInHouse(Card card) {
    if (card is Castle) {
      if (!(head is Daimyo)) {
        throw new InvalidActionException("Only daimyos can have castles.");
      }
      if (contents.any((card) => card is Castle)) {
        throw new InvalidActionException("Daimyos can only have one castle.");
      }
    } else if (card is Okugata && contents.where((card) => card is Okugata).length > 0) {
      throw new InvalidActionException("A house can only have one okugata.");
    } else if (card is Army && contents.where((card) => card is Army).length > 4) {
      throw new InvalidActionException("A house can only have at most 5 armies.");
    }

    contents.add(card);
  }
}