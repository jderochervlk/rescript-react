# JsxDOM removal: PR #2 build timings

This measures the additional cost of owning React's intrinsic props/ref types
locally, after the 15-module WebAPI migration in PR #1. It does not measure the
still-pending removal of `JsxDOMStyle` or `JsxEvent`.

## Same-session before/after results

ReScript **13.0.0-alpha.7**. Median wall-clock milliseconds, **10 samples per
mode per version**, pooled from two blocks of five:

| Source snapshot | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: |
| PR #1: before JsxDOM removal | 182.87 | 58.92 | 97.36 |
| PR #2: after JsxDOM removal | **208.52** | **61.76** | **121.91** |
| Difference in medians | +25.65 | +2.84 | +24.55 |

Ranges (minimum–maximum milliseconds):

| Source snapshot | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: |
| Before | 164.21–237.43 | 46.72–74.04 | 70.44–113.44 |
| After | 191.15–234.44 | 53.40–70.15 | 100.64–140.36 |

The clean and edited-build medians are higher after the change in both blocks.
Cached-build ranges overlap substantially. This experiment does **not** show a
build-speed improvement from removing JsxDOM, and is not a general compiler
performance guarantee.

Both versions compile **15 WebAPI + 9 React = 24 source modules**. Removing an
alias to a precompiled runtime type does not remove one of those source modules;
PR #2 instead puts the intrinsic-props record in React's own compilation.
That is a plausible source of extra work, not a compiler-profiled attribution.
The incremental edit recompiles two modules in both versions.

Do not compare these absolute timings directly with PR #1's older 122.27 ms
15-module median or the original no-WebAPI v12/v13 baselines. Those came from
different sessions. The freshly measured PR #1 row above is the control here.

## Exact revisions and timestamps

- Before: `9ab058ca78be7fec01f3b6001f5683f4cf5a5f02` (PR #1).
- After: `5410e8095a2c57498b226b50da662bffcd579bf5` (PR #2).
- Shared WebAPI: `81ac4eebeae3ff0cc9118e7b4b62323e3cee9729`.
- Shared WebAPI input SHA-256:
  `de9a938ec0d196dd0da1553a4f9c1346f8c3fe22d5488e6b9d063ce1e81ae118`.

Each raw result's `recorded_at` timestamp is captured after fixture setup,
before its warm-up and measured builds. It is a **block timestamp**, not an
individual sample timestamp:

| Execution order | Recorded at (local offset included) | Raw samples and build logs |
| --- | --- | --- |
| Before A | `2026-11-17T06:45:47-0500` | [jsxdom-before-a.json](results/jsxdom-before-a.json) |
| After A | `2026-11-17T06:45:51-0500` | [jsxdom-after-a.json](results/jsxdom-after-a.json) |
| After B | `2026-11-17T06:45:55-0500` | [jsxdom-after-b.json](results/jsxdom-after-b.json) |
| Before B | `2026-11-17T06:45:58-0500` | [jsxdom-before-b.json](results/jsxdom-before-b.json) |

The results' `source_ref` identifies the measured source revision.
`react_commit` identifies the harness checkout, which stayed on PR #2 throughout.
Source hashes were checked against each `source_ref`; only ReactDOM.res,
ReactEvent.res, and ReactEvent.resi differ between the measured source sets.
The effective ReScript configuration and WebAPI fingerprint match in all blocks.

## Method

- Used the existing `builds.py` harness without changes: **60 measured builds**.
- Executed sequentially, before → after in block A, after → before in block B.
  No parallel benchmark or validation builds were launched.
- Each scenario gets a separate React fixture and an untimed warm-up. All link
  the same private local WebAPI source snapshot, archived from the exact commit
  without its development dependencies. The external WebAPI checkout is untouched.
- Build timing includes compiler startup, but excludes npm installation and
  cleanup. Clean removes compiler artifacts, not OS page caches or the installed
  precompiled runtime. The harness checks for leftover WebAPI build artifacts.
- Cached builds change no source. Edited builds append an exported
  `benchmarkIteration` value to the fixture's ReactDOMStyle.res, then restore it.
- Linux x86_64, eight logical CPUs; Node `v24.16.0`, npm `11.15.0`,
  React and React DOM `19.2.0`. No CPU-frequency or system-load isolation.
- This is a library-build benchmark, not an application JSX compilation or runtime
  benchmark. It does not rerun the DOM-props behavioral regression suite.

## Reproduce

Prepare a local WebAPI source snapshot at the shared revision above, without
installed development dependencies. Then run the following sequentially, choosing
new scenario names if fixtures with these names already exist:

```sh
for pair in \
  "before-a 9ab058ca78be7fec01f3b6001f5683f4cf5a5f02" \
  "after-a 5410e8095a2c57498b226b50da662bffcd579bf5" \
  "after-b 5410e8095a2c57498b226b50da662bffcd579bf5" \
  "before-b 9ab058ca78be7fec01f3b6001f5683f4cf5a5f02"
do
  set -- $pair
  python3 benchmarks/builds.py "jsxdom-repeat-$1" --compiler 13 --runs 5 \
    --source-ref "$2" --webapi /path/to/private-webapi-snapshot \
    --webapi-source-ref 81ac4eebeae3ff0cc9118e7b4b62323e3cee9729 \
    --feature WebAPI.DOMTree --feature WebAPI.History --feature WebAPI.Location
done
```

The harness writes compiler artifacts into the linked snapshot; do not use it
concurrently for other builds. Raw JSON includes every sample, compiler log,
configuration, source hashes, timestamp, and compiled-module inventory.
