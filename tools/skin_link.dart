// Makes a gift link for a Halloween skin, working for seven days.
//
//   dart run tools/skin_link.dart fantasma
//   dart run tools/skin_link.dart vampiro --giorni 3
//
// Skins: fantasma, vampiro, zucca, zombi (or ghost, vampire, jackOLantern,
// zombie). Every run makes a different link, even for the same skin, and
// each works on its own until it expires. Opened on a phone with Stepbound
// installed, it gives the skin to all four slots; past its expiry the game
// says "Link scaduto" and gives nothing.
//
// Exit codes: 64 wrong arguments.
import 'dart:io';

import 'package:stepbound/game/progress.dart';
import 'package:stepbound/save/skin_links.dart';

const Map<String, PlayerOutfit> _names = <String, PlayerOutfit>{
  'fantasma': PlayerOutfit.ghost,
  'vampiro': PlayerOutfit.vampire,
  'zucca': PlayerOutfit.jackOLantern,
  'zombi': PlayerOutfit.zombie,
  'ghost': PlayerOutfit.ghost,
  'vampire': PlayerOutfit.vampire,
  'jackolantern': PlayerOutfit.jackOLantern,
  'zombie': PlayerOutfit.zombie,
};

void main(List<String> args) {
  final outfit = args.isEmpty ? null : _names[args.first.toLowerCase()];
  var days = skinLinkValidity.inDays;
  if (args.length == 3 && args[1] == '--giorni') {
    days = int.tryParse(args[2]) ?? 0;
  } else if (args.length != 1) {
    days = 0;
  }
  if (outfit == null || days < 1) {
    stderr.writeln(
      'uso: dart run tools/skin_link.dart '
      '<fantasma|vampiro|zucca|zombi> [--giorni N]',
    );
    exitCode = 64;
    return;
  }
  final expiresAt = DateTime.now().add(Duration(days: days));
  final link = skinGiftLink(
    outfit,
    expiresAt: expiresAt,
    nonce: randomSkinLinkNonce(),
  );
  String two(int value) => value.toString().padLeft(2, '0');
  stdout
    ..writeln(link)
    ..writeln(
      'Skin ${outfit.label}, valido fino al '
      '${two(expiresAt.day)}/${two(expiresAt.month)}/${expiresAt.year} '
      '${two(expiresAt.hour)}:${two(expiresAt.minute)}',
    );
}
