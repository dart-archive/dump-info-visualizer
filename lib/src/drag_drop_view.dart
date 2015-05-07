// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.dragdrop;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

@CustomTag('drag-drop-view')
class DragDropView extends PolymerElement {
  Element get _dropZone => $['drag-target'];
  Element get _fileUpload => $['file_upload'];

  DragDropView.created() : super.created();

  final StreamController<String> _streamController =
      new StreamController<String>();

  Stream<String> get onFile => _streamController.stream;

  void ready() {
    _fileUpload.onChange.listen((event) {
      var file = (event.target as InputElement).files.first;
      _loadFile(file);
    });

    _dropZone.onDragOver.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      _dropZone.style.backgroundColor = 'rgb(200,200,200)';
    });

    _dropZone.onDrop.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      File file = e.dataTransfer.files.first;
      _loadFile(file);
    });
  }

  void hide() {
    _dropZone.style.display = 'none';
  }

  void show() {
    _dropZone.style.display = 'block';
  }

  void _loadFile(File file) {
    FileReader reader = new FileReader();

    reader.onLoad.first.then((_) {
      String fileContents = reader.result;
      // Substring because fileContents contains the mime type
      var contents =
          window.atob(fileContents.substring(fileContents.indexOf(',') + 1));
      _dropZone.style.backgroundColor = '';
      _streamController.add(contents);
    });
    reader.readAsDataUrl(file);
  }
}
