library viewer;

import 'dart:html';
import 'dart:convert';
import 'package:polymer/polymer.dart';
import 'polymer_lib/tree_table.dart';
import 'dart:async';

part './dragdrop.dart';


main() {
  initPolymer();
  
  var dnd = new DndFile(querySelector("#drag-target"));
  dnd.onFile.listen((String json){
    _processData(JSON.decode(json));
    dnd.hide();
  });
}

void _processData(Map document) {
  var libs = document['libs'];
  var prog = document['program'];

  // Information about the whole program.
  DivElement programInfoDiv = querySelector("#prog-info") as DivElement;
  programInfoDiv.children.addAll([
        "Program Size: " + prog['program_size'].toString() + " bytes",
        "Compile Time: " + prog['compile_time'],
        "Compile Duration: " + prog['compile_duration']
      ].map((t) => new HeadingElement.h3()..text = t));

  // Information about specific pieces of the program
  TreeTable tt = querySelector("tree-table") as TreeTable;
  tt.columnTitles = ["Kind", "Name", "Bytes", "%", "Type"];
  
  // A recursive function that builds up a tree of LogicalRows 
  LogicalRow buildTree(Map<String, dynamic> node, bool isTop, 
                       HtmlElement tbody, int level) {
    if (node['size'] == null) {
      node['size'] = _computeSize(node);
    }
    node['size_percent'] = 
        (100 * node['size'] / prog['program_size']).toStringAsFixed(2) + "%";
    
    var row = new LogicalRow(node, _renderRow, tbody, level);
    if (isTop) {
      tt.addTopLevel(row);
    }
    
    if (node.containsKey('children')) {
      for (var child in node['children']) {
        var built = buildTree(child, false, tbody, level + 1);
        row.addChild(built);
      }
    }
    return row;
  }
  
  // The top level library nodes. 
  for (var library in libs) {
   buildTree(library, true, tt.tbody, 0).show();
  }

  tt.sort('kind');

  var select = querySelector("#sort") as SelectElement;
  select.onChange.listen((e) {
    var sortby = select.options[select.selectedIndex].value;
    tt.sort(sortby);
  });
}

int _toInt(dynamic n) {
  if (n is int) {
    return n;
  } else if (n is String) {
    return int.parse(n);
  } else {
    return 0;
  }
}

/// Compute the size of a node in the node tree.
int _computeSize(Map<String, dynamic> info) {
  if (info.containsKey('size') && info['size'] != null) {
    return _toInt(info['size']);
  } else if (info.containsKey('children')) {
    return info['children'].map(_computeSize).fold(0, (a, b) => a + b);
  } else {
    return 0;
  }
}

TableCellElement _cell({dynamic text, String align: 'left', String colspan: "1", bool pre: false}) {
  TableCellElement element = new TableCellElement()
  ..style.textAlign = align
  ..attributes['colspan'] = colspan;
  
  if (pre) {
    PreElement pre = new PreElement();
    pre.text = text.toString();
    element.append(pre);
  } else {
    element.text = text.toString();
  }
  
  return element;
}

void _renderRow(TreeTableRow row, LogicalRow logicalRow) {
  Map<String, dynamic> props = logicalRow.data;
  List<TableCellElement> cells = [];
  cells.addAll([
    _cell(text: props['kind']),
    _cell(text: props['name'])
  ]);
  switch (props['kind']) {
    case 'function':
    case 'closure':
    case 'constructor':
    case 'method':
    case 'field':
      cells.addAll([
        _cell(text: props['size'], align: 'right'),
        _cell(text: props['size_percent'], align: 'right'),
        _cell(text: props['type'], pre: true)
      ]);
      break;
    case 'library':
      cells.addAll([
        _cell(text: props['size'], align: 'right'),
        _cell(text: props['size_percent'], align: 'right'),
        _cell(text: "")
      ]);
      break;
    case 'typedef':
      cells.addAll([
        _cell(text: "0", align: 'right'),
        _cell(text: "0.000%", align: 'right'),
        _cell(text: props['type'], pre: true)
      ]);
      break;
    case 'class':
      cells.addAll([
        _cell(text: props['size'], align: 'right'),
        _cell(text: props['size_percent'], align: 'right'),
        _cell(text: props['name'], pre: true)
      ]);
      break;
    case 'inferred':
      cells.removeLast();
      cells.addAll([
        _cell(text: props['desc']),
        _cell(text: props['type'], colspan: '3', pre: true)
      ]);
      break;
    case 'code':
      cells.removeLast();
      cells.addAll([
        _cell(text: props['code'], colspan: '4', pre: true)              
      ]);
  }
  row.data = cells;
}
