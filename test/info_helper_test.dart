@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dump_viz/src/info_helper.dart';

Map<String, dynamic> _content;

void main() {
  setUp(() async {
    if (_content == null) {
      var samplePath = p.join(p.current, 'test', 'sample.info.json');
      var file = new File(samplePath);
      var jsonString = await file.readAsString();
      _content = JSON.decode(jsonString);
    }
  });

  test('bootstrap', () {
    expect(_content, isNotEmpty);
  });

  test("basics", () {
    var info = new InfoHelper.fromJson(_content);

    expect(info.dumpVersion, 3);
    expect(info.size, 929444);
    expect(info.joinedPaths, hasLength(5148));
  });
}
