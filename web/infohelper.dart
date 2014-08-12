class InfoHelper {
  // A Map of type (kind -> (id -> element properties)) that
  // stores the properties of elements.
  final Map<String, Map<String, Map<String, dynamic>>> _elementProperties;

  // A map storing the raw representation of the whole-program
  // properties that dump-info generates.
  final Map<String, dynamic> _programProperties;

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
  // [library name, class name, function name]
  final Map<String, List<String>> _path = {};

  Iterable<Map<String, dynamic>> allOfType(String type) =>
    _elementProperties[type].values;

  List<String> dependencies(String id) {
    if (_dependencies[id] != null) {
      return _dependencies[id];
    } else {
      return const [];
    }
  }

  List<String> reverseDependencies(String id) {
    if (_reverseDependencies[id] != null) {
      return _reverseDependencies[id];
    } else {
      return const [];
    }
  }

  Map<String, dynamic> properties(String id) => _idToProperties[id];
  List<String> path(String id) => _path[id];

  String get compilationMoment => _programProperties['compilationMoment'];
  String get compilationDuration => _programProperties['compilationDuration'];
  String get dart2jsVersion => _programProperties['dart2jsVersion'];
  int get size => _programProperties['size'];

  // Given an id, returns the node associated with it.
  dynamic elementById(String id) {
    var split =  id.split("/");
    return _elementProperties[split[0]][split[1]];
  }

  InfoHelper(Map<String, Map<String, Map<String, dynamic>>> properties,
             Map<String, List<String>> deps,
             Map<String, dynamic> programProperties):
               _elementProperties = properties,
               _programProperties = programProperties{
    // Set up dependencies
    for (Map<String, dynamic> section in properties.values) {
      for (var prop in section.values) {
        String id = prop['id'];
        _idToProperties[id] = prop;
        _dependencies[id] = deps[id];
      }
    }

    // Set up reverse dependencies
    deps.forEach((e, deps) {
      for (var dep in deps) {
        _reverseDependencies.putIfAbsent(dep, () => <String>[])
            .add(e);
      }
    });

    // Set up paths
    void traverseNames(Map<String, dynamic> node, List<String> prevPath) {
      List<String> newPath = new List.from(prevPath)..add(node['name']);
      _path[node['id']] = newPath;

      if (node['children'] != null) {
        for (String id in node['children']) {
          traverseNames(elementById(id), newPath);
        }
      }
    }

    for (var node in properties['library'].values) {
      traverseNames(node, []);
    }
  }
}
