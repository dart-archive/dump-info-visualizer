part of versions;

class ViewVersion1 {
  final InfoHelper model;
  final TreeTable treeTable;
  final DependencyView depView;

  final Function switchToHierTab;
  final Function switchToDepsTab;

  ViewVersion1(this.model, this.treeTable, this.depView, this.switchToHierTab,
               this.switchToDepsTab) {
    (depView as DependencyView).dumpInfo = this.model;
  }

  void display() {
    treeTable.columnTitles = ['Kind', 'Name', 'Bytes', '%', 'Type'];

    _setupProgramwideInfo();

    int programSize = model.size;

    // A helper function for lazilly constructing the tree
    LogicalRow buildTree(String id, bool isTop, HtmlElement tbody, int level){
      Map<String, dynamic> node = model.elementById(id);
      if (node['size'] == null) {
        node['size'] = _computeSize(node, model.elementById);
      }
      node['size_percent'] =
          (100 * node['size'] / programSize).toStringAsFixed(2) + '%';

      var row = new LogicalRow(node, _renderRow1, tbody, level);
      _addMetadata(node, row, tbody, level + 1, model.elementById);

      if (isTop) {
        treeTable.addTopLevel(row);
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
    for (String libraryId in model.allOfType('library').map((a)=>a['id'])) {
      buildTree('$libraryId', true, treeTable.tbody, 0).show();
    }
  }

  void _setupProgramwideInfo() {
    DivElement programInfoDiv = querySelector('#prog-info') as DivElement;
    programInfoDiv.children.addAll([
            'Program Size: ' + model.size.toString() + ' bytes',
            'Compile Time: ' + model.compilationMoment,
            'Compile Duration: ' + model.compilationDuration,
          ].map((t) => new HeadingElement.h3()..text = t));

    // Function Extraction
    // TODO(tyoverby, herhut):
    //   Make function comparing a first-class
    //   citizen in the dump-info viewer.
    programInfoDiv.children.add(
      new ButtonElement()
        ..text = 'Extract Function Names'
        ..onClick.listen((_) {
          String text = model.allOfType('function')
                          .map((a) => "${a['name']}")
                          .join(', ');
          text = '[$text]';
          String encoded =
            'data:text/plain;charset=utf-8,${Uri.encodeComponent(text)}';

          AnchorElement downloadLink = new AnchorElement(href: encoded);
          downloadLink.text = 'download file';
          downloadLink.setAttribute('download', 'functions.txt');
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
    GenerateRowFunction renderSelfWith(Function renderFn, {int sortPriority: 0}) {
      void render(TreeTableRow row, LogicalRow lRow) {
        row.data = renderFn();
      }
      return () {
        LogicalRow lrow =  new LogicalRow(node, render,
            row.parentElement, level);
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
          [_cell('side effects'), _cell(node['sideEffects'], colspan: '4')]));
        // Modifiers
        if (node.containsKey('modifiers')) {
          (node['modifiers'] as Map<String, bool>).forEach((k, v) {
            if (v) {
              row.addChild(renderSelfWith(() =>
                [_cell('modifier'), _cell(k, colspan: '4')]));
            }
          });
        }
        // Return type
        String returnTypeString =
            'inferred: ${node['inferredReturnType']},'
            ' declared: ${node['returnType']}';
        row.addChild(renderSelfWith(() =>
          [_cell('return type'), _cell(returnTypeString, colspan: '4')]));
        // Parameters
        if (node.containsKey('parameters')) {
          for (Map<String, dynamic> param in node['parameters']) {
            row.addChild(renderSelfWith(() =>
              [_cell('parameter'), _cell(param['name']),
               _cell(param['type'], colspan: '3')]));
          }
        }
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() =>
            [_cell('code'), _cell(node['code'], colspan: '4', pre: true)],
            sortPriority: -1));
        }
        break;
      case 'field':
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() =>
            [_cell('code'), _cell(node['code'], colspan: '4', pre: true)],
            sortPriority: -1));
        }
        // Types
        if (node['inferredType'] != null && node['type'] != null) {
          String returnTypeString =
              'inferred: ${node['inferredType']}, declared: ${node['type']}';
          row.addChild(renderSelfWith(() =>
              [_cell('type'),
               _cell(returnTypeString, colspan: '4', pre: true)]));
        }
        break;
        case 'class':
        case 'library':
          // Show how much of the size we can't account for.
          row.addChild(renderSelfWith(() =>
              [_cell('scaffolding'),
               _cell('(unaccounted for)'),
               _cell(node['size'] -
                     _computeSize(node, fetch, force: true), align: 'right')]
          ));
          break;
    }
  }

  void _renderRow1(TreeTableRow row, LogicalRow logicalRow) {
    Map<String, dynamic> props = logicalRow.data;
    List<TableCellElement> cells = [
      _cell(props['kind']),
    ];

    switch (props['kind']) {
      case 'function':
      case 'closure':
      case 'constructor':
      case 'method':
      case 'field':
        cells.addAll([
          new TableCellElement()..children.addAll([
            new SpanElement()..text = props['name'],
            new AnchorElement(href: '#')
            ..onClick.listen((_) {
              this.depView.target = props['id'];
              this.switchToDepsTab();
            })
            ..children.add(
              new ImageElement(src: 'deps_icon.svg')..style.float = 'right'),
          ]),
          _cell(props['size'], align: 'right'),
          _cell(props['size_percent'], align: 'right'),
          _cell(props['type'], pre: true)
        ]);
        break;
      case 'library':
        cells.addAll([
          _cell(props['name']),
          _cell(props['size'], align: 'right'),
          _cell(props['size_percent'], align: 'right'),
          _cell('')
        ]);
        break;
      case 'typedef':
        cells.addAll([
          _cell(props['name']),
          _cell('0', align: 'right'),
          _cell('0.00%', align:'right')
        ]);
        break;
      case 'class':
        cells.addAll([
          _cell(props['name']),
          _cell(props['size'], align: 'right'),
          _cell(props['size_percent'], align:'right'),
          _cell(props['name'], pre: true)
        ]);
        break;
      default:
        throw new StateError("Unknown element type: ${props['kind']}");
    }
    row.data = cells;
  }

  _depsVisible(String id) {
    this.depView.target = id;
  }
}
