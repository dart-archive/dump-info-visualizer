// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library async;

import 'dart:async';

/// Mixes the two streams into one.  All the events from
/// the incoming streams are placed into the output Stream
/// in the order that they are received.
Stream intermix(Stream a, Stream b) {
  StreamController _streamController = new StreamController();
  bool otherDone = false;
  a.listen((e) {
    _streamController.add(e);
  }, onError: (e) {
    _streamController.addError(e);
  }, onDone: () {
    if (otherDone) {
      _streamController.close();
    }
    otherDone = true;
  });

  b.listen((e) {
    _streamController.add(e);
  }, onError: (e) {
    _streamController.addError(e);
  }, onDone: () {
    if (otherDone) {
      _streamController.close();
    }
    otherDone = true;
  });

  return _streamController.stream;
}

/// Takes a `Stream<A>` [a] and a `Stream<B>` [b] and produces a
/// `Stream<[A, B]>`
///
/// Once the function has received an item of each stream, it pushes the
/// pair `[lastA, lastB]` for every new value of `lastA` or `lastB` (where
/// `lastA` and `lastB` are the last received elements of `a` and `b`
/// respectively.  The element of the non-changing stream is reused.
///
/// This stream may discard elements.  For example, if `a` sends two elements
/// before `b` sends any, the first element from `a` will not exist in the
/// stream.
Stream pairStream(Stream a, Stream b) {
  bool otherDone = false;
  StreamController _streamController = new StreamController();
  var lastAFound = false;
  var lastBFound = false;
  var lastA = null;
  var lastB = null;

  a.listen((e) {
    lastA = e;
    lastAFound = true;
    if (lastBFound) {
      _streamController.add([lastA, lastB]);
    }
  }, onError: (e) {
    _streamController.addError(e);
  }, onDone: () {
    if (otherDone) {
      _streamController.close();
    }
    otherDone = true;
  });

  b.listen((e) {
    lastB = e;
    lastBFound = true;
    if (lastAFound) {
      _streamController.add([lastA, lastB]);
    }
  }, onError: (e) {
    _streamController.addError(e);
  }, onDone: () {
    if (otherDone) {
      _streamController.close();
    }
    otherDone = true;
  });

  return _streamController.stream;
}
