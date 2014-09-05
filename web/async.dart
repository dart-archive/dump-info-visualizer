// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library async;

import 'dart:async';

// Mixes the two streams into one.  All the events from
// the incoming streams are placed into the output Stream
// in the order that they are recieved.
Stream intermix(Stream a, Stream b) {
  StreamController _streamController = new StreamController();
  a.listen((e){
    _streamController.add(e);
  }, onError: (e){
    _streamController.addError(e);
  });

  b.listen((e){
    _streamController.add(e);
  }, onError: (e){
    _streamController.addError(e);
  });

  return _streamController.stream;
}

// Takes a Stream<A> and a Stream<B> and produces
// a Stream<[A, B]>.  The first item in the stream
// is produced after all other values have been
// seen at least once.  After that happens, a new
// list will be pushed through the stream when
// either stream gets updated.
Stream pairStream(Stream a, Stream b) {
  StreamController _streamController = new StreamController();
  var lastA = null;
  var lastB = null;

  a.listen((e){
    lastA = e;
    if (lastB != null) {
      _streamController.add([lastA, lastB]);
    }
  }, onError: (e){
    _streamController.addError(e);
  });

  b.listen((e){
    lastB = e;
    if (lastA != null) {
      _streamController.add([lastA, lastB]);
    }
  }, onError: (e){
    _streamController.addError(e);
  });

  return _streamController.stream;
}
