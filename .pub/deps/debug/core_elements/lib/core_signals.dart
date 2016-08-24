// DO NOT EDIT: auto-generated with `pub run custom_element_apigen:update`

/// Dart API for the polymer element `core_signals`.
@HtmlImport('core_signals_nodart.html')
library core_elements.core_signals;

import 'dart:html';
import 'dart:js' show JsArray, JsObject;
import 'package:web_components/web_components.dart';
import 'package:polymer_interop/polymer_interop.dart';

/// `core-signals` provides basic publish-subscribe functionality.
///
/// Note: avoid using `core-signals` whenever you can use
/// a controller (parent element) to mediate communication
/// instead.
///
/// To send a signal, fire a custom event of type `core-signal`, with
/// a detail object containing `name` and `data` fields.
///
///     this.fire('core-signal', {name: 'hello', data: null});
///
/// To receive a signal, listen for `core-signal-<name>` event on a
/// `core-signals` element.
///
///   <core-signals on-core-signal-hello="{{helloSignal}}">
///
/// You can fire a signal event from anywhere, and all
/// `core-signals` elements will receive the event, regardless
/// of where they are in DOM.
@CustomElementProxy('core-signals')
class CoreSignals extends HtmlElement with CustomElementProxyMixin, PolymerProxyMixin {
  CoreSignals.created() : super.created();
  factory CoreSignals() => new Element.tag('core-signals');
}
