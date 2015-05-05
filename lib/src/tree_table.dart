// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library tree_table;

import 'dart:collection' show Queue;
import 'dart:html';

import 'package:observe/observe.dart';
import 'package:polymer/polymer.dart';

import 'logical_row.dart';

typedef void RenderFunction(TreeTableRow ttr, LogicalRow logicalRow);

/// The amount of padding to be added to each level in the tree.
const int _PADDING_SIZE = 25;

/**
 * A Polymer TreeTable element.
 */
@CustomTag('tree-table')
class TreeTable extends PolymerElement {
  // The top-level rows in the tree.
  List<LogicalRow> _rootNodes = [];

  // A set of the nodes that were opened in the tree-table
  // before the json was reloaded.  Storing this information
  // makes it possible to re-open the tree to where it
  // was before.
  Set<String> _previouslyOpened = new Set<String>();

  TreeTable.created() : super.created() {}

  factory TreeTable() {
    return document.createElement('tree-table') as TreeTable;
  }

  /**
   * Adds a row to the table that is at the top level of the
   * tree in the structure.
   */
  LogicalRow addTopLevel(LogicalRow child) {
    _rootNodes.add(child);
    return child;
  }

  HtmlElement get tbody => this.$['inner_table_body'];

  /**
   * Clears the table.  Used when reloading the file.
   */
  void clear() {
    Set<String> openedPaths = new Set<String>();
    Queue<LogicalRow> possiblyOpen = new Queue();
    possiblyOpen.addAll(_rootNodes);
    while (possiblyOpen.isNotEmpty) {
      LogicalRow next = possiblyOpen.removeFirst();
      if (next.open) {
        openedPaths.add(next.id);
        possiblyOpen.addAll(next.children);
      }
    }

    this._previouslyOpened = openedPaths;

    _rootNodes.clear();
    this.children.clear();
    this.$['inner_table_head'].children.clear();
  }

  void reset() {
    Queue<LogicalRow> couldBeOpened = new Queue<LogicalRow>();
    couldBeOpened.addAll(_rootNodes);
    while (couldBeOpened.isNotEmpty) {
      LogicalRow next = couldBeOpened.removeFirst();
      if (_previouslyOpened.contains(next.id)) {
        next.click();
        couldBeOpened.addAll(next.children);
      }
    }
  }

  /**
   * Sets the titles for the columns of the table.
   */
  void columnInfo(List<String> names, List<String> helps, List<String> sizes) {
    for (int i = 0; i < names.length; i++) {
      TableCellElement cell = new TableCellElement();
      cell.style.textAlign = 'center';
      cell.text = names[i];
      cell.title = helps[i];
      String size = sizes[i];
      if (size != null) {
        cell.style.width = size;
      }
      this.$['inner_table_head'].children.add(cell);
    }
  }

  /**
   * Sorts this TreeTable by creating a comparator function
   * for LogicalRows sorting on a key in the data section.
   */
  void sort(String key) {
    var comparator = (LogicalRow a, LogicalRow b) {
      if (a.sortable && !b.sortable) {
        return 1;
      } else if (!a.sortable && b.sortable) {
        return -1;
      } else if (!a.sortable && !b.sortable) {
        return a.nonSortablePriority.compareTo(b.nonSortablePriority);
      }

      var d1 = a.data[key];
      var d2 = b.data[key];
      if (d1 == null) d1 = '';
      if (d2 == null) d2 = '';
      if (d1 is num && d2 is num) {
        return d1.compareTo(d2);
      }
      return d2.toString().compareTo(d1.toString());
    };

    // Clear all of the rows in the table because
    // we will be sorting the `logical` rows and then
    // re-add them all.
    tbody.children.clear();
    this._rootNodes.sort(comparator);

    for (var rootNode in this._rootNodes) {
      rootNode.sort(comparator);
    }

    // Re-add the now-sorted rows.
    for (var rootNode in this._rootNodes) {
      rootNode.show();
    }
  }
}

/**
 * A TreeTableRow element.  TreeTableRows are only to be inserted into
 * a TreeTable element.  Because TreeTableRows are nodes in the tree
 * structure, they can have children added to them via the [addChild]
 * method.
 */
@CustomTag('tree-table-row')
class TreeTableRow extends TableRowElement with Polymer, Observable {
  LogicalRow logicalRow;
  // True if data has been rendered into this row.
  bool populated = false;

  TreeTableRow.created() : super.created() {
    polymerCreated();
  }

  factory TreeTableRow(LogicalRow logicalRow) {
    TreeTableRow ttr = document.createElement('tr', 'tree-table-row');
    ttr.logicalRow = logicalRow;
    ttr.onClick.listen((_) => ttr.logicalRow.click());
    return ttr;
  }

  // Set the cells in this row.
  void set data(List<TableCellElement> elements) {
    if (elements.isNotEmpty) {
      this.$['content'].text = elements.first.text;
    }
    for (TableCellElement cell in elements.skip(1)) {
      this.shadowRoot.append(cell);
    }
  }

  // Set the level of indentation for this row.
  void set level(int level) {
    this.$['first-cell'].style.paddingLeft = "${level * _PADDING_SIZE}px";
  }

  void setArrow(bool hasChildren, bool open) {
    if (hasChildren) {
      if (open) {
        this.$['arrow'].text = '▼';
      } else {
        this.$['arrow'].text = '▶';
      }
    } else {
      this.$['arrow'].text = '○';
    }
  }
}
