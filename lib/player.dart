part of samurai;

class Player {

  Human human;
  List<Card> hand;
  House daimyo;
  House samurai;
  Player ally;
  int honor;
  bool isShogun;

  int calculateHonorGain() {
    if (daimyo == null) {
      if (ally == null) {
        return 0;
      } else {
        return (samurai.getHonor() + ally.daimyo.getHonor()) ~/ 2;
      }
    } else {
      return samurai.getHonor() + daimyo.getHonor();
    }
  }

  int getKi() {
    if (daimyo != null) {
      return daimyo.getKi() + samurai.getKi();
    } else {
      return samurai.getKi();
    }
  }

  int getStrength() {
    if (ally != null) {
      return daimyo.getStrength() + samurai.getStrength() + ally.samurai.getStrength();
    } else {
      return daimyo.getStrength() + samurai.getStrength();
    }
  }

  List<Card> killHouse(bool isDaimyo) {
    List<Card> contents;
    if (isDaimyo) {
      contents = daimyo.contents;
      contents.add(daimyo.head);
      daimyo = null;
    } else {
      contents = new List();
      contents.addAll(samurai.contents);
      samurai.contents.clear();

      if (daimyo != null && ally != null) {
        ally.daimyo = daimyo;
        daimyo = null;
        ally.ally = null;
        ally = null;
      }
    }
  }

  void validateSteal(House targetHouse, int cardIndex, int destination) {
    Card card = targetHouse.contents[cardIndex];
    if (card is HouseGuard) {
      throw new InvalidActionException("Can't steal house guard");
    }
    if (card is StatCard && card.isNinjaProof()) {
      throw new InvalidActionException("Can't steal castles or okugatas");
    }

    switch (destination) {
      case 0:
        if (daimyo == null) {
          throw new InvalidActionException("Can't put stolen goods in nonexistant daimyo house");
        }
        break;
      default:
    }
  }

  void doSteal(House targetHouse, int cardIndex, int destination, List<Card> discard) {
    Card card = targetHouse.contents[cardIndex];

    switch (destination) {
      case 0:
        daimyo.putInHouse(card);
        break;
      case 1:
        samurai.putInHouse(card);
        break;
      default:
        discard.add(card);
    }
    targetHouse.contents.removeAt(cardIndex);
  }

}