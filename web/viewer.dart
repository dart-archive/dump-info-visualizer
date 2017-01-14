// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.viewer;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';

import 'package:paper_elements/paper_ripple.dart';
import 'package:paper_elements/paper_tab.dart';
import 'package:polymer/polymer.dart';

import 'package:dump_viz/dump_viz.dart';

export 'package:polymer/init.dart';

const List<String> _slides = const <String>[
  'info',
  'hier',
  'dep',
  'load',
  'diff'
];
const Duration _animationTime = const Duration(milliseconds: 10);

const _localStorageKey = 'dump_viz.last_file';

bool get hasCache => window.localStorage.containsKey(_localStorageKey);

String _getCache() {
  if (!hasCache) {
    throw 'No value stored!';
  }
  return window.localStorage[_localStorageKey];
}

String _setCache(String value) => window.localStorage[_localStorageKey] = value;

void _noSlide() {
  // Disable all of the slides and tabs
  for (String id in _slides) {
    var slide = document.querySelector('#$id-slide');
    slide.style.opacity = '0';
    //slide.style.left = '100px';
    slide.style.left = '0px';
    slide.style.maxHeight = '0px';
    slide.style.zIndex = '0';

    var tab = document.querySelector('#$id-tab');
    if (tab != null) {
      tab.classes.remove('core-selected');
    }
  }
}

void _switchSlide(String id, {bool fromMouse: false}) {
  _noSlide();
  var slide = document.querySelector('#$id-slide');
  slide.style.maxHeight = 'none';
  slide.style.zIndex = '1';

  new Timer(_animationTime, () {
    slide.style.opacity = '1';
    slide.style.left = '0px';
    var tab = document.querySelector('#$id-tab');

    if (tab != null) {
      tab.classes.add('core-selected');
      var tabs = document.querySelector('paper-tabs');
      tabs.attributes['selected'] = tab.attributes['offset'];
      // Draw a ripple on the tab if we didn't already click on it.
      if (!fromMouse) {
        PaperRipple ripple = tab.shadowRoot.querySelector('paper-ripple');
        var pos = {
          'x': tabs.offsetLeft + tab.offsetLeft + tab.clientWidth / 2,
          'y': 0
        };
        ripple.jsElement.callMethod('downAction', [new JsObject.jsify(pos)]);
        window.animationFrame
            .then((_) => ripple.jsElement.callMethod('upAction', []));
      }
    }
  });
}

ButtonElement get _useLastButton => querySelector('#useLast') as ButtonElement;

ButtonElement get _clearCacheButton =>
    querySelector('#clearCache') as ButtonElement;

@whenPolymerReady
void init() {
  HistoryState.setup(_switchSlide, _animationTime);
  _noSlide();
  _switchSlide('load');

  bool alreadyLoaded = false;

  var dragDrop = querySelector('drag-drop-view') as DragDropView;
  var dependencyView = querySelector('dependency-view') as DependencyView;
  var diffView = querySelector('diff-view') as DiffView;
  var hierarchyView = querySelector('hierarchy-view') as HierarchyView;
  var programInfoView = querySelector('program-info-view') as ProgramInfoView;

  var tabs = querySelectorAll('paper-tab');
  for (PaperTab tab in tabs) {
    tab.onClick.listen((_) {
      String link = tab.attributes['slide'];
      HistoryState.switchTo(new HistoryState(link));
    });
  }

  void loadJson(String jsonString) {
    var json;
    try {
      json = JSON.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      window.console.error("Error parsing json");
      window.console.error(e);
      return;
    }
    document.querySelector('core-toolbar').style.top = "0";

    var info = new InfoHelper.fromJson(json);

    diffView.currentlyLoaded = info;

    if (alreadyLoaded) {
      hierarchyView.clear();
    } else {
      HistoryState.switchTo(new HistoryState('info'));
    }

    var dumpVersion = info.dumpVersion as num;

    if (dumpVersion < 1 || dumpVersion > 5) {
      window.alert('Unknown dump-info version: $dumpVersion');
      return;
    }

    dependencyView.dumpInfo = info;
    hierarchyView.dumpInfo = info;
    programInfoView.dumpInfo = info;

    alreadyLoaded = true;
    _updateButton();
  }

  // When a file is loaded
  dragDrop.onFile.listen((json) {
    try {
      _setCache(json);
    } catch (e) {
      window.console.error(
          'Could not populate cache. May be too big. Try the clear button.');
      window.console.error(e);
    }
    loadJson(json);
  });

  _clearCacheButton.onClick.listen((_) {
    window.localStorage.clear();
    _updateButton();
  });

  _useLastButton.onClick.listen((_) {
    loadJson(_getCache());
  });

  _updateButton();
}

void _updateButton() {
  _useLastButton.disabled = !hasCache;
  _clearCacheButton.disabled = window.localStorage.isEmpty;
}
