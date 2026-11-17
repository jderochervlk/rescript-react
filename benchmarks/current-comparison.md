# Current upstream versus WebAPI migration benchmark

This report compares the unchanged upstream ReScript React package with the
migrated implementation in three compiler/configuration combinations.

## Revisions and setup

- Upstream React source and configuration: `bb34644ca803e021e7218a8a63b572705df73701`.
- Migrated React source and configuration: `5010c947b2b4729f42b082662b9ba29ed43a42e7`.
- Upstream ReScript 12: `12.3.1`, with no WebAPI dependency.
- Upstream ReScript 13: `13.0.0-alpha.7`, with no WebAPI dependency.
- Migrated ReScript 13: `13.0.0-alpha.7`, with the WebAPI dependency and features
  from the migrated revision's `package.json` and `rescript.json`.
- Each fixture used React and React DOM `19.2.0`.

The upstream fixtures preserve the upstream source and the rest of its
`rescript.json`, but normalize `dependencies` to `[]` so they compile without
WebAPI. Thus they measure the upstream no-WebAPI behavior, not a byte-identical
upstream configuration file. The migrated fixture uses the candidate
`rescript.json` and its WebAPI feature selection.

The eventual candidate tip `dbd1f13` has identical `src/**/*.res`, `src/**/*.resi`,
and `rescript.json` to measured commit `5010c94`; its follow-up changes are outside
the benchmarked source/configuration.

The migrated configuration cannot be run under ReScript 12 because its WebAPI
feature dependency requires ReScript 13. The comparison therefore reports that
configuration as unavailable, rather than treating an unsupported combination
as a measurement.

## Results

All values are wall-clock milliseconds, with 30 samples in each cell. Cells show
median (95% bootstrap interval; observed minimum–maximum).

| Configuration | Clean | Cached no-op | Single-file edit |
| --- | ---: | ---: | ---: |
| Upstream, ReScript 12.3.1 | 131.12 (128.91–136.17; 114.71–149.50) | 45.54 (44.77–46.31; 39.27–53.86) | 79.04 (78.35–80.23; 73.17–85.05) |
| Upstream, ReScript 13.0.0-alpha.7 | 88.78 (86.03–93.89; 74.39–108.17) | 43.62 (42.70–44.64; 35.71–54.76) | 64.38 (63.20–65.28; 57.59–134.90) |
| Migrated, ReScript 13.0.0-alpha.7 | 127.56 (120.73–137.39; 102.26–177.57) | 47.51 (47.18–47.96; 40.13–56.46) | 70.33 (67.75–72.36; 60.45–139.72) |

Against upstream ReScript 13, the migrated configuration's medians are 43.7%
higher for clean builds, 8.9% higher for cached no-op builds, and 9.2% higher
for the edit build. The separate median intervals do not overlap in this run;
they are not an interval for the difference itself. Occasional long edit-build
samples materially widen the observed ranges, so medians and uncertainty are
more informative than comparing means.

The sample-level observations and captured compiler output are in
[`results/current-30.json`](results/current-30.json). Each mode's summary
contains the mean, median, standard deviation, range, and bootstrap interval.

## Method

Run from the repository root:

```sh
python3 benchmarks/compare.py --runs 30 \
  --candidate-ref 5010c947b2b4729f42b082662b9ba29ed43a42e7
```

The runner resolves the requested candidate ref and the fixed upstream commit,
copies only `src/**/*.res`, `src/**/*.resi`, and `rescript.json` into three
independent temporary fixtures, and performs isolated dependency installs.
React source/configuration is measured from those exact revisions; installed
dependencies are pinned in each generated fixture lockfile. For upstream
fixtures, `rescript.json` is normalized as described above. The compiler version
is the exact version pinned in each fixture manifest (`12.3.1` or
`13.0.0-alpha.7`); the runner does not independently inspect the installed
compiler package. The output records hashes of source inputs, configuration,
package manifest, and lockfile, along with full configuration data and the React
commit for each scenario. It does not include the lockfile contents or hashes
of installed compiler/WebAPI files.

There is one untimed warm-up build per fixture. Then 30 rounds run, shuffling
the three configurations in each round using the recorded fixed seed, to
distribute time/order effects across configurations. For each configuration,
every round consists of:

1. `clean`: remove compiler outputs, then time a build from scratch.
2. `cached`: immediately time a no-op rebuild.
3. `edit`: append a round-specific binding to `ReactDOMStyle.res`, time the
   incremental build, then restore the source.

All cleanup and fixture installation are outside timed intervals. Inputs are
re-fingerprinted after all runs and the runner aborts if they changed. The
runner records the raw compiler output and elapsed time per sample. The
uncertainty interval is a percentile bootstrap 95% interval for the median,
using 10,000 resamples. It describes sampling uncertainty for these observations,
not machine-to-machine variation.

## Limitations

Build time includes compiler process startup. OS page caches were not flushed,
and CPU affinity, power settings, and external system activity were not
controlled. Configuration randomization mitigates order drift but does not
remove these sources of noise. The results characterize these sources and
dependencies on this machine, not a universal compiler-performance guarantee.
