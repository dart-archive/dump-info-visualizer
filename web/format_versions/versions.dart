// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library versions;

import 'dart:html';
import '../polymer_lib/tree_table.dart';
import '../polymer_lib/dependency_view.dart';
import '../infohelper.dart';
import '../history.dart';

part 'version0.dart';
part 'version1.dart';

//
// Common utilities.
//

int _toInt(dynamic n) {
  if (n is int) {
    return n;
  } else if (n is String) {
    return int.parse(n);
  } else {
    return 0;
  }
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

TableCellElement _verticalCell(dynamic upper, dynamic lower,
    {String align: 'left', String colspan: '1', bool pre: false}) {
  DivElement div = new DivElement();
  Node upperNode, lowerNode;
  if (pre) {
    upper = new PreElement()..text = (upper.toString());
    lower = new PreElement()..text = (lower.toString());
  }
  if (upper is! Node) upper = new SpanElement()..text = (upper.toString());
  if (lower is! Node) lower = new SpanElement()..text = (lower.toString());
  div.children.addAll([
    upper,
    new BRElement(),
    lower
  ]);
  return _cell(div, align: align, colspan: colspan, pre: false);
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
