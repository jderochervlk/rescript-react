let toPublic = (element: WebAPI.DOM.element): WebAPI.Element.t => element
let fromPublic = (element: WebAPI.Element.t): WebAPI.DOM.element => element
let toTree = (element: WebAPI.DOM.element): WebAPI.DOMTree.element => element
let fromTree = (element: WebAPI.DOMTree.element): WebAPI.DOM.element => element

let createRootFromElement = (parent: WebAPI.Element.t) =>
  parent
  ->WebAPI.Element.querySelector("#root")
  ->Null.toOption
  ->Option.map(ReactDOM.Client.createRoot)

let capturePointer = (element: WebAPI.DOM.element, event: ReactEvent.Pointer.t) =>
  element->WebAPI.Element.setPointerCapture(event->ReactEvent.Pointer.pointerId)
