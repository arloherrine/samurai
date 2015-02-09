part of samurai;

abstract class Interface {

  int playerIndex;
  String expectedCommand;

  List<Player> players;
  int remainingActions;

  bool hasDaimyo;
  bool hasSaveFace;

  Function callback;

  void requestAction(int playerIndex, List<Player> players, int remainingActions, Function callback) {
    this.playerIndex = playerIndex;
    this.players = players;
    this.remainingActions = remainingActions;
    this.callback = callback;
    expectedCommand = 'action';
  }

  void doAction(String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return;
    }
    if (tokens[0] != "action") {
      alert(playerIndex, "Expecting action command but received: " + command);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return;
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
          return;
        }
        action = new AttackDeclaration(playerIndex, targetIndex);
        break;
      case 'ally':
        int targetIndex;
        try {
          targetIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to ally must be the target's index: " + command);
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
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to discard must be the card's index: " + command);
          return;
        }
        action = new DiscardAction(playerIndex, cardIndex);
        break;
      case 'put':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to put must be the card's index: " + command);
          return;
        }
        bool daimyo;
        switch (tokens[3]) {
          case 'daimyo': daimyo = true; break;
          case 'samurai': daimyo = false; break;
          default:
            alert(playerIndex, "third argument to put must be house: " + command);
            return;
        }
        action = new PutInHouseAction(playerIndex, cardIndex, daimyo);
        break;
      case 'play':
        int cardIndex;
        try {
          cardIndex = int.parse(tokens[2]);
        } on FormatException {
          alert(playerIndex, "second argument to play must be the card's index: " + command);
          return;
        }
        action = new PlayOnAction(playerIndex, cardIndex, tokens.getRange(3, tokens.length));
        break;
      default:
        alert(playerIndex, "unrecognized subcommand in: " + command);
        return;
    }
    String validationMsg = action.validate(players, remainingActions);
    if (validationMsg != null) {
      alert(playerIndex, validationMsg);
      return;
    }
    update(command);
    callback(action);
  }

  void requestDishonorResponse(int playerIndex, bool hasDaimyo, bool hasSaveFace, Function callback) {
    playerIndex = playerIndex;
    this.hasDaimyo = hasDaimyo;
    this.hasSaveFace = hasSaveFace;
    this.callback = callback;
    expectedCommand = 'dishonored';
  }

  void doDishonorResponse(String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return;
    }
    if (tokens[0] != "dishonored") {
      alert(playerIndex, "Expecting dishonored command but received: " + command);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return;
    }
    DishonorResponse result;
    switch (tokens[1]) {
      case 'nothing':
        result = DishonorResponse.NOTHING;
        break;
      case 'save':
        if (!hasSaveFace) {
          alert(playerIndex, "You don't have a save face card to play");
          return;
        }
        result = DishonorResponse.SAVE_FACE;
        break;
      case 'sepuku':
        if (tokens.length < 3) {
          alert(playerIndex, "Sepuku response missing target: " + command);
          return;
        }
        switch (tokens[2]) {
          case 'daimyo':
            if (!hasDaimyo) {
              alert(playerIndex, "you don't have a daimyo to kill");
              return;
            }
            result = DishonorResponse.DAIMYO_SEPUKU;
            break;
          case 'samurai':
            result = DishonorResponse.SAMURAI_SEPUKU;
            break;
          default:
            alert(playerIndex, "unrecognized sepuku target in: " + command);
            return;
        }
      default:
        alert(playerIndex, "unrecognized dishonor response in: " + command);
        return;
    }
    update(command);
    callback(result);
  }

  void requestTakeCastle(int playerIndex, Function callback) {
    this.playerIndex = playerIndex;
    this.callback = callback;
    this.expectedCommand = "castle";
  }

  void doTakeCastle(String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return;
    }
    if (tokens[0] != "castle") {
      alert(playerIndex, "Expecting castle command but received: " + command);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return;
    }
    bool result;
    switch (tokens[1]) {
      case 'take':
        result = true;
        break;
      case 'burn':
        result = false;
        break;
      default:
        alert(playerIndex, "unrecognized castle response in: " + command);
        return;
    }
    update(command);
    callback(result);
  }

  void requestSaveFace(int playerIndex, Function callback) {
    this.playerIndex = playerIndex;
    this.callback = callback;
    this.expectedCommand = "save";
  }

  void doSaveFace(String command) {
    List<String> tokens = command.split(" ");
    if (tokens.length < 3) {
      alert(playerIndex, "Not enough arguments: " + command);
      return;
    }
    if (tokens[0] != "save") {
      alert(playerIndex, "Expecting save command but received: " + command);
      return;
    }
    try {
      int receivedIndex = int.parse(tokens[2]);
      if (receivedIndex != playerIndex) {
        alert(playerIndex, "first argument must always be the player's index: " + command);
        return;
      }
    } on FormatException {
      alert(playerIndex, "first argument must always be the player's index: " + command);
      return;
    }
    bool result;
    switch (tokens[1]) {
      case 'save':
        result = true;
        break;
      case 'dont':
        result = false;
        break;
      default:
        alert(playerIndex, "unrecognized save response in: " + command);
        return;
    }
    update(command);
    callback(result);
  }

  Random random;

  void initRandomSeed();

  List<int> roll(int playerIndex, int dice) {
    List<int> result = new Iterable.generate(dice, (x) => random.nextInt(6) + 1);
  }

  void update(String command);

  void alert(int playerIndex, String msg);
}

enum DishonorResponse {
  DAIMYO_SEPUKU,
  SAMURAI_SEPUKU,
  SAVE_FACE,
  NOTHING
}
