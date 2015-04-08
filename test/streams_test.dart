// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:unittest/unittest.dart';
import '../web/async.dart';

class StreamWrapper<A> {
  final List<A> list = [];
  final Stream<A> stream;
  StreamWrapper(this.stream) {
    stream.listen((e) => list.add(e));
  }
}

void main() {
  test('intermix', () {
    var a = new StreamController();
    var b = new StreamController();
    var c = intermix(a.stream, b.stream);
    var w = new StreamWrapper(c);

    scheduleMicrotask(() => a.add(5));
    scheduleMicrotask(() => b.add(6));
    scheduleMicrotask(() => a.add(7));
    scheduleMicrotask(() => b.add(8));

    var check = expectAsync(() {
      expect(w.list, equals([5, 6, 7, 8]));
    });

    Timer.run(check);
  });

  test('pair', () {
    var a = new StreamController();
    var b = new StreamController();
    var c = pairStream(a.stream, b.stream);
    var w = new StreamWrapper(c);

    scheduleMicrotask(() => a.add(5));
    scheduleMicrotask(() => b.add(6));
    scheduleMicrotask(() => a.add(7));
    scheduleMicrotask(() => b.add(8));

    var check = expectAsync(() {
      expect(w.list, equals([[5, 6], [7, 6], [7, 8]]));
    });

    Timer.run(check);
  });
}
