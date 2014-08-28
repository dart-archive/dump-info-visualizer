// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library history;

import 'dart:html';
import 'dart:async';

abstract class HistoryState {
  /// Apply this history state and modify the view.
  void apply();
  /// Called when a HistoryState is about to be
  /// moved out of.
  void finalize();

  String get asUrl;

  /// Convert this history state to JSON to be serialized
  Map<String, dynamic> toJson();

  factory HistoryState(String type, {String depTarget: null}) {
    switch (type) {
      case 'info': return new _InfoHistoryState();
      case 'hier': return new _HierHistoryState(_lastHierPos);
      case 'dep':
        var target = depTarget;
        if (target == null) {
          target = _lastDepFocus;
        }
        return new _DepHistoryState(target);
      default: return null;
    }
  }

  static void setup(Function slideSwitcher, int animationTime) {
    window.onPopState.listen((popStateEvent) {
      var newState = HistoryState.fromJson(popStateEvent.state);
      print("poping $newState");
      switchTo(newState, fromPop: true);
    });
    HistoryState._slideSwitcher = slideSwitcher;
    HistoryState._animationTime = animationTime;
  }

  static switchTo(HistoryState newState, {fromPop: false}) {
    if (_currentState != null) {
      _currentState.finalize();
    }
    if (!fromPop) {
      print("pushing $newState");
      window.history.pushState(newState.toJson(), "test", "?" + newState.asUrl);
    }
    newState.apply();
    _currentState = newState;
  }

  /// Convert json to a HistoryState
  static HistoryState fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'info':
        return new _InfoHistoryState();
      case 'hier':
        return new _HierHistoryState(json['pos']);
      case 'dep':
        return new _DepHistoryState(json['focus']);
      default: return null;
    }
  }

  // When modifying the history from outside the
  // back / forward buttons, we need to track these
  // values ourselves.
  static int _lastHierPos = 0;
  static String _lastDepFocus = null;
  static HistoryState _currentState = null;
  static Function _slideSwitcher;
  static int _animationTime;
}

class _InfoHistoryState implements HistoryState {
  String get asUrl => "slide=info";
  void apply() {
    HistoryState._slideSwitcher('info');
  }
  void finalize() { }
  dynamic toJson() {
    return { 'kind': 'info' };
  }
}

class _HierHistoryState implements HistoryState {
  int pos;
  _HierHistoryState(this.pos);

  String get asUrl => "slide=hier";

  void apply() {
    HistoryState._slideSwitcher('hier');
    new Timer(HistoryState._animationTime * 2, () {
      document.body.scrollTop = pos;
    });
  }

  void finalize() {
   pos = document.body.scrollTop;
   HistoryState._lastHierPos = pos;
   window.history.replaceState(this.toJson(), "", "");
  }

  dynamic toJson() {
    return { 'kind': 'hier', 'pos': pos };
  }
}

class _DepHistoryState implements HistoryState {
  final String focus;
  _DepHistoryState(this.focus);

  String get asUrl => "slide=dep&focus=$focus";

  void apply() {
    DependencyView depview = querySelector('dependency-view');
    if (focus != null) {
      depview.target = focus;
    }
    HistoryState._slideSwitcher('dep');
    HistoryState._lastDepFocus = focus;
  }

  void finalize() {
    HistoryState._lastDepFocus = focus;
  }

  dynamic toJson() {
    return { 'kind': 'dep', 'focus': focus };
  }
}
