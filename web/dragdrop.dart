part of viewer;

class DndFile {
  Element _dropZone;
  Element _fileUpload;
  
  StreamController<String> _streamController;
  
  Stream<String> onFile;
  
  void handleFile(File file) {
    document.title = file.name;
    FileReader reader = new FileReader();
    reader.onLoad.listen((e) {
      String fileContents = reader.result;
      // Substring because fileContents contains the mime type
      var contents = window.atob(fileContents.substring(fileContents.indexOf(",") + 1));
      this._streamController.add(contents);
    });
    reader.readAsDataUrl(file);
  }
  
  DndFile(this._dropZone, this._fileUpload) {
    this._streamController = new StreamController();
    this.onFile = _streamController.stream;
    
    _fileUpload.onChange.listen((event){
      var file = (event.target as InputElement).files.first;
      handleFile(file);
    });
    
    _dropZone.onDragOver.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      _dropZone.style.backgroundColor = "rgb(200,200,200)";
    });
    
    _dropZone.onDrop.listen((e) {
      e.stopPropagation();
      e.preventDefault();
      File file = e.dataTransfer.files.first;
      handleFile(file);
    });
  }
  void hide() {
    this._dropZone.style.display = "none";
  }
  void show() {
    this._dropZone.style.display = "block";
  }
}