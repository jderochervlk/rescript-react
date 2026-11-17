# Core-backed placeholder types

PR #1 now strengthens the following existing bindings without adding WebAPI
features. The selection remains DOMTree + History + Location: **15 WebAPI
source modules**, plus nine React source modules.

| React API | New return type |
| --- | --- |
| All event families and Synthetic: `nativeEvent` | `WebAPI.DOM.event` |
| All event families and Synthetic: `target` | `WebAPI.DOM.eventTarget` |
| All event families and Synthetic: `currentTarget` | `option<WebAPI.DOM.eventTarget>` |
| Focus, Mouse, Pointer: `relatedTarget` | `option<WebAPI.DOM.eventTarget>` |
| UI, Pointer: `view` | `option<WebAPI.DOM.window>` |
| `ReactDOM.FormData.file` | Alias of `WebAPI.DOM.file` |

These are deliberate public type changes from open objects or opaque local
types. Synthetic event tags remain React-specific; a synthetic event is not
itself a native DOM event.

## Migration and nullability

- `target` is an EventTarget, not necessarily an Element. Do not assume it has
  element-specific fields. Open-object `event->ReactEvent.Mouse.target##value`
  access no longer type-checks; use a suitably typed DOM binding and runtime
  narrowing for the concrete target instead of an unchecked identity cast.
- React clears `currentTarget` after each handler, even after `persist()`.
  Match `Some(target)` / `None` before using it, and capture a present target
  inside the handler if it is needed later.
- Native UI events can have a null `view`. React also forwards ordinary scroll
  events that have no `view` property. Both null and undefined become `None`.
- Related targets keep their existing option shape, but now carry EventTarget.
- `FormData.getFile` and the existing boxed `String`/`File` form-value variants
  keep their behavior. Returned files now expose the WebAPI file fields.
  Selecting `WebAPI.File` in a consumer also enables file operations without
  conversions: `WebAPI.File.t` and this core type have the same identity.
- DOM event operations require the consumer to select `WebAPI.Event` (or a
  feature that includes it). Merely returning the core event type does not
  automatically enable those operations.

## Deliberately deferred placeholders

The current WebAPI pin does not isolate all the required types into small public
features. Static source-module counts for adding its existing features are:

| Remaining API | Public WebAPI replacement | Required feature | Total WebAPI sources |
| --- | --- | --- | ---: |
| Clipboard `clipboardData` | `option<WebAPI.DataTransfer.t>` | UIEvents | 90 |
| Touch `changedTouches`, `targetTouches`, `touches` | `WebAPI.TouchList.t` | UIEvents | 90 |
| Local `FormData.t` | `WebAPI.FormData.t` | Fetch | 48 |
| Both groups | Both of the above | UIEvents + Fetch | 102 |

These counts include the existing 15-module selection and were calculated from
the pinned feature graph, not measured as new build timings. A focused upstream
feature split is preferable to silently broadening PR #1's dependency selection.
The remaining TODO getters stay unchanged until that scope is agreed.

The full FormData module is not a drop-in replacement: WebAPI uses an unboxed
string/file union, different argument labels, and raw null returns. React's
current wrapper and form-action/status type identities remain intact.
The existing string-plus-filename `append`/`set` overloads also deserve a
separate correction; the filename overload belongs to Blob values.

Intentional abstractions such as a React root, a postponed SSR state, and
`domElementToObj`'s explicit object escape hatch are not missing DOM types.
No relevant incorrect WebAPI file/list declarations were found. One API
limitation is that Event/EventTarget and several UI-event operation modules have
no public `t` alias; use the actual core types, not invented paths.

## Evidence and benchmark scope

`python3 benchmarks/check-consumer.py` checks the shared event contract across
every event family, core and public File alias interoperability, rejected
Element/currentTarget/view/private-file assumptions, and preservation of the
15-module inventory. Its Node assertions exercise getter identity, nullable
conversion, and native FormData/File values; they do not simulate real React
browser dispatch.

Previously recorded profiling results remain measurements of their exact
recorded source revisions, **before this additional type strengthening**.
No benchmark result has been relabeled as measuring these newer sources.
