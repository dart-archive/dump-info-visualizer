library viewer;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_tab.dart';

import './format_versions/versions.dart';
import './polymer_lib/tree_table.dart';
import './polymer_lib/dep_view.dart';
import './infohelper.dart';

part './dragdrop.dart';

List<String> slides = const ["info", "hier", "dep", "load"]; 

void _noSlide() {
  for (String id in slides) {
    var slide = document.querySelector("#$id-slide");
    slide.style.opacity = "0";
    slide.style.height = '0';
    var tab = document.querySelector("#$id-tab");
    if(tab != null) {
      tab.classes.remove("core-selected");
    }
  }
}

void _switchSlide(String id) {
  _noSlide();
  var slide = document.querySelector("#$id-slide"); 
  slide.style.opacity = "1";
  slide.style.height = "auto";
  var tab = document.querySelector("#$id-tab");
  if (tab != null) {
    tab.classes.add("core-selected");
    var tabs = document.querySelector("paper-tabs");
    tabs.attributes['selected'] = tab.attributes['offset'];
  }
}

main() {
  initPolymer();
  
  _noSlide();
  _switchSlide("load");
 
  
  var dnd = new DndFile(querySelector("#drag-target"), querySelector("#file_upload"));
  
  // When a file is loaded
  dnd.onFile.listen((String jsonString) {
    _switchSlide("info");
    
    List<PaperTab> tabs = querySelectorAll("paper-tab") as List<PaperTab>;
    for (PaperTab tab in tabs) {
      print(tab);
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
          var view = new ViewVersion1(info, tt, dv, 
              () => _switchSlide("hier"), ()=>_switchSlide("dep"));
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