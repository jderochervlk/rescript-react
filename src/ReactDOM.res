/* First time reading a ReScript file? */
/* `external` is the foreign function call in OCaml. */
/* here we're saying `I guarantee that on the JS side, we have a `render` function in the module "react-dom"
 that takes in a reactElement, a dom element, and returns unit (nothing) */
/* It's like `let`, except you're pointing the implementation to the JS side. The compiler will inline these
 calls and add the appropriate `require("react-dom")` in the file calling this `render` */

// Helper so that ReactDOM itself doesn't bring any runtime
@val @return(nullable)
external querySelector: string => option<WebAPI.DOMTree.element> = "document.querySelector"

module Client = {
  module Root = {
    type t

    @send external render: (t, React.element) => unit = "render"

    @send external unmount: (t, unit) => unit = "unmount"
  }

  @module("react-dom/client")
  external createRoot: WebAPI.DOMTree.element => Root.t = "createRoot"

  @module("react-dom/client")
  external hydrateRoot: (WebAPI.DOMTree.element, React.element) => Root.t = "hydrateRoot"
}

// Very rudimentary form data bindings
module FormData = {
  type t = WebAPI.FormData.t
  type file = WebAPI.DOM.file

  type formValue =
    | String(string)
    | File(file)

  @new external make: unit => t = "FormData"

  @send external append: (t, string, string, ~filename: string=?) => unit = "append"
  @send external delete: (t, string) => unit = "delete"
  @return(nullable) @send external getUnsafe: (t, string) => option<'a> = "get"
  @send external getAllUnsafe: (t, string) => array<'a> = "getAll"

  let getString = (formData, name) => {
    switch formData->getUnsafe(name) {
    | Some(value) => typeof(value) === #string ? Some(value) : None
    | _ => None
    }
  }

  external _asFile: 'a => file = "%identity"

  let getFile = (formData, name) => {
    switch formData->getUnsafe(name) {
    | Some(value) => typeof(value) === #string ? None : Some(value->_asFile)
    | _ => None
    }
  }

  let getAll = (t, string) => {
    t
    ->getAllUnsafe(string)
    ->Array.map(value => {
      typeof(value) === #string ? String(value) : File(value->_asFile)
    })
  }

  @send external set: (t, string, string, ~filename: string=?) => unit = "set"
  @send external has: (t, string) => bool = "has"
  // @send external keys: t => Iterator.t<string> = "keys";
  // @send external values: t => Iterator.t<value> = "values";
}

@module("react-dom")
external createPortal: (React.element, WebAPI.DOMTree.element) => React.element = "createPortal"

external domElementToObj: WebAPI.DOMTree.element => {..} = "%identity"

type style = ReactDOMStyle.t

type domRef

module Ref = {
  type t = domRef
  type currentDomRef = React.ref<nullable<WebAPI.DOMTree.element>>
  type callbackDomRef = nullable<WebAPI.DOMTree.element> => option<unit => unit>

  external domRef: currentDomRef => domRef = "%identity"
  external callbackDomRef: callbackDomRef => domRef = "%identity"
}

// Hooks

@unboxed
type formStatusActionResult =
  | @as(undefined) Sync
  | Async(promise<unit>)

type formStatusAction = FormData.t => formStatusActionResult

type formStatus = {
  /** If true, this means the parent <form> is pending submission. Otherwise, false. */
  pending: bool,
  /** An object implementing the FormData interface that contains the data the parent <form> is submitting. If there is no active submission or no parent <form>, it will be null. */
  data: nullable<FormData.t>,
  /** This represents whether the parent <form> is submitting with either a GET or POST HTTP method. By default, a <form> will use the GET method and can be specified by the method property. */
  method: nullable<[#get | #post]>,
  /** A reference to the function passed to the action prop on the parent <form>. If there is no parent <form>, the property is null. If there is a URI value provided to the action prop, or no action prop specified, status.action will be null. */
  action: nullable<formStatusAction>,
}

external formAction: React.formAction<FormData.t> => string = "%identity"

/** `useFormStatus` is a Hook that gives you status information of the last form submission. */
@module("react-dom")
external useFormStatus: unit => formStatus = "useFormStatus"

// Resource Preloading APIs

/** The CORS policy to use. */
type crossOrigin = [
  | #anonymous
  | #"use-credentials"
]

/** The Referrer header to send when fetching. */
type referrerPolicy = [
  | #"referrer-when-downgrade"
  | #"no-referrer"
  | #origin
  | #"origin-when-cross-origin"
  | #"unsafe-url"
]

/** Suggests a relative priority for fetching the resource. */
type fetchPriority = [#auto | #high | #low]

/** `prefetchDNS` lets you eagerly look up the IP of a server that you expect to load resources from. */
@module("react-dom")
external prefetchDNS: string => unit = "prefetchDNS"

/** `preconnect` lets you eagerly connect to a server that you expect to load resources from. */
@module("react-dom")
external preconnect: string => unit = "preconnect"

type preloadOptions = {
  /** The type of resource. */
  @as("as")
  as_: [
    | #audio
    | #document
    | #embed
    | #fetch
    | #font
    | #image
    | #object
    | #script
    | #style
    | #track
    | #video
    | #worker
  ],
  /** The CORS policy to use. It is required when as is set to "fetch". */
  crossOrigin?: crossOrigin,
  /** The Referrer header to send when fetching. */
  referrerPolicy?: referrerPolicy,
  /** A cryptographic hash of the resource, to verify its authenticity. */
  integrity?: string,
  /** The MIME type of the resource. */
  @as("type")
  type_?: string,
  /** A cryptographic nonce to allow the resource when using a strict Content Security Policy. */
  nonce?: string,
  /** Suggests a relative priority for fetching the resource. */
  fetchPriority?: fetchPriority,
  /** For use only with as: "image". Specifies the source set of the image. */
  imageSrcSet?: string,
  /** For use only with as: "image". Specifies the sizes of the image. */
  imageSizes?: string,
}

/** `preload` lets you eagerly fetch a resource such as a stylesheet, font, or external script that you expect to use. */
@module("react-dom")
external preload: (string, preloadOptions) => unit = "preload"

type preloadModuleOptions = {
  /** The type of resource. */
  @as("as")
  as_: [#script],
  /** The CORS policy to use. It is required when as is set to "fetch". */
  crossOrigin?: crossOrigin,
  /** A cryptographic hash of the resource, to verify its authenticity. */
  integrity?: string,
  /** A cryptographic nonce to allow the resource when using a strict Content Security Policy. */
  nonce?: string,
}

/** `preloadModule` lets you eagerly fetch an ESM module that you expect to use. */
@module("react-dom")
external preloadModule: (string, preloadModuleOptions) => unit = "preloadModule"

type preinitOptions = {
  /** The type of resource. */
  @as("as")
  as_: [#script | #style],
  /** Required with stylesheets. Says where to insert the stylesheet relative to others. Stylesheets with higher precedence can override those with lower precedence. */
  precedence?: [#reset | #low | #medium | #high],
  /** The CORS policy to use. It is required when as is set to "fetch". */
  crossOrigin?: crossOrigin,
  /** The Referrer header to send when fetching. */
  referrerPolicy?: referrerPolicy,
  /** A cryptographic hash of the resource, to verify its authenticity. */
  integrity?: string,
  nonce?: string,
  /** Suggests a relative priority for fetching the resource. */
  fetchPriority?: fetchPriority,
}

/** `preinit` lets you eagerly fetch and evaluate a stylesheet or external script. */
@module("react-dom")
external preinit: (string, preinitOptions) => unit = "preinit"

/** To preinit an ESM module, call the `preinitModule` function from react-dom. */
@module("react-dom")
external preinitModule: (string, preloadModuleOptions) => unit = "preinitModule"

// Runtime

/**
 * React's intrinsic DOM props. Based on @rescript/runtime 13.0.0-alpha.7
 * JsxDOM definitions.
 *
 * Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * Copyright (C) 2017- Hongbo Zhang, Authors of ReScript
 * SPDX-License-Identifier: MIT
 */
type popover = | @as("auto") Auto | @as("manual") Manual | @as("hint") Hint

type popoverTargetAction = | @as("toggle") Toggle | @as("show") Show | @as("hide") Hide

type domProps = {
  key?: string,
  children?: Jsx.element,
  ref?: domRef,
  allow?: string,
  @as("aria-current")
  ariaCurrent?: [#page | #step | #location | #date | #time | #"true" | #"false"],
  @as("aria-details") ariaDetails?: string,
  @as("aria-disabled") ariaDisabled?: bool,
  @as("aria-hidden") ariaHidden?: bool,
  @as("aria-invalid") ariaInvalid?: [#grammar | #"false" | #spelling | #"true"],
  @as("aria-keyshortcuts") ariaKeyshortcuts?: string,
  @as("aria-label") ariaLabel?: string,
  @as("aria-roledescription") ariaRoledescription?: string,
  @as("aria-autocomplete") ariaAutocomplete?: [#inline | #list | #both | #none],
  @as("aria-checked") ariaChecked?: [#"true" | #"false" | #mixed],
  @as("aria-expanded") ariaExpanded?: bool,
  @as("aria-haspopup")
  ariaHaspopup?: [#menu | #listbox | #tree | #grid | #dialog | #"true" | #"false"],
  @as("aria-level") ariaLevel?: int,
  @as("aria-modal") ariaModal?: bool,
  @as("aria-multiline") ariaMultiline?: bool,
  @as("aria-multiselectable") ariaMultiselectable?: bool,
  @as("aria-orientation") ariaOrientation?: [#horizontal | #vertical | #undefined],
  @as("aria-placeholder") ariaPlaceholder?: string,
  @as("aria-pressed") ariaPressed?: [#"true" | #"false" | #mixed],
  @as("aria-readonly") ariaReadonly?: bool,
  @as("aria-required") ariaRequired?: bool,
  @as("aria-selected") ariaSelected?: bool,
  @as("aria-sort") ariaSort?: string,
  @as("aria-valuemax") ariaValuemax?: float,
  @as("aria-valuemin") ariaValuemin?: float,
  @as("aria-valuenow") ariaValuenow?: float,
  @as("aria-valuetext") ariaValuetext?: string,
  @as("aria-atomic") ariaAtomic?: bool,
  @as("aria-busy") ariaBusy?: bool,
  @as("aria-live") ariaLive?: [#off | #polite | #assertive | #rude],
  @as("aria-relevant") ariaRelevant?: string,
  @as("aria-dropeffect") ariaDropeffect?: [#copy | #move | #link | #execute | #popup | #none],
  @as("aria-grabbed") ariaGrabbed?: bool,
  @as("aria-activedescendant") ariaActivedescendant?: string,
  @as("aria-colcount") ariaColcount?: int,
  @as("aria-colindex") ariaColindex?: int,
  @as("aria-colspan") ariaColspan?: int,
  @as("aria-controls") ariaControls?: string,
  @as("aria-describedby") ariaDescribedby?: string,
  @as("aria-errormessage") ariaErrormessage?: string,
  @as("aria-flowto") ariaFlowto?: string,
  @as("aria-labelledby") ariaLabelledby?: string,
  @as("aria-owns") ariaOwns?: string,
  @as("aria-posinset") ariaPosinset?: int,
  @as("aria-rowcount") ariaRowcount?: int,
  @as("aria-rowindex") ariaRowindex?: int,
  @as("aria-rowspan") ariaRowspan?: int,
  @as("aria-setsize") ariaSetsize?: int,
  defaultChecked?: bool,
  defaultValue?: string,
  accessKey?: string,
  capture?: [#user | #environment],
  className?: string,
  contentEditable?: bool,
  contextMenu?: string,
  @as("data-testid") dataTestId?: string,
  dir?: string,
  draggable?: bool,
  hidden?: bool,
  id?: string,
  inert?: bool,
  lang?: string,
  popover?: popover,
  popoverTarget?: string,
  popoverTargetAction?: popoverTargetAction,
  role?: string,
  style?: style,
  spellCheck?: bool,
  tabIndex?: int,
  title?: string,
  itemID?: string,
  itemProp?: string,
  itemRef?: string,
  itemScope?: bool,
  itemType?: string,
  accept?: string,
  acceptCharset?: string,
  action?: string,
  allowFullScreen?: bool,
  alt?: string,
  @as("as") as_?: string,
  async?: bool,
  autoComplete?: string,
  autoCapitalize?: string,
  autoFocus?: bool,
  autoPlay?: bool,
  challenge?: string,
  charSet?: string,
  checked?: bool,
  cite?: string,
  crossOrigin?: string,
  cols?: int,
  colSpan?: int,
  content?: string,
  controls?: bool,
  coords?: string,
  data?: string,
  dateTime?: string,
  default?: bool,
  defer?: bool,
  disabled?: bool,
  download?: string,
  encType?: string,
  form?: string,
  formAction?: string,
  formTarget?: string,
  formMethod?: string,
  frameBorder?: int,
  headers?: string,
  height?: string,
  high?: int,
  href?: string,
  hrefLang?: string,
  htmlFor?: string,
  httpEquiv?: string,
  icon?: string,
  inputMode?: string,
  integrity?: string,
  keyType?: string,
  kind?: string,
  label?: string,
  list?: string,
  loading?: [#lazy | #eager],
  loop?: bool,
  low?: int,
  manifest?: string,
  max?: string,
  maxLength?: int,
  media?: string,
  mediaGroup?: string,
  method?: string,
  min?: string,
  minLength?: int,
  multiple?: bool,
  muted?: bool,
  name?: string,
  nonce?: string,
  noValidate?: bool,
  @as("open") open_?: bool,
  optimum?: int,
  pattern?: string,
  placeholder?: string,
  playsInline?: bool,
  poster?: string,
  preload?: string,
  radioGroup?: string,
  readOnly?: bool,
  rel?: string,
  required?: bool,
  reversed?: bool,
  rows?: int,
  rowSpan?: int,
  sandbox?: string,
  scope?: string,
  scoped?: bool,
  scrolling?: string,
  selected?: bool,
  shape?: string,
  size?: int,
  sizes?: string,
  span?: int,
  src?: string,
  srcDoc?: string,
  srcLang?: string,
  srcSet?: string,
  start?: int,
  step?: float,
  summary?: string,
  target?: string,
  @as("type") type_?: string,
  useMap?: string,
  value?: string,
  width?: string,
  wrap?: string,
  onCancel?: ReactEvent.Synthetic.t => unit,
  onCancelCapture?: ReactEvent.Synthetic.t => unit,
  onClose?: ReactEvent.Synthetic.t => unit,
  onCloseCapture?: ReactEvent.Synthetic.t => unit,
  onFullscreenChange?: ReactEvent.Synthetic.t => unit,
  onFullscreenChangeCapture?: ReactEvent.Synthetic.t => unit,
  onFullscreenError?: ReactEvent.Synthetic.t => unit,
  onFullscreenErrorCapture?: ReactEvent.Synthetic.t => unit,
  onBeforeToggle?: ReactEvent.Toggle.t => unit,
  onBeforeToggleCapture?: ReactEvent.Toggle.t => unit,
  onToggle?: ReactEvent.Toggle.t => unit,
  onToggleCapture?: ReactEvent.Toggle.t => unit,
  onCopy?: ReactEvent.Clipboard.t => unit,
  onCopyCapture?: ReactEvent.Clipboard.t => unit,
  onCut?: ReactEvent.Clipboard.t => unit,
  onCutCapture?: ReactEvent.Clipboard.t => unit,
  onPaste?: ReactEvent.Clipboard.t => unit,
  onPasteCapture?: ReactEvent.Clipboard.t => unit,
  onCompositionEnd?: ReactEvent.Composition.t => unit,
  onCompositionEndCapture?: ReactEvent.Composition.t => unit,
  onCompositionStart?: ReactEvent.Composition.t => unit,
  onCompositionStartCapture?: ReactEvent.Composition.t => unit,
  onCompositionUpdate?: ReactEvent.Composition.t => unit,
  onCompositionUpdateCapture?: ReactEvent.Composition.t => unit,
  onKeyDown?: ReactEvent.Keyboard.t => unit,
  onKeyDownCapture?: ReactEvent.Keyboard.t => unit,
  onKeyPress?: ReactEvent.Keyboard.t => unit,
  onKeyPressCapture?: ReactEvent.Keyboard.t => unit,
  onKeyUp?: ReactEvent.Keyboard.t => unit,
  onKeyUpCapture?: ReactEvent.Keyboard.t => unit,
  onFocus?: ReactEvent.Focus.t => unit,
  onFocusCapture?: ReactEvent.Focus.t => unit,
  onBlur?: ReactEvent.Focus.t => unit,
  onBlurCapture?: ReactEvent.Focus.t => unit,
  onBeforeInput?: ReactEvent.Form.t => unit,
  onBeforeInputCapture?: ReactEvent.Form.t => unit,
  onChange?: ReactEvent.Form.t => unit,
  onChangeCapture?: ReactEvent.Form.t => unit,
  onInput?: ReactEvent.Form.t => unit,
  onInputCapture?: ReactEvent.Form.t => unit,
  onReset?: ReactEvent.Form.t => unit,
  onResetCapture?: ReactEvent.Form.t => unit,
  onSubmit?: ReactEvent.Form.t => unit,
  onSubmitCapture?: ReactEvent.Form.t => unit,
  onInvalid?: ReactEvent.Form.t => unit,
  onInvalidCapture?: ReactEvent.Form.t => unit,
  onAuxClick?: ReactEvent.Mouse.t => unit,
  onAuxClickCapture?: ReactEvent.Mouse.t => unit,
  onClick?: ReactEvent.Mouse.t => unit,
  onClickCapture?: ReactEvent.Mouse.t => unit,
  onContextMenu?: ReactEvent.Mouse.t => unit,
  onContextMenuCapture?: ReactEvent.Mouse.t => unit,
  onDoubleClick?: ReactEvent.Mouse.t => unit,
  onDoubleClickCapture?: ReactEvent.Mouse.t => unit,
  onDrag?: ReactEvent.Mouse.t => unit,
  onDragCapture?: ReactEvent.Mouse.t => unit,
  onDragEnd?: ReactEvent.Mouse.t => unit,
  onDragEndCapture?: ReactEvent.Mouse.t => unit,
  onDragEnter?: ReactEvent.Mouse.t => unit,
  onDragEnterCapture?: ReactEvent.Mouse.t => unit,
  onDragExit?: ReactEvent.Mouse.t => unit,
  onDragExitCapture?: ReactEvent.Mouse.t => unit,
  onDragLeave?: ReactEvent.Mouse.t => unit,
  onDragLeaveCapture?: ReactEvent.Mouse.t => unit,
  onDragOver?: ReactEvent.Mouse.t => unit,
  onDragOverCapture?: ReactEvent.Mouse.t => unit,
  onDragStart?: ReactEvent.Mouse.t => unit,
  onDragStartCapture?: ReactEvent.Mouse.t => unit,
  onDrop?: ReactEvent.Mouse.t => unit,
  onDropCapture?: ReactEvent.Mouse.t => unit,
  onMouseDown?: ReactEvent.Mouse.t => unit,
  onMouseDownCapture?: ReactEvent.Mouse.t => unit,
  onMouseEnter?: ReactEvent.Mouse.t => unit,
  onMouseLeave?: ReactEvent.Mouse.t => unit,
  onMouseMove?: ReactEvent.Mouse.t => unit,
  onMouseMoveCapture?: ReactEvent.Mouse.t => unit,
  onMouseOut?: ReactEvent.Mouse.t => unit,
  onMouseOutCapture?: ReactEvent.Mouse.t => unit,
  onMouseOver?: ReactEvent.Mouse.t => unit,
  onMouseOverCapture?: ReactEvent.Mouse.t => unit,
  onMouseUp?: ReactEvent.Mouse.t => unit,
  onMouseUpCapture?: ReactEvent.Mouse.t => unit,
  onSelect?: ReactEvent.Selection.t => unit,
  onSelectCapture?: ReactEvent.Selection.t => unit,
  onTouchCancel?: ReactEvent.Touch.t => unit,
  onTouchCancelCapture?: ReactEvent.Touch.t => unit,
  onTouchEnd?: ReactEvent.Touch.t => unit,
  onTouchEndCapture?: ReactEvent.Touch.t => unit,
  onTouchMove?: ReactEvent.Touch.t => unit,
  onTouchMoveCapture?: ReactEvent.Touch.t => unit,
  onTouchStart?: ReactEvent.Touch.t => unit,
  onTouchStartCapture?: ReactEvent.Touch.t => unit,
  onPointerOver?: ReactEvent.Pointer.t => unit,
  onPointerOverCapture?: ReactEvent.Pointer.t => unit,
  onPointerEnter?: ReactEvent.Pointer.t => unit,
  onPointerDown?: ReactEvent.Pointer.t => unit,
  onPointerDownCapture?: ReactEvent.Pointer.t => unit,
  onPointerMove?: ReactEvent.Pointer.t => unit,
  onPointerMoveCapture?: ReactEvent.Pointer.t => unit,
  onPointerUp?: ReactEvent.Pointer.t => unit,
  onPointerUpCapture?: ReactEvent.Pointer.t => unit,
  onPointerCancel?: ReactEvent.Pointer.t => unit,
  onPointerCancelCapture?: ReactEvent.Pointer.t => unit,
  onPointerOut?: ReactEvent.Pointer.t => unit,
  onPointerOutCapture?: ReactEvent.Pointer.t => unit,
  onPointerLeave?: ReactEvent.Pointer.t => unit,
  onGotPointerCapture?: ReactEvent.Pointer.t => unit,
  onGotPointerCaptureCapture?: ReactEvent.Pointer.t => unit,
  onLostPointerCapture?: ReactEvent.Pointer.t => unit,
  onLostPointerCaptureCapture?: ReactEvent.Pointer.t => unit,
  onScroll?: ReactEvent.UI.t => unit,
  onScrollCapture?: ReactEvent.UI.t => unit,
  onScrollEnd?: ReactEvent.UI.t => unit,
  onScrollEndCapture?: ReactEvent.UI.t => unit,
  onWheel?: ReactEvent.Wheel.t => unit,
  onWheelCapture?: ReactEvent.Wheel.t => unit,
  onAbort?: ReactEvent.Media.t => unit,
  onAbortCapture?: ReactEvent.Media.t => unit,
  onCanPlay?: ReactEvent.Media.t => unit,
  onCanPlayCapture?: ReactEvent.Media.t => unit,
  onCanPlayThrough?: ReactEvent.Media.t => unit,
  onCanPlayThroughCapture?: ReactEvent.Media.t => unit,
  onDurationChange?: ReactEvent.Media.t => unit,
  onDurationChangeCapture?: ReactEvent.Media.t => unit,
  onEmptied?: ReactEvent.Media.t => unit,
  onEmptiedCapture?: ReactEvent.Media.t => unit,
  onEncrypted?: ReactEvent.Media.t => unit,
  onEncryptedCapture?: ReactEvent.Media.t => unit,
  onEnded?: ReactEvent.Media.t => unit,
  onEndedCapture?: ReactEvent.Media.t => unit,
  onError?: ReactEvent.Media.t => unit,
  onErrorCapture?: ReactEvent.Media.t => unit,
  onLoadedData?: ReactEvent.Media.t => unit,
  onLoadedDataCapture?: ReactEvent.Media.t => unit,
  onLoadedMetadata?: ReactEvent.Media.t => unit,
  onLoadedMetadataCapture?: ReactEvent.Media.t => unit,
  onLoadStart?: ReactEvent.Media.t => unit,
  onLoadStartCapture?: ReactEvent.Media.t => unit,
  onPause?: ReactEvent.Media.t => unit,
  onPauseCapture?: ReactEvent.Media.t => unit,
  onPlay?: ReactEvent.Media.t => unit,
  onPlayCapture?: ReactEvent.Media.t => unit,
  onPlaying?: ReactEvent.Media.t => unit,
  onPlayingCapture?: ReactEvent.Media.t => unit,
  onProgress?: ReactEvent.Media.t => unit,
  onProgressCapture?: ReactEvent.Media.t => unit,
  onRateChange?: ReactEvent.Media.t => unit,
  onRateChangeCapture?: ReactEvent.Media.t => unit,
  onResize?: ReactEvent.Media.t => unit,
  onResizeCapture?: ReactEvent.Media.t => unit,
  onSeeked?: ReactEvent.Media.t => unit,
  onSeekedCapture?: ReactEvent.Media.t => unit,
  onSeeking?: ReactEvent.Media.t => unit,
  onSeekingCapture?: ReactEvent.Media.t => unit,
  onStalled?: ReactEvent.Media.t => unit,
  onStalledCapture?: ReactEvent.Media.t => unit,
  onSuspend?: ReactEvent.Media.t => unit,
  onSuspendCapture?: ReactEvent.Media.t => unit,
  onTimeUpdate?: ReactEvent.Media.t => unit,
  onTimeUpdateCapture?: ReactEvent.Media.t => unit,
  onVolumeChange?: ReactEvent.Media.t => unit,
  onVolumeChangeCapture?: ReactEvent.Media.t => unit,
  onWaiting?: ReactEvent.Media.t => unit,
  onWaitingCapture?: ReactEvent.Media.t => unit,
  onLoad?: ReactEvent.Image.t => unit,
  onLoadCapture?: ReactEvent.Image.t => unit,
  onAnimationStart?: ReactEvent.Animation.t => unit,
  onAnimationStartCapture?: ReactEvent.Animation.t => unit,
  onAnimationEnd?: ReactEvent.Animation.t => unit,
  onAnimationEndCapture?: ReactEvent.Animation.t => unit,
  onAnimationIteration?: ReactEvent.Animation.t => unit,
  onAnimationIterationCapture?: ReactEvent.Animation.t => unit,
  onTransitionCancel?: ReactEvent.Transition.t => unit,
  onTransitionCancelCapture?: ReactEvent.Transition.t => unit,
  onTransitionRun?: ReactEvent.Transition.t => unit,
  onTransitionRunCapture?: ReactEvent.Transition.t => unit,
  onTransitionStart?: ReactEvent.Transition.t => unit,
  onTransitionStartCapture?: ReactEvent.Transition.t => unit,
  onTransitionEnd?: ReactEvent.Transition.t => unit,
  onTransitionEndCapture?: ReactEvent.Transition.t => unit,
  accentHeight?: string,
  accumulate?: string,
  additive?: string,
  alignmentBaseline?: string,
  allowReorder?: string,
  alphabetic?: string,
  amplitude?: string,
  arabicForm?: string,
  ascent?: string,
  attributeName?: string,
  attributeType?: string,
  autoReverse?: string,
  azimuth?: string,
  baseFrequency?: string,
  baseProfile?: string,
  baselineShift?: string,
  bbox?: string,
  begin?: string,
  bias?: string,
  by?: string,
  calcMode?: string,
  capHeight?: string,
  clip?: string,
  clipPath?: string,
  clipPathUnits?: string,
  clipRule?: string,
  colorInterpolation?: string,
  colorInterpolationFilters?: string,
  colorProfile?: string,
  colorRendering?: string,
  contentScriptType?: string,
  contentStyleType?: string,
  cursor?: string,
  cx?: string,
  cy?: string,
  d?: string,
  decelerate?: string,
  descent?: string,
  diffuseConstant?: string,
  direction?: string,
  display?: string,
  divisor?: string,
  dominantBaseline?: string,
  dur?: string,
  dx?: string,
  dy?: string,
  edgeMode?: string,
  elevation?: string,
  enableBackground?: string,
  end?: string,
  exponent?: string,
  externalResourcesRequired?: string,
  fill?: string,
  fillOpacity?: string,
  fillRule?: string,
  filter?: string,
  filterRes?: string,
  filterUnits?: string,
  floodColor?: string,
  floodOpacity?: string,
  focusable?: string,
  fontFamily?: string,
  fontSize?: string,
  fontSizeAdjust?: string,
  fontStretch?: string,
  fontStyle?: string,
  fontVariant?: string,
  fontWeight?: string,
  fomat?: string,
  from?: string,
  fx?: string,
  fy?: string,
  g1?: string,
  g2?: string,
  glyphName?: string,
  glyphOrientationHorizontal?: string,
  glyphOrientationVertical?: string,
  glyphRef?: string,
  gradientTransform?: string,
  gradientUnits?: string,
  hanging?: string,
  horizAdvX?: string,
  horizOriginX?: string,
  ideographic?: string,
  imageRendering?: string,
  @as("in") in_?: string,
  in2?: string,
  intercept?: string,
  k?: string,
  k1?: string,
  k2?: string,
  k3?: string,
  k4?: string,
  kernelMatrix?: string,
  kernelUnitLength?: string,
  kerning?: string,
  keyPoints?: string,
  keySplines?: string,
  keyTimes?: string,
  lengthAdjust?: string,
  letterSpacing?: string,
  lightingColor?: string,
  limitingConeAngle?: string,
  local?: string,
  markerEnd?: string,
  markerHeight?: string,
  markerMid?: string,
  markerStart?: string,
  markerUnits?: string,
  markerWidth?: string,
  mask?: string,
  maskContentUnits?: string,
  maskUnits?: string,
  mathematical?: string,
  mode?: string,
  numOctaves?: string,
  offset?: string,
  opacity?: string,
  operator?: string,
  order?: string,
  orient?: string,
  orientation?: string,
  origin?: string,
  overflow?: string,
  overflowX?: string,
  overflowY?: string,
  overlinePosition?: string,
  overlineThickness?: string,
  paintOrder?: string,
  panose1?: string,
  pathLength?: string,
  patternContentUnits?: string,
  patternTransform?: string,
  patternUnits?: string,
  pointerEvents?: string,
  points?: string,
  pointsAtX?: string,
  pointsAtY?: string,
  pointsAtZ?: string,
  preserveAlpha?: string,
  preserveAspectRatio?: string,
  primitiveUnits?: string,
  r?: string,
  radius?: string,
  referrerPolicy?: string,
  refX?: string,
  refY?: string,
  renderingIntent?: string,
  repeatCount?: string,
  repeatDur?: string,
  requiredExtensions?: string,
  requiredFeatures?: string,
  restart?: string,
  result?: string,
  rotate?: string,
  rx?: string,
  ry?: string,
  scale?: string,
  seed?: string,
  shapeRendering?: string,
  slope?: string,
  slot?: string,
  spacing?: string,
  specularConstant?: string,
  specularExponent?: string,
  speed?: string,
  spreadMethod?: string,
  startOffset?: string,
  stdDeviation?: string,
  stemh?: string,
  stemv?: string,
  stitchTiles?: string,
  stopColor?: string,
  stopOpacity?: string,
  strikethroughPosition?: string,
  strikethroughThickness?: string,
  string?: string,
  stroke?: string,
  strokeDasharray?: string,
  strokeDashoffset?: string,
  strokeLinecap?: string,
  strokeLinejoin?: string,
  strokeMiterlimit?: string,
  strokeOpacity?: string,
  strokeWidth?: string,
  surfaceScale?: string,
  systemLanguage?: string,
  tableValues?: string,
  targetX?: string,
  targetY?: string,
  textAnchor?: string,
  textDecoration?: string,
  textLength?: string,
  textRendering?: string,
  to?: string,
  transform?: string,
  u1?: string,
  u2?: string,
  underlinePosition?: string,
  underlineThickness?: string,
  unicode?: string,
  unicodeBidi?: string,
  unicodeRange?: string,
  unitsPerEm?: string,
  vAlphabetic?: string,
  vHanging?: string,
  vIdeographic?: string,
  vMathematical?: string,
  values?: string,
  vectorEffect?: string,
  version?: string,
  vertAdvX?: string,
  vertAdvY?: string,
  vertOriginX?: string,
  vertOriginY?: string,
  viewBox?: string,
  viewTarget?: string,
  visibility?: string,
  widths?: string,
  wordSpacing?: string,
  writingMode?: string,
  x?: string,
  x1?: string,
  x2?: string,
  xChannelSelector?: string,
  xHeight?: string,
  xlinkActuate?: string,
  xlinkArcrole?: string,
  xlinkHref?: string,
  xlinkRole?: string,
  xlinkShow?: string,
  xlinkTitle?: string,
  xlinkType?: string,
  xmlns?: string,
  xmlnsXlink?: string,
  xmlBase?: string,
  xmlLang?: string,
  xmlSpace?: string,
  y?: string,
  y1?: string,
  y2?: string,
  yChannelSelector?: string,
  z?: string,
  zoomAndPan?: string,
  about?: string,
  datatype?: string,
  inlist?: string,
  prefix?: string,
  property?: string,
  resource?: string,
  typeof?: string,
  vocab?: string,
  dangerouslySetInnerHTML?: {"__html": string},
  suppressContentEditableWarning?: bool,
}

@variadic @module("react")
external createElement: (string, ~props: domProps=?, array<React.element>) => React.element =
  "createElement"

@variadic @module("react")
external createDOMElementVariadic: (
  string,
  ~props: domProps=?,
  array<React.element>,
) => React.element = "createElement"

external someElement: React.element => option<React.element> = "%identity"

@module("react/jsx-runtime")
external jsx: (string, domProps) => Jsx.element = "jsx"

@module("react/jsx-runtime")
external jsxKeyed: (string, domProps, ~key: string=?, @ignore unit) => Jsx.element = "jsx"

@module("react/jsx-runtime")
external jsxs: (string, domProps) => Jsx.element = "jsxs"

@module("react/jsx-runtime")
external jsxsKeyed: (string, domProps, ~key: string=?, @ignore unit) => Jsx.element = "jsxs"

module Style = ReactDOMStyle
