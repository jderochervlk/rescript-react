# WebAPI build experiment

This is the archived report from the first experiment, before the History/Location
split and before moving WebAPI to a branch based on current main. References below
to the current setup describe that historical state. See [README.md](README.md)
for the final branch, configuration, measurements, and validation.

## Results

Measured on November 16, 2026. The first two rows were captured before changing
any React sources or package configuration, at React commit
`bb34644ca803e021e7218a8a63b572705df73701`. Versions were resolved from npm's
`latest` and `next-13` tags. The WebAPI rows use identical migrated source files.

Wall-clock milliseconds, **median of five runs** (minimum–maximum):

| Configuration | Clean | Cached no-op | Single-file edit |
| --- | ---: | ---: | ---: |
| ReScript 12.3.1, unchanged | 178.17 (142.23–223.88) | 79.38 (60.07–99.51) | 103.54 (84.14–330.95) |
| ReScript 13.0.0-alpha.7, unchanged | 89.56 (86.86–109.04) | 48.07 (36.65–50.16) | 65.69 (57.01–79.21) |
| ReScript 13.0.0-alpha.7 + all WebAPI | 594.29 (573.00–611.64) | 75.87 (70.41–83.67) | 111.46 (104.55–147.64) |
| ReScript 13.0.0-alpha.7 + WebAPI.Window | 413.95 (323.50–470.86) | 62.47 (60.74–69.40) | 105.62 (81.98–116.34) |

In this small sample, version 13's median is 49.7% lower for clean builds,
39.4% lower for cached builds, and 36.6% lower for edit rebuilds. This is a local
measurement, not a general compiler performance claim; the laptop was not
isolated from other processes, and version 12 had a substantial edit outlier.

Feature selection reduced the WebAPI clean-build median by **30.3%** and the
cached median by **17.7%**. The edit median decreased by only **5.2%**, with
overlapping ranges: do not treat that as a reliable incremental-build speedup.
Even with selection, clean builds remain about **4.6×** the unchanged version-13
baseline because the dependency still compiles a large API surface.

Raw measurements, source SHA-256 hashes, compiler versions, and configuration
are in `results/baseline-12.json`, `results/baseline-13.json`,
`results/webapi-all.json`, and `results/webapi-limited.json`.
The artifact counts count files under both `lib/bs` and `lib/ocaml`, **not**
unique modules. The WebAPI results additionally contain per-sample compiler
logs and a nonduplicated `lib/bs` compiled-module inventory:

| Configuration | React source modules | WebAPI source modules | WebAPI feature directories |
| --- | ---: | ---: | ---: |
| Either unchanged baseline | 9 | 0 | 0 |
| All WebAPI | 9 | 339 | 27 |
| WebAPI.Window | 9 | 231 | 18 |

Each WebAPI inventory also contains one generated namespace `.cmj`, not
included in the source-module counts above. All cached builds compiled zero
modules; all edit builds parsed one source and compiled two modules.

## Method

- Machine: Intel Core Ultra 7 355, eight logical CPUs, x86-64 Linux
  `7.2.9-1-MANJARO`; Node 24.16.0, npm 11.15.0.
- Run `node_modules/.bin/rescript build` directly, including CLI startup and
  subprocess overhead, not npm's script-launch overhead.
- Use separate disposable fixtures under `node_modules/.webapi-benchmark/`.
  Copy the current `src` and `rescript.json` without modifying the working
  source tree (or read a historical revision with `--source-ref`).
  Baselines have no ReScript dependencies.
- Install the exact compiler and its matching runtime, plus React/React DOM
  19.2.0, in each fixture. Installation is not timed. The fixture manifest
  omits unrelated publishing tooling and the root's version-13 runtime peer
  constraint so the version-12 baseline uses its own matching runtime.
- One untimed clean/build warm-up precedes measurement.
- Each of five rounds restores the source, runs `rescript clean` outside the
  timer, then times a clean build, an immediate no-op build, and a build after
  appending `let benchmarkIteration = <round>` to `ReactDOMStyle.res`.
  The edit changes the module interface and can rebuild dependents.
- “Clean” means compiler artifacts removed. OS filesystem/page caches are
  **not** flushed; installed, precompiled compiler/runtime libraries remain.
  For the WebAPI runs, the harness checks that the linked library has no
  remaining `.cmj` files after every clean; dependency builds are included.
- Scenarios run sequentially: version 12, version 13, then (after migration)
  all WebAPI and selected WebAPI. No concurrent benchmark processes, fixed
  CPU affinity, randomized ordering, or power controls were used.
- All **60 measured builds and four warm-up builds** succeeded. This measures
  compilation, not browser/runtime correctness. The repository's test script
  is only a disabled-test message and was not run.

## Reproduce

Reproduce the unchanged baselines without reverting the migration:

```sh
python3 benchmarks/builds.py baseline-12-repeat --compiler 12 \
  --source-ref bb34644ca803e021e7218a8a63b572705df73701
python3 benchmarks/builds.py baseline-13-repeat --compiler 13 \
  --source-ref bb34644ca803e021e7218a8a63b572705df73701
```

Choose new scenario names for repeat experiments: the script refuses to
overwrite an existing fixture. Results are JSON; detailed compiler output is
also retained locally in ignored `results/*.log` files. Failed compiler runs
abort the experiment rather than becoming successful timing samples.

## Local WebAPI setup

The library was linked directly from `/home/josh/Dev/experimental-rescript-webapi`,
commit `eb25639f8de1cb3051151caa7eeb4f63efa57d08`. Its source files were not
modified; its compiler artifacts were repeatedly cleaned and rebuilt.

The experiment's `package.json` contains a **machine-local absolute `file:` path**,
and `package-lock.json` records a checkout-location-specific local link. This is
an experimental setup, not a portable/publishable dependency declaration. On
another machine, change that path. If the React checkout moves (including from
the Delta worktree to the primary checkout), regenerate the lockfile with
`npm install` rather than reusing it with `npm ci`:

```sh
npm install --legacy-peer-deps --ignore-scripts --no-audit --no-fund
npm run clean
npm run build
```

The local WebAPI package declares a `rescript: ">=13"` peer, which does not
accept version-13 prereleases under npm semver. `--legacy-peer-deps` bypasses
that mismatch for this experiment; the root compiler is pinned to
`13.0.0-alpha.7`. No npm-published WebAPI package is installed.

The two benchmark configurations differ only in their ReScript dependency:

```json
{"dependencies": ["@rescript/webapi"]}
```

```json
{
  "dependencies": [
    {"name": "@rescript/webapi", "features": ["WebAPI.Window"]}
  ]
}
```

The root is left in the **feature-selected** configuration.

**`WebAPI.DOM` alone is not a replacement for all built-in `Dom` types.**
The original React sources use element, document, window, event, history,
location, and pointer ID types. WebAPI's element type lives in
`WebAPI.Element.t` (`WebAPI.DOMNodes`), while location/history live in the
`WebAPI.Window` feature. The latter transitively enables DOMNodes and DOM.
With the current feature graph, selecting `WebAPI.Window` enables **18 of 27**
feature-gated source directories, not just the core DOM directory.
The compiled-module inventories verify that these nine directories are absent:
Canvas, CSSFontLoading, Device, Navigator, Observers, SVG, UIEvents, WebAudio,
and Workers.

Repeat the WebAPI benchmarks with the migrated sources:

```sh
python3 benchmarks/builds.py webapi-all-repeat --compiler 13 \
  --webapi /path/to/experimental-rescript-webapi --features all
python3 benchmarks/builds.py webapi-limited-repeat --compiler 13 \
  --webapi /path/to/experimental-rescript-webapi --features limited
```

These commands link the local checkout directly, **not an npm copy**, and will
clean/write compiler artifacts there. Do not run against a concurrently
building checkout. In Delta, attach that repository or authorize direct
build access before running this phase (direct access was authorized here).

## Migration scope and checks

| Built-in type | Replacement |
| --- | --- |
| `Dom.element` | `WebAPI.Element.t` |
| `Dom.document` | `WebAPI.DOM.document` |
| `Dom.window` | `WebAPI.DOM.window` |
| `Dom.event` | `WebAPI.DOM.event` |
| `Dom.history` | `WebAPI.History.Types.history` |
| `Dom.location` | `WebAPI.Location.t` |
| `Dom.eventPointerId` | `int` |

Only existing explicit type references were migrated; the existing bindings,
FormData/stream types, synthetic-event object placeholders, and built-in
`JsxDOM`/`JsxEvent`/`JsxDOMStyle` infrastructure remain. This is not a removal of
all indirect built-in DOM dependencies. Public DOM types are intentionally
different from the old opaque types. Pointer IDs match WebAPI's integer field
and pointer-capture arguments.

Generated JavaScript was rebuilt. Differences include the version-13 runtime
`.mjs` imports and removal of option boxing/unboxing now that the compiler knows
the DOM values are records.

```sh
python3 benchmarks/check-consumer.py
```

The downstream compile checks pass for React roots receiving elements returned
by WebAPI, DOM refs in JSX, synthetic pointer IDs used for pointer capture,
event windows, and test-helper element types. They also verify:

- A consumer using React alone can rely on React's transitive WebAPI dependency.
- To **name WebAPI modules directly**, a consumer must declare WebAPI as a direct
  ReScript dependency too; transitive modules are not directly visible.
- With `WebAPI.Window` selected, `WebAPI.OffscreenCanvas` cannot be referenced.
- Adding an **unrestricted direct WebAPI dependency enables all features again**,
  including OffscreenCanvas. React's selection is not an upper bound on the
  consuming project's feature set. Consumers must select their own needed
  features as well.
- Restoring the selected dependency removes the excluded module again.

The consumer checks are outside the timed runs. Final root clean/build and
format checks for the six migrated source/interface files passed. Baseline
source reconstruction, matching input hashes, per-mode compile counts, and
benchmark CLI failure cases were also checked. No browser or runtime test suite
was run. An independent agent review was attempted but could not complete
because its connection was offline.

## WebAPI follow-up

One apparent MDN-alignment limitation was found in the local library:
`src/window/HistoryTypes.res:25` types `history.state` as `JSON.t`, and
`src/window/History.res` restricts `pushState`/`replaceState` data to `JSON.t`.
[MDN describes history state as serializable data](https://developer.mozilla.org/en-US/docs/Web/API/History/pushState),
which can include structured-cloneable non-JSON values such as `Date` and `Map`.
This looks narrower than the browser API, rather than a regression caused by
the migration. It was left unchanged; this router still passes `null` through
its existing bindings. A WebAPI follow-up could model state as `unknown` or a
typed state parameter instead of assuming JSON.
