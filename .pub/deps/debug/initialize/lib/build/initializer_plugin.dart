// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.build.initializer_plugin;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart';
import 'package:initialize/transformer.dart';
import 'package:path/path.dart' as path;

/// A plug which allows an initializer to write out an [InitEntry] given some
/// [InitializerData] from an annotation that was found.
abstract class InitializerPlugin {
  /// Whether or not this plugin should be applied to an [Initializer] given
  /// some [InitializerData]. If [true] is returned then this plugin will take
  /// ownership of this [InitializerData] and no subsequent plugins will have
  /// an opportunity to access it.
  bool shouldApply(InitializerPluginData data);

  /// Returns a [String] or [null]. The [String] should represent dart code
  /// which creates a new [InitEntry] and that entry is added to the static
  /// initializers list. If [null] is returned then no entry is added at all for
  /// this [InitializerData].
  String apply(InitializerPluginData data);
}

/// A class which wraps all the default data passed to an [InitializerPlugin]
/// for each annotation.
class InitializerPluginData {
  final InitializerData initializer;
  final AssetId bootstrapId;
  final Map<LibraryElement, String> libraryPrefixes;
  final TransformLogger logger;
  final Resolver resolver;
  InitializerPluginData(this.initializer, this.bootstrapId,
      this.libraryPrefixes, this.resolver, this.logger);
}

/// The basic [InitializerPlugin]. This generates a new [InitEntry] to be added
/// to the static initializers list, and applies to every item it sees.
class DefaultInitializerPlugin implements InitializerPlugin {
  const DefaultInitializerPlugin();

  /// Applies to everything. Put other plugins before this one to override this
  /// behaviour.
  bool shouldApply(InitializerPluginData data) => true;

  /// Creates a normal [InitEntry] string.
  String apply(InitializerPluginData pluginData) {
    var target = buildTarget(pluginData);
    var meta = buildMeta(pluginData);
    return 'new InitEntry($meta, $target)';
  }

  /// Builds a [String] representing the meta of an [InitEntry] given an
  /// [ElementAnnotation] that was found.
  String buildMeta(InitializerPluginData pluginData) {
    var logger = pluginData.logger;
    var elementAnnotation = pluginData.initializer.annotationElement;
    var elementAnnotationElement = elementAnnotation.element;
    if (elementAnnotationElement is ConstructorElement) {
      return buildConstructorMeta(elementAnnotation, pluginData);
    } else if (elementAnnotationElement is PropertyAccessorElement) {
      return buildPropertyMeta(elementAnnotation, pluginData);
    } else {
      logger.error('Unsupported annotation type. Only constructors and '
          'properties are supported as initializers.');
    }
    return null;
  }

  /// Builds a [String] representing the meta of an [InitEntry] given an
  /// [ElementAnnotation] whose element was a [ConstructorElement].
  String buildConstructorMeta(
      ElementAnnotation elementAnnotation, InitializerPluginData pluginData) {
    var logger = pluginData.logger;
    var node = pluginData.initializer.targetNode;
    var metaPrefix =
        pluginData.libraryPrefixes[elementAnnotation.element.library];

    var annotation = pluginData.initializer.annotationNode;
    if (annotation == null) {
      logger.error(
          'Initializer annotations are only supported on libraries, classes, '
          'and top level methods. Found $node.');
    }
    var clazz = annotation.name;
    var constructor = annotation.constructorName == null
        ? ''
        : '.${annotation.constructorName}';
    var args = buildArgumentList(annotation.arguments, pluginData);
    return 'const $metaPrefix.${clazz}$constructor$args';
  }

  /// Builds a [String] representing the meta of an [InitEntry] given an
  /// [ElementAnnotation] whose element was a [PropertyAccessorElement].
  String buildPropertyMeta(
      ElementAnnotation annotation, InitializerPluginData pluginData) {
    var metaPrefix = pluginData.libraryPrefixes[annotation.element.library];
    return '$metaPrefix.${annotation.element.name}';
  }

  /// Builds a [String] for the target of an [InitEntry] given an [Element] that
  /// was annotated.
  String buildTarget(InitializerPluginData pluginData) {
    var element = pluginData.initializer.targetElement;
    var logger = pluginData.logger;
    if (element is LibraryElement) {
      return buildLibraryTarget(element, pluginData);
    } else if (element is ClassElement) {
      return buildClassTarget(element, pluginData);
    } else if (element is FunctionElement) {
      return buildFunctionTarget(element, pluginData);
    } else {
      logger.error('Initializers can only be applied to top level functions, '
          'libraries, and classes.');
    }
    return null;
  }

  /// Builds a [String] for the target of an [InitEntry] given [element] which
  /// is an annotated class.
  String buildClassTarget(
          ClassElement element, InitializerPluginData pluginData) =>
      buildSimpleTarget(element, pluginData);

  /// Builds a [String] for the target of an [InitEntry] given [element] which
  /// is an annotated function.
  String buildFunctionTarget(
          FunctionElement element, InitializerPluginData pluginData) =>
      buildSimpleTarget(element, pluginData);

  /// Builds a [String] for the target of an [InitEntry] for a simple [Element].
  /// This is just the library prefix followed by the element name.
  String buildSimpleTarget(Element element, InitializerPluginData pluginData) =>
      '${pluginData.libraryPrefixes[element.library]}.${element.name}';

  /// Builds a [String] for the target of an [InitEntry] given [element] which
  /// is an annotated library.
  String buildLibraryTarget(
      LibraryElement element, InitializerPluginData pluginData) {
    var bootstrapId = pluginData.bootstrapId;
    var logger = pluginData.logger;
    var segments = element.source.uri.pathSegments;
    var package = segments[0];
    var libraryPath;
    var packageString;
    if (bootstrapId.package == package &&
        bootstrapId.path.startsWith('${segments[1]}/')) {
      // reset `package` to null, we will do a relative path in this case.
      packageString = 'null';
      libraryPath = path.url.relative(
          path.url.joinAll(segments.getRange(1, segments.length)),
          from: path.url.dirname(path.url.join(bootstrapId.path)));
    } else if (segments[1] == 'lib') {
      packageString = "'$package'";
      libraryPath = path.url.joinAll(segments.getRange(2, segments.length));
    } else {
      logger.error('Unable to import `${element.source.uri.path}` from '
          '${bootstrapId.path}.');
    }

    return "const LibraryIdentifier"
        "(#${element.name}, $packageString, '$libraryPath')";
  }

  /// Builds a [String] representing an [ArgumentList] taking into account the
  /// [libraryPrefixes] from [pluginData].
  String buildArgumentList(
      ArgumentList args, InitializerPluginData pluginData) {
    var buffer = new StringBuffer();
    buffer.write('(');
    var first = true;
    for (var arg in args.arguments) {
      if (!first) buffer.write(', ');
      first = false;

      Expression expression;
      if (arg is NamedExpression) {
        buffer.write('${arg.name.label.name}: ');
        expression = arg.expression;
      } else {
        expression = arg;
      }

      buffer.write(buildExpression(expression, pluginData));
    }
    buffer.write(')');
    return buffer.toString();
  }

  /// Builds a [String] representing [expression] taking into account the
  /// [libraryPrefixes] from [pluginData].
  String buildExpression(
      Expression expression, InitializerPluginData pluginData) {
    var logger = pluginData.logger;
    var libraryPrefixes = pluginData.libraryPrefixes;
    var buffer = new StringBuffer();
    if (expression is StringLiteral && expression.stringValue != null) {
      buffer.write(_stringValue(expression.stringValue));
    } else if (expression is BooleanLiteral ||
        expression is DoubleLiteral ||
        expression is IntegerLiteral ||
        expression is NullLiteral) {
      buffer.write('${expression}');
    } else if (expression is ListLiteral) {
      buffer.write('const [');
      var first = true;
      for (Expression listExpression in expression.elements) {
        if (!first) buffer.write(', ');
        first = false;
        buffer.write(buildExpression(listExpression, pluginData));
      }
      buffer.write(']');
    } else if (expression is MapLiteral) {
      buffer.write('const {');
      var first = true;
      for (MapLiteralEntry entry in expression.entries) {
        if (!first) buffer.write(', ');
        first = false;
        buffer.write(buildExpression(entry.key, pluginData));
        buffer.write(': ');
        buffer.write(buildExpression(entry.value, pluginData));
      }
      buffer.write('}');
    } else if (expression is Identifier) {
      var element = expression.bestElement;
      if (element == null) {
        logger.error('Unable to get `bestElement` for expression: $expression');
      } else if (!element.isPublic) {
        // Inline the evaluated value of private identifiers.
        buffer.write(_evaluateExpression(expression, pluginData));
      } else {
        libraryPrefixes.putIfAbsent(
          element.library, () => 'i${libraryPrefixes.length}');

        buffer.write('${libraryPrefixes[element.library]}.');
        if (element is ClassElement) {
          buffer.write(element.name);
        } else if (element is PropertyAccessorElement) {
          var variable = element.variable;
          if (variable is FieldElement) {
            buffer.write('${variable.enclosingElement.name}.');
          }
          buffer.write('${variable.name}');
        } else {
          logger.error('Unsupported argument to initializer constructor.');
        }
      }
    } else if (expression is PropertyAccess) {
      buffer.write(buildExpression(expression.target, pluginData));
      buffer.write('.${expression.propertyName}');
    } else if (expression is InstanceCreationExpression) {
      logger.error('Unsupported expression in initializer, found $expression. '
          'Instance creation expressions are not supported (yet). Instead, '
          'please assign it to a const variable and use that instead.');
    } else {
      buffer.write(_evaluateExpression(expression, pluginData));
    }
    return buffer.toString();
  }

  _evaluateExpression(
      Expression expression, InitializerPluginData pluginData) {
    var logger = pluginData.logger;
    var result = pluginData.resolver.evaluateConstant(
        pluginData.initializer.targetElement.library, expression);
    if (!result.isValid) {
      logger.error('Invalid expression in initializer, found $expression. '
          'And got the following errors: ${result.errors}.');
      return null;
    }

    var value = _getValue(result.value);

    if (value == null) {
      logger.error('Unsupported expression in initializer, found '
          '$expression. Please file a bug at '
          'https://github.com/dart-lang/initialize/issues');
    }

    if (value is String) value = _stringValue(value);

    return value;
  }

  // Returns an expression for a string value. Wraps it in single quotes and
  // escapes existing single quotes and escapes.
  _stringValue(String value) {
    value = value.replaceAll(r'\', r'\\').replaceAll(r"'", r"\'");
    return "'$value'";
  }

  // Gets an actual value for a [DartObject].
  _getValue(DartObject object) {
    if (object == null) return null;
    var value = object.toBoolValue() ??
        object.toDoubleValue() ??
        object.toIntValue() ??
        object.toStringValue();
    if (value == null) {
      value = object.toListValue();
      if (value != null) {
        return value.map((DartObject element) => _getValue(element)).toList();
      }
      Map<DartObject, DartObject> map = object.toMapValue();
      if (map != null) {
        Map result = {};
        map.forEach((DartObject key, DartObject value) {
          dynamic mappedKey = _getValue(key);
          if (mappedKey != null) {
            result[mappedKey] = _getValue(value);
          }
        });
        return result;
      }
    }
    return value;
  }
}
