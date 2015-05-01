// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.dragdrop;

import 'dart:async';
import 'dart:html';

class DragDropFile {
  Element _dropZone;
  Element _fileUpload;

  StreamController<String> _streamController;

  Stream<String> onFile;

  File _selectedFile;

  void loadFile(File file) {
    _selectedFile = file;
    document.title = file.name + " - Dump Info Viewer";
    FileReader reader = new FileReader();
    reader.onLoad.listen((e) {
      String fileContents = reader.result;
      // Substring because fileContents contains the mime type
      var contents =
          window.atob(fileContents.substring(fileContents.indexOf(',') + 1));
      this._streamController.add(contents);
    });
    reader.readAsDataUrl(file);
  }

  DragDropFile(this._dropZone, this._fileUpload) {
    this._streamController = new StreamController();
    this.onFile = _streamController.stream;

    _fileUpload.onChange.listen((event) {
      var file = (event.target as InputElement).files.first;
      loadFile(file);
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
      loadFile(file);
    });
  }
  void hide() {
    this._dropZone.style.display = 'none';
  }
  void show() {
    this._dropZone.style.display = 'block';
  }

  void reload() {
    loadFile(_selectedFile);
  }
}
