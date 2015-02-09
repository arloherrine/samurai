part of samurai;

abstract class Interface {
  Action getAction(int playerIndex, List<Player> players, int remainingActions) {
    String command = getRawResponse(playerIndex);
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return getAction(playerIndex, players, remainingActions);
    }
    if (tokens[0] != "action") {
      alert(playerIndex, "Expecting action command but received: " + command);
      return getAction(playerIndex, players, remainingActions);
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return getAction(playerIndex, players, remainingActions);
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return getAction(playerIndex, players, remainingActions);
    }

    Action action;
    switch (tokens[1]) {
      case 'end':
        action = new EndTurn(playerIndex); break;
      case 'shogun':
        action = new ShogunDeclaration(playerIndex); break;
      case 'attack':
        int targetIndex;
        try {
          targetIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to attack must be the target's index: " + command);
          return getAction(playerIndex, players, remainingActions);
        }
        action = new AttackDeclaration(playerIndex, targetIndex);
        break;
      case 'ally':
        int targetIndex;
        try {
          targetIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to ally must be the target's index: " + command);
          return getAction(playerIndex, players, remainingActions);
        }
        action = new AllyDeclaration(playerIndex, targetIndex);
        break;
      case 'dissolve':
        action = new DissolveDeclaration(playerIndex); break;
      case 'draw':
        action = new DrawAction(playerIndex); break;
      case 'discard':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to discard must be the card's index: " + command);
          return getAction(playerIndex, players, remainingActions);
        }
        action = new DiscardAction(playerIndex, cardIndex);
        break;
      case 'put':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to put must be the card's index: " + command);
          return getAction(playerIndex, players, remainingActions);
        }
        bool daimyo;
        switch (tokens[3]) {
          case 'daimyo': daimyo = true; break;
          case 'samurai': daimyo = false; break;
          default:
            alert(playerIndex, "third argument to put must be house: " + command);
            return getAction(playerIndex, players, remainingActions);
        }
        action = new PutInHouseAction(playerIndex, cardIndex, daimyo);
        break;
      case 'play':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to play must be the card's index: " + command);
          return getAction(playerIndex, players, remainingActions);
        }
        action = new PlayOnAction(playerIndex, cardIndex, tokens.getRange(3, tokens.length));
        break;
      default:
        alert(playerIndex, "unrecognized subcommand in: " + command);
        return getAction(playerIndex, players, remainingActions);
    }
    String validationMsg = action.validate(players, remainingActions);
    if (validationMsg != null) {
      alert(playerIndex, validationMsg);
      return getAction(playerIndex, players, remainingActions);
    }
    update(command);
    return action;
  }

  DishonorResponse getDishonorResponse(int playerIndex, bool hasDaimyo, bool hasSaveFace) {
    String command = getRawResponse(playerIndex);
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
    }
    if (tokens[0] != "dishonored") {
      alert(playerIndex, "Expecting dishonored command but received: " + command);
      return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
    }
    DishonorResponse result;
    switch (tokens[1]) {
      case 'nothing':
        result = DishonorResponse.NOTHING; break;
      case 'save':
        if (!hasSaveFace) {
          alert(playerIndex, "You don't have a save face card to play");
          return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
        }
        result = DishonorResponse.SAVE_FACE; break;
      case 'sepuku':
        if (tokens.length < 3) {
          alert(playerIndex, "Sepuku response missing target: " + command);
          return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
        }
        switch (tokens[2]) {
          case 'daimyo':
            if (!hasDaimyo) {
              alert(playerIndex, "you don't have a daimyo to kill");
              return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
            }
            result = DishonorResponse.DAIMYO_SEPUKU; break;
          case 'samurai':
            result = DishonorResponse.SAMURAI_SEPUKU; break;
          default:
            alert(playerIndex, "unrecognized sepuku target in: " + command);
            return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
        }
      default:
        alert(playerIndex, "unrecognized dishonor response in: " + command);
        return getDishonorResponse(playerIndex, hasDaimyo, hasSaveFace);
    }
    update(command);
    return result;
  }

  bool getTakeCastle(int playerIndex) {
    String command = getRawResponse(playerIndex);
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return getTakeCastle(playerIndex);
    }
    if (tokens[0] != "castle") {
      alert(playerIndex, "Expecting castle command but received: " + command);
      return getTakeCastle(playerIndex);
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return getTakeCastle(playerIndex);
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return getTakeCastle(playerIndex);
    }
    bool result;
    switch (tokens[1]) {
      case 'take': result = true; break;
      case 'burn': result = false; break;
      default:
        alert(playerIndex, "unrecognized castle response in: " + command);
        return getTakeCastle(playerIndex);
    }
    update(command);
    return result;
  }

  bool getSaveFace(int playerIndex) {
    String command = getRawResponse(playerIndex);
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return getTakeCastle(playerIndex);
    }
    if (tokens[0] != "save") {
      alert(playerIndex, "Expecting save command but received: " + command);
      return getTakeCastle(playerIndex);
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return getTakeCastle(playerIndex);
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return getTakeCastle(playerIndex);
    }
    bool result;
    switch (tokens[1]) {
      case 'save': result = true; break;
      case 'dont': result = false; break;
      default:
        alert(playerIndex, "unrecognized save response in: " + command);
        return getTakeCastle(playerIndex);
    }
    update(command);
    return result;
  }

  List<int> roll(int playerIndex, int dice);

  String getRawResponse(int playerIndex);

  void update(String command);

  void alert(int playerIndex, String msg);
}

enum DishonorResponse {
  DAIMYO_SEPUKU,
  SAMURAI_SEPUKU,
  SAVE_FACE,
  NOTHING
}
