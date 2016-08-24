// DO NOT EDIT: auto-generated with `pub run custom_element_apigen:update`

/// Dart API for the polymer element `core_field`.
@HtmlImport('core_field_nodart.html')
library core_elements.core_field;

import 'dart:html';
import 'dart:js' show JsArray, JsObject;
import 'package:web_components/web_components.dart';
import 'package:polymer_interop/polymer_interop.dart';

/// The `core-field` supplies a horizontal layout, anticipating an input.
///
/// Example:
///
///     <core-field>
///       <core-icon icon="menu"></core-icon>
///       <label>I'm a label!</label>
///       <input placeholder="I have a label" flex>
///     </core-field>
@CustomElementProxy('core-field')
class CoreField extends HtmlElement with CustomElementProxyMixin, PolymerProxyMixin {
  CoreField.created() : super.created();
  factory CoreField() => new Element.tag('core-field');
}
