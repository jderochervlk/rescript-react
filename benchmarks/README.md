# WebAPI feature-isolation experiment

## Final setup

React now selects **DOMNodes + History + Location**, rather than Window.
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

For portable installation and PR review, `package.json` pins the public WebAPI
archive at `625b8687db9f30cd4510584e641bb5718361610f`. That pin is not a claim that
the historical timings used an archive: every WebAPI benchmark below used a
local folder link, with the exact measured source state recorded separately.

The checkout originally used `feat/safe-fetch` at
`eb25639f8de1cb3051151caa7eeb4f63efa57d08`. Its pre-port edits were preserved in
a stash named `Backup History Location feature split before moving from feat/safe-fetch to main`.
The original branch and local main were not moved.

Both projects use **ReScript 13.0.0-alpha.7**. WebAPI's peer range is now
`>=13.0.0-alpha.7 <13.0.0`, preserving main's prerelease-only upper bound.

## Final measurements on main-based WebAPI

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
