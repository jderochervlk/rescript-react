#!/usr/bin/env python3
"""Benchmark compiler builds in disposable fixtures, never the working sources."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
VERSIONS = {"12": "12.3.1", "13": "13.0.0-alpha.7"}


def run(command, cwd):
    started = time.perf_counter_ns()
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000
    if result.returncode:
        raise RuntimeError(f"{command} in {cwd}\n{result.stdout}\n{result.stderr}")
    return elapsed_ms, result.stdout + result.stderr


def copy_sources(fixture, source_ref):
    if not source_ref:
        shutil.copytree(ROOT / "src", fixture / "src")
        shutil.copy(ROOT / "rescript.json", fixture / "rescript.json")
        return
    _, commit = run(["git", "rev-parse", "--verify", f"{source_ref}^{{commit}}"], ROOT)
    _, paths = run(
        ["git", "ls-tree", "-r", "--name-only", commit.strip(), "--", "src", "rescript.json"], ROOT
    )
    for name in paths.splitlines():
        if name == "rescript.json" or Path(name).suffix in (".res", ".resi"):
            destination = fixture / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(run(["git", "show", f"{commit.strip()}:{name}"], ROOT)[1])


def selected_features(args):
    if args.feature:
        return args.feature
    return ["WebAPI.Window"] if args.features == "limited" else None


def copy_probe(fixture, probe):
    (fixture / "src").mkdir()
    shutil.copy(ROOT / "benchmarks" / "probes" / f"{probe}.res", fixture / "src/Probe.res")
    config = {
        "name": "webapi-probe",
        "sources": ["src"],
        "package-specs": {"module": "esmodule", "in-source": True},
        "suffix": ".res.js",
    }
    (fixture / "rescript.json").write_text(json.dumps(config, indent=2) + "\n")


def prepare_fixture(args):
    fixture_root = (
        Path(args.fixture_root).resolve()
        if args.fixture_root
        else ROOT / "node_modules" / ".webapi-benchmark"
    )
    fixture = fixture_root / args.scenario
    if fixture.exists():
        raise RuntimeError(f"Fixture already exists: {fixture}; choose a new scenario name")
    fixture.mkdir(parents=True)
    if args.probe:
        copy_probe(fixture, args.probe)
    else:
        copy_sources(fixture, args.source_ref)
    config = json.loads((fixture / "rescript.json").read_text())
    config.pop("dependencies", None)
    if args.webapi:
        features = selected_features(args)
        config["dependencies"] = [
            {"name": "@rescript/webapi", "features": features} if features else "@rescript/webapi"
        ]
    (fixture / "rescript.json").write_text(json.dumps(config, indent=2) + "\n")
    manifest = {
        "name": config["name"],
        "private": True,
        "dependencies": {
            "rescript": VERSIONS[args.compiler],
            "react": "19.2.0",
            "react-dom": "19.2.0",
        },
    }
    (fixture / "package.json").write_text(json.dumps(manifest, indent=2) + "\n")
    run(["npm", "install", "--ignore-scripts", "--no-audit", "--no-fund"], fixture)
    if args.webapi:
        link = fixture / "node_modules" / "@rescript" / "webapi"
        link.symlink_to(Path(args.webapi).resolve(), target_is_directory=True)
    return fixture


def source_hashes(fixture):
    return {
        str(path.relative_to(fixture)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted((fixture / "src").glob("*.res*"))
        if path.suffix in (".res", ".resi")
    }


def webapi_fingerprint(webapi):
    root = Path(webapi).resolve()
    sources = [path for path in (root / "src").rglob("*") if path.suffix in (".res", ".resi")]
    inputs = [root / name for name in ("rescript.json", "package.json", "package-lock.json")]
    hashes = {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted([*sources, *inputs])
    }
    return hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()


def artifact_counts(fixture, webapi, probe=None):
    roots = {"consumer" if probe else "react": fixture}
    if webapi:
        roots["webapi"] = Path(webapi).resolve()
    return {
        name: {
            suffix: len(list((root / "lib").rglob(f"*{suffix}")))
            for suffix in (".cmi", ".cmj", ".ast")
        }
        for name, root in roots.items()
    }


def compiled_modules(webapi):
    if not webapi:
        return []
    root = Path(webapi).resolve() / "lib" / "bs"
    return sorted(str(path.relative_to(root)) for path in root.rglob("*.cmj"))


def clean(compiler, fixture, webapi):
    run([compiler, "clean"], fixture)
    if webapi and compiled_modules(webapi):
        raise RuntimeError("rescript clean left WebAPI artifacts; refusing a false clean sample")


def measure(args, fixture, output):
    compiler = str(fixture / "node_modules" / ".bin" / "rescript")
    clean(compiler, fixture, args.webapi)
    _, warmup = run([compiler, "build"], fixture)
    (output / f"{args.scenario}-warmup.log").write_text(warmup)
    edited = fixture / "src" / ("Probe.res" if args.probe else "ReactDOMStyle.res")
    original = edited.read_text()
    samples = []
    try:
        for iteration in range(1, args.runs + 1):
            edited.write_text(original)
            clean(compiler, fixture, args.webapi)
            for mode in ("clean", "cached", "edit"):
                if mode == "edit":
                    edited.write_text(original + f"\nlet benchmarkIteration = {iteration}\n")
                elapsed_ms, log = run([compiler, "build"], fixture)
                (output / f"{args.scenario}-{iteration}-{mode}.log").write_text(log)
                samples.append({"iteration": iteration, "mode": mode, "ms": elapsed_ms, "log": log})
                print(f"{args.scenario} {iteration} {mode}: {elapsed_ms:.2f} ms", flush=True)
    finally:
        edited.write_text(original)
    return samples


def summarize(samples):
    def summary(mode):
        values = [sample["ms"] for sample in samples if sample["mode"] == mode]
        return {
            "median_ms": statistics.median(values),
            "min_ms": min(values),
            "max_ms": max(values),
            "mean_ms": statistics.mean(values),
        }
    return {mode: summary(mode) for mode in ("clean", "cached", "edit")}


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scenario")
    parser.add_argument("--compiler", choices=VERSIONS, required=True)
    parser.add_argument("--webapi", help="Local checkout; compiler artifacts WILL be written here")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument(
        "--features", choices=("all", "limited"), default="all",
        help="Legacy presets: all is unrestricted; limited selects WebAPI.Window",
    )
    selection.add_argument("--feature", action="append", help="Select a public feature; repeat to combine")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument(
        "--fixture-root",
        help="Disposable fixture parent; use a directory outside this project for v12, which cannot parse an ancestor's feature dependencies",
    )
    parser.add_argument("--source-ref", help="Read baseline sources/config from this Git revision")
    parser.add_argument("--webapi-source-ref", help="Declared source revision for a non-Git WebAPI snapshot")
    parser.add_argument("--probe", choices=("dom", "location", "url", "fetch", "cssom"), help="Benchmark a tiny non-React consumer")
    args = parser.parse_args()
    if args.runs < 1 or Path(args.scenario).name != args.scenario or args.scenario in (".", ".."):
        parser.error("Use a simple scenario name and a positive run count")
    if selected_features(args) and not args.webapi:
        parser.error("Feature selection requires --webapi")
    if args.webapi and args.compiler != "13":
        parser.error("This WebAPI experiment requires compiler 13")
    if args.probe and (not args.webapi or args.source_ref):
        parser.error("--probe requires --webapi and cannot be combined with --source-ref")
    return args


def webapi_git_metadata(path):
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], cwd=path, capture_output=True, text=True
    )
    if result.returncode or Path(result.stdout.strip()).resolve() != Path(path).resolve():
        return {"webapi_commit": None, "webapi_status": None}
    return {
        "webapi_commit": run(["git", "rev-parse", "HEAD"], path)[1].strip(),
        "webapi_status": run(["git", "status", "--porcelain"], path)[1],
    }


def metadata_for(args, fixture):
    metadata = {
        "scenario": args.scenario,
        "compiler": VERSIONS[args.compiler],
        "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "react_commit": run(["git", "rev-parse", "HEAD"], ROOT)[1].strip(),
        "source_ref": args.source_ref,
        "fixture": str(fixture),
        "probe": args.probe,
        "platform": platform.platform(),
        "cpu_count": os.cpu_count(),
        "node": run(["node", "--version"], ROOT)[1].strip(),
        "npm": run(["npm", "--version"], ROOT)[1].strip(),
        "webapi": str(Path(args.webapi).resolve()) if args.webapi else None,
        "features": (selected_features(args) or "all") if args.webapi else None,
        "sources": source_hashes(fixture),
        "config": json.loads((fixture / "rescript.json").read_text()),
    }
    if args.webapi:
        metadata.update(webapi_git_metadata(args.webapi))
        metadata["webapi_source_ref"] = args.webapi_source_ref
        metadata["webapi_inputs_sha256"] = webapi_fingerprint(args.webapi)
    return metadata


def main():
    args = parse_args()
    fixture = prepare_fixture(args)
    output = ROOT / "benchmarks" / "results"
    output.mkdir(exist_ok=True)
    metadata = metadata_for(args, fixture)
    samples = measure(args, fixture, output)
    if args.webapi and webapi_fingerprint(args.webapi) != metadata["webapi_inputs_sha256"]:
        raise RuntimeError("WebAPI inputs changed during measurement; refusing mixed results")
    result = {
        **metadata,
        "samples": samples,
        "summary": summarize(samples),
        "artifacts": artifact_counts(fixture, args.webapi, args.probe),
        "webapi_compiled_modules": compiled_modules(args.webapi),
    }
    (output / f"{args.scenario}.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["summary"], indent=2))


if __name__ == "__main__":
    main()
