// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.hierarchy_view;

import 'dart:html';

import 'package:polymer/polymer.dart';

import 'info_helper.dart';
import 'tree_table.dart';
import 'view_version.dart';

@CustomTag('hierarchy-view')
class HierarchyView extends PolymerElement {
  HierarchyView.created() : super.created();

  TreeTable get _treeTable => $['treeTable'];
  SelectElement get _select => $['selectSort'];

  void ready() {
    super.ready();

    // Sort by chosen sorting methods.
    _select.value = 'name';

    _select.onChange.listen((e) {
      _treeTable.sort(_sortBy);
    });
  }

  String get _sortBy => _select.value;

  void clear() {
    _treeTable.clear();
  }

  void set dumpInfo(InfoHelper info) {
    var view = new ViewVersion(info, _treeTable);
    view.display();
    _treeTable.sort(_sortBy);
    _treeTable.reset();
  }
}
