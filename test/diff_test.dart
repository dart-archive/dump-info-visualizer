// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library dump_viz.test.diff_test;

import 'package:dump_viz/src/info_helper.dart';
import 'package:dump_viz/src/diff_alg.dart';

import 'package:test/test.dart';

class FakeInfoHelper {
  InfoHelper info;
  FakeInfoHelper() {
    info = new InfoHelper(3, {}, {}, {});
  }
  FakeInfoHelper.fromFuncs(List funcs) {
    int i = 0;
    Map<String, Map<String, Map<String, dynamic>>> elements = {};
    Map<String, Map<String, dynamic>> functions = {};
    Map<String, Map<String, dynamic>> libraries = {};

    elements['function'] = functions;
    elements['library'] = libraries;

    Map<String, dynamic> liba = {'name': "LibA"};
    libraries['0'] = liba;
    List<String> children = [];
    liba['children'] = children;

    for (var func in funcs) {
      functions['$i'] = func;
      children.add('function/$i');
      func['id'] = 'function/$i';
      i++;
    }
    info = new InfoHelper(3, elements, {}, {});
  }
}

void main() {
  test('empty', () {
    var d = diff(new FakeInfoHelper().info, new FakeInfoHelper().info);
    expect(d, equals([]));
  });
  test('change', () {
    var one = [{'name': 'foo', 'size': 10}];
    var two = [{'name': 'foo', 'size': 20}];
    expect(diff(new FakeInfoHelper.fromFuncs(one).info,
            new FakeInfoHelper.fromFuncs(two).info),
        equals([new DiffItem('partial-add', 'LibA.foo', 10)]));
  });
  test('add/remove', () {
    var one = [{'name': 'foo', 'size': 10}];
    var two = [{'name': 'bar', 'size': 20}];
    expect(diff(new FakeInfoHelper.fromFuncs(one).info,
        new FakeInfoHelper.fromFuncs(two).info), equals([
      new DiffItem('full-add', 'LibA.bar', 20),
      new DiffItem('full-remove', 'LibA.foo', -10)
    ]));
  });
}
