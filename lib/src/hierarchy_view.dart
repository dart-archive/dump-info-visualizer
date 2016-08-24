// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.hierarchy_view;

import 'dart:html';

import 'package:polymer/polymer.dart';

import 'history_state.dart';
import 'info_helper.dart';
import 'logical_row.dart';
import 'tree_table.dart';

const _columnNames = const ['Kind', 'Name', 'Bytes', 'Bytes R', '%', 'Type'];

const _columnHelp = const [
  '',
  'The given name of the element',
  'The direct size attributed to the element',
  'The sum of the sizes of all the elements that can '
      'only be reached from this element',
  'The percentage of the direct size compared to the program size',
  'The given type of the element'
];

const _columnSizes = const ["200px", null, "100px", "100px", "70px", null];

@CustomTag('hierarchy-view')
class HierarchyView extends PolymerElement {
  HierarchyView.created() : super.created();

  InfoHelper _model;

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
    this._model = info;
    _display();
    _treeTable.sort(_sortBy);
    _treeTable.reset();
  }

  void _display() {
    _treeTable.columnInfo(_columnNames, _columnHelp, _columnSizes);

    int programSize = _model.size;

    // A helper function for lazily constructing the tree
    LogicalRow buildTree(String id, bool isTop, HtmlElement tbody, int level) {
      Map<String, dynamic> node = _model.elementById(id);
      if (node['size'] == null) {
        node['size'] = _computeSize(node, _model.elementById);
      }
      node['size_percent'] =
          (100 * node['size'] / programSize).toStringAsFixed(2) + '%';

      var row = new LogicalRow(node, _renderRow, tbody, level);
      _addMetadata(node, row, tbody, level + 1, _model.elementById);

      if (isTop) {
        _treeTable.addTopLevel(row);
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
    for (String libraryId in _model.allOfType('library').map((a) => a['id'])) {
      buildTree('$libraryId', true, _treeTable.tbody, 0).show();
    }
  }

  /**
   * A helper method for adding rows that are not elements but instead provide
   * extra information about an element.
   */
  void _addMetadata(Map<String, dynamic> node, LogicalRow row,
      HtmlElement tbody, int level, Function fetch) {

    // A helper method for generating a row-generating function.
    GenerateRowFunction renderSelfWith(Function renderFn,
        {int sortPriority: 0}) {
      void render(TreeTableRow row, LogicalRow lRow) {
        row.data = renderFn();
      }
      return () {
        LogicalRow lrow =
            new LogicalRow(node, render, row.parentElement, level);
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
        row.addChild(renderSelfWith(() => [
          _cell('side effects'),
          _cell(node['sideEffects'], colspan: '5')
        ]));
        // Modifiers
        if (node.containsKey('modifiers')) {
          (node['modifiers'] as Map<String, bool>).forEach((k, v) {
            if (v) {
              row.addChild(renderSelfWith(
                  () => [_cell('modifier'), _cell(k, colspan: '5')]));
            }
          });
        }
        // Return type
        row.addChild(renderSelfWith(() => [
          _cell('return type'),
          _typeCell(node['returnType'], node['inferredReturnType'],
              colspan: '5')
        ]));
        // Parameters
        if (node.containsKey('parameters')) {
          for (Map<String, dynamic> param in node['parameters']) {
            String declaredType = param['declaredType'] == null
                ? "unavailable"
                : param['declaredType'];
            row.addChild(renderSelfWith(() => [
              _cell('parameter'),
              _cell(param['name']),
              _typeCell(declaredType, param['type'], colspan: '4')
            ]));
          }
        }
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() => [
            _cell('code'),
            _cell(node['code'], colspan: '5', pre: true)
          ], sortPriority: -1));
        }
        break;
      case 'field':
        // Code
        if (node['code'] != null && node['code'].length != 0) {
          row.addChild(renderSelfWith(() => [
            _cell('code'),
            _cell(node['code'], colspan: '5', pre: true)
          ], sortPriority: -1));
        }
        // Types
        if (node['inferredType'] != null && node['type'] != null) {
          row.addChild(renderSelfWith(() => [
            _cell('type'),
            _typeCell(node['type'], node['inferredType'], colspan: '5')
          ]));
        }
        break;
      case 'class':
      case 'library':
        // Show how much of the size we can't account for.
        row.addChild(renderSelfWith(() => [
          _cell('scaffolding'),
          _cell('(unaccounted for)'),
          _cell(node['size'] - _computeSize(node, fetch, force: true),
              align: 'right')
        ]));
        break;
    }
  }

  void _renderRow(TreeTableRow row, LogicalRow logicalRow) {
    Map<String, dynamic> props = logicalRow.data;
    List<TableCellElement> cells = [_cell(props['kind']),];

    switch (props['kind']) {
      case 'function':
      case 'closure':
      case 'constructor':
      case 'method':
      case 'field':
        var span = new SpanElement();
        span.text = props['name'];

        var anchor = new AnchorElement();
        anchor.onClick.listen((_) {
          HistoryState
              .switchTo(new HistoryState('dep', depTarget: props['id']));
        });
        anchor.children.add(
            new ImageElement(src: 'packages/dump_viz/src/deps_icon.svg')
          ..style.float = 'right');

        cells.addAll([
          new TableCellElement()..children.addAll([span, anchor]),
          _cell(props['size'], align: 'right'),
          _cell(_model.triviallyOwnedSize(props['id']), align: 'right'),
          _cell(props['size_percent'], align: 'right'),
          _cell(props['type'], pre: true)
        ]);
        break;
      case 'library':
        cells.addAll([
          _cell(props['canonicalUri']),
          _cell(props['size'], align: 'right'),
          _cell(''),
          _cell(props['size_percent'], align: 'right'),
          _cell('')
        ]);
        break;
      case 'typedef':
        cells.addAll([
          _cell(props['name']),
          _cell('0', align: 'right'),
          _cell('0', align: 'right'),
          _cell('0.00%', align: 'right')
        ]);
        break;
      case 'class':
        cells.addAll([
          _cell(props['name']),
          _cell(props['size'], align: 'right'),
          _cell(''),
          _cell(props['size_percent'], align: 'right'),
          _cell(props['name'], pre: true)
        ]);
        break;
      default:
        throw new StateError("Unknown element type: ${props['kind']}");
    }
    row.data = cells;
  }
}

TableCellElement _typeCell(String declaredType, String inferredType,
    {colspan: '1'}) => _verticalCell(new SpanElement()
  ..appendText('inferred: ')
  ..append(_span(inferredType, cssClass: 'preSpan')), new SpanElement()
  ..appendText('declared: ')
  ..append(_span(declaredType, cssClass: 'preSpan')), colspan: colspan);

TableCellElement _verticalCell(dynamic upper, dynamic lower,
    {String align: 'left', String colspan: '1'}) {
  DivElement div = new DivElement();
  div.children.addAll([
    upper is SpanElement ? upper : _span(upper),
    new BRElement(),
    lower is SpanElement ? lower : _span(lower)
  ]);
  return _cell(div, align: align, colspan: colspan, pre: false);
}

SpanElement _span(dynamic contents, {String cssClass}) {
  SpanElement span = new SpanElement();
  if (cssClass != null) span.classes.add(cssClass);
  if (contents is Node) {
    span.append(contents);
  } else {
    span.appendText('$contents');
  }
  return span;
}

/**
 * A helper method for creating TableCellElements with options
 * for alignment, colspan and wrapping the inner text inside of
 * a <pre></pre> element.
 */
TableCellElement _cell(dynamic text,
    {String align: 'left', String colspan: '1', bool pre: false}) {
  TableCellElement element = new TableCellElement()
    ..style.textAlign = align
    ..attributes['colspan'] = colspan;

  if (pre) {
    PreElement pre = new PreElement();
    pre.text = text.toString();
    element.append(pre);
  } else if (text is Node) {
    element.children.add(text);
  } else {
    element.text = text.toString();
  }

  return element;
}

/**
 * Compute the size of a node in the node tree by first checking to see if
 * that node has a size property.  If it does, use that unless [force] is
 * set to true.  Otherwise, aquire the size by summing the sizes of
 * the children.
 */
int _computeSize(Map<String, dynamic> info, Function fetchElement,
    {bool force: false}) {
  if (info.containsKey('size') && info['size'] != null && !force) {
    return _toInt(info['size']);
  } else if (info.containsKey('children')) {
    return info['children']
        .map(fetchElement)
        .map((a) => _computeSize(a, fetchElement))
        .fold(0, (a, b) => a + b);
  } else {
    return 0;
  }
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
