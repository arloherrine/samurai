part of samurai;

class InterfaceCallback {
  final int playerIndex;
  final Function closure;
  InterfaceCallback(this.playerIndex, this.closure);
}

abstract class Interface {

  Queue<InterfaceCallback> closureQueue = new Queue();

  void requestAction(int playerIndex, List<Player> players, int remainingActions, bool hasMadeDeclaration, Function callback) {
    this.closureQueue.addLast(new InterfaceCallback(playerIndex, (String command)
        => doAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback, command)));
  }

  void doAction(int playerIndex, List<Player> players, int remainingActions, bool hasMadeDeclaration, Function callback, String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[0]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
      return;
    }
    if (tokens[1] != "action") {
      alert(playerIndex, "Expecting action command but received: " + command);
      requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
      return;
    }

    Action action;
    switch (tokens[2]) {
      case 'end':
        action = new EndTurn(playerIndex); break;
      case 'shogun':
        action = new ShogunDeclaration(playerIndex); break;
      case 'attack':
        int targetIndex;
        try {
          targetIndex = int.parse(tokens[3]);
        } on FormatException {
          alert(playerIndex, "second argument to attack must be the target's index: " + command);
          requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
          return;
        }
        action = new AttackDeclaration(playerIndex, targetIndex);
        break;
      case 'ally':
        int targetIndex;
        try {
          targetIndex = int.parse(tokens[3]);
        } on FormatException {
          alert(playerIndex, "second argument to ally must be the target's index: " + command);
          requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
          return;
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
          cardIndex = int.parse(tokens[3]);
        } on FormatException {
          alert(playerIndex, "second argument to discard must be the card's index: " + command);
          requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
          return;
        }
        action = new DiscardAction(playerIndex, cardIndex);
        break;
      case 'put':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[3]);
        } on FormatException {
          alert(playerIndex, "second argument to put must be the card's index: " + command);
          requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
          return;
        }
        bool daimyo;
        switch (tokens[4]) {
          case 'daimyo': daimyo = true; break;
          case 'samurai': daimyo = false; break;
          default:
            alert(playerIndex, "third argument to put must be house: " + command);
            requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
            return;
        }
        action = new PutInHouseAction(playerIndex, cardIndex, daimyo);
        break;
      case 'play':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[3]);
        } on FormatException {
          alert(playerIndex, "second argument to play must be the card's index: " + command);
          requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
          return;
        }
        action = new PlayOnAction(playerIndex, cardIndex, new List.from(tokens.getRange(4, tokens.length)));
        break;
      default:
        alert(playerIndex, "unrecognized subcommand in: " + command);
        requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
        return;
    }
    if (hasMadeDeclaration && action is Declaration) {
      alert(playerIndex, "You've already made a declaration this turn.");
      return;
    }
    String validationMsg = action.validate(players, remainingActions);
    if (validationMsg != null) {
      alert(playerIndex, validationMsg);
      requestAction(playerIndex, players, remainingActions, hasMadeDeclaration, callback);
      return;
    }
    callback(action);
    update(command);
  }

  void requestDishonorResponse(int playerIndex, bool hasDaimyo, bool hasSaveFace, Function callback) {
    this.closureQueue.addLast(new InterfaceCallback(playerIndex, (String command)
        => doDishonorResponse(playerIndex, hasDaimyo,hasSaveFace, callback, command)));
  }

  void doDishonorResponse(int playerIndex, bool hasDaimyo, bool hasSaveFace, Function callback, String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[0]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
      return;
    }
    if (tokens[1] != "dishonored") {
      alert(playerIndex, "Expecting dishonored command but received: " + command);
      requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
      return;
    }
    String result;
    switch (tokens[2]) {
      case 'nothing':
        result = "NOTHING";
        break;
      case 'save':
        if (!hasSaveFace) {
          alert(playerIndex, "You don't have a save face card to play");
          requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
          return;
        }
        result = "SAVE_FACE";
        break;
      case 'sepuku':
        if (tokens.length < 3) {
          alert(playerIndex, "Sepuku response missing target: " + command);
          requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
          return;
        }
        if (tokens[3] == 'daimyo') {
          if (!hasDaimyo) {
            alert(playerIndex, "you don't have a daimyo to kill");
            requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
            return;
          }
          result = "DAIMYO_SEPUKU";
        } else if (tokens[3] == 'samurai') {
          result = "SAMURAI_SEPUKU";
        } else {
          alert(playerIndex, "unrecognized sepuku target in: " + command);
          requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
          return;
        }
        break;
      default:
        alert(playerIndex, "unrecognized dishonor response in: " + command);
        requestDishonorResponse(playerIndex, hasDaimyo, hasSaveFace, callback);
        return;
    }
    callback(result);
    update(command);
  }

  void requestTakeCastle(int playerIndex, Function callback) {
    this.closureQueue.addLast(new InterfaceCallback(playerIndex, (String command)
        => doTakeCastle(playerIndex, callback, command)));
  }

  void doTakeCastle(int playerIndex, Function callback, String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      requestTakeCastle(playerIndex, callback);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[0]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        requestTakeCastle(playerIndex, callback);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      requestTakeCastle(playerIndex, callback);
      return;
    }
    if (tokens[1] != "castle") {
      alert(playerIndex, "Expecting castle command but received: " + command);
      requestTakeCastle(playerIndex, callback);
      return;
    }
    bool result;
    switch (tokens[2]) {
      case 'take':
        result = true;
        break;
      case 'burn':
        result = false;
        break;
      default:
        alert(playerIndex, "unrecognized castle response in: " + command);
        requestTakeCastle(playerIndex, callback);
        return;
    }
    callback(result);
    update(command);
  }

  void requestSaveFace(int playerIndex, Function callback) {
    this.closureQueue.addLast(new InterfaceCallback(playerIndex, (String command)
        => doSaveFace(playerIndex, callback, command)));
  }

  void doSaveFace(int playerIndex, Function callback, String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      requestSaveFace(playerIndex, callback);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[0]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        requestSaveFace(playerIndex, callback);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      requestSaveFace(playerIndex, callback);
      return;
    }
    if (tokens[1] != "save") {
      alert(playerIndex, "Expecting save command but received: " + command);
      requestSaveFace(playerIndex, callback);
      return;
    }
    bool result;
    switch (tokens[2]) {
      case 'save':
        result = true;
        break;
      case 'dont':
        result = false;
        break;
      default:
        alert(playerIndex, "unrecognized save response in: " + command);
        requestSaveFace(playerIndex, callback);
        return;
    }
    callback(result);
    update(command);
  }

  Random random;

  void initRandomSeed();

  Iterable<int> roll(int playerIndex, int dice) => new Iterable.generate(dice, (x) => random.nextInt(6) + 1);

  void update(String command);

  void alert(int playerIndex, String msg);
}
