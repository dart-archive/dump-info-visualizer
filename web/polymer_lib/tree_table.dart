library tree_table;

import 'package:polymer/polymer.dart';
import 'package:observe/observe.dart';
import 'dart:html';

/**
 * A Polymer TreeTable element.
 */
@CustomTag('tree-table')
class TreeTable extends PolymerElement {
  // The top-level rows in the tree.
  List<LogicalRow> _rootNodes = [];

  TreeTable.created() : super.created() {}

  factory TreeTable() {
    return document.createElement("tree-table") as TreeTable;
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
   * Sets the titles for the columns of the table.
   */
  void set columnTitles(List<String> names) {
    this.$["inner_table_head"].children.addAll(names.map((name) {
      var tableCell = new TableCellElement()..text = name;
      // TODO(tyoverby): special cases are bad
      
      if (name == "Bytes" || name == "%") {
        tableCell.style.width = "70px";
      }
      if (name == "Kind") {
        tableCell.style.width = "160px";
      }
      if (name == "Name") {
        tableCell.style.width = "300px";        
      }
      return tableCell;
    }));
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
      if (d1 == null) d1 = "";
      if (d2 == null) d2 = "";
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
      rootNode._sort(comparator);
    }
    
    // Re-add the now-sorted rows.
    for (var rootNode in this._rootNodes) {
      rootNode.show();
    }
  }
}

/// The amount of padding to be added to each level in the tree.
final int _PADDING_SIZE = 25;

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
    var ttr = document.createElement("tr", "tree-table-row") as TreeTableRow;
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
  void set _level(int level) {
     this.$['first-cell'].style.paddingLeft =
      (level * _PADDING_SIZE).toString() + "px";
  }

  void _setArrow(bool hasChildren, bool open) {
    if(hasChildren) {
        if(open) {
          this.$["arrow"].text = "▼";
        } else {
          this.$["arrow"].text = "▶";
        }
    } else {
      this.$["arrow"].text = "○";
    }
  }
}

typedef LogicalRow GenRowFn();
typedef void RenderFunction(TreeTableRow ttr, LogicalRow logicalRow);

class LogicalRow {
  // If the row is currently in an opened state.
  bool open = false;
  
  // A pointer into the data 
  Map<String, dynamic> data;
  
  // A list of "soon to be children" row functions.  
  // This is the key part of having the entire data 
  // structure be lazily evaluated.
  List<GenRowFn> generatorFns = [];
  
  // After the generatorFns array is processed when this 
  // node is expanded, this children array will be filled with
  // [LogicalRow]s 
  List<LogicalRow> children = [];
  
  // If this row is sortable.  An example of a non-sortable row
  // would be the "code" and "parameters" rows of a function
  // element properties.
  bool sortable = true;
  
  // If this row is not sortable, use this priority instead.
  int nonSortablePriority = 0;
  
  // A function that is called when this tree needs to be rendered 
  // into the DOM.
  RenderFunction renderFunction;
  
  // The actual rendered row.
  TreeTableRow rowElement;
  
  // The TreeTableRow element.  Stored here to make show/hide easier.
  HtmlElement parentElement;
  
  // The depth of this row in the overall tree.
  int level;
  
  // Stored comparator for the sorting function.  
  // Because the tree is generated lazily, this needs to be stored to
  // be called on generation of future children.
  Function sortComparator;
  
  LogicalRow(this.data, this.renderFunction, this.parentElement, this.level);
  
  // Add a child function lazilly.
  GenRowFn addChild(GenRowFn genRowFn) {
    this.generatorFns.add(genRowFn);
    return genRowFn;
  }
  
  void click() {
    open = !open;
    if (open) {
      if (children.isEmpty) {
        children = generatorFns.map((a) => a()).toList();
        // Resort because more children were generated.
        _sort(sortComparator);
      }
      this.children.forEach((child) => child.show(before: this.rowElement));
    } else {
      this.children.forEach((child) => child.hide());
    }
    this.rowElement._setArrow(this.children.isNotEmpty, open);
  }
  
  void hide() {
    this.parentElement.children.remove(this.getElement());
    if (this.open) {
      this.children.forEach((child) => child.hide());
    }
  }
  
  /**
   * Adds this row to the TreeTableElement.  
   * [before] is an optional element that this row 
   * will be inserted after.
   */
  void show({HtmlElement before}) {
    if (before != null) {
      // Place this element right after [before]
      int loc = this.parentElement.children.indexOf(before) + 1;
      this.parentElement.children.insert(loc, this.getElement());
    } else {
      // Prepend this element into the table
      this.parentElement.children.insert(0, this.getElement());
    }
    this.rowElement._level = this.level;
    if (!this.rowElement.populated) {
      this.renderFunction(this.rowElement, this);
      this.rowElement._setArrow(this.generatorFns.isNotEmpty, open);
      this.rowElement.populated = true;
    }
    if (this.open) {
      // Open up children spatially after this element
      this.children.forEach((child) => child.show(before: this.rowElement));
    }
  }
  
  TreeTableRow getElement() {
    if (rowElement != null) {
      return rowElement;
    } else {
      this.rowElement = new TreeTableRow(this);
      return this.rowElement;
    }
  }
  
  void _sort(Function comparator) {
    sortComparator = comparator;
    this.children.sort(comparator);
    this.children.forEach((child) => child._sort(comparator));
  }
}