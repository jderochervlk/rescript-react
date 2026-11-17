# Narrow data features: current profiling results

[WebAPI PR #416](https://github.com/rescript-lang/experimental-rescript-webapi/pull/416)
adds Touch, FormData, DataTransfer, and FileEntries independently of broad
UIEvents/Fetch. It is stacked on #415; its new branch contains main at
`20d11da1` and the #415 prerequisite.

React PR #1 now selects DOMTree, History, Location, Touch, DataTransfer, and
FormData. This compiles **27 WebAPI + 9 React = 36 source modules**.
Clipboard data is nullable, touch getters return TouchList, and the local
FormData wrapper shares WebAPI.FormData.t while retaining its boxed variants.
PR #2 separately owns JSX DOM props and refs on top of that base.

## Same-session timing comparison

Median milliseconds, **10 samples per mode**, pooled from two blocks of five.
Except for the explicit v12 baseline, every row uses ReScript 13.0.0-alpha.7.
Both original baselines have identical unmodified React sources and no WebAPI.

| Case | WebAPI sources | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: | ---: |
| Unchanged React, ReScript 12.3.1 | 0 | 133.04 | 44.60 | 76.93 |
| Unchanged React, ReScript 13.0.0-alpha.7 | 0 | 86.29 | 42.13 | 64.86 |
| Previous core-backed React, data placeholders retained | 15 | 129.04 | 48.00 | 74.06 |
| **PR #1: narrow data features** | **27** | **127.57** | **48.31** | **69.89** |
| Same PR #1 sources, broad UIEvents + Fetch | 102 | 206.83 | 55.09 | 74.34 |
| **PR #2: JsxDOM removed, narrow data features** | **27** | **175.80** | **48.86** | **108.16** |

Minimum–maximum milliseconds:

| Case | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: |
| Baseline v12 | 128.22–171.73 | 34.78–50.37 | 66.55–79.59 |
| Baseline v13 | 77.86–97.02 | 41.77–46.82 | 63.28–72.22 |
| Previous 15 | 121.13–159.63 | 42.91–53.49 | 68.64–81.21 |
| Narrow 27 | 119.31–183.67 | 40.27–48.87 | 67.90–86.03 |
| Broad 102 | 165.50–278.05 | 50.13–66.05 | 68.54–114.64 |
| JsxDOM removal, 27 | 141.06–226.10 | 47.05–71.44 | 80.37–142.45 |

The narrow/broad rows have **identical React source hashes and WebAPI inputs**;
only feature selection differs. Narrow selection reduces the recorded clean
median, but the broad block medians varied from 184.43 to 256.99 ms. Do not
treat the pooled ratio as a precise universal performance claim.

The current 27-module selection is close to the prior 15-module control in
this run; overlapping ranges do not establish that adding bindings made builds
faster. Both remain slower than unchanged v13 React.

PR #2's clean and edited-build medians remain higher than PR #1's in both
blocks. Removing JsxDOM is a type-ownership change, **not a demonstrated
build-speed improvement**. Cached differences are small relative to variation.

## Revisions, timestamps, and raw evidence

| Raw-file label | React source revision | WebAPI revision |
| --- | --- | --- |
| `baseline12`, `baseline13` | `bb34644ca803e021e7218a8a63b572705df73701` | None |
| `current15` | `d561f0ed008465634d3e8b0defbbc9795c4a854a` | `81ac4eebeae3ff0cc9118e7b4b62323e3cee9729` |
| `narrow27`, `broad102` | `0e266a6496dbbf398001e1f9711b1c3a5e8a8b53` | `691bc3f20dc5d621d22f5bf9931b4ec086542d5f` |
| `jsxdom27` | `b35fa9d7de992e38333d58e8f164de223aa3a8e0` | `691bc3f20dc5d621d22f5bf9931b4ec086542d5f` |

Block timestamps on **2026-11-17, UTC−05:00**, captured before each warm-up:

| Case | Block A | Block B | Raw files |
| --- | --- | --- | --- |
| Baseline v12 | 07:21:06 | 07:21:36 | [A](results/data-baseline12-a.json), [B](results/data-baseline12-b.json) |
| Baseline v13 | 07:21:08 | 07:21:34 | [A](results/data-baseline13-a.json), [B](results/data-baseline13-b.json) |
| Previous 15 | 07:21:10 | 07:21:32 | [A](results/data-current15-a.json), [B](results/data-current15-b.json) |
| Narrow 27 | 07:21:13 | 07:21:29 | [A](results/data-narrow27-a.json), [B](results/data-narrow27-b.json) |
| Broad 102 | 07:21:15 | 07:21:25 | [A](results/data-broad102-a.json), [B](results/data-broad102-b.json) |
| JsxDOM removal | 07:21:19 | 07:21:22 | [A](results/data-jsxdom27-a.json), [B](results/data-jsxdom27-b.json) |

These timestamps identify measurement blocks, not individual samples.
Each JSON contains source hashes, configuration, WebAPI fingerprint, every
sample/log, and artifact inventory. `source_ref` identifies the measured React
sources; `react_commit` identifies the harness checkout. Hashes were verified
against the source revisions and every clean v13 WebAPI build's module count
was checked against the intended inventory.

## Method and reproduction

- **180 successful measured builds**, sequential, with no concurrent builds.
- Block A follows the table order; block B reverses it.
- Equivalent private WebAPI source archives, linked locally without WebAPI
  development dependencies. No timing claim is based on an npm archive install.
- Exact compiler pins, React/React DOM 19.2.0, Node 24.16.0, npm 11.15.0.
- Clean removes compiler artifacts, not OS page caches or the precompiled
  runtime. Setup/installation/cleanup are outside the timer; compiler startup
  is included. Each scenario has an untimed warm-up.
- The edit appends an exported benchmarkIteration value to fixture
  ReactDOMStyle.res and restores the original afterwards.
- All fixtures use an external temporary parent through `--fixture-root`.
  ReScript 12 otherwise discovers this project's ancestor config and rejects
  feature-object dependencies before building. The initial in-project attempt
  failed during setup/clean and produced no timing samples.
- No CPU-frequency/load isolation; these are library-build measurements,
  not application compilation, browser execution, or bundle-size measurements.

Example narrow/broad reproduction, with a private WebAPI folder at `691bc3f2`:

```sh
fixtures=$(mktemp -d)
python3 benchmarks/builds.py data-repeat-narrow --compiler 13 --runs 5 \
  --fixture-root "$fixtures" \
  --source-ref 0e266a6496dbbf398001e1f9711b1c3a5e8a8b53 \
  --webapi /path/to/private-webapi-snapshot \
  --webapi-source-ref 691bc3f20dc5d621d22f5bf9931b4ec086542d5f \
  --feature WebAPI.DOMTree --feature WebAPI.History --feature WebAPI.Location \
  --feature WebAPI.Touch --feature WebAPI.DataTransfer --feature WebAPI.FormData
python3 benchmarks/builds.py data-repeat-broad --compiler 13 --runs 5 \
  --fixture-root "$fixtures" \
  --source-ref 0e266a6496dbbf398001e1f9711b1c3a5e8a8b53 \
  --webapi /path/to/private-webapi-snapshot \
  --webapi-source-ref 691bc3f20dc5d621d22f5bf9931b4ec086542d5f \
  --feature WebAPI.DOMTree --feature WebAPI.History --feature WebAPI.Location \
  --feature WebAPI.UIEvents --feature WebAPI.Fetch
```

Repeat in reversed order with new scenario names. For PR #2, use its source
revision from the table with the narrow features. For unchanged baselines,
use `--compiler 12` or `13`, the original source revision, and omit WebAPI flags.
The 15-module control uses its old WebAPI snapshot and only DOMTree/History/Location.
The linked folders receive compiler artifacts and must not be built concurrently.

## Validation and review

Upstream: all 36 feature builds, exact narrow inventories, packed consumers,
negative fixtures, Node runtime tests, four Chromium tests, formatting, docs
build, and 40 documentation-check tests passed. A subagent reviewed #416's final
head and found no blocking issues; its review was static, not a second test run.

React: clean build confirms 36 sources, the consumer harness verifies data/type
interoperability and feature exclusion/recovery, and PR #2's JsxDOM-free
compilation and JSX/SSR regression suite pass.

An existing alpha.7 limitation permits `{}` construction for the declared private
empty FormData type; this also occurs before the split and is documented upstream.
No upstream main merge or npm publication was performed.
