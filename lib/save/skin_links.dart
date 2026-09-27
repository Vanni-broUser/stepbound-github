import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:stepbound/game/progress.dart';

/// How long a gift link works once made: see `tools/skin_link.dart`.
const Duration skinLinkValidity = Duration(days: 7);

/// A gift link read back: the skin it gives and when it stops working.
final class SkinLink {
  const SkinLink(this.outfit, this.expiresAt);

  final PlayerOutfit outfit;
  final DateTime expiresAt;

  bool expiredAt(DateTime now) => !now.isBefore(expiresAt);
}

/// `stepbound://unlock/<token>`, where the token is the skin, the moment
/// the link stops working and a random number, signed so that neither can
/// be changed and no link can be made without the key. The random number
/// makes every link different, even two made for the same skin at once.
Uri skinGiftLink(
  PlayerOutfit outfit, {
  required DateTime expiresAt,
  required int nonce,
}) {
  final code = _codes[outfit];
  if (code == null) {
    throw ArgumentError.value(outfit, 'outfit', 'is not a gift');
  }
  final payload = ByteData(_payloadLength)
    ..setUint8(0, _version)
    ..setUint8(1, code)
    ..setUint32(2, expiresAt.millisecondsSinceEpoch ~/ 1000)
    ..setUint32(6, nonce);
  final bytes = payload.buffer.asUint8List();
  final token = base64Url
      .encode(<int>[...bytes, ..._sign(bytes)])
      .replaceAll('=', '');
  return Uri(scheme: 'stepbound', host: 'unlock', pathSegments: [token]);
}

/// A fresh random number for [skinGiftLink].
int randomSkinLinkNonce() => math.Random.secure().nextInt(1 << 32);

/// Whether [uri] is meant as a gift link, good or not: the app answers
/// these, and leaves any other link alone.
bool isSkinLink(Uri uri) =>
    uri.scheme.toLowerCase() == 'stepbound' &&
    uri.host.toLowerCase() == 'unlock';

/// The gift [uri] carries, expired or not, or null for anything that is
/// not a link this game made: a strict reading keeps a stray or edited
/// link from touching the slots.
SkinLink? readSkinLink(Uri uri) {
  if (!isSkinLink(uri) ||
      uri.pathSegments.length != 1 ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(uri.pathSegments.single));
  } on FormatException {
    return null;
  }
  if (bytes.length != _payloadLength + _signatureLength) {
    return null;
  }
  final payload = bytes.sublist(0, _payloadLength);
  final signature = bytes.sublist(_payloadLength);
  final expected = _sign(payload);
  var difference = 0;
  for (var i = 0; i < _signatureLength; i++) {
    difference |= signature[i] ^ expected[i];
  }
  if (difference != 0) {
    return null;
  }
  final data = ByteData.sublistView(payload);
  if (data.getUint8(0) != _version) {
    return null;
  }
  final code = data.getUint8(1);
  final outfit = <PlayerOutfit>[
    for (final MapEntry(:key, :value) in _codes.entries)
      if (value == code) key,
  ].firstOrNull;
  if (outfit == null) {
    return null;
  }
  return SkinLink(
    outfit,
    DateTime.fromMillisecondsSinceEpoch(data.getUint32(2) * 1000),
  );
}

List<int> _sign(List<int> payload) =>
    Hmac(sha256, _key).convert(payload).bytes.sublist(0, _signatureLength);

/// Version, skin, expiry in seconds, random number.
const int _payloadLength = 10;
const int _signatureLength = 10;
const int _version = 1;

/// One number per skin that can be given, fixed forever: links already
/// sent name their skin by it.
const Map<PlayerOutfit, int> _codes = <PlayerOutfit, int>{
  PlayerOutfit.ghost: 1,
  PlayerOutfit.vampire: 2,
  PlayerOutfit.jackOLantern: 3,
  PlayerOutfit.zombie: 4,
};

/// Signs the links. It ships inside the app, so a determined player could
/// dig it out: enough to keep links from being guessed or edited, not a
/// safe for anything valuable.
final List<int> _key = <int>[
  for (var i = 0; i < _keyHex.length; i += 2)
    int.parse(_keyHex.substring(i, i + 2), radix: 16),
];
const String _keyHex =
    'd7f161d60c8aacd052d30ed1a3fcd3618884c2c551da5791768943501e992144';
