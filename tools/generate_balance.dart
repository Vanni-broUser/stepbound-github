// Generates the typed balance defaults the pure-Dart core compiles in.
//
// `assets/balance/default.json` is the single source of the actor stats. The
// core cannot read a file, so the values are generated into a Dart map that
// `BalanceConfig.standard()` returns. CI runs this tool with `--check` and
// refuses a generated file that no longer matches the asset.
//
//   dart run tools/generate_balance.dart          rewrite the generated file
//   dart run tools/generate_balance.dart --check  fail if it is out of date
//
// Exit codes: 1 the generated file is stale, 64 wrong arguments, 65 the
// asset is unusable.
import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/balance/default.json';
const String _outputPath = 'lib/core/entities/default_balance.g.dart';

/// Every `EntityKind` that carries stats, in the order they are generated.
/// Kept here on purpose: the generator refuses an asset that does not match
/// this list, so adding an actor stays a deliberate three-step change (the
/// enum in `entity.dart`, the asset, this list).
const List<String> _actorKinds = <String>[
  'player',
  'wanderer',
  'sprinter',
  'brute',
  'blind',
  'carabiniere',
  'mutilated',
  'burning',
  'drunk',
  'cultist',
];

/// The stats every actor must carry, in generated order, with the smallest
/// value each one accepts.
const Map<String, int> _requiredStats = <String, int>{
  'tickCost': 1,
  'health': 1,
  'vision': 0,
  'hearing': 0,
  'contactDamage': 0,
};

/// Optional: an actor without it bites the tile in front of it.
const String _attackReach = 'attackReach';
const int _minimumAttackReach = 1;

/// Optional flags: only `true` is written. [_stationary] for an actor that
/// never walks, [_trailsFire] for one that sets alight the tiles it leaves,
/// [_staggers] for one that walks a random way instead of hunting.
const String _stationary = 'stationary';
const String _trailsFire = 'trailsFire';
const String _staggers = 'staggers';
const List<String> _flags = <String>[_stationary, _trailsFire, _staggers];

void main(List<String> arguments) {
  final check = arguments.length == 1 && arguments.single == '--check';
  if (arguments.isNotEmpty && !check) {
    stderr.writeln('Usage: dart run tools/generate_balance.dart [--check]');
    exitCode = 64;
    return;
  }

  final root = _repositoryRoot();
  final source = File('$root/$_sourcePath');
  if (!source.existsSync()) {
    _fail('Cannot find $_sourcePath: looked under $root.');
  }

  final generated = _format(_generate(_readActors(source)));
  final output = File('$root/$_outputPath');
  if (check) {
    final current = output.existsSync() ? output.readAsStringSync() : '';
    if (_normaliseNewlines(current) != _normaliseNewlines(generated)) {
      stderr.writeln(
        '$_outputPath no longer matches $_sourcePath. Run: '
        'dart run tools/generate_balance.dart',
      );
      exitCode = 1;
    }
    return;
  }

  output
    ..createSync(recursive: true)
    ..writeAsStringSync(generated);
  stdout.writeln('Generated $_outputPath from $_sourcePath.');
}

/// The checkout holding this script, so the tool works from any directory.
/// Falls back to the working directory when the script path is unusable,
/// as it is when the tool runs from a snapshot.
String _repositoryRoot() {
  final script = Platform.script;
  if (script.isScheme('file')) {
    final root = File.fromUri(script).parent.parent.path;
    if (File('$root/$_sourcePath').existsSync()) {
      return root;
    }
  }
  return Directory.current.path;
}

Map<String, Object?> _readActors(File source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source.readAsStringSync());
  } on FormatException catch (error) {
    _fail('$_sourcePath is not valid JSON: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    _fail('$_sourcePath must contain a JSON object.');
  }
  final actors = decoded['actors'];
  if (actors is! Map<String, Object?>) {
    _fail('$_sourcePath must contain an "actors" object.');
  }
  final missing = _actorKinds.where((kind) => !actors.containsKey(kind));
  final unexpected = actors.keys.where((kind) => !_actorKinds.contains(kind));
  if (missing.isNotEmpty || unexpected.isNotEmpty) {
    _fail(
      '$_sourcePath must define exactly ${_actorKinds.join(', ')}.'
      '${missing.isEmpty ? '' : ' Missing: ${missing.join(', ')}.'}'
      '${unexpected.isEmpty ? '' : ' Unexpected: ${unexpected.join(', ')}.'}',
    );
  }
  return actors;
}

String _generate(Map<String, Object?> actors) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: $_sourcePath')
    ..writeln()
    ..writeln("part of 'balance.dart';")
    ..writeln()
    ..writeln(
      'const Map<EntityKind, ActorStats> _defaultActorStats = '
      '<EntityKind, ActorStats>{',
    );

  for (final kind in _actorKinds) {
    final encoded = actors[kind];
    if (encoded is! Map<String, Object?>) {
      _fail('Actor "$kind" must be a JSON object.');
    }
    _validateStats(kind, encoded);
    buffer.writeln('  EntityKind.$kind: ActorStats(');
    for (final stat in _requiredStats.keys) {
      buffer.writeln('    $stat: ${encoded[stat]},');
    }
    if (encoded.containsKey(_attackReach)) {
      buffer.writeln('    $_attackReach: ${encoded[_attackReach]},');
    }
    for (final flag in _flags) {
      if (encoded[flag] == true) {
        buffer.writeln('    $flag: true,');
      }
    }
    buffer.writeln('  ),');
  }

  buffer.writeln('};');
  return buffer.toString();
}

void _validateStats(String kind, Map<String, Object?> stats) {
  final allowed = <String>{..._requiredStats.keys, _attackReach, ..._flags};
  final unknown = stats.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) {
    _fail('Actor "$kind" has unknown fields: ${unknown.join(', ')}.');
  }
  for (final MapEntry(key: stat, value: minimum) in _requiredStats.entries) {
    _validateStat(kind, stat, stats[stat], minimum, required: true);
  }
  if (stats.containsKey(_attackReach)) {
    _validateStat(
      kind,
      _attackReach,
      stats[_attackReach],
      _minimumAttackReach,
      required: false,
    );
  }
  for (final flag in _flags) {
    if (stats.containsKey(flag) && stats[flag] is! bool) {
      _fail('Actor "$kind" field "$flag" must be true or false.');
    }
  }
}

void _validateStat(
  String kind,
  String stat,
  Object? value,
  int minimum, {
  required bool required,
}) {
  if (value == null && !required) {
    _fail('Actor "$kind" leaves "$stat" null: drop the field instead.');
  }
  if (value is! int) {
    _fail('Actor "$kind" field "$stat" must be an integer, was: $value.');
  }
  if (value < minimum) {
    _fail('Actor "$kind" field "$stat" must be at least $minimum, was $value.');
  }
}

/// Runs the generated source through the same formatter CI checks, so a
/// regenerated file can never fail `dart format`.
String _format(String source) {
  final directory = Directory.systemTemp.createTempSync('stepbound_balance');
  try {
    final file = File('${directory.path}/default_balance.g.dart')
      ..writeAsStringSync(source);
    final result = Process.runSync(Platform.resolvedExecutable, <String>[
      'format',
      '--summary=none',
      file.path,
    ]);
    if (result.exitCode != 0) {
      _fail('dart format rejected the generated source:\n${result.stderr}');
    }
    return file.readAsStringSync();
  } finally {
    directory.deleteSync(recursive: true);
  }
}

String _normaliseNewlines(String value) => value.replaceAll('\r\n', '\n');

Never _fail(String message) {
  stderr.writeln(message);
  exit(65);
}
