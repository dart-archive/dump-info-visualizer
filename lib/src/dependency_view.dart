// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.dependency_view;

import 'dart:html' hide Selection;

import 'package:polymer/polymer.dart';

import 'history_state.dart';
import 'info_helper.dart';

@CustomTag('dependency-view')
class DependencyView extends PolymerElement {
  InfoHelper _dumpInfo;
  String _currentlyTargeting;

  TableSectionElement ownersTable;
  TableSectionElement currentTable;
  TableSectionElement ownedTable;

  DependencyView.created() : super.created() {}

  set target(String id) {
    $['information'].style.display = 'none';
    $['tables'].style.display = 'block';
    _currentlyTargeting = id;
    _populate(id);
  }

  String get target {
    return _currentlyTargeting;
  }

  set dumpInfo(InfoHelper dumpInfo) {
    TableSectionElement getTbody(TableElement table) =>
        table.querySelector('tbody');

    _dumpInfo = dumpInfo;
    ownersTable = getTbody($['in']);
    currentTable = getTbody($['current']);
    ownedTable = getTbody($['out']);
  }

  TableRowElement _generateRow(String id, String mask) {
    List<String> path = _dumpInfo.path(id);
    if (path == null) return null;
    // TODO(TyOverby): Make a polymer element to abstract this mess
    return new TableRowElement()
      ..children.addAll([
        // Name Column
        new TableCellElement()..text = path.join('.'),
        new TableCellElement()..text = mask,
        // Stats Column
        new TableCellElement()
          ..children.add(new SpanElement()
            ..text = '↖ ${_dumpInfo.reverseDependencies(id).length} | '
            '${_dumpInfo.dependencies(id).length} ↘'
            ..style.float = 'right')
      ])
      ..onClick.listen(
          (_) => HistoryState.switchTo(new HistoryState('dep', depTarget: id)));
  }

  void _populate(String id) {
    ownersTable.children.clear();
    currentTable.children.clear();
    ownedTable.children.clear();

    List<Selection> owners = _dumpInfo.reverseDependencies(id);
    List<Selection> owned = _dumpInfo.dependencies(id);

    ownersTable.children.addAll(_sortedRows(owners));
    currentTable.children.add(_generateRow(id, ""));
    ownedTable.children.addAll(_sortedRows(owned));
  }

  Iterable<TableRowElement> _sortedRows(Iterable<Selection> ids) {
    var sorted = ids.toList()
      ..sort(
          (sel1, sel2) => _dumpInfo.reverseDependencies(sel1.elementId).length -
              _dumpInfo.reverseDependencies(sel2.elementId).length);
    return sorted
        .map((s) => _generateRow(s.elementId, s.mask))
        .where((a) => a != null);
  }
}
