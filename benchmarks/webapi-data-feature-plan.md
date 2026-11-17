# Plan: narrow WebAPI data features for React

Status: implemented upstream in [WebAPI PR #416](https://github.com/rescript-lang/experimental-rescript-webapi/pull/416),
reviewed at `691bc3f20dc5d621d22f5bf9931b4ec086542d5f`. The feature-consumer
checks confirm the 27-source target. The original design and acceptance plan
below are preserved; actual profiling results are recorded separately.

## Goal and branch placement

Replace the remaining React clipboard/touch open-object getters and local
FormData type with interoperable WebAPI types, without selecting all UIEvents
or Fetch and without enlarging basic DOM.

WebAPI #413 is now merged. #415 is open against main and contains the selected
DOMTree/CSSOMCore layout. Start a **new follow-up branch and PR based on #415**,
not a rewrite of #413 or a replacement of #415. The inspected #415 head is
`5cf8acf56380618a2bbe27ec7531ba75476eb9ec`; its relevant source/configuration
matches React's pin `81ac4eebeae3ff0cc9118e7b4b62323e3cee9729`.
Recheck branch state at implementation time; if #415 has merged, branch from
updated main instead.

After the upstream work is approved and validated, update React PR #1's pin
and remaining bindings, then carry that base into PR #2 through an ordinary
merge. Keep JsxDOM ownership in PR #2, not in this upstream split.

## Recommended architecture

Add four public features. Prefer existing public API modules as canonical type
owners when their dependency graph is acyclic. Keep internal legacy type paths
as representation-preserving aliases; do not duplicate nominal record types.

| New feature | Source modules it owns | Dependencies |
| --- | --- | --- |
| `WebAPI.Touch` | Touch, TouchList | DOM |
| `WebAPI.FormData` | FormData, FormDataEntryValue | DOM |
| `WebAPI.FileEntries` | BaseFileAndDirectoryEntries, FileAndDirectoryEntriesTypes, FileSystemEntry, FileSystemDirectoryEntry, FileSystemDirectoryReader | DOM |
| `WebAPI.DataTransfer` | DataTransfer, DataTransferItem, DataTransferItemList | DOMTree, FileEntries |

The two file-entry backing modules remain internal. The other modules retain
their existing public names; new feature names are additive.

Existing broad features become compatibility umbrellas:

- UIEvents includes Touch and DataTransfer and keeps its other dependencies.
- Fetch includes FormData and keeps its other dependencies.
- File includes FileEntries and keeps its other dependencies.
- No existing public feature loses a module or an operation.

There are no new `.res` backing-holder modules in this proposal: existing files
move between source groups, and the exact small representations move from
UiEventsTypes/FetchTypes into the relevant public modules. This is not another
large type-record consolidation.

### 1. Touch: two modules

Move Touch and TouchList to `src/touch`.

- Touch owns the existing private touch record, touch initializer, and the
  `Direct`/`Stylus` touch-type variant. Give the initializer a public name such
  as `Touch.init`, preserving its current fields and mutability.
- TouchList owns its existing private length-only record; `item` returns
  `Null.t<Touch.t>`.
- UiEventsTypes re-exports the exact touch, touchList, touchInit, and touchType
  representations and constructors. TouchEvent remains in UIEvents.
- Preserve all coordinates as floats and the target as DOM.eventTarget.

Dependency direction: TouchList → Touch → DOM. Neither narrow module may
reference UiEventsTypes; otherwise the broad dependency returns.

### 2. FormData: two modules

Move FormData and FormDataEntryValue to `src/form-data`.

- FormData owns the existing private empty-record representation.
- FormDataEntryValue owns the existing **unboxed** String/File variant. Its
  File payload uses DOM.file, which is already the canonical identity behind
  FileTypes.file and File.t.
- FormData's Blob overload signatures use DOM.blob instead of the equal
  Blob.t alias. This avoids selecting Blob operations and the entire File
  feature just to mention a Blob type.
- FetchTypes re-exports formData and the unboxed entry-value representation,
  including its constructors and completion metadata.
- Retain FormData's existing methods, labels, FFI names, exception annotations,
  null returns, and iterable return types.

Dependency direction: FormData → FormDataEntryValue → DOM. Neither narrow
module may reference FetchTypes, FileTypes, Blob, Request, or Response.

Broad consumers must still accept FormData through BodyInit.fromFormData,
Request/Response form-data APIs, and Navigator.sendBeacon5.

### 3. File entries: preserve the legacy dependency honestly

Move the five file-entry modules listed above unchanged to `src/file-entries`.
They depend on DOM but not on FileTypes, streams, FileSystemHandle operations,
or Event operations.

This is needed because DataTransferItem exposes `webkitGetAsEntry`. Removing
that method, weakening its return type, or exposing only a partial module
would be a compatibility regression. Selecting a small intact FileEntries
feature preserves the method and useful operations on its returned entries.

Keep BaseFileAndDirectoryEntries' recursive records, privacy, field order,
and completion owners unchanged. This is a file move, not a type redesign.

### 4. DataTransfer: three modules

Move DataTransfer, DataTransferItem, and DataTransferItemList to
`src/data-transfer`.

- Each public module owns its existing record representation.
- UiEventsTypes re-exports those representations so InputEvent and other
  broader event types remain interoperable.
- Replace FileTypes.file references in method signatures with the equal
  DOM.file type. DataTransfer.files already uses DOM.fileList.
- Keep DataTransfer.setDragImage's DOMTree.element signature. React already
  selects DOMTree; do not weaken it to a generic value to reduce dependencies.
- Keep DataTransferItem.webkitGetAsEntry and its precise nullable entry type.
- Preserve DataTransfer's currently non-private record and mutable fields;
  preserve the private item and item-list records.

The acyclic direction is DataTransfer → DataTransferItemList →
DataTransferItem → FileEntries, plus DOM/DOMTree as needed. No narrow module
may reference UiEventsTypes or FileTypes.

## Expected module counts

Static estimates, excluding generated namespace artifacts:

| React dependency selection | WebAPI source modules |
| --- | ---: |
| Current DOMTree + History + Location | 15 |
| Current + proposed Touch | 17 |
| Current + proposed FormData | 17 |
| Current + proposed DataTransfer (includes FileEntries) | 23 |
| Current + all three required data features | **27** |
| Current + existing UIEvents + Fetch instead | **102** |

The full proposed selection is 27 WebAPI + 9 React = **36 source modules**.
The extra twelve WebAPI modules are two touch, two form-data, three transfer,
and five file-entry modules. Dependencies on DOM and DOMTree are already paid
for by React and are counted only once.

Standalone Touch and FormData each target five sources including basic DOM.
Basic DOM itself remains the same three sources with **byte-identical DOM.res**.
Existing broad feature inventories should retain the same module sets: the
proposal moves modules rather than adding duplicate implementations.

These are design targets, not a promise of faster builds. Canonical public
owners avoid extra backing layers, but declaration/alias work still has a cost.

### File-list operations are a separate opt-in

The 27-module target gives DataTransfer.files its existing DOM.fileList type,
but does **not** select the FileList operation module. Consumers can already
read its length, but FileList.item still requires today's broader File feature.

If standalone file-list iteration is required, also split `WebAPI.FileList`
as a one-module feature depending only on DOM, with its item result referring
to the equal DOM.file type. Have File retain it transitively. Including that
feature in DataTransfer would make the combined React target **28**, not 27.
Keep this as an explicit optional addition rather than claiming that the
27-module plan includes all file operations.

## Compatibility rules

- Preserve public module names, nominal type equality, constructor paths,
  record field order, private/public distinctions, mutability, optionality,
  `@as`, `@unboxed`, `@throws`, and nullable results.
- Use representation-preserving re-exports, not fresh lookalike records.
- Keep UiEventsTypes and FetchTypes compatibility declarations in their
  existing order where constructor inference could depend on it.
- Preserve completion annotations on both canonical declarations and any
  immediate backing aliases inspected by the feature checker.
- Do not move UIEvent, TouchEvent, InputEvent, FileTypes, or FetchTypes wholesale.
- Do not add the new records to DOM or introduce a types-only copy that needs
  casts to use existing operations.
- Keep unrelated binding corrections separate, including FormData's generic
  constructor parameters and React's existing string-plus-filename overloads.

## React integration after the upstream split

In PR #1:

1. Add Touch, DataTransfer, and FormData to the existing feature selection.
2. Type clipboardData as `option<WebAPI.DataTransfer.t>` with nullable
   conversion. Script-created clipboard events may have no data transfer.
3. Type changedTouches, targetTouches, and touches as WebAPI.TouchList.t.
   Lists are non-null; an out-of-range item is nullable.
4. Alias ReactDOM.FormData.t to WebAPI.FormData.t. Keep the React wrapper and
   existing public helper names rather than including WebAPI.FormData wholesale.
5. Preserve React's **boxed** `String`/`File` formValue variant. If helpers use
   WebAPI's typed entry values internally, explicitly convert between the
   unboxed WebAPI union and that boxed React result. Never alias those variants.
6. Check form-action and form-status flows, including passing form data to a
   WebAPI consumer and back, without casts.

PR #2 inherits the new types and dependency pin. Its JsxDOM ownership changes
remain separate; JsxDOMStyle and JsxEvent ownership remain out of this plan.

## Validation and acceptance gates

### Upstream

- Add the four feature owners/source groups to rescript.json and the feature
  checker. Add narrow packed-consumer fixtures, not just local linked builds.
- Verify each feature independently and all combinations. Narrow consumers
  must reject UIEvent/TouchEvent/InputEvent, Fetch/Request/Response, Window,
  and unrelated File/stream operations until explicitly selected.
- Verify broad-feature consumers still compile, including InputEvent's data
  transfer, TouchEvent's lists/constructors, File entry callbacks, and the
  Fetch/Navigator FormData paths.
- Check bidirectional alias assignment, legacy variant constructors, private
  record rejection, mutable transfer fields, nullable list/file/entry results,
  and unboxed FormData entry-value emission.
- Exercise FormData string/file reads and Blob overloads with real platform
  values. Exercise DataTransfer and touch objects in the browser; feature-detect
  Touch construction and report unsupported browser cases explicitly.
- Run build, check:features, test, check:consumer, test:browser, format:check,
  build:docs, and check:docs-links. Inspect runtime output differences and
  explicitly verify live completion where practical; retaining metadata alone
  is not editor validation.

### React and performance

- Extend the existing consumer tests for nullable clipboard data, touch-list
  access, File interop, FormData action/status interop, negative assumptions,
  and recovery to the exact narrow inventory after broad-feature checks.
- Run the PR #2 JsxDOM-free compilation and JSX/SSR regression checks again.
- Benchmark sequentially with equivalent private local WebAPI snapshots,
  identical compiler/runtime pins, untimed setup/warm-up, and reversed order
  across two five-run blocks. Capture ten clean/cached/edit samples per case.
- Compare **new narrow features versus broad UIEvents+Fetch using identical
  migrated React sources**. This isolates feature selection from API changes.
- Include a fresh current 15-module React control. It still has placeholders,
  so label it as the pre-integration control rather than an equivalent API.
- Refresh unchanged v12/v13 controls if presenting a single end-to-end timing
  table; never mix historical and new sessions without labeling the difference.
- Refresh PR #2's before/after comparison on the same new base. Record source
  revisions, fingerprints, timestamps, ranges, and actual compiled inventory.

Acceptance requires correct interoperability and a genuinely narrow dependency
closure. If timings regress materially, investigate before adoption; do not
declare success from the module count alone.

## Alternatives considered

- **Enable today's broad groups:** least implementation work, but 102 WebAPI
  sources for React and substantial unrelated operations.
- **Move backing groups into DOM:** rejected; repeats the earlier shared-core
  payload regression.
- **Create several new backing-only modules:** viable fallback if compilation
  reveals a genuine ownership cycle, but adds modules and alias layers without
  a demonstrated need in the inspected graph.
- **Split only file-entry backing records:** could save a few modules, but
  adds an extra low-level feature and leaves returned entries without their
  operation modules. Start with the five intact modules instead.
- **Drop or weaken legacy transfer methods:** rejected; narrows the module by
  breaking its API rather than isolating its dependencies.

The original planning turn changed no upstream sources, pins, or PRs.
Implementation followed approval on a new branch from updated main, with the
unmerged #415 prerequisite merged into it and #416 stacked on #415.

## Source evidence

Inspected against React's pinned source and the matching #415 source:

- [Touch and TouchList representations](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/ui-events/UiEventsTypes.res#L311-L377),
  and [TouchList.item](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/ui-events/TouchList.res#L1-L7).
- [DataTransfer records](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/ui-events/UiEventsTypes.res#L50-L122),
  [setDragImage](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/ui-events/DataTransfer.res#L9-L20),
  and [webkitGetAsEntry](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/ui-events/DataTransferItem.res#L17-L23).
- [Legacy file-entry recursive records](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/file/BaseFileAndDirectoryEntries.res#L6-L70)
  and [callback/type holder](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/file/FileAndDirectoryEntriesTypes.res#L6-L35).
- [FormData's current public module](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/fetch/FormData.res#L1-L24)
  and [unboxed entry-value re-export](https://github.com/rescript-lang/experimental-rescript-webapi/blob/81ac4eebeae3ff0cc9118e7b4b62323e3cee9729/src/fetch/FormDataEntryValue.res#L1-L2).
