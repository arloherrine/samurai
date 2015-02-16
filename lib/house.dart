part of samurai;

abstract class House {

  final List<Card> contents = new List();
  StatCard head;

  House.samurai() {
    head = new StatCard("Samurai", 0, 6, 0);
  }

  House.daimyo(Daimyo daimyo) {
    head = daimyo;
  }

  House(this.head);

  int getHonor() {
    return contents.map((card) => card.honor).fold(head.honor, (a,b) => a+b);
  }

  int getKi() {
    return contents.map((card) => card.ki).fold(head.ki, (a,b) => a+b);
  }

  String validatePutInHouse(Card card) {
    if (card is Castle) {
      if (!(head is Daimyo)) {
        return "Only daimyos can have castles.";
      }
      if (contents.any((card) => card is Castle)) {
        return "Daimyos can only have one castle.";
      }
    } else if (card is Okugata && contents.any((card) => card is Okugata)) {
      return "A house can only have one okugata.";
    } else if (card is Army && contents.where((card) => card is Army).length > 4) {
      return "A house can only have at most 5 armies.";
    }
  }
}

class SamuraiHouse extends House {

  SamuraiHouse() : super(new StatCard("Samurai", 0, 6, 0));

  SamuraiHouse.from(SamuraiHouse other) : super(other.head) {
    contents.addAll(other.contents);
  }

  int getStrength() {
    return contents.map((card) => card.strength).fold(head.strength, (a,b) => a+b);
  }
}


class DaimyoHouse extends House {

  DaimyoHouse(Daimyo daimyo) : super(daimyo);

  DaimyoHouse.from(DaimyoHouse other) : super(other.head) {
    contents.addAll(other.contents);
  }

  int getStrength(bool attacking) {
    return contents.where((card) => !(attacking && card is Castle)).map((card) => card.strength).fold(head.strength, (a,b) => a+b);
  }
}