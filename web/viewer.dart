library viewer;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:polymer/polymer.dart';

import './format_versions/versions.dart';
import './polymer_lib/tree_table.dart';

part './dragdrop.dart';

main() {
  initPolymer();

  var dnd = new DndFile(querySelector("#drag-target"), querySelector("#file_upload"));

  // When a file is loaded
  dnd.onFile.listen((String jsonString) {
    Map<String, dynamic> json = JSON.decode(jsonString);
    TreeTable tt = querySelector("tree-table");
    if (!json.containsKey('dump_version')) {
      processData0(json, tt);
    } else {
      switch (json['dump_version'] as dynamic) {
        case 1:
        case 2:
          processData1(json, tt);
          break;
        default:
          window.alert("Unknown dump-info schema");
      }
    }

    // Sort by name as default
    tt.sort('name');

    // Sort by chosen sorting methods.
    var select = querySelector("#sort") as SelectElement;
    select.onChange.listen((e) {
      var sortby = select.options[select.selectedIndex].value;
      tt.sort(sortby);
    });

    // Hide the drag-and-drop element.
    dnd.hide();
  });
}
