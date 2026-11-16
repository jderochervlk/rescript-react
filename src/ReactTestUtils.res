type undefined = nullable<unit>

let undefined: undefined = Nullable.undefined

@module("react-dom/test-utils")
external reactAct: (unit => undefined) => unit = "act"

let act: (unit => unit) => unit = func => {
  let reactFunc = () => {
    func()
    undefined
  }
  reactAct(reactFunc)
}

@module("react-dom/test-utils")
external reactActAsync: (unit => promise<'a>) => promise<unit> = "act"

let actAsync = func => {
  let reactFunc = () => func()
  reactActAsync(reactFunc)
}

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

module Simulate = {
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

  let changeWithValue = (element, value) => {
    let event = {
      "target": {
        "value": value,
      },
    }
    changeWithEvent(element, event)
  }

  let changeWithChecked = (element, value) => {
    let event = {
      "target": {
        "checked": value,
      },
    }
    changeWithEvent(element, event)
  }

  @module("react-dom/test-utils") @scope("Simulate")
  external canPlay: WebAPI.DOM.element => unit = "canPlay"

  @module("react-dom/test-utils") @scope("Simulate")
  external timeUpdate: WebAPI.DOM.element => unit = "timeUpdate"

  @module("react-dom/test-utils") @scope("Simulate")
  external ended: WebAPI.DOM.element => unit = "ended"

  @module("react-dom/test-utils") @scope("Simulate")
  external focus: WebAPI.DOM.element => unit = "focus"
}

@val external document: WebAPI.DOM.document = "document"

@send
external querySelector: (WebAPI.DOM.element, string) => option<WebAPI.DOM.element> = "querySelector"

@send
external querySelectorAll: (WebAPI.DOM.element, string) => Array.arrayLike<WebAPI.DOM.element> =
  "querySelectorAll"

@get external textContent: WebAPI.DOM.element => string = "textContent"
@get external body: WebAPI.DOM.document => option<WebAPI.DOM.element> = "body"

@send
external createElement: (WebAPI.DOM.document, string) => WebAPI.DOM.element = "createElement"

@send external remove: WebAPI.DOM.element => unit = "remove"

@send
external appendChild: (WebAPI.DOM.element, WebAPI.DOM.element) => WebAPI.DOM.element = "appendChild"

let querySelectorAll = (element, string) => Array.fromArrayLike(querySelectorAll(element, string))

module DOM = {
  @return(nullable) @get
  external value: WebAPI.DOM.element => option<string> = "value"

  let findBySelector = (element, selector) => querySelector(element, selector)

  let findByAllSelector = (element, selector) => querySelectorAll(element, selector)

  let findBySelectorAndTextContent = (element, selector, content) =>
    querySelectorAll(element, selector)->Array.find(node => node->textContent === content)

  let findBySelectorAndPartialTextContent = (element, selector, content) =>
    querySelectorAll(element, selector)->Array.find(node =>
      node->textContent->String.includes(content)
    )
}

let prepareContainer = (container: ref<option<WebAPI.DOM.element>>, ()) => {
  let containerElement = document->createElement("div")
  switch document->body {
  | Some(body) => body->appendChild(containerElement)->ignore
  | None => ()
  }
  container := Some(containerElement)
}

let cleanupContainer = (container: ref<option<WebAPI.DOM.element>>, ()) => {
  switch container.contents {
  | Some(contents) => remove(contents)
  | None => ()
  }
  container := None
}

let getContainer = container =>
  switch container.contents {
  | Some(contents) => contents
  | None => throw(Not_found)
  }
