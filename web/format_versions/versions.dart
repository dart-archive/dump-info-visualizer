library versions;

import 'dart:html';
import '../polymer_lib/tree_table.dart';

part './version0.dart';
part './version1.dart';

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

TableCellElement _cell(dynamic text, {String align: 'left', String colspan: "1", bool pre: false}) {
  TableCellElement element = new TableCellElement()
  ..style.textAlign = align
  ..attributes['colspan'] = colspan;
  
  if (pre) {
    PreElement pre = new PreElement();
    pre.text = text.toString();
    element.append(pre);
  } else {
    element.text = text.toString();
  }
  
  return element;
}

/// Compute the size of a node in the node tree.
int _computeSize(Map<String, dynamic> info, Function fetchElement, {bool force: false}) {
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