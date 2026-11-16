// Compile-only checks: real WebAPI types flowing into the React bindings.
let createRootFromElement = (parent: WebAPI.Element.t) =>
  parent
  ->WebAPI.Element.querySelector("#root")
  ->Null.toOption
  ->Option.map(ReactDOM.Client.createRoot)

let capturePointer = (element: WebAPI.Element.t, event: ReactEvent.Pointer.t) =>
  element->WebAPI.Element.setPointerCapture(event->ReactEvent.Pointer.pointerId)

let eventWindow = (event: ReactEvent.UI.t): WebAPI.DOM.window => event->ReactEvent.UI.view

let elementWithRef = (ref: ReactDOM.Ref.currentDomRef) =>
  <div ref={ReactDOM.Ref.domRef(ref)} />

let elementWithCallbackRef = (ref: ReactDOM.Ref.callbackDomRef) =>
  <div ref={ReactDOM.Ref.callbackDomRef(ref)} />

let findChild = (element: WebAPI.Element.t) =>
  ReactTestUtils.DOM.findBySelector(element, ".child")

let container = (element: WebAPI.Element.t) => {
  let container = ref(Some(element))
  ReactTestUtils.cleanupContainer(container, ())
}

let historyState = (history: WebAPI.History.Types.history) => history.state
let locationPath = (location: WebAPI.Location.t) => location.pathname
