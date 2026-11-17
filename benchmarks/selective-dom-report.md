# Selective DOM reduction

## Unchanged React baselines: ReScript 12 and 13, without WebAPI

Both baselines build the original nine React source modules and `rescript.json`
at `bb34644ca803e021e7218a8a63b572705df73701`, before any WebAPI migration.
The recorded source hashes and configuration are identical. Neither has a
WebAPI dependency: both raw results record `webapi: null` and `features: null`.
Only the fixture toolchain changes to use the respective compiler/runtime.

Wall-clock milliseconds, **five samples per mode**; median (minimum–maximum):

| Compiler | WebAPI source modules | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: | ---: |
| ReScript 12.3.1 | 0 | 178.17 (142.23–223.88) | 79.38 (60.07–99.51) | 103.54 (84.14–330.95) |
| ReScript 13.0.0-alpha.7 | 0 | 89.56 (86.86–109.04) | 48.07 (36.65–50.16) | 65.69 (57.01–79.21) |

Raw samples, configuration and source hashes:
[baseline-12.json](results/baseline-12.json) and
[baseline-13.json](results/baseline-13.json).
Build timing includes compiler startup, but excludes installation and cleanup.
Clean removes compiler artifacts, not OS caches; cached builds change no source,
and single-file rebuilds use the harness's small ReactDOMStyle edit.

These were captured **before** the later ten-sample WebAPI-layout comparison.
The selected 15-module layout's clean median (122.27 ms) exceeds the unchanged
v13 baseline (89.56 ms) in the recorded results. Different sessions and sample
counts mean this is not a precise causal estimate of migration overhead.
In particular, improvements against the 59-module WebAPI layout below are
**not improvements against unchanged React on ReScript 13**.

## Selected layout

PR #1 uses the **15-module selective feature layout**, replacing the earlier
six-module consolidation. It provides essentially the same React clean-build time in this
sample without putting the rich DOM-tree and CSS records into basic DOM.

This layout is adopted in [React PR #1](https://github.com/jderochervlk/rescript-react/pull/1)
and its [JsxDOM follow-up](https://github.com/jderochervlk/rescript-react/pull/2).
The prerequisite is [WebAPI PR #415](https://github.com/rescript-lang/experimental-rescript-webapi/pull/415),
stacked on the History/Location work in #413. React pins WebAPI commit
`81ac4eebeae3ff0cc9118e7b4b62323e3cee9729` through an exact public archive.

The measurements used local source-folder links, not the archive install. The
portable dependency pin makes the PRs reproducible without a machine-local path.
No new timings are claimed for the separate JsxDOM-removal code in PR #2.

## What changed this time

Compared with the original History/Location split at `625b8687`:

- **Basic `DOM.res` is byte-for-byte unchanged**: 1,029 lines, not the expanded
  4,560-line version from the six-module attempt.
- Seven existing CSS declaration modules move unchanged into a selectable
  `WebAPI.CSSOMCore` feature:
  CSSStyleDeclaration, CSSStyleValue, MediaList, StylePropertyMap,
  StylePropertyMapReadOnly, StyleSheet, and StyleSheetList.
- CSSOM continues to provide the complete API. It includes CSSOMCore plus its
  remaining modules and Event dependency, without selecting DOMTree.
- The existing DOMTree record group becomes independently selectable as
  `WebAPI.DOMTree`. It depends on basic DOM and CSSOMCore, not the DOM operation
  modules.
- DOMStringMap moves unchanged alongside DOMTree. SVG still receives it through
  SVG → DOMNodes → DOMTree.
- Only the small generic HTMLCollection representation moves into DOMTree to
  break the dependency on its operation module. HTMLCollection retains the
  representation-preserving alias and unchanged methods.
- React uses the pre-existing `WebAPI.DOMTree.element` type path rather than the
  experimental `WebAPI.DOM.element` path.

There is no large-record consolidation or CSS representation re-export layer in
the recommended variant. The existing CSS modules and their declarations remain
intact. Relative to `625b8687`, the seven CSS moves have zero content changes;
DOMTree has a small collection-type adjustment and all original records remain.

The 15 modules are:

| Group | Modules |
| --- | ---: |
| Basic DOM | 3 |
| CSS declaration modules | 7 |
| DOMTree + DOMStringMap | 2 |
| History | 2 |
| Location | 1 |
| **WebAPI total** | **15** |
| React | 9 |
| **Total source modules** | **24** |

Important boundary: this is not a completely type-only CSS feature. It includes
the seven CSS modules' existing operations. Keeping those inexpensive declarations
with their types is intentional, avoiding the extra type layer of the nine-module
alternative. Element, Node, HTMLCollection, Event, Animation, geometry, Window,
Document, and MediaQueryList operation modules remain excluded until selected.

## Four already-migrated WebAPI implementations compared

| Label | Layout |
| --- | --- |
| `original` | Already-migrated 59-module DOMNodes selection; WebAPI `625b8687`, React `e549ebf` |
| `six` | Earlier six-module consolidation; WebAPI `acf8d6ce`, React `6be1cf1` |
| `nine` | Basic DOM restored, rich DOMTree separately selected, CSS records extracted into CSSOMTypes |
| `fifteen` | Basic DOM restored, rich DOMTree selected with seven intact CSS declaration modules |

The nine-module implementation is retained in WebAPI history at commit `4e2d1224`.
The final fifteen-module implementation avoids the additional CSS extraction/
aliasing layer, keeping the original CSS definitions and public module set.

## Migrated React timings: later controlled comparison

All rows use ReScript 13.0.0-alpha.7 and depend on WebAPI.
Wall-clock milliseconds, median of **10 samples per mode**:

| Layout | WebAPI source modules | Clean | Cached no-op | Single-file rebuild |
| --- | ---: | ---: | ---: | ---: |
| Already-migrated DOMNodes baseline | 59 | 196.98 | 50.21 | 79.67 |
| Earlier consolidation | 6 | 121.48 | 45.92 | 64.19 |
| Extracted type features | 9 | 124.96 | 46.02 | 69.90 |
| **Selective intact modules** | **15** | **122.27** | **45.54** | **70.03** |

The three reduced layouts are effectively tied on clean-build speed at this
sample size. **Six is not meaningfully faster than fifteen here.**

The 15-module clean median is 37.9% below the already-migrated 59-module baseline
in this run, not below unchanged React. That ratio must not be treated as a
precise general performance claim. The 59-module layout's two
block medians differed substantially: 203.94 ms and 157.65 ms. The fifteen-module
block medians were 119.58 ms and 124.95 ms. This was ordinary laptop execution,
not a controlled CPU-frequency or load-isolated laboratory.

Clean sample ranges:

| Layout | Minimum–maximum |
| --- | ---: |
| Already-migrated DOMNodes baseline | 152.41–231.92 ms |
| Six | 96.65–154.82 ms |
| Nine | 117.58–149.51 ms |
| Fifteen | 100.66–164.98 ms |

Cached and incremental ranges also overlap. Do not interpret small differences
between the reduced layouts as established wins.

## Other consumers

Clean-build medians, also ten samples each:

| Consumer | Original | Six | Nine | Fifteen |
| --- | ---: | ---: | ---: | ---: |
| DOM | 86.49 ms | 95.35 ms | 78.11 ms | 81.65 ms |
| Location | 83.44 ms | 100.54 ms | 82.91 ms | 81.32 ms |
| URL | 76.14 ms | 101.14 ms | 80.52 ms | 83.09 ms |
| Fetch | 118.91 ms | 132.37 ms | 122.94 ms | 107.60 ms |
| CSSOM | 92.89 ms | 133.25 ms | 100.55 ms | 99.21 ms |

The large, systematic shared-core penalty is substantially reduced. This is not
a promise of zero regression: the latest fifteen-module URL and CSSOM medians
remain about 7 ms and 6 ms above the original, and the ranges overlap broadly.
The stronger structural result is that basic DOM and all seven CSS declarations
are unchanged, rather than making every basic DOM consumer process rich CSS/tree
records.

The CSSOM closure remains 17 modules in the original and fifteen-module layouts;
the nine-module layout adds CSSOMTypes, making it 18. DOM, Location, URL, and Fetch
closures remain 3, 4, 6, and 36 modules respectively.

## Method and controls

- All variants used ReScript 13.0.0-alpha.7 and React 19.2.0 on the same machine.
- Each dependency was an equivalent source snapshot under a common parent,
  without installed WebAPI development dependencies or pre-existing build artifacts.
  Every scenario linked its designated snapshot locally.
- Two blocks of five clean/cached/edit rounds were run. Variant order was
  original → six → nine → fifteen, then reversed for the second block.
- Each scenario had an untimed warm-up; installation and cleanup were not timed.
  Clean removes compiler artifacts, not OS page caches.
- React edits used the same small ReactDOMStyle source change as prior experiments.
  Standalone probes edited their own one-source consumer.
- Every sample's compiler module count was checked. The final comparison has
  **720 successful measured builds**.
- The nine- and fifteen-module React source snapshots/configurations are identical;
  their WebAPI layouts differ. Source hashes and library fingerprints are recorded.

An exploratory run initially compared archive baselines with the live development
checkout. That was a filesystem-layout confounder, so it is not the primary
comparison. Those results are retained as `selective-*`. The first normalized
three-variant run is retained as `controlled-*`. Use the final four-variant
`final-*` results and `selective-summary.json` for the tables above.

## Evidence and reproduction

Raw data:

- `results/final-react-{original,six,nine,fifteen}-{a,b}.json`
- `results/final-probe-{dom,location,url,fetch,cssom}-{variant}-{a,b}.json`
- `results/selective-summary.json` includes medians, ranges, block medians, source
  counts, fingerprints, and source snapshot identifiers.

The measured nine- and fifteen-module source-tree identifiers are respectively
`111c6d62b701c2b3082517575e76167341318867` and
`01db7c05115a48700cc61623e894a46546858d0c`. Their compiled source inputs correspond
to commits `4e2d1224` and `81ac4eeb`; the latter adds only test-fixture cleanup
after the snapshot. Fingerprints identify actual compiled inputs independently of
those Git metadata differences.

For a normal checkout, run `npm ci`, then `npm run build`. To work with a local
WebAPI checkout at the matching revision without changing the committed pin:

```sh
npm install --no-save --package-lock=false /path/to/selective-webapi
```

The benchmark harness independently links whichever folder is supplied through
`--webapi`. Reinstall from the lockfile to restore the portable dependency.

Benchmark examples, using separate baseline/candidate folders and unused names:

```sh
python3 benchmarks/builds.py selective-original-repeat --compiler 13 \
  --source-ref e549ebf4bdd9a3a2da240d077173dc6706bb9ebc \
  --webapi /path/to/original-webapi \
  --feature WebAPI.DOMNodes --feature WebAPI.History --feature WebAPI.Location

python3 benchmarks/builds.py selective-fifteen-repeat --compiler 13 \
  --webapi /path/to/selective-webapi \
  --feature WebAPI.DOMTree --feature WebAPI.History --feature WebAPI.Location

python3 benchmarks/builds.py selective-cssom-repeat --compiler 13 \
  --probe cssom --webapi /path/to/selective-webapi --feature WebAPI.CSSOM
```

For archive snapshots without their own Git repository, supply
`--webapi-source-ref <commit-or-tree>` as provenance. Do not benchmark against a
checkout being built or edited elsewhere.

## Validation

For the recommended fifteen-module variant:

- All 32 feature builds and isolated feature consumers pass.
- Existing Node runtime fixtures and packed-package positive/negative consumers pass.
- All four Chromium browser tests pass.
- Formatting, documentation generation, and documentation-link checks pass.
- React builds 24 source modules; its consumer checks enforce the 15-module WebAPI
  inventory and the intended operation-module exclusions.
- Broad consumers retain interoperability with Element/Node/Window methods.
- All **338 original WebAPI JavaScript outputs are byte-identical** to baseline,
  compared by logical module name across the moved directories.
- Independent static review found no concrete feature or compatibility defect.
- Live editor interaction was not manually checked.

## Scope

The fifteen-module selective layout replaces the six-module draft in PR #1 and
is inherited by its JsxDOM follow-up. The tradeoff is a larger
module count than six, but no bloated basic DOM, no CSS type consolidation, much
smaller source changes, and comparable React build performance.

The PRs remain separate review steps. This update does not remove JsxDOMStyle or
JsxEvent, and it does not merge any PR into its destination branch.
