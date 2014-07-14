part of versions;

void processData1(Map document, TreeTable tt) {
  Map<String, dynamic> elements = document['elements'];
  Map<String, dynamic> prog = document['program'];
  Map<String, dynamic> fetch(String id) {
    int divider = id.indexOf("/");
    String kind = id.substring(0, divider);
    String numId = id.substring(divider + 1);
    return elements[kind][numId];
  }
  
  DivElement programInfoDiv = querySelector("#prog-info") as DivElement;
  programInfoDiv.children.addAll([
          "Program Size: " + prog['size'].toString() + " bytes",
          "Compile Time: " + prog['compilationMoment'].toString(),
          "Compile Duration: " + prog['compilationDuration'].toString(),
          "--dump-info Duration: " + prog['dumpInfoDuration'] + " + " +
          prog['toJsonDuration']
        ].map((t) => new HeadingElement.h3()..text = t));
  
  int programSize = prog['size'];
  
  void addMetadata(Map<String, dynamic> node, 
                  LogicalRow row, 
                  HtmlElement tbody, 
                  int level) {
    
    LogicalRow renderSelfWith(Function renderFn, {int sortPriority: 0}) {
      void render(TreeTableRow row, LogicalRow lRow) {
        row.data = renderFn();
      }
      LogicalRow lrow =  new LogicalRow(node, render, row.parentElement, level);
      lrow.sortable = false;
      lrow.nonSortablePriority = sortPriority;
      return lrow;
    }
    
    switch (node['kind']) {
      case 'function':
      case 'closure':
      case 'constructor':
      case 'method':
        // Side Effects
        row.addChild(renderSelfWith(() =>
          [_cell("side effects"), _cell(node['sideEffects'], colspan: '4')]));
        // Modifiers
        if (node.containsKey('modifiers')) {
          (node['modifiers'] as Map<String, bool>).forEach((k, v) {
            if (v) {
              row.addChild(renderSelfWith(() => 
                [_cell("modifier"), _cell(k, colspan: '4')]));
            }
          });
        }
        // Return type
        String returnTypeString =
            "inferred: ${node['inferredReturnType']}, declared: ${node['returnType']}";
        row.addChild(renderSelfWith(() =>
          [_cell("return type"), _cell(returnTypeString, colspan: '4')]));
        // Parameters
        if (node.containsKey('parameters')) {
          for (Map<String, dynamic> param in node['parameters']) {
            row.addChild(renderSelfWith(() =>
              [_cell("parameter"), _cell(param['name']), _cell(param['type'])]));
          }
        }
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() =>
            [_cell("code"), _cell(node['code'], colspan: '4', pre: true)], 
            sortPriority: -1));     
        }
        break;
      case 'field':
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() =>
            [_cell("code"), _cell(node['code'], colspan: '4', pre: true)],
            sortPriority: -1));     
        }
        String returnTypeString = 
            "inferred: ${node['inferredType']}, declared: ${node['type']}";
        row.addChild(renderSelfWith(() => 
            [_cell("type"), _cell(returnTypeString, colspan: '4', pre: true)]));
        break;
        // TODO(tyoverby): add more cases
    }
  }
  
  LogicalRow buildTree(String id, bool isTop, HtmlElement tbody, int level){
    Map<String, dynamic> node = fetch(id);  
    if (node['size'] == null || node['kind'] == 'class') {
      node['size'] = _computeSize(node, fetch, force: node['kind'] == 'class');
    }
    node['size_percent'] = 
        (100 * node['size'] / programSize).toStringAsFixed(2) + "%";

    var row = new LogicalRow(node, _renderRow1, tbody, level);
    addMetadata(node, row, tbody, level + 1);
    
    if (isTop) {
      tt.addTopLevel(row);
    }
    if (node.containsKey('children')) {
      for (var childId in node['children']) {
        var built = buildTree(childId, false, tbody, level + 1);
        row.addChild(built);
      }
    }
    return row;
  }
  
  for (String libraryId in elements['library'].keys) {
    buildTree("library/$libraryId", true, tt.tbody, 0).show();
  }
}

void _renderRow1(TreeTableRow row, LogicalRow logicalRow) {
  Map<String, dynamic> props = logicalRow.data;
  List<TableCellElement> cells = [
    _cell(props['kind']),
    _cell(props['name']),                             
  ];
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
        _cell(props['size']),
        _cell(props['size_percent'], align: 'right'),
        _cell("")
      ]);
      break;
    case 'typedef':
      cells.addAll([
        _cell(props['0'], align: 'right'),
        _cell(props['0.00%'], align:'right')
      ]);
      break;
    case 'class':
      cells.addAll([
        _cell(props['size'], align: 'right'),
        _cell(props['size_percent'], align:'right'),
        _cell(props['name'], pre: true)
      ]);
  }
  row.data = cells;
}