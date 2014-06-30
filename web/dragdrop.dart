part of viewer;

class DndFile {
  Element _dropZone;
  
  StreamController<String> _streamController;
  
  Stream<String> onFile;
  
  DndFile(this._dropZone) {
    this._streamController = new StreamController();
    this.onFile = _streamController.stream;
    
    _dropZone.onDragOver.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      _dropZone.style.backgroundColor = "rgb(200,200,200)";
    });
    _dropZone.onDrop.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      File file = e.dataTransfer.files.first;
      FileReader reader = new FileReader();
      reader.onLoad.listen((e) {
        String fileContents = reader.result;
        var contents = window.atob(fileContents.substring(fileContents.indexOf(",") + 1));
        this._streamController.add(contents);
      });
      reader.readAsDataUrl(file);
    });
  }
  void hide() {
    this._dropZone.style.display = "none";
  }
  void show() {
    this._dropZone.style.display = "block";
  }
}