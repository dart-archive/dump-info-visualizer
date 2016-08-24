import 'dart:html';

import 'tree_table.dart';

typedef LogicalRow GenerateRowFunction();

class LogicalRow {
  // If the row is currently in an opened state.
  bool open = false;

  // A pointer into the data
  final Map<String, dynamic> data;

  String get id => data['id'];

  // A list of 'soon to be children' row functions.
  // This is the key part of having the entire data
  // structure be lazily evaluated.
  final List<GenerateRowFunction> generatorFns = <GenerateRowFunction>[];

  // After the generatorFns array is processed when this
  // node is expanded, this children array will be filled with
  // [LogicalRow]s
  final List<LogicalRow> children = <LogicalRow>[];

  // If this row is sortable.  An example of a non-sortable row
  // would be the 'code' and 'parameters' rows of a function
  // element properties.
  bool sortable = true;

  // If this row is not sortable, use this priority instead.
  int nonSortablePriority = 0;

  // A function that is called when this tree needs to be rendered
  // into the DOM.
  final RenderFunction renderFunction;

  // The actual rendered row.
  TreeTableRow rowElement;

  // The TreeTableRow element.  Stored here to make show/hide easier.
  HtmlElement parentElement;

  // The depth of this row in the overall tree.
  final int level;

  // Stored comparator for the sorting function.
  // Because the tree is generated lazily, this needs to be stored to
  // be called on generation of future children.
  LogicalRowComparer sortComparator;

  LogicalRow(this.data, this.renderFunction, this.parentElement, this.level);

  // Add a child function lazily.
  GenerateRowFunction addChild(GenerateRowFunction genRowFn) {
    this.generatorFns.add(genRowFn);
    return genRowFn;
  }

  void click() {
    open = !open;
    if (open) {
      if (children.isEmpty) {
        children.addAll(generatorFns.map((a) => a()));
        // Resort because more children were generated.
        sort(sortComparator);
      }
      this.children.forEach((child) => child.show(before: this.rowElement));
    } else {
      this.children.forEach((child) => child.hide());
    }
    this.rowElement.setArrow(this.children.isNotEmpty, open);
  }

  void hide() {
    this.getElement().remove();
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
      print(loc);
      this.parentElement.children.insert(loc, this.getElement());
    } else {
      // Prepend this element into the table
      this.parentElement.children.insert(0, this.getElement());
      //this.parentElement.append(this.getElement());
    }
    this.rowElement.level = this.level;
    if (!this.rowElement.populated) {
      this.renderFunction(this.rowElement, this);
      this.rowElement.setArrow(this.generatorFns.isNotEmpty, open);
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

  void sort(LogicalRowComparer comparator) {
    sortComparator = comparator;
    this.children.sort(comparator);
    this.children.forEach((child) => child.sort(comparator));
  }
}

typedef int LogicalRowComparer(LogicalRow a, LogicalRow b);
