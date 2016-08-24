// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@HtmlImport('polymer.html')
library polymer_interop.polymer_interop;

import 'dart:async';
import 'dart:html';
import 'dart:js' as js;
import 'package:web_components/web_components.dart';
export 'src/polymer_proxy_mixin.dart';

final js.JsObject _polymer = js.context['Polymer'];

/// Wrapper which provides access to many polymer js apis.
class PolymerJs {
  static js.JsFunction get constructor => _polymer as js.JsFunction;

  static void resolveElementPaths(Node node) {
    if (!checkExists()) return;
    _polymer['urlResolver'].callMethod('resolveDom', [node]);
  }

  static void flush() {
    if (!checkExists()) return;
    _polymer.callMethod('flush');
  }

  static List<Element> get waitingFor {
    if (!checkExists()) return null;
    return _polymer.callMethod('waitingFor', [null]);
  }

  static void forceReady([int timeout]) {
    if (!checkExists()) return null;
    _polymer.callMethod('forceReady', [null, timeout]);
  }

  static Future importElements(Node elementOrFragment) {
    if (!checkExists()) return null;
    var completer = new Completer();
    _polymer.callMethod(
        'importElements', [elementOrFragment, () => completer.complete()]);
    return completer.future;
  }

  static Future import(List urls) {
    if (!checkExists()) return null;
    var completer = new Completer();
    _polymer.callMethod('import', [urls, () => completer.complete()]);
    return completer.future;
  }

  static void whenPolymerReady(f()) {
    if (!checkExists()) return null;
    _polymer.callMethod(
        'whenPolymerReady', [Zone.current.bindCallback(() => f())]);
  }

  static void endOfMicrotask(f()) {
    if (!checkExists()) return null;
    _polymer.callMethod('endOfMicrotask', [() => f()]);
  }

  static bool outputPolymerError = false;
  static bool checkExists() {
    if (_polymer != null) return true;
    if (!outputPolymerError) {
      outputPolymerError = true;
      window.console.error('Unable to find Polymer. Please make sure you are '
          'waiting on initWebComponents() or initPolymer() before attempting '
          'to use Polymer.');
    }
    return false;
  }
}

final js.JsObject _polymerGestures = js.context['PolymerGestures'];

class PolymerGesturesJs {
  static void addEventListener(Node node, String type, callback) {
    if (!checkExists()) return null;
    _polymerGestures.callMethod('addEventListener', [node, type, callback]);
  }

  static void removeEventListener(Node node, String type, callback) {
    if (!checkExists()) return null;
    _polymerGestures.callMethod('removeEventListener', [node, type, callback]);
  }

  static bool outputPolymerGesturesError = false;
  static bool checkExists() {
    if (_polymerGestures != null) return true;
    if (!outputPolymerGesturesError) {
      outputPolymerGesturesError = true;
      window.console.error('Unable to find PolymerGestures. Please make sure '
          'you are waiting on initWebComponents() or initPolymer() before '
          'attempting to use PolymerGestures.');
    }
    return false;
  }
}
