// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.diff_view;

import 'dart:convert';
import 'dart:html' hide Selection;

import 'package:polymer/polymer.dart';

import 'diff_alg.dart';
import 'drag_drop_view.dart';
import 'info_helper.dart';

@CustomTag('diff-view')
class DiffView extends PolymerElement {
  UListElement get _list => $['list'];
  InfoHelper currentlyLoaded;

  DiffView.created() : super.created();

  InfoHelper _beforeContent;
  InfoHelper _afterContent;

  DragDropView get _beforeView => $['before-drop'] as DragDropView;
  DragDropView get _afterView => $['after-drop'] as DragDropView;

  ButtonElement get _beforeUseCurrent =>
      $['before-current-btn'] as ButtonElement;
  ButtonElement get _afterUseCurrent => $['after-current-btn'] as ButtonElement;

  void ready() {
    assert(currentlyLoaded != null);

    _beforeView.onFile.map(_strToHelper).listen((InfoHelper ih) {
      _update(ih, null);
    });

    _afterView.onFile.map(_strToHelper).listen((InfoHelper ih) {
      _update(null, ih);
    });

    _beforeUseCurrent.onClick.listen((_) {
      _update(currentlyLoaded, null);
    });

    _afterUseCurrent.onClick.listen((_) {
      _update(null, currentlyLoaded);
    });
  }

  void _update(InfoHelper before, InfoHelper after) {
    if (before != null) {
      _beforeContent = before;
    }

    if (after != null) {
      _afterContent = after;
    }

    _diff();
  }

  void _diff() {
    _list.children.clear();

    if (_beforeContent == null || _afterContent == null) {
      return;
    }

    var diffItems = diff(_beforeContent, _afterContent);

    for (DiffItem diffItem in diffItems) {
      _addRow(diffItem);
    }
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
    _list.children.add(e);
  }
}

InfoHelper _strToHelper(String input) =>
    new InfoHelper.fromJson(JSON.decode(input));
