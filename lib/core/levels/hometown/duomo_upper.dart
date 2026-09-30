import 'package:stepbound/core/levels/place.dart';

/// The first floor of the harbour Duomo, where the community lives.
///
/// West of the partition `I` is the dormitory: three rows of four beds
/// `B`, each two cells long with its head to the north and its night table
/// `n` beside it, a cell of floor between every bed; four wardrobes `A`
/// against the walls, a few chairs `C`, and the occultist robe `R` on the
/// floor. East of it is the kitchen and the refectory: the counters `k`
/// along the back wall with the hearth `F`, the sink `H` and two dressers
/// `K`; below them two long tables `T`, five cells by two, and two square
/// ones, two by two, each with its chairs drawn up on every side (a chair
/// turns to the table it stands by). The doorway `d` joins the two rooms.
///
/// The stairs `D` in the front wall are the ones that came up from the
/// nave, and go back down. The locked door `L` in the back wall opens on
/// the stairs to the second floor, straight above them: on every floor
/// above the nave the way up and the way down are in the same column, the
/// second in from the east wall, with a cell of floor between them and it.
// duomo-upper-rows-start
const List<String> duomoUpperRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWLWWx',
  'xI.Bn..Bn..Bn..Bn...IkkkFFkkHkKK....Ix',
  'xI.B...B...B...B....Ik..............Ix',
  'xI...C..............Ik..............Ix',
  'xIA................AI...CCCCC..CC...Ix',
  'xI........R.........I..CTTTTT.CTT...Ix',
  'xI..................I...TTTTTC.TTC..Ix',
  'xI.Bn..Bn..Bn..Bn...I...CCCCC..CC...Ix',
  'xI.B...B...B...B....I...............Ix',
  'xI...........C......I...............Ix',
  'xIA................AI...CCCCC..CC...Ix',
  'xI..................I..CTTTTT.CTT...Ix',
  'xI..................I...TTTTTC.TTC..Ix',
  'xI.Bn..Bn..Bn..Bn...I...CCCCC..CC...Ix',
  'xI.B...B...B...B....I...............Ix',
  'xI.......C..........d...............Ix',
  'xI..................I...............Ix',
  'xI..................I...............Ix',
  'xwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwDwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// duomo-upper-rows-end

/// The community's floor: the locked door `L` on up is in the wall, and
/// what furnishes the dormitory and the refectory is waist high.
const Legend duomoUpperLegend = Legend(walls: 'xWwIL', obstacles: 'TCBKkFHnA');
