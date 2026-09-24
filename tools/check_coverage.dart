// Checks the line coverage of `flutter test --coverage` against
// tools/coverage_policy.json, and makes sure the number means something.
//
// An LCOV file only lists the libraries some test ran code in: a library
// no test touches is missing from both sides of the percentage, and the
// total still looks fine. So every library under lib/ must be accounted
// for, one of three ways:
//
// - in the LCOV file, and then counted in the first area of the policy
//   whose paths it matches (each area has its own minimum);
// - without a line of executable code (constants, enums, level maps,
//   exports), which is why it is missing;
// - excluded by the policy, with the reason written next to it.
//
// A library that is none of those is untested code, and fails the check.
//
//   flutter test --coverage
//   dart run tools/check_coverage.dart
//
// Exit codes: 1 the coverage fails the policy, 64 wrong arguments, 66 a
// file is missing.
import 'dart:convert';
import 'dart:io';

const String _policyPath = 'tools/coverage_policy.json';
const String _lcovPath = 'coverage/lcov.info';

void main(List<String> arguments) {
  if (arguments.isNotEmpty) {
    stderr.writeln('Usage: dart run tools/check_coverage.dart');
    exitCode = 64;
    return;
  }
  final lcov = File(_lcovPath);
  final policy = File(_policyPath);
  for (final file in <File>[lcov, policy]) {
    if (!file.existsSync()) {
      stderr.writeln(
        'Cannot find ${file.path}: run `flutter test --coverage` first, '
        'from the repository root.',
      );
      exitCode = 66;
      return;
    }
  }
  final libraries = <String, String>{
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        _normalise(entity.path): entity.readAsStringSync(),
  };
  final result = checkCoverage(
    lcov: lcov.readAsStringSync(),
    libraries: libraries,
    policy: CoveragePolicy.fromJson(
      jsonDecode(policy.readAsStringSync()) as Map<String, Object?>,
    ),
  );
  stdout.write(result.report);
  if (!result.passed) {
    exitCode = 1;
  }
}

/// What tools/coverage_policy.json says.
final class CoveragePolicy {
  const CoveragePolicy({
    required this.total,
    required this.areas,
    required this.excluded,
  });

  factory CoveragePolicy.fromJson(Map<String, Object?> json) => CoveragePolicy(
    total: (json['total']! as num).toDouble(),
    areas: <CoverageArea>[
      for (final area in json['areas']! as List<Object?>)
        CoverageArea.fromJson(area! as Map<String, Object?>),
    ],
    excluded: <String, String>{
      for (final MapEntry(:key, :value)
          in (json['excluded']! as Map<String, Object?>).entries)
        key: value! as String,
    },
  );

  /// Minimum line coverage of everything counted, in percent.
  final double total;

  /// In order: a library counts in the first area it matches.
  final List<CoverageArea> areas;

  /// Libraries left out of every count, each with its reason.
  final Map<String, String> excluded;
}

/// A part of lib/ with its own minimum.
final class CoverageArea {
  const CoverageArea({
    required this.name,
    required this.paths,
    required this.minimum,
  });

  factory CoverageArea.fromJson(Map<String, Object?> json) => CoverageArea(
    name: json['name']! as String,
    paths: (json['paths']! as List<Object?>).cast<String>(),
    minimum: (json['minimum']! as num).toDouble(),
  );

  final String name;

  /// Library paths, or folders ending in `/`.
  final List<String> paths;
  final double minimum;

  bool contains(String library) => paths.any(
    (path) => path.endsWith('/') ? library.startsWith(path) : library == path,
  );
}

/// Lines found and lines hit.
typedef LineCount = ({int found, int hit});

final class CoverageResult {
  const CoverageResult({required this.report, required this.failures});

  final String report;
  final List<String> failures;

  bool get passed => failures.isEmpty;
}

/// Checks [lcov] against [policy]; [libraries] maps every library under
/// lib/ (as `lib/...`) to its source.
CoverageResult checkCoverage({
  required String lcov,
  required Map<String, String> libraries,
  required CoveragePolicy policy,
}) {
  final covered = parseLcov(lcov);
  final failures = <String>[];
  final report = StringBuffer();

  for (final path in policy.excluded.keys) {
    if (!libraries.containsKey(path)) {
      failures.add('$path is excluded but does not exist: drop it.');
    }
  }
  final noCode = <String>[];
  for (final library in libraries.keys.toList()..sort()) {
    if (covered.containsKey(library) || policy.excluded.containsKey(library)) {
      continue;
    }
    if (hasExecutableCode(libraries[library]!)) {
      failures.add(
        '$library has code no test runs: test it, or exclude it in '
        '$_policyPath with the reason.',
      );
    } else {
      noCode.add(library);
    }
  }

  final byArea = <String, LineCount>{
    for (final area in policy.areas) area.name: (found: 0, hit: 0),
  };
  var total = (found: 0, hit: 0);
  for (final MapEntry(key: library, value: lines) in covered.entries) {
    if (policy.excluded.containsKey(library)) {
      continue;
    }
    total = (found: total.found + lines.found, hit: total.hit + lines.hit);
    final area = policy.areas.where((area) => area.contains(library));
    if (area.isEmpty) {
      failures.add('$library is in no area of $_policyPath.');
      continue;
    }
    final sum = byArea[area.first.name]!;
    byArea[area.first.name] = (
      found: sum.found + lines.found,
      hit: sum.hit + lines.hit,
    );
  }

  report.writeln('Line coverage by area:');
  for (final area in policy.areas) {
    final lines = byArea[area.name]!;
    final percent = _percent(lines);
    final ok = percent >= area.minimum;
    report.writeln(
      '  ${area.name.padRight(12)} ${'${lines.hit}/${lines.found}'.padLeft(11)}'
      '  ${percent.toStringAsFixed(2).padLeft(6)}%'
      '  (minimum ${area.minimum.toStringAsFixed(0)}%)'
      '${ok ? '' : '  FAIL'}',
    );
    if (!ok) {
      failures.add(
        '${area.name} is at ${percent.toStringAsFixed(2)}%, below its '
        'minimum of ${area.minimum.toStringAsFixed(0)}%.',
      );
    }
  }
  report
    ..writeln()
    ..writeln('Libraries with no executable code, not in the report:');
  for (final library in noCode) {
    report.writeln('  $library');
  }
  if (policy.excluded.isNotEmpty) {
    report.writeln('Excluded from every count:');
    for (final MapEntry(key: path, value: reason) in policy.excluded.entries) {
      report.writeln('  $path: $reason');
    }
  }
  final percent = _percent(total);
  report
    ..writeln()
    ..writeln('Line coverage: ${percent.toStringAsFixed(2)}%');
  if (percent < policy.total) {
    failures.add(
      'The total is at ${percent.toStringAsFixed(2)}%, below its minimum of '
      '${policy.total.toStringAsFixed(0)}%.',
    );
  }
  for (final failure in failures) {
    report.writeln('FAIL: $failure');
  }
  return CoverageResult(report: report.toString(), failures: failures);
}

/// Lines found and hit per library in an LCOV report, keyed `lib/...`.
Map<String, LineCount> parseLcov(String lcov) {
  final libraries = <String, LineCount>{};
  String? current;
  var found = 0;
  var hit = 0;
  for (final line in const LineSplitter().convert(lcov)) {
    if (line.startsWith('SF:')) {
      current = _normalise(line.substring(3));
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && current != null) {
      libraries[current] = (found: found, hit: hit);
      current = null;
    }
  }
  return libraries;
}

/// Whether [source] has a line the VM could report: a function, method,
/// getter or constructor body, or a constructor's initialiser list. Doc
/// comments, strings, const constructors and data do not count. It errs
/// towards true: a false "no code" would hide an untested library.
bool hasExecutableCode(String source) {
  final code = _stripCommentsAndStrings(source);
  return code.contains('=>') ||
      RegExp(r'\)\s*(async\s*\*?|sync\s*\*)?\s*\{').hasMatch(code) ||
      RegExp(r'\b(get|set)\s+\w+\s*(\([^)]*\))?\s*\{').hasMatch(code) ||
      // A constructor's initialiser list.
      RegExp(r'\)\s*:\s*\w').hasMatch(code);
}

String _stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    final char = source[i];
    if (char == "'" || char == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(char * 3, i);
      final quote = triple ? char * 3 : char;
      var j = i + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        j += !raw && source[j] == r'\' ? 2 : 1;
      }
      out.write('""');
      i = j + quote.length;
      continue;
    }
    out.write(char);
    i++;
  }
  return out.toString();
}

double _percent(LineCount lines) =>
    lines.found == 0 ? 100 : lines.hit * 100 / lines.found;

/// `lib/...` with forward slashes, whatever the platform and the path
/// before `lib/` (LCOV files hold absolute paths).
String _normalise(String path) {
  final slashed = path.replaceAll(r'\', '/');
  final lib = slashed.lastIndexOf('/lib/');
  return lib >= 0 ? slashed.substring(lib + 1) : slashed;
}
