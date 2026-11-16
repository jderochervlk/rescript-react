let act: (unit => unit) => unit

let actAsync: (unit => promise<'a>) => promise<unit>

@module("react-dom/test-utils")
external isElement: 'element => bool = "isElement"

@module("react-dom/test-utils")
external isElementOfType: ('element, React.component<'props>) => bool = "isElementOfType"

@module("react-dom/test-utils")
external isDOMComponent: 'element => bool = "isDOMComponent"

@module("react-dom/test-utils")
external isCompositeComponent: 'element => bool = "isCompositeComponent"

@module("react-dom/test-utils")
external isCompositeComponentWithType: ('element, React.component<'props>) => bool =
  "isCompositeComponentWithType"

module Simulate: {
  @module("react-dom/test-utils") @scope("Simulate")
  external click: WebAPI.DOM.element => unit = "click"

  @module("react-dom/test-utils") @scope("Simulate")
  external clickWithEvent: (WebAPI.DOM.element, 'event) => unit = "click"

  @module("react-dom/test-utils") @scope("Simulate")
  external change: WebAPI.DOM.element => unit = "change"

  @module("react-dom/test-utils") @scope("Simulate")
  external blur: WebAPI.DOM.element => unit = "blur"

  @module("react-dom/test-utils") @scope("Simulate")
  external changeWithEvent: (WebAPI.DOM.element, 'event) => unit = "change"

  let changeWithValue: (WebAPI.DOM.element, string) => unit
  let changeWithChecked: (WebAPI.DOM.element, bool) => unit

  @module("react-dom/test-utils") @scope("Simulate")
  external canPlay: WebAPI.DOM.element => unit = "canPlay"

  @module("react-dom/test-utils") @scope("Simulate")
  external timeUpdate: WebAPI.DOM.element => unit = "timeUpdate"

  @module("react-dom/test-utils") @scope("Simulate")
  external ended: WebAPI.DOM.element => unit = "ended"

  @module("react-dom/test-utils") @scope("Simulate")
  external focus: WebAPI.DOM.element => unit = "focus"
}

module DOM: {
  @return(nullable) @get
  external value: WebAPI.DOM.element => option<string> = "value"

  let findBySelector: (WebAPI.DOM.element, string) => option<WebAPI.DOM.element>
  let findByAllSelector: (WebAPI.DOM.element, string) => array<WebAPI.DOM.element>

  let findBySelectorAndTextContent: (
    WebAPI.DOM.element,
    string,
    string,
  ) => option<WebAPI.DOM.element>

  let findBySelectorAndPartialTextContent: (
    WebAPI.DOM.element,
    string,
    string,
  ) => option<WebAPI.DOM.element>
}

let prepareContainer: (ref<option<WebAPI.DOM.element>>, unit) => unit
let cleanupContainer: (ref<option<WebAPI.DOM.element>>, unit) => unit
let getContainer: ref<option<WebAPI.DOM.element>> => WebAPI.DOM.element
