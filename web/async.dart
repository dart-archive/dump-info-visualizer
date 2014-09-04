library async;

import 'dart:async';

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
