// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library diff;

import 'package:polymer/polymer.dart';
import 'dart:html' hide Selection;
import 'dart:convert';

import '../infohelper.dart';
import '../history.dart';
import '../viewer.dart';
import '../async.dart';

class DiffElement {
  final String kind;
  final String path;
  final int diff;
  DiffElement(this.kind, this.path, this.diff);
}

@CustomTag('diff-view')
class DiffView extends PolymerElement {
  UListElement list;
  InfoHelper currentlyLoaded;

  DiffView.created(): super.created();

  void ready() {
    InfoHelper strToHelper(String input) {
      Map<String, dynamic> json = JSON.decode(input);
      return new InfoHelper(
          json['elements'],
          json['holding'],
          json['program']);
    }
    list = $['list'];

    var beforeFile = new DragDropFile(
        $['before-drop'],
        $['before-file-upload']).onFile.map(strToHelper);
    var afterFile = new DragDropFile(
        $['after-drop'],
        $['after-file-upload']).onFile.map(strToHelper);
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
      diff(helpers[0], helpers[1]);
    });
  }

  void _addRow(DiffElement row) {
    var e = new Element.tag('li')
      ..text = row.path
      ..classes.add(row.kind)
      ..children.addAll([
          new SpanElement()
          ..text = row.path,
          new SpanElement()
          ..text = row.diff.toString()
          ..style.float = "right"]);
    list.children.add(e);
  }

  void diff(InfoHelper before, InfoHelper after) {
    list.children.clear();
    List<DiffElement> changedElements = [];
    for (String path in before.joinedPaths) {
      String beforeId = before.idFromJoinedPath(path);
      int beforeSize = before.sizeOf(beforeId);
      if (beforeSize == null) continue;
      if (after.idFromJoinedPath(path) != null) {
        String afterId = after.idFromJoinedPath(path);
        int afterSize = after.sizeOf(afterId);
        if (afterSize == null) continue;
        int diff = afterSize - beforeSize;
        if (diff == 0) {
          continue;
        } else if (diff > 0) {
          changedElements.add(new DiffElement('partial-add', path, diff));
        } else {
          changedElements.add(new DiffElement('partial-remove', path, diff));
        }
      } else {
        changedElements.add(new DiffElement("full-remove", path, -beforeSize));
      }
    }

    for (String path in after.joinedPaths) {
      String afterId = after.idFromJoinedPath(path);
      int afterSize = after.sizeOf(afterId);
      if (afterSize == null) continue;
      if (before.idFromJoinedPath(path) == null) {
        changedElements.add(new DiffElement("full-add", path, afterSize));
      }
    }

    changedElements.sort((a, b) => -a.diff.abs().compareTo(b.diff.abs()));
    for (DiffElement diffElement in changedElements) {
      _addRow(diffElement);
    }
  }
}
