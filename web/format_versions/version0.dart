// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of versions;

void processData0(Map document, TreeTable tt) {
  var libs = document['libs'];
  var prog = document['program'];

  // Information about the whole program.
  TableElement programInfoDiv = querySelector('#prog-info');
  programInfoDiv.children.addAll([
    'Program Size: ' + prog['program_size'].toString() + ' bytes',
    'Compile Time: ' + prog['compile_time'],
    'Compile Duration: ' + prog['compile_duration']
  ].map((t) => new HeadingElement.h3()..text = t));

  tt.columnInfo(
      // Names
      ['Kind', 'Name', 'Bytes', 'Bytes R', '%', 'Type'],
      // Help Info
      [
    '',
    'The given name of the element',
    'The direct size attributed to the element',
    'The sum of the sizes of all the elements that can '
        'only be reached from this element',
    'The percentage of the direct size compared to the '
        'program size',
    'The given type of the element'
  ],
      // Sizes
      ["200px", null, "100px", "100px", "70px", null]);
  // A recursive function that builds up a tree of LogicalRows
  LogicalRow buildTree(
      Map<String, dynamic> node, bool isTop, HtmlElement tbody, int level) {
    if (node['size'] == null) {
      node['size'] = _computeSize(node, (a) => a);
    }
    node['size_percent'] =
        (100 * node['size'] / prog['program_size']).toStringAsFixed(2) + '%';

    var row = new LogicalRow(node, _renderRow0, tbody, level);
    if (isTop) {
      tt.addTopLevel(row);
    }

    if (node.containsKey('children')) {
      for (var child in node['children']) {
        LogicalRow built = buildTree(child, false, tbody, level + 1);
        row.addChild(() => built);
      }
    }
    return row;
  }

  // The top level library nodes.
  for (var library in libs) {
    buildTree(library, true, tt.tbody, 0).show();
  }
}

void _renderRow0(TreeTableRow row, LogicalRow logicalRow) {
  Map<String, dynamic> props = logicalRow.data;
  List<TableCellElement> cells = [];
  cells.addAll([_cell(props['kind']), _cell(props['name'])]);
  switch (props['kind']) {
    case 'function':
    case 'closure':
    case 'constructor':
    case 'method':
    case 'field':
      cells.addAll([
        _cell(props['size'], align: 'right'),
        _cell(props['size_percent'], align: 'right'),
        _cell(props['type'], pre: true)
      ]);
      break;
    case 'library':
      cells.addAll([
        _cell(props['size'], align: 'right'),
        _cell(props['size_percent'], align: 'right'),
        _cell('')
      ]);
      break;
    case 'typedef':
      cells.addAll([
        _cell('0', align: 'right'),
        _cell('0.000%', align: 'right'),
        _cell(props['type'], pre: true)
      ]);
      break;
    case 'class':
      cells.addAll([
        _cell(props['size'], align: 'right'),
        _cell(props['size_percent'], align: 'right'),
        _cell(props['name'], pre: true)
      ]);
      break;
    case 'inferred':
      cells.removeLast();
      cells.addAll([
        _cell(props['desc']),
        _cell(props['type'], colspan: '3', pre: true)
      ]);
      break;
    case 'code':
      cells.removeLast();
      cells.addAll([_cell(props['code'], colspan: '4', pre: true)]);
  }
  row.data = cells;
}
