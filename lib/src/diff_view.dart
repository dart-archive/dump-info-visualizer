// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.diff_view;

import 'dart:async';
import 'dart:convert';
import 'dart:html' hide Selection;

import 'package:polymer/polymer.dart';

import 'async.dart';
import 'diff_alg.dart';
import 'drag_drop_file.dart';
import 'info_helper.dart';

@CustomTag('diff-view')
class DiffView extends PolymerElement {
  UListElement list;
  InfoHelper currentlyLoaded;

  DiffView.created() : super.created();

  void ready() {
    InfoHelper strToHelper(String input) {
      Map<String, dynamic> json = JSON.decode(input);
      return new InfoHelper(json['elements'], json['holding'], json['program']);
    }
    list = $['list'];

    var beforeFile = new DragDropFile(
        $['before-drop'], $['before-file-upload']).onFile.map(strToHelper);
    var afterFile = new DragDropFile(
        $['after-drop'], $['after-file-upload']).onFile.map(strToHelper);
    var beforeUseCurrent = $['before-use-current'];
    var afterUseCurrent = $['after-use-current'];

    Stream<InfoHelper> beforeCurrent =
        beforeUseCurrent.onClick.map((_) => currentlyLoaded);
    Stream<InfoHelper> afterCurrent =
        afterUseCurrent.onClick.map((_) => currentlyLoaded);

    Stream<InfoHelper> before = intermix(beforeCurrent, beforeFile);
    Stream<InfoHelper> after = intermix(afterCurrent, afterFile);
    Stream<List<InfoHelper>> bothLoaded = pairStream(before, after);
    bothLoaded.listen((helpers) {
      _diff(helpers[0], helpers[1]);
    });
  }

  void _addRow(DiffItem row) {
    var e = new Element.tag('li')
      ..classes.add(row.kind)
      ..children.addAll([
        new SpanElement()..text = row.path,
        new SpanElement()
          ..text = row.diff.toString()
          ..style.float = "right"
      ]);
    list.children.add(e);
  }

  void _diff(InfoHelper before, InfoHelper after) {
    list.children.clear();
    for (DiffItem diffItem in diff(before, after)) {
      _addRow(diffItem);
    }
  }
}
