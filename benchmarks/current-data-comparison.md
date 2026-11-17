# Upstream versus WebAPI data-type migration benchmark

This comparison measures unchanged upstream React and the current React
migration that adds narrower WebAPI clipboard, touch, and form-data types.

## Revisions and configurations

- Upstream React sources: `bb34644ca803e021e7218a8a63b572705df73701`.
- Migrated React sources/configuration: `14d720074ebd511c002d0f3ceb9e36171e9b1499`.
- WebAPI dependency: `691bc3f20dc5d621d22f5bf9931b4ec086542d5f`.
- Upstream ReScript 12: `12.3.1`, without WebAPI.
- Upstream ReScript 13: `13.0.0-alpha.7`, without WebAPI.
- Migrated ReScript 13: `13.0.0-alpha.7`, with the pinned WebAPI dependency
  and feature selection from the migrated revision. This selection compiles
  27 WebAPI source modules.
- All fixtures use React and React DOM `19.2.0`.

The upstream fixtures retain upstream sources and the rest of their
`rescript.json`, but normalize `dependencies` to `[]` so they compile without
WebAPI. They represent upstream no-WebAPI behavior, not byte-identical upstream
configuration files. The migrated configuration requires ReScript 13 and was
not treated as a ReScript 12 measurement.

## Results

All values are wall-clock milliseconds, with 30 samples in each cell. Cells
show median (95% bootstrap interval; observed minimum–maximum).

| Configuration | Clean | Cached no-op | Single-file edit |
| --- | ---: | ---: | ---: |
| Upstream, ReScript 12.3.1 | 132.81 (128.06–135.65; 109.86–177.92) | 46.46 (45.53–47.32; 39.14–53.69) | 78.95 (77.86–79.89; 59.99–113.19) |
| Upstream, ReScript 13.0.0-alpha.7 | 87.81 (85.91–92.52; 77.61–131.95) | 43.70 (42.62–45.74; 33.41–62.88) | 64.49 (59.27–65.24; 49.94–96.62) |
| Migrated, ReScript 13.0.0-alpha.7 | 129.88 (127.08–158.04; 115.01–226.93) | 50.75 (49.26–51.89; 37.63–70.63) | 69.98 (68.76–71.92; 58.86–119.35) |

The new raw samples, captured compiler output, and per-mode spread and
uncertainty are in [`results/data-current-30.json`](results/data-current-30.json).
Relative to upstream ReScript 13, the migrated configuration's medians are
47.9% higher for clean builds, 16.1% higher for cached no-op builds, and 8.5%
higher for the edit build. The intervals are bootstrap intervals for each
individual median, not intervals for the differences. Occasional long samples
widen some observed ranges, particularly in clean and edit modes.

## Method

Reproduce from the repository root after fetching the candidate ref:

```sh
python3 benchmarks/compare.py --runs 30 \
  --candidate-ref 14d720074ebd511c002d0f3ceb9e36171e9b1499 \
  --output benchmarks/results/data-current-30.json
```

The runner uses the fixed upstream revision above and copies each revision's
ReScript sources and configuration into independent temporary fixtures. It
pins the compiler version in each fixture manifest (`12.3.1` or
`13.0.0-alpha.7`) and installs the candidate's WebAPI dependency from its
package manifest. Upstream fixture dependencies are normalized as described
above. The output records hashes of source/configuration/manifest/lockfile
inputs and the React commit. It records the pinned compiler version, but does
not independently inspect installed compiler or WebAPI files and does not
include lockfile contents.

Each fixture receives one untimed warm-up. Then 30 rounds randomize the order of
the three configurations with seed `20260417`. Each config/round times a clean
build, cached no-op build, and a single-file incremental edit build. Cleanup and
dependency installation are outside timed intervals. Input fingerprints are
checked again after measurement. Median uncertainty is a percentile bootstrap
95% interval from 10,000 resamples. Configurations ran serially, with no
competing benchmark/build workload during the timed window.

## Limitations

Build time includes compiler process startup. OS page caches were not flushed;
CPU affinity and power settings were not controlled. Order randomization
mitigates time drift but cannot eliminate system noise. These results describe
the measured machine and dependency revisions, not a universal performance
claim. No comparison to any other WebAPI layout is made here.
