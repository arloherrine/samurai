part of samurai;

class Player {

  final List<Card> hand;
  DaimyoHouse daimyo = null;
  final SamuraiHouse samurai;
  Player ally;
  int honor = 0;
  bool isShogun = false;

  final String name;

  Player(this.name)
      : hand = new List(),
        samurai = new SamuraiHouse();

  Player.from(Player other, Future<Map<String, Player>> playerCopyMapFuture)
      : name = other.name,
        hand = new List.from(other.hand),
        samurai = new SamuraiHouse.from(other.samurai) {
    daimyo = new DaimyoHouse.from(other.daimyo);
    honor = other.honor;
    isShogun = other.isShogun;
    playerCopyMapFuture.then((m) => ally = m[other.ally.name]);
  }

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

  int getStrength(bool attacking) {
    int strength = samurai.getStrength();
    if (daimyo != null) {
      strength += daimyo.getStrength(attacking);
      if (ally != null) {
        strength += ally.samurai.getStrength();
      }
    }
    return strength;
  }

  int getAttackStrength() {

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
    return contents;
  }

  String validateSteal(House targetHouse, int cardIndex, int destination) {
    if (cardIndex >= targetHouse.contents.length) {
      return "out of range card index";
    }
    Card card = targetHouse.contents[cardIndex];
    if (card is HouseGuard) {
      return "Can't steal house guard";
    }
    if (card is StatCard && card.isNinjaProof()) {
      return "Can't steal castles or okugatas";
    }

    switch (destination) {
      case 0:
        if (daimyo == null) {
          return "Can't put stolen goods in nonexistant daimyo house";
        }
        return daimyo.validatePutInHouse(card);
      case 1:
        return samurai.validatePutInHouse(card);
      default:
        return null;
    }
  }
}