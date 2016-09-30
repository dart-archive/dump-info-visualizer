// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.info_helper;

import 'dart:collection' show Queue;

class Selection {
  String elementId;
  final String mask;
  Selection(this.elementId, this.mask);
}

class InfoHelper {
  final int dumpVersion;

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
  final Map<String, List<Selection>> _dependencies = {};

  // A map of depedencies from an ID of an element
  // to the IDS of the elements that depend on it.
  final Map<String, List<Selection>> _reverseDependencies = {};

  // A mapping from an ID of an element to that elements path.
  // A path for a function might look like
  // [library name, class name, function name]
  final Map<String, List<String>> _path = {};

  // A mapping from an id to a joined path.
  // A joined path might look like "libname.classname.functionname"
  final Map<String, String> _joinedPath = <String, String>{};

  // A mapping from a joined path to an id.
  final Map<String, String> _reverseJoinedPath = {};

  Iterable<Map<String, dynamic>> allOfType(String type) =>
      _elementProperties[type].values;

  List<Selection> dependencies(String id) {
    var deps = _dependencies[id];
    if (deps == null) {
      return const <Selection>[];
    }
    return deps;
  }

  List<Selection> reverseDependencies(String id) {
    if (_reverseDependencies[id] != null) {
      return _reverseDependencies[id];
    } else {
      return const [];
    }
  }

  Iterable<String> get joinedPaths => _reverseJoinedPath.keys;

  String joinedPathFromId(String id) {
    return _joinedPath[id];
  }

  String idFromJoinedPath(String path) {
    return _reverseJoinedPath[path];
  }

  int sizeOf(String id) => _idToProperties[id]['size'];

  Map<String, dynamic> properties(String id) => _idToProperties[id];
  List<String> path(String id) => _path[id];

  String get compilationMoment =>
      _programProperties['compilationMoment'].toString();
  String get compilationDuration =>
      _programProperties['compilationDuration'].toString();
  String get dart2jsVersion => _programProperties['dart2jsVersion'];
  int get size => _programProperties['size'];
  bool get noSuchMethodEnabled => _programProperties['noSuchMethodEnabled'];

  // Given an id, returns the node associated with it.
  dynamic elementById(String id) {
    var split = id.split("/");
    return _elementProperties[split[0]][split[1]];
  }

  Selection selectionFor(dynamic input) {
    if (input is String) {
      return new Selection(input, null);
    } else if (input is Map<String, String>) {
      return new Selection(input['id'], input['mask']);
    } else {
      throw new ArgumentError("$input is unexpected.");
    }
  }

  factory InfoHelper.fromJson(Map<String, dynamic> json) => new InfoHelper(
      json['dump_version'], json['elements'], json['holding'], json['program']);

  InfoHelper(
      this.dumpVersion,
      Map<String, Map<String, Map<String, dynamic>>> properties,
      Map<String, List<String>> deps,
      Map<String, dynamic> programProperties)
      : _elementProperties = properties,
        _programProperties = programProperties {
    // Set up dependencies
    for (Map<String, dynamic> section in properties.values) {
      for (var prop in section.values) {
        String id = prop['id'];
        _idToProperties[id] = prop;
        if (deps[id] != null) {
          _dependencies[id] = deps[id].map(selectionFor).toList();
        }
      }
    }

    // Set up reverse dependencies
    deps.forEach((e, deps) {
      for (var dep in deps) {
        Selection selection = selectionFor(dep);
        _reverseDependencies
            .putIfAbsent(selection.elementId, () => <Selection>[])
            .add(selection..elementId = e);
      }
    });

    // Set up paths
    void traverseNames(Map<String, dynamic> node, List<String> prevPath) {
      List<String> newPath = new List.from(prevPath)..add(node['name']);
      String id = node['id'];
      _path[id] = newPath;
      String joined = newPath.join('.');
      _joinedPath[id] = joined;
      _reverseJoinedPath[joined] = id;

      if (node['children'] != null) {
        for (String id in node['children']) {
          traverseNames(elementById(id), newPath);
        }
      }
    }

    if (properties.containsKey('library')) {
      for (var node in properties['library'].values) {
        traverseNames(node, []);
      }
    }
  }

  bool _parentsAllContained(String id, Set<String> container) =>
      reverseDependencies(id).every((a) => container.contains(a.elementId));

  Set<String> _triviallyReachedFrom(String id) {
    Queue<String> queue = new Queue<String>();
    Set<String> owns = new Set<String>();

    queue.add(id);
    owns.add(id);

    while (queue.isNotEmpty) {
      String next = queue.removeFirst();
      for (String child in dependencies(next).map((a) => a.elementId)) {
        if (!owns.contains(child) && _parentsAllContained(child, owns)) {
          queue.add(child);
          owns.add(child);
        }
      }
    }
    return owns;
  }

  int triviallyOwnedSize(String id) => _triviallyReachedFrom(id)
      .map((a) => properties(a)['size'])
      .reduce((a, b) => a + b);
}
