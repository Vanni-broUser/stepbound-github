import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/check_coverage.dart';

/// An LCOV record for [path] with [hit] of [found] lines hit.
String _record(String path, int found, int hit) =>
    'SF:$path\nDA:1,1\nLF:$found\nLH:$hit\nend_of_record\n';

const String _code = 'int twice(int x) => x * 2;\n';
const String _data = '''
/// Level rows.
const List<String> rows = <String>['x => y', 'a) {'];
enum Kind { a, b }
''';

void main() {
  const policy = CoveragePolicy(
    total: 50,
    areas: <CoverageArea>[
      CoverageArea(name: 'platform', paths: <String>['lib/p.dart'], minimum: 0),
      CoverageArea(name: 'core', paths: <String>['lib/core/'], minimum: 80),
    ],
    excluded: <String, String>{'lib/main.dart': 'the entry point'},
  );

  CoverageResult check(String lcov, Map<String, String> libraries) =>
      checkCoverage(lcov: lcov, libraries: libraries, policy: policy);

  test('a library no test loads fails, when it has code', () {
    final result = check(_record('lib/core/a.dart', 10, 10), <String, String>{
      'lib/core/a.dart': _code,
      'lib/core/untested.dart': _code,
      'lib/main.dart': _code,
    });
    expect(result.passed, isFalse);
    expect(result.failures.single, contains('lib/core/untested.dart'));
  });

  test('a library with nothing to run is listed, not failed', () {
    final result = check(_record('lib/core/a.dart', 10, 10), <String, String>{
      'lib/core/a.dart': _code,
      'lib/core/rows.dart': _data,
      'lib/main.dart': _code,
    });
    expect(result.passed, isTrue, reason: result.report);
    expect(result.report, contains('lib/core/rows.dart'));
  });

  test('an excluded library is left out of every count, and said so', () {
    final result = check(
      _record('lib/core/a.dart', 10, 9) + _record('lib/main.dart', 50, 0),
      <String, String>{'lib/core/a.dart': _code, 'lib/main.dart': _code},
    );
    expect(result.passed, isTrue, reason: result.report);
    expect(result.report, contains('Line coverage: 90.00%'));
    expect(result.report, contains('lib/main.dart: the entry point'));
  });

  test('an exclusion for a library that is gone fails', () {
    final result = check(_record('lib/core/a.dart', 1, 1), <String, String>{
      'lib/core/a.dart': _code,
    });
    expect(result.failures.single, contains('lib/main.dart'));
  });

  test('an area under its minimum fails, whatever the total', () {
    final result = check(
      _record('lib/core/a.dart', 10, 7) + _record('lib/p.dart', 90, 90),
      <String, String>{
        'lib/core/a.dart': _code,
        'lib/p.dart': _code,
        'lib/main.dart': _code,
      },
    );
    expect(result.report, contains('Line coverage: 97.00%'));
    expect(result.failures.single, contains('core is at 70.00%'));
  });

  test('the total under its minimum fails', () {
    final result = check(_record('lib/p.dart', 10, 1), <String, String>{
      'lib/p.dart': _code,
      'lib/main.dart': _code,
    });
    expect(result.failures.single, contains('The total is at 10.00%'));
  });

  test('a library in no area fails', () {
    final result = check(_record('lib/ui/menu.dart', 10, 10), <String, String>{
      'lib/ui/menu.dart': _code,
      'lib/main.dart': _code,
    });
    expect(result.failures.single, contains('lib/ui/menu.dart'));
  });

  test('LCOV paths are absolute and may use backslashes', () {
    final lines = parseLcov(
      _record(r'C:\work\stepbound\lib\core\a.dart', 4, 3) +
          _record('/builds/stepbound/lib/p.dart', 2, 2),
    );
    expect(lines.keys, <String>['lib/core/a.dart', 'lib/p.dart']);
    expect(lines['lib/core/a.dart'], (found: 4, hit: 3));
  });

  group('executable code', () {
    for (final (source, expected) in <(String, bool)>[
      ('const int answer = 42;', false),
      ("export 'package:x/y.dart';", false),
      (
        'enum Sfx { a(1); const Sfx(this.v, {this.w = 2}); final int v; '
            'final int w; }',
        false,
      ),
      ("// void run() { go(); }\nconst String s = 'x => y';", false),
      ('void run() {}', true),
      ('int get size => 3;', true),
      ('int get size { return 3; }', true),
      ('Future<void> load() async {}', true),
      ('final class A { A(int x) : y = x; final int y; }', true),
    ]) {
      test(source.replaceAll('\n', r'\n'), () {
        expect(hasExecutableCode(source), expected);
      });
    }
  });

  test('the policy of the repository reads, and its paths exist', () {
    final policy = CoveragePolicy.fromJson(
      jsonDecode(File('tools/coverage_policy.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(policy.areas.map((area) => area.name), <String>[
      'platform',
      'persistence',
      'core',
      'ui',
      'game',
    ]);
    for (final area in policy.areas) {
      for (final path in area.paths) {
        expect(
          path.endsWith('/')
              ? Directory(path).existsSync()
              : File(path).existsSync(),
          isTrue,
          reason: path,
        );
      }
    }
  });
}
