part of samurai;

abstract class Human {

  Action getAction();

  DishonorResponse getDishonorResponse();

  bool getTakeCastle();

  int getSaveFace();

  void updateDisplay(Game game);

  void alert(String msg);
}

class DishonorResponse {}

class SaveFaceDishonorResponse extends DishonorResponse {
  int cardIndex;
}

class SepukuDishonorResponse extends DishonorResponse {
  bool daimyo;
}

abstract class Declaration {
  int playerIndex;
}

class BasicDeclaration extends Declaration {
  bool shogun;
}

class TargetDeclaration extends Declaration {
  bool attack;
  int targetIndex;
}