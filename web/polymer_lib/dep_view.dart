library dep_view;

import 'package:polymer/polymer.dart';
import 'dart:html';

import '../infohelper.dart';

@CustomTag('dep-view')
class DepView extends PolymerElement {
  InfoHelper _dumpInfo;
  String _currentlyTargeting;

  TableSectionElement ownersTable;
  TableSectionElement currentTable;
  TableSectionElement ownedTable;

  DepView.created() : super.created() {}

  set target(String id) {
    _currentlyTargeting = id;
    _populate(id);
  }

  String get target {
    return _currentlyTargeting;
  }

  factory DepView(InfoHelper dumpinfo) {
    DepView dv = document.createElement("tree-table") as DepView;
    dv.dumpInfo = dumpinfo;
    return dv;
  }

  set dumpInfo(InfoHelper dumpInfo) {
    TableSectionElement getTbody(TableElement table) =>
      table.querySelector("tbody");

    _dumpInfo = dumpInfo;
    ownersTable = getTbody($['owners']);
    currentTable = getTbody($['current']);
    ownedTable = getTbody($['owned']);
  }

  TableRowElement _generateRow(String id) {
    List<String> path = _dumpInfo.path(id);
    // TODO(TyOverby): Make a polymer element to abstract this mess
    return new TableRowElement()
      ..children.addAll([
          // Name Column
          new TableCellElement()
            ..text = path.join("."),
          // Stats Column
          new TableCellElement()
            ..children.add(
              new SpanElement()
                 ..text = "↖ ${_dumpInfo.reverseDependencies(id).length} | " +
                           "${_dumpInfo.dependencies(id).length} ↘"
                 ..style.float = "right"
          )
        ])
        ..onClick.listen((_)=> this.target = id);
  }

  void _populate(String id) {
    ownersTable.children.clear();
    currentTable.children.clear();
    ownedTable.children.clear();

    List<String> owners = _dumpInfo.reverseDependencies(id);
    List<String> owned = _dumpInfo.dependencies(id);

    Iterable<TableRowElement> sortedRows(Iterable<String> ids) {
      var sorted = ids.toList()..sort((id1, id2) =>
          _dumpInfo.reverseDependencies(id1).length -
          _dumpInfo.reverseDependencies(id2).length);
      return sorted.map(_generateRow);
    }

    ownersTable.children.addAll(sortedRows(owners));
    currentTable.children.add(_generateRow(id));
    ownedTable.children.addAll(sortedRows(owned));
  }
}
