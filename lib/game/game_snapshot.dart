/// What a save stores: the simulation, the story's scripts, the
/// player's progress, the unlocked controls and the name of the place.
typedef GameSnapshot = ({
  Map<String, Object?> world,
  Map<String, Object?> story,
  Map<String, Object?> progress,
  List<String> hud,
  String place,
});
