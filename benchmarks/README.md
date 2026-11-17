# WebAPI feature-isolation experiment

## Unchanged React baselines: no WebAPI

Before any WebAPI migration, the same nine React source modules and unchanged
`rescript.json` from `bb34644ca803e021e7218a8a63b572705df73701` were built with
each compiler. Neither configuration has a WebAPI dependency or feature selection.
The fixture compiler/runtime versions were varied; the React sources were not.

Median wall-clock milliseconds, **five samples per mode**:

| Compiler | WebAPI source modules | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: | ---: |
| ReScript 12.3.1 | 0 | 178.17 | 79.38 | 103.54 |
| ReScript 13.0.0-alpha.7 | 0 | 89.56 | 48.07 | 65.69 |

Raw data: [baseline-12.json](results/baseline-12.json) and
[baseline-13.json](results/baseline-13.json). Both record identical source hashes
and configuration, with `webapi: null` and `features: null`.

These baselines precede the later ten-sample migrated-layout comparison below.
The selected WebAPI layout's recorded clean median (122.27 ms) is higher than
the unchanged v13 baseline (89.56 ms); the separate sessions and sample counts
do not establish a precise migration overhead. The 59-module comparison is
already migrated to WebAPI, **not** the unchanged React baseline.

## Current selection: 15 WebAPI modules

PR #1 now uses **DOMTree + History + Location**, compiling **15 WebAPI source
modules + 9 React modules = 24**. Its dependency is pinned to WebAPI commit
`81ac4eebeae3ff0cc9118e7b4b62323e3cee9729` in
[WebAPI PR #415](https://github.com/rescript-lang/experimental-rescript-webapi/pull/415).
Basic DOM and the seven CSS declaration modules remain unchanged from the
original library; the feature boundaries select only the needed groups.

See [selective-dom-report.md](selective-dom-report.md) for the primary comparison,
raw data, tradeoffs, and reproduction instructions. Median clean builds in the
final ten-sample comparison were 196.98 ms for the migrated 59-module selection,
121.48 ms for the six-module consolidation, and 122.27 ms for the selected
15-module layout. The reduced layouts are effectively tied at this sample size.

PR #2 retains only the separate JsxDOM props/ref removal on top of this base.
The six-module investigation below is preserved as historical evidence, not the
current implementation or a new measurement of the follow-up.

## Earlier six-module consolidation (superseded)

The earlier version of PR #1 included the core type consolidation, using
[WebAPI PR #415](https://github.com/rescript-lang/experimental-rescript-webapi/pull/415)
stacked on the History/Location work in #413. React selected **DOM + History +
Location**, compiling **6 WebAPI source modules + 9 React source modules = 15**.
The existing JsxDOM/JsxDOMStyle/JsxEvent aliases remain in this base PR.

WebAPI commit `acf8d6ce07341d5c6c98027b43ac5aaaaf68fac8` moves the concrete element,
DOM-tree, stylesheet, and supporting collection/style representations into DOM.
Existing API modules retain representation-preserving aliases and their methods.
No fields, privacy restrictions, or existing type identities were deliberately
changed. The two slot-assignment variants remain distinct, and a regression test
preserves unannotated `DOM.Manual`/`DOM.Named` inference.

### Fresh same-session comparison

Median wall-clock milliseconds, five runs per mode:

| Configuration | WebAPI modules | Clean | Cached no-op | Edit |
| --- | ---: | ---: | ---: | ---: |
| #413 library + original React selection | 59 | 182.26 | 49.43 | 75.20 |
| Core candidate + unchanged React source/selection | 59 | 215.19 | 51.91 | 75.00 |
| Core candidate + core-only React selection | **6** | **145.13** | **51.87** | **70.78** |
| Core candidate + unrestricted WebAPI | 338 | 654.73 | 72.11 | 96.19 |

The core-only clean median is **20.4% lower** than the fresh 59-module baseline.
Cached and edited-build ranges overlap; do not claim a reliable improvement there.
The counterfactual 59-module candidate is slower, showing that moving records
alone is not an optimization unless consumers can drop the operation features.

Baseline WebAPI is `625b8687db9f30cd4510584e641bb5718361610f`; baseline React is
`e549ebf4bdd9a3a2da240d077173dc6706bb9ebc`. The candidate measurements were captured
before committing the WebAPI change and match the sources now in `acf8d6ce`.
The recorded fingerprints are:

- Baseline: `cd3405819664af46c4dcbe517a0a5be38f1c3cab9db3ee516cb4ac1cebb08fee`
- Candidate: `0e182d9fc11aa09a8435100e8b855d1f8e10936cf514418c1f81db4e1c456972`

Raw timings, ranges, logs, configurations, source hashes and compiled-module
inventories are in `results/core-baseline-59.json`,
`results/core-candidate-59.json`, `results/core-candidate-6.json`, and
`results/core-candidate-all.json`.

### Cost to other core consumers

The shared core is larger: its source grew from roughly 1,030 to 4,561 lines,
including the existing 425-field style-declaration record. Separate tiny
non-React consumers show a real cost:

| Probe | WebAPI modules before/after | Clean before | Clean after | Change |
| --- | ---: | ---: | ---: | ---: |
| DOM | 3 / 3 | 85.84 ms | 112.51 ms | +31.1% |
| Location | 4 / 4 | 81.88 ms | 108.37 ms | +32.4% |
| URL | 6 / 6 | 79.74 ms | 104.07 ms | +30.5% |
| Fetch | 36 / 36 | 114.60 ms | 146.15 ms | +27.5% |

These are five-run medians, not a universal compiler performance claim. The
absolute clean overhead was approximately **24–32 ms**. Raw data for clean,
cached, and edited builds is preserved in `results/core-probe-*-before.json`
and `results/core-probe-*-after.json`. This cost motivated the later selective
layout instead of adopting the consolidated core.

### Reproduce the core comparison

Use separate local WebAPI folders at the baseline and candidate revisions:

```sh
python3 benchmarks/builds.py core-before-repeat --compiler 13 \
  --source-ref e549ebf4bdd9a3a2da240d077173dc6706bb9ebc \
  --webapi /path/to/webapi-before \
  --feature WebAPI.DOMNodes --feature WebAPI.History --feature WebAPI.Location
python3 benchmarks/builds.py core-after-repeat --compiler 13 \
  --source-ref 6be1cf10cd6445c5a1047c8b76c53e80a258cf9f \
  --webapi /path/to/webapi-after \
  --feature WebAPI.DOM --feature WebAPI.History --feature WebAPI.Location
python3 benchmarks/builds.py core-dom-probe-repeat --compiler 13 \
  --probe dom --webapi /path/to/webapi-after --feature WebAPI.DOM
```

Probe choices are `dom`, `location`, `url`, `fetch`, and `cssom`. For a source archive
rather than a Git checkout, add `--webapi-source-ref <commit>` to record its
provenance. The harness refuses to mistake an enclosing repository's HEAD for
the WebAPI revision. Every run also fingerprints the actual source inputs.

### Core reduction validation

- Standalone DOM builds with three sources; the React core selection builds with six.
- All 30 WebAPI features and the broad re-export consumers compile.
- Positive fixtures cover recursive fields, all moved record families, generic
  collections, aliases in both directions, mutation and variant re-exports.
- Negative fixtures retain private-record restrictions and distinct nominal variants.
- WebAPI runtime tests, packed consumers, all four Chromium browser tests,
  formatting, documentation build, and documentation-link checks passed.
- All 338 emitted WebAPI JavaScript files match the pre-migration output exactly.
- React's consumer checks reject Element, Node, DOMTree, CSSStyleDeclaration,
  Window, Document and OffscreenCanvas under the core-only selection; opting
  into their features restores them and preserves interoperability.
- Static review's constructor-inference finding was reproduced, fixed, and covered
  by a regression fixture. Live editor interaction was not manually verified.

The fresh measurements add 60 React-build samples and 120 standalone-probe samples.
All are separate from the historical measurements below.

## Earlier History/Location-only setup

Before the core reduction, React selected **DOMNodes + History + Location**, rather than Window.
The profiling runs linked WebAPI from `/home/josh/Dev/experimental-rescript-webapi`.
Its changes were developed on **`feat/isolate-history-location`**, created directly from
fetched `origin/main` at `4888db2cc601ad568b76af6ed2add60da0ad96cb`.
The changes are published in [WebAPI PR #413](https://github.com/rescript-lang/experimental-rescript-webapi/pull/413),
targeting main. The feature split is commit `9430c006`; compiler-required formatter
normalization is a separate commit, `c469e565`. A subsequent documentation renderer
compatibility fix is commit `625b8687`. Nothing was merged into main.

This base change migrates explicit built-in `Dom` types only. It deliberately
retains the `JsxDOM`, `JsxDOMStyle`, and `JsxEvent` aliases. The separate follow-up
removes `JsxDOM`; none of the numbers here measure that follow-up.

For the first version of this PR, `package.json` pinned the public WebAPI
archive at `625b8687db9f30cd4510584e641bb5718361610f`; it now pins the core candidate.
Neither pin is a claim that
the historical timings used an archive: every WebAPI benchmark below used a
local folder link, with the exact measured source state recorded separately.

The checkout originally used `feat/safe-fetch` at
`eb25639f8de1cb3051151caa7eeb4f63efa57d08`. Its pre-port edits were preserved in
a stash named `Backup History Location feature split before moving from feat/safe-fetch to main`.
The original branch and local main were not moved.

Both projects use **ReScript 13.0.0-alpha.7**. WebAPI's peer range is now
`>=13.0.0-alpha.7 <13.0.0`, preserving main's prerelease-only upper bound.

## History/Location-only measurements (preserved)

Median wall-clock milliseconds, **five runs per cell** (minimum–maximum):

| ReScript 13 configuration | Clean | Cached no-op | Single-file edit |
| --- | ---: | ---: | ---: |
| Unrestricted WebAPI | 545.71 (465.71–581.03) | 64.91 (61.85–75.21) | 92.95 (90.01–104.42) |
| WebAPI.Window | 352.47 (320.63–418.42) | 64.72 (61.05–66.20) | 89.21 (80.52–106.13) |
| DOMNodes + History + Location | **207.36 (152.00–234.90)** | **51.62 (44.71–59.35)** | **76.80 (67.14–81.94)** |

The narrow selection reduced the clean-build median by **41.2% versus Window**
and **62.0% versus unrestricted WebAPI** in this run. Incremental medians improved,
but edit ranges overlap; these small laptop samples are not a general compiler
performance guarantee.

| Selection | WebAPI source modules | React source modules | WebAPI feature directories |
| --- | ---: | ---: | ---: |
| Unrestricted | 338 | 9 | 30 |
| Window | 229 | 9 | 20 |
| Narrow | **59** | 9 | **9** |

The narrow selection compiled only core, event, dom-platform, animation, geometry,
cssom, dom-nodes, history, and location. It did not compile Window or Document API
modules. Core DOM still supplies their shared types.

The final three scenarios have identical React source hashes and the same WebAPI
input fingerprint. These timings were captured before the separate formatter commit;
their source state corresponds to feature-split commit `9430c006`, not the formatted PR tip:

```text
4bba5c056db7f584fee2882743cac3ad3626d2251ee1f0944db30a0a4ae8cb06
```

The fingerprint hashes a sorted mapping of WebAPI `.res`/`.resi` source paths and
content hashes, plus `rescript.json`, `package.json`, and `package-lock.json`.
It distinguishes the uncommitted source state from its base commit and detects
source/config changes during timing.

Raw measurements, compiler logs, configurations, and unique compiled-module
inventories are in:

- `results/main-split-all.json`
- `results/main-split-window.json`
- `results/main-split-narrow.json`

The inventories include one extra generated namespace `.cmj`; the table counts
only source modules. The older `artifacts` field counts both `lib/bs` and
`lib/ocaml` copies and should not be read as a unique module count.

## Preserved earlier measurements

The unchanged React baselines were captured **before any source migration**:

| Compiler | Clean median | Cached median | Edit median |
| --- | ---: | ---: | ---: |
| ReScript 12.3.1 | 178.17 ms | 79.38 ms | 103.54 ms |
| ReScript 13.0.0-alpha.7 | 89.56 ms | 48.07 ms | 65.69 ms |

These remain in `results/baseline-12.json` and `results/baseline-13.json`.
The initial unrestricted/Window comparison is preserved in `results/webapi-*.json`
and [initial-results.md](initial-results.md).

An intermediate split experiment on the older `feat/safe-fetch` base is preserved
in `results/split-{all,window,narrow}.json`:

| Older-base split selection | Clean median | Cached median | Edit median |
| --- | ---: | ---: | ---: |
| Unrestricted | 416.53 ms | 69.11 ms | 91.16 ms |
| Window | 330.21 ms | 63.23 ms | 88.48 ms |
| Narrow | 172.14 ms | 52.13 ms | 76.93 ms |

These are historical, not the final branch results. Main contains additional API
changes and a separate SafeFetch feature, so its full/Window module counts differ
from the initial 339/231 counts. Do not attribute differences between sessions or
source revisions solely to this split; use the same-input final comparison above.

## Implementation

WebAPI gained two source-owning public features:

```json
{
  "WebAPI.History": ["History"],
  "WebAPI.Location": ["WebAPI.DOM", "Location"]
}
```

- `History.res` and `HistoryTypes.res` moved from `src/window` to `src/history`.
- `Location.res` moved from `src/window` to `src/location`.
- All three files are byte-identical to their versions on main. Public module
  names and type identities, including main's `WebAPI.History.t`, are preserved.
- Window includes both new features, keeping existing Window consumers working.
- Feature ownership checks and tests cover the new modules. Main already had a
  dynamic feature-count diagnostic; its SafeFetch feature is retained.
- Compiler, peer range, packed-consumer checks, and compiler-baseline docs were
  aligned with alpha.7. The packed check now reads its compiler from the manifest.
- One existing ImageData compile test needed an explicit
  `Uint8ClampedArray.t` to `TypedArray.t<int>` coercion under alpha.7. No binding
  semantics or runtime assertion was changed.

React's production bindings did not need another type migration for this split:

```json
{
  "dependencies": [
    {
      "name": "@rescript/webapi",
      "features": ["WebAPI.DOMNodes", "WebAPI.History", "WebAPI.Location"]
    }
  ]
}
```

DOMNodes already includes DOM transitively. Element/DOMTree isolation and changes
to History's JSON state typing remain outside this experiment's scope.

## Reproduce

### Install and reproduce the WebAPI source state

The project installs an exact public WebAPI commit, not a machine-specific path:

```sh
npm install --ignore-scripts --no-audit --no-fund
```

For a new profiling run, pass your local WebAPI checkout to `--webapi` as shown
below. The harness links that folder directly and never substitutes the installed
archive for the linked benchmark dependency.

To reproduce the recorded main-based source state exactly, use a separate WebAPI
checkout at commit `9430c006` from PR #413 and install its dependencies. This
deliberately excludes the later formatter/documentation commits. The source-input
fingerprint above identifies the measured files. Do not switch a shared checkout
that has someone else's uncommitted work.

To use a local WebAPI link for ordinary development without changing the committed
archive pin or lockfile:

```sh
npm install --no-save --package-lock=false /path/to/experimental-rescript-webapi
```

Reinstall from the lockfile to restore the portable dependency. Neither install
mode needs `--legacy-peer-deps`.

### Run benchmarks from rescript-react

Choose unused scenario names; existing fixtures are never overwritten.

```sh
python3 benchmarks/builds.py main-all-repeat --compiler 13 \
  --webapi /path/to/experimental-rescript-webapi --features all
python3 benchmarks/builds.py main-window-repeat --compiler 13 \
  --webapi /path/to/experimental-rescript-webapi --feature WebAPI.Window
python3 benchmarks/builds.py main-narrow-repeat --compiler 13 \
  --webapi /path/to/experimental-rescript-webapi \
  --feature WebAPI.DOMNodes --feature WebAPI.History --feature WebAPI.Location
```

**The legacy `--features limited` preset still means `WebAPI.Window`.** It is
retained for historical reproduction and does not copy the root's current feature
selection. Use repeated `--feature` options for the narrow experiment.

Historical baselines can be reproduced without reverting current sources:

```sh
python3 benchmarks/builds.py baseline-12-repeat --compiler 12 \
  --source-ref bb34644ca803e021e7218a8a63b572705df73701
python3 benchmarks/builds.py baseline-13-repeat --compiler 13 \
  --source-ref bb34644ca803e021e7218a8a63b572705df73701
```

## Measurement method

- Intel Core Ultra 7 355, eight logical CPUs, x86-64 Linux `7.2.9-1-MANJARO`;
  Node 24.16.0 and npm 11.15.0.
- Exact compiler/runtime versions in separate fixtures under
  `node_modules/.webapi-benchmark`; React and React DOM 19.2.0.
- Direct `rescript build` wall-clock time includes CLI/process startup, but not
  npm installation, cleanup, or the npm script wrapper.
- One untimed warm-up, followed by five clean/cached/edit rounds per scenario.
- Each clean removes React and linked WebAPI compiler artifacts, with an explicit
  check that no WebAPI `.cmj` remains. OS page caches are **not** flushed, and
  precompiled compiler/runtime libraries remain installed.
- The edit appends `let benchmarkIteration = <round>` to a fixture copy of
  `ReactDOMStyle.res`, forcing a source/interface change; original source is restored.
- Every cached sample compiled zero modules. Every edit sample parsed one source
  and compiled two modules. Clean counts match the inventories plus nine React modules.
- Runs were sequential, not randomized, without CPU affinity, power controls, or
  isolation from ordinary laptop activity. Each final scenario has five samples
  per mode; all **45 final measured builds and three warm-ups** succeeded.
- The local WebAPI symlink is real: builds clean/write its compiler artifacts.
  Do not run another build against that checkout concurrently.

## Validation

On the final main-based WebAPI branch:

- `npm run check:features`: seven validator tests, clean builds of all **30**
  feature bundles, and existing SafeFetch consumer isolation checks passed.
- `npm test`: full test compilation and all seven configured Node runtime fixtures passed.
- `npm run check:consumer`: packed-package consumers, runtime check, unsupported
  compiler rejection, and all negative binding fixtures passed.
- Targeted ReScript and Oxfmt formatting checks passed for the changed/moved files.
- `git diff --check` passed.

In rescript-react:

- Normal `npm install` without legacy peer bypass and root clean/build passed.
- `python3 benchmarks/check-consumer.py` verifies narrow interoperability, rejection
  of Window/Document/OffscreenCanvas, explicit feature re-enablement, restoration
  of the narrow artifact inventory, and compatibility of a broader Window consumer.
- `Interop.res` intentionally avoids Document and Window API modules;
  `WindowInterop.res` exercises them only when Window is explicitly selected.
- A consumer naming WebAPI directly must declare it directly. An unrestricted
  direct dependency enables all features again; React's selection is not an upper bound.
- Final sample logs, identical input hashes, and byte-identical source moves were checked.
- Benchmark syntax, feature selection, CLI failure cases, and complete patch replay were checked.
- Static agent review found no actionable correctness issue on the final branch.

Before opening PR #413, the full `npm run format:check` identified formatting changes
required by alpha.7 in 40 files. These were applied in a separate formatting commit,
then `npm run format:check`, `npm run check:features`, `npm test`, and
`npm run check:consumer` all passed again. The existing benchmark files were not
rewritten to claim they measured that later source snapshot.

The initial PR CI passed its browser step, then exposed an alpha.7 documentation
metadata incompatibility. Commit `625b8687` unwraps parameter type metadata for
linked signatures and retains the complete compiler-rendered signature as the
fallback for unsupported detail shapes. Local `npm run build:docs` then built
307 pages, and `npm run check:docs-links` passed 38 tests and validated 675 built files.

The browser suite was not run locally. No package publishing or landing was performed.
