part of versions;

void processData1(Map document, TreeTable tt) {
  tt.columnTitles = ["Kind", "Name", "Bytes", "%", "Type"];
  Map<String, dynamic> elements = document['elements'];
  Map<String, dynamic> prog = document['program'];
  Map<String, dynamic> fetch(String id) {
    int divider = id.indexOf("/");
    String kind = id.substring(0, divider);
    String numId = id.substring(divider + 1);
    return elements[kind][numId];
  }
  
  _setupProgramwideInfo(prog, elements);
  
  int programSize = prog['size'];

  // A helper function for lazilly constructing the tree
  LogicalRow buildTree(String id, bool isTop, HtmlElement tbody, int level){
    Map<String, dynamic> node = fetch(id);  
    if (node['size'] == null) {
      node['size'] = _computeSize(node, fetch);
    }
    node['size_percent'] = 
        (100 * node['size'] / programSize).toStringAsFixed(2) + "%";

    var row = new LogicalRow(node, _renderRow1, tbody, level);
    _addMetadata(node, row, tbody, level + 1, fetch);
    
    if (isTop) {
      tt.addTopLevel(row);
    }
    
    if (node['children'] != null) {
      for (var childId in node['children']) {
        // Thunk!  Lazy tree creation happens in this closure.
        row.addChild(() => buildTree(childId, false, tbody, level + 1));
      }
    }
    return row;
  }
  
  // Start building the tree from the libraries because 
  // libraries are always the top level.
  for (String libraryId in elements['library'].keys) {
    buildTree("library/$libraryId", true, tt.tbody, 0).show();
  }
}

void _setupProgramwideInfo(Map<String, dynamic> prog, Map<String, dynamic> elements) {
  DivElement programInfoDiv = querySelector("#prog-info") as DivElement;
  programInfoDiv.children.addAll([
          "Program Size: " + prog['size'].toString() + " bytes",
          "Compile Time: " + prog['compilationMoment'].toString(),
          "Compile Duration: " + prog['compilationDuration'].toString(),
          "--dump-info Duration: " + prog['dumpInfoDuration'] + " + " +
          prog['toJsonDuration']
        ].map((t) => new HeadingElement.h3()..text = t));
  
  // Function Extraction
  // TODO(tyoverby, herhut): 
  //   Make function comparing a first-class 
  //   citizen in the dump-info viewer.
  programInfoDiv.children.add(
    new ButtonElement()
      ..text = "Extract Function Names"
      ..onClick.listen((_) {
        String text = elements['function']
                        .values
                        .map((a) => '"${a['name']}"')
                        .join(', ');
        text = "[$text]";
        String encoded = 'data:text/plain;charset=utf-8,${Uri.encodeComponent(text)}';
        
        AnchorElement downloadLink = new AnchorElement(href: encoded);
        downloadLink.text = "download file";
        downloadLink.setAttribute("download", "functions.txt");
        downloadLink.click();
      })
  );
}

/**
 * A helper method for adding rows that are not elements but instead provide 
 * extra information about an element.
 */
void _addMetadata(Map<String, dynamic> node, 
                  LogicalRow row, 
                  HtmlElement tbody, 
                  int level, Function fetch) {
  
  // A helper method for generating a row-generating function.
  GenRowFn renderSelfWith(Function renderFn, {int sortPriority: 0}) {
    void render(TreeTableRow row, LogicalRow lRow) {
      row.data = renderFn();
    }
    return () {
      LogicalRow lrow =  new LogicalRow(node, render, row.parentElement, level);
      lrow.sortable = false;
      lrow.nonSortablePriority = sortPriority;
      return lrow;
    };
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
            [_cell("parameter"), _cell(param['name']), _cell(param['type'], colspan: '3')]));
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
      // Types
      if (node['inferredType'] != null && node['type'] != null) {
        String returnTypeString = 
            "inferred: ${node['inferredType']}, declared: ${node['type']}";
        row.addChild(renderSelfWith(() => 
            [_cell("type"), _cell(returnTypeString, colspan: '4', pre: true)]));
      }
      break;
      case 'class':
      case 'library':
        // Show how much of the size we can't account for.
        row.addChild(renderSelfWith(() => 
            [_cell("scaffolding"), 
             _cell("(unaccounted for)"), 
             _cell(node['size'] - _computeSize(node, fetch, force: true), align: 'right')]
        ));
        break;
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
        _cell(props['size'], align: 'right'),
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