class InfoHelper {
  final Map<String, Map<String, Map<String, dynamic>>> _properties;
  
  // A map from the ids of an element to the 
  // properties of that element.
  final Map<String, Map<String, dynamic>> _idToProperties = {};
  
  // A map of dependencies from an ID of an element
  // to the IDs of the elements that it depends on.
  final Map<String, List<String>> _dependencies = {};
  
  // A map of depedencies from an ID of an element 
  // to the IDS of the elements that depend on it.
  final Map<String, List<String>> _reverseDependencies = {};
  
  // A mapping from an ID of an element to that elements path.
  // A path for a function might look like 
  // [libraryName, className, functionName]
  final Map<String, List<String>> _path = {};
  
  List<String> dependencies(String id) => _dependencies[id];
  List<String> reverseDependencies(String id) => _reverseDependencies[id];
  Map<String, dynamic> properties(String id) => _idToProperties[id];
  
  // Given an id, returns the node associated with it.
  dynamic fetchElementById(String id) {
    var split =  id.split("/");
    return _properties[split[0]][split[1]];
  }
  
  InfoHelper(Map<String, Map<String, Map<String, dynamic>>> properties, 
             Map<String, List<String>> deps): _properties = properties {
    // Set up dependencies
    for (Map<String, dynamic> section in properties.values) {
      for (var prop in section.values) {
        String id = prop['id'];
        _idToProperties[id] = prop;
        _dependencies[id] = deps[id];
      }    
    }
    
    // Set up reverse dependencies
    _dependencies.forEach((e, deps) {
      for (var dep in deps) {
        _reverseDependencies.putIfAbsent(dep, ()=> <String>[])
            .add(e);
      }
    });
    
    // Set up paths
    void traverseNames(Map<String, dynamic> node, List<String> prevPath) {
      List<String> newPath = new List.from(prevPath)..add(node['name']);
      _path[node['id']] = newPath;
      
      if (node['children'] != null) {
        for (String id in node['children']) {
          traverseNames(fetchElementById(id), newPath);
        }
      }
    }
    
    for (var node in properties['library'].values) {
      traverseNames(node, []);    
    }
  }
}