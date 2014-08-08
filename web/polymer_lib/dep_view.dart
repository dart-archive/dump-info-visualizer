library dep_view;

import 'package:polymer/polymer.dart';
import 'dart:html';

import '../infohelper.dart';

@CustomTag('dep-view')
class DepView extends PolymerElement {
  InfoHelper _dumpInfo;
  String _currentlyTargeting;
  
  TableElement ownersTable;
  TableElement currentTable;
  TableElement ownedTable;
  
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
    _dumpInfo = dumpInfo;
    ownersTable = $['owners'];
    currentTable = $['current'];
    ownedTable = $['owned'];
  }
  
  TableRowElement _generateRow(String id) {
    List<String> path = _dumpInfo.path(id);
    return new TableRowElement()..children.addAll(
        [
           new TableCellElement()..text = path.join("."),
           new TableCellElement()..text = 
            _dumpInfo.reverseDependencies(id).length.toString()
        ]);
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