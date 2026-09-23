import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/balance/default.json';
const String _outputPath = 'lib/core/entities/default_balance.g.dart';
const Set<String> _actorKinds = <String>{
  'player',
  'wanderer',
  'sprinter',
  'brute',
  'blind',
  'carabiniere',
};
const List<String> _requiredStats = <String>[
  'tickCost',
  'health',
  'vision',
  'hearing',
  'contactDamage',
];

void main(List<String> arguments) {
  if (arguments.any((argument) => argument != '--check') ||
      arguments.where((argument) => argument == '--check').length > 1) {
    stderr.writeln('Usage: dart run tools/generate_balance.dart [--check]');
    exitCode = 64;
    return;
  }

  final decoded = jsonDecode(File(_sourcePath).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    _fail('$_sourcePath must contain a JSON object.');
  }
  final actors = decoded['actors'];
  if (actors is! Map<String, Object?>) {
    _fail('$_sourcePath must contain an "actors" object.');
  }
  final actualKinds = actors.keys.toSet();
  if (!_sameSet(actualKinds, _actorKinds)) {
    _fail(
      '$_sourcePath must define exactly: ${_actorKinds.join(', ')}; '
      'found: ${actualKinds.join(', ')}.',
    );
  }

  final generated = _generate(actors);
  final output = File(_outputPath);
  if (arguments.contains('--check')) {
    final current = output.existsSync() ? output.readAsStringSync() : '';
    if (_normaliseNewlines(current) != _normaliseNewlines(generated)) {
      stderr.writeln(
        '$_outputPath is out of date. Run: '
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

String _generate(Map<String, Object?> actors) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: assets/balance/default.json')
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
    buffer
      ..writeln('  EntityKind.$kind: ActorStats(')
      ..writeln("    tickCost: ${encoded['tickCost']},")
      ..writeln("    health: ${encoded['health']},")
      ..writeln("    vision: ${encoded['vision']},")
      ..writeln("    hearing: ${encoded['hearing']},")
      ..writeln("    contactDamage: ${encoded['contactDamage']},");
    if (encoded['attackReach'] case final int attackReach) {
      buffer.writeln('    attackReach: $attackReach,');
    }
    buffer.writeln('  ),');
  }

  buffer.writeln('};');
  return buffer.toString();
}

void _validateStats(String kind, Map<String, Object?> stats) {
  final allowed = <String>{..._requiredStats, 'attackReach'};
  final unknown = stats.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    _fail('Actor "$kind" has unknown fields: ${unknown.join(', ')}.');
  }
  for (final field in _requiredStats) {
    if (stats[field] is! int) {
      _fail('Actor "$kind" field "$field" must be an integer.');
    }
  }
  if (stats['attackReach'] != null && stats['attackReach'] is! int) {
    _fail('Actor "$kind" field "attackReach" must be an integer.');
  }
  if ((stats['tickCost']! as int) <= 0 ||
      (stats['health']! as int) <= 0 ||
      (stats['vision']! as int) < 0 ||
      (stats['hearing']! as int) < 0 ||
      (stats['contactDamage']! as int) < 0 ||
      (stats['attackReach'] as int? ?? 1) <= 0) {
    _fail('Actor "$kind" contains stats outside their valid range.');
  }
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _normaliseNewlines(String value) => value.replaceAll('\r\n', '\n');

Never _fail(String message) {
  stderr.writeln(message);
  exit(65);
}
