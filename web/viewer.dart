library viewer;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_tabs.dart';
import 'package:paper_elements/paper_tab.dart';

import './format_versions/versions.dart';
import './polymer_lib/tree_table.dart';
import './polymer_lib/dep_view.dart';
import './infohelper.dart';

part './dragdrop.dart';

void _noSlide() {
  for (String id in ["prog-info-slide", "hier-slide", "dep-slide", "load-slide"]) {
    //document.querySelector("#$id").style.display = "none";
    var slide = document.querySelector("#$id");
    slide.style.opacity = "0";
    slide.style.height = '0';
  }
}

void _switchSlide(String id) {
  _noSlide();
  var slide = document.querySelector("#$id");
  slide.style.opacity = "1";
  slide.style.height = "auto";
}

main() {
  initPolymer();
  _noSlide();
  _switchSlide("load-slide");

  var dnd = new DndFile(querySelector("#drag-target"), querySelector("#file_upload"));

  // When a file is loaded
  dnd.onFile.listen((String jsonString) {
    _switchSlide("prog-info-slide");

    List<PaperTab> tabs = querySelectorAll("paper-tab") as List<PaperTab>;
    for (PaperTab tab in tabs) {
      tab.onClick.listen((_){
        String link = tab.attributes["slide"];
        if (link != null) {
          _switchSlide(link);
        }
      });
    }


    Map<String, dynamic> json = JSON.decode(jsonString);
    TreeTable tt = querySelector("tree-table");
    DepView dv = querySelector("dep-view");
    if (!json.containsKey('dump_version')) {
      processData0(json, tt);
    } else {
      switch (json['dump_version'] as dynamic) {
        case 1:
        case 2:
          var info = new InfoHelper(json['elements'], json['holding'], json['program']);
          var view = new ViewVersion1(info, tt, dv);
          view.display();
          break;
        default:
          window.alert("Unknown dump-info version");
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
  });
}
