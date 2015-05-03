// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.history;

import 'dart:async';
import 'dart:html';

import 'dependency_view.dart';

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
      case 'info':
        return new _InfoHistoryState();
      case 'hier':
        return new _HierHistoryState(_lastHierPos);
      case 'dep':
        var target = depTarget;
        if (target == null) {
          target = _lastDepFocus;
        }
        return new _DepHistoryState(target);
      case 'diff':
        return new _DiffHistoryState(_lastDiffPos);
      default:
        return null;
    }
  }

  static void setup(Function slideSwitcher, Duration animationTime) {
    window.onPopState.listen((popStateEvent) {
      var newState = HistoryState.fromJson(popStateEvent.state);
      switchTo(newState, fromPop: true);
    });
    HistoryState._slideSwitcher = slideSwitcher;
    HistoryState._animationTime = animationTime;
  }

  static void switchTo(HistoryState newState, {fromPop: false}) {
    if (_currentState != null) {
      _currentState.finalize();
    }
    if (!fromPop) {
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
      case 'diff':
        return new _DiffHistoryState(json['pos']);
      default:
        return null;
    }
  }

  // When modifying the history from outside the
  // back / forward buttons, we need to track these
  // values ourselves.
  static int _lastHierPos = 0;
  static int _lastDiffPos = 0;
  static String _lastDepFocus = null;
  static HistoryState _currentState = null;
  static Function _slideSwitcher;
  static Duration _animationTime;
}

class _InfoHistoryState implements HistoryState {
  String get asUrl => "slide=info";

  void apply() {
    HistoryState._slideSwitcher('info');
  }

  void finalize() {}

  dynamic toJson() {
    return {'kind': 'info'};
  }
}

class _DiffHistoryState implements HistoryState {
  int pos;
  _DiffHistoryState(this.pos);

  String get asUrl => "slide=diff";

  void apply() {
    HistoryState._slideSwitcher('diff');
    new Timer(HistoryState._animationTime * 3, () {
      document.body.scrollTop = pos;
    });
  }

  void finalize() {
    pos = document.body.scrollTop;
    HistoryState._lastDiffPos = pos;
    window.history.replaceState(this.toJson(), "", "");
  }

  dynamic toJson() {
    return {'kind': 'diff', 'pos': pos};
  }
}

class _HierHistoryState implements HistoryState {
  int pos;
  _HierHistoryState(this.pos);

  String get asUrl => "slide=hier";

  void apply() {
    HistoryState._slideSwitcher('hier');
    new Timer(HistoryState._animationTime * 3, () {
      document.body.scrollTop = pos;
    });
  }

  void finalize() {
    pos = document.body.scrollTop;
    HistoryState._lastHierPos = pos;
    window.history.replaceState(this.toJson(), "", "");
  }

  dynamic toJson() {
    return {'kind': 'hier', 'pos': pos};
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
    return {'kind': 'dep', 'focus': focus};
  }
}
