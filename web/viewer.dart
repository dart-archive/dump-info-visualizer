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

final List<String> slides = const <String>[
  'info',
  'hier',
  'dep',
  'load',
  'diff'
];
final Duration animationTime = const Duration(milliseconds: 10);

void _noSlide() {
  // Disable all of the slides and tabs
  for (String id in slides) {
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

  new Timer(animationTime, () {
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

@whenPolymerReady
void init() {
  HistoryState.setup(_switchSlide, animationTime);
  _noSlide();
  _switchSlide('load');

  var dragDrop = new DragDropFile(
      querySelector('#drag-target'), querySelector('#file_upload'));

  var refreshButton = querySelector('#refresh');
  refreshButton.onClick.listen((e) {
    e.preventDefault();
    e.stopPropagation();
    dragDrop.reload();
  });

  bool alreadyLoaded = false;

  var treeTable = querySelector('tree-table') as TreeTable;
  var dependencyView = querySelector('dependency-view') as DependencyView;
  var diffView = querySelector('diff-view') as DiffView;

  var tabs = querySelectorAll('paper-tab');
  for (PaperTab tab in tabs) {
    tab.onClick.listen((_) {
      String link = tab.attributes['slide'];
      HistoryState.switchTo(new HistoryState(link));
    });
  }

  // Sort by chosen sorting methods.
  var select = querySelector('select#sort') as SelectElement;
  var sortby = 'name';
  select.onChange.listen((e) {
    sortby = select.options[select.selectedIndex].value;
    treeTable.sort(sortby);
  });

  // When a file is loaded
  dragDrop.onFile.listen((String jsonString) {
    Map<String, dynamic> json = JSON.decode(jsonString);
    document.querySelector('core-toolbar').style.top = "0";

    var info =
        new InfoHelper(json['elements'], json['holding'], json['program']);

    diffView.currentlyLoaded = info;

    if (alreadyLoaded) {
      treeTable.clear();
    } else {
      HistoryState.switchTo(new HistoryState('info'));
    }

    if (!json.containsKey('dump_version')) {
      processData(json, treeTable);
    } else {
      switch (json['dump_version'] as dynamic) {
        case 1:
        case 2:
        case 3:
          var view = new ViewVersion(info, treeTable, dependencyView,
              () => HistoryState.switchTo(new HistoryState('hier')),
              () => HistoryState.switchTo(new HistoryState('dep')));
          view.display();
          treeTable.sort(sortby);
          treeTable.reset();
          break;
        default:
          window.alert('Unknown dump-info version');
      }
    }

    // Sort by name as default
    treeTable.sort(sortby);

    alreadyLoaded = true;
  });
}
