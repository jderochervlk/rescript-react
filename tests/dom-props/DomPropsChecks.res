let empty = <div />
let single = <div id="single">{React.string("child")}</div>

let multiple =
  <div>
    <span />
    <span />
  </div>

let keyed = <div key="one">{React.string("child")}</div>

let keyedMultiple =
  <div key="many">
    <span />
    <span />
  </div>

let optionalKey = key => <div key=?key />

let baseProps: ReactDOM.domProps = {id: "base", title: "kept"}
let spreadOnly = <div {...baseProps} />
let spreadOverride = <div {...baseProps} id="overridden" />

let styles: ReactDOMStyle.t = {color: "red", marginTop: "2px"}

let styled =
  <div
    style={ReactDOM.Style.combine(styles, {display: "block"})}
    ariaLabel="example"
    ariaHidden=true
    dataTestId="styled"
  />

let customStyle = <div style={ReactDOM.Style.unsafeAddProp(styles, "--accent", "blue")} />

let svg =
  <svg viewBox="0 0 10 10">
    <path d="M0 0L1 1" strokeWidth="2" />
  </svg>

let rawHtml = <div dangerouslySetInnerHTML={{"__html": "<b>raw</b>"}} />
let popover = <button popover={ReactDOM.Auto} popoverTargetAction={ReactDOM.Toggle} />

let objectRef: ReactDOM.Ref.currentDomRef = React.createRef()
let withObjectRef = <div ref={ReactDOM.Ref.domRef(objectRef)} />
let callbackRef: ReactDOM.Ref.callbackDomRef = _element => Some(() => ())
let withCallbackRef = <div ref={ReactDOM.Ref.callbackDomRef(callbackRef)} />

let clicked = <button onClick={event => ReactEvent.Mouse.preventDefault(event)} />
let changed = <input onChange={event => ReactEvent.Form.preventDefault(event)} />
let pointer = <div onPointerDown={event => ReactEvent.Pointer.preventDefault(event)} />
let keyboard = <input onKeyDown={event => ReactEvent.Keyboard.preventDefault(event)} />
let focused = <input onFocus={event => ReactEvent.Focus.preventDefault(event)} />
let toggled = <div onToggle={event => ReactEvent.Toggle.preventDefault(event)} />
let beforeToggle = <div onBeforeToggleCapture={event => ReactEvent.Toggle.preventDefault(event)} />

let toggleSource = (event: ReactEvent.Toggle.t): option<WebAPI.Element.t> =>
  ReactEvent.Toggle.source(event)

let toggleState = (event: ReactEvent.Toggle.t) => (
  ReactEvent.Toggle.oldState(event),
  ReactEvent.Toggle.newState(event),
)

let direct = ReactDOM.jsx("div", {id: "direct"})
let directKeyed = ReactDOM.jsxKeyed("div", {id: "direct-keyed"}, ~key="direct-key", ())
let directMany = ReactDOM.jsxs("div", {children: React.array([empty, single])})

let directManyKeyed = ReactDOM.jsxsKeyed(
  "div",
  {children: React.array([empty, single])},
  ~key="direct-many-key",
  (),
)

let created = ReactDOM.createElement("div", ~props={id: "created"}, [single])
let createdVariadic = ReactDOM.createDOMElementVariadic("div", ~props={id: "variadic"}, [single])
