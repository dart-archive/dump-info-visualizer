part of versions;

void processData0(Map document, TreeTable tt) {
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
  tt.columnTitles = ["Kind", "Name", "Bytes", "%", "Type"];
  
  // A recursive function that builds up a tree of LogicalRows 
  LogicalRow buildTree(Map<String, dynamic> node, bool isTop, 
                       HtmlElement tbody, int level) {
    if (node['size'] == null) {
      node['size'] = _computeSize(node, (a) => a);
    }
    node['size_percent'] = 
        (100 * node['size'] / prog['program_size']).toStringAsFixed(2) + "%";
    
    var row = new LogicalRow(node, _renderRow0, tbody, level);
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


}

void _renderRow0(TreeTableRow row, LogicalRow logicalRow) {
  Map<String, dynamic> props = logicalRow.data;
  List<TableCellElement> cells = [];
  cells.addAll([
    _cell(props['kind']),
    _cell(props['name'])
  ]);
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
        _cell("")
      ]);
      break;
    case 'typedef':
      cells.addAll([
        _cell("0", align: 'right'),
        _cell("0.000%", align: 'right'),
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
      cells.addAll([
        _cell(props['code'], colspan: '4', pre: true)
      ]);
  }
  row.data = cells;
}