library tree_table;

import 'package:polymer/polymer.dart';
import 'package:observe/observe.dart';
import 'dart:html';

/**
 * A Polymer TreeTable element.
 */
@CustomTag('tree-table')
class TreeTable extends PolymerElement {
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

  // Sorts this TreeTable by creating a comparator function 
  // for LogicalRows sorting on a key in the data section.
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

    tbody.children.clear();
    this._rootNodes.sort(comparator);

    for (var child in this._rootNodes) {
      child._sort(comparator);
    }
    
    for (var child in this._rootNodes) {
      child.show();
    }
  }
}

/// The amount of padding to be added to each level in the tree.
final int _PADDING_SIZE = 25;

typedef void RenderFunction(TreeTableRow ttr, LogicalRow logicalRow);

/**
 * A TreeTableRow element.  TreeTableRows are only to be inserted into
 * a TreeTable element.  Because TreeTableRows are nodes in the tree
 * structure, they can have children added to them via the [addChild]
 * method.
 */
@CustomTag('tree-table-row')
class TreeTableRow extends TableRowElement with Polymer, Observable {
  LogicalRow logicalRow;
  bool populated = false;  
  
  TreeTableRow.created() : super.created() {
    polymerCreated();
  }
  
  factory TreeTableRow(LogicalRow logicalRow) {
    var ttr = document.createElement("tr", "tree-table-row") as TreeTableRow;
    ttr.logicalRow = logicalRow;
    ttr.onClick.listen((_) {ttr.logicalRow.click();});
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

class LogicalRow {
  bool open = false;
  Map<String, dynamic> data;
  List<LogicalRow> children = [];
  bool sortable = true;
  int nonSortablePriority = 0;
  
  RenderFunction renderFunction;
  TreeTableRow rowElement;
  HtmlElement parentElement;
  int level;
  
  LogicalRow(this.data, this.renderFunction, this.parentElement, this.level);
  
  LogicalRow addChild(LogicalRow child) {
    this.children.add(child);
    return child;
  }
  
  void click() {
    open = !open;
    if (open) {
      this.children.forEach((child){child.show(before: this.rowElement);});
    } else {
      this.children.forEach((child){child.hide();});
    }
    this.rowElement._setArrow(this.children.isNotEmpty, open);
  }
  
  void hide() {
    this.parentElement.children.remove(this.asElement());
    if (this.open) {
      this.children.forEach((child)=> child.hide());
    }
  }
  
  void show({HtmlElement before}) {
    if (before != null) {
      int loc = this.parentElement.children.indexOf(before) + 1;
      this.parentElement.children.insert(loc, this.asElement());
    } else {
      this.parentElement.children.insert(0, this.asElement());
    }
    this.rowElement._level = this.level;
    if (!this.rowElement.populated) {
      this.renderFunction(this.rowElement, this);
      this.rowElement._setArrow(this.children.isNotEmpty, open);
      this.rowElement.populated = true;
    }
    if (this.open) {
      this.children.forEach((child) {child.show(before: this.rowElement);});
    }
  }
  
  TreeTableRow asElement() {
    if (rowElement != null) {
      return rowElement;
    } else {
      this.rowElement = new TreeTableRow(this);
      return this.rowElement;
    }
  }
  
  void _sort(Function comparator) {
    this.children.sort(comparator);
    this.children.forEach((child) => child._sort(comparator));
  }
}