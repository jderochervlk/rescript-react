#!/usr/bin/env python3
"""Balanced repeated comparison of upstream React and the migrated branch."""

import argparse
import hashlib
import json
import os
import platform
import random
import shutil
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_TEMP = tempfile.TemporaryDirectory(prefix="rescript-react-benchmark-")
FIXTURE_ROOT = Path(FIXTURE_TEMP.name)
UPSTREAM = "bb34644ca803e021e7218a8a63b572705df73701"
COMPILER_VERSIONS = {"12": "12.3.1", "13": "13.0.0-alpha.7"}
CONFIGS = {
    "upstream-v12": ("12", UPSTREAM, False),
    "upstream-v13": ("13", UPSTREAM, False),
    "migrated-v13": ("13", None, True),
}


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{command} in {cwd}\n{result.stdout}\n{result.stderr}")
    return result.stdout + result.stderr


def digest(paths, root):
    values = {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(paths) if path.is_file()
    }
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest(), values


def prepare(name, compiler, ref, migrated, candidate_ref):
    fixture = FIXTURE_ROOT / name
    if fixture.exists():
        raise RuntimeError(f"Refusing to overwrite {fixture}")
    fixture.mkdir(parents=True)
    revision = run(
        ["git", "rev-parse", f"{ref or candidate_ref}^{{commit}}"], ROOT
    ).strip()
    for path in ("rescript.json",):
        (fixture / path).write_bytes(subprocess.check_output(
            ["git", "show", f"{revision}:{path}"], cwd=ROOT
        ))
    listing = run(["git", "ls-tree", "-r", "--name-only", revision, "--", "src"], ROOT)
    for name_in_repo in listing.splitlines():
        if Path(name_in_repo).suffix not in (".res", ".resi"):
            continue
        target = fixture / name_in_repo
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(subprocess.check_output(
            ["git", "show", f"{revision}:{name_in_repo}"], cwd=ROOT
        ))
    config_path = fixture / "rescript.json"
    config = json.loads(config_path.read_text())
    manifest = json.loads(subprocess.check_output(
        ["git", "show", f"{revision}:package.json"], cwd=ROOT
    ))
    dependencies = {"rescript": {"12": "12.3.1", "13": "13.0.0-alpha.7"}[compiler],
                    "react": "19.2.0", "react-dom": "19.2.0"}
    if migrated:
        dependencies["@rescript/webapi"] = manifest["dependencies"]["@rescript/webapi"]
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    (fixture / "package.json").write_text(json.dumps({
        "name": f"benchmark-{name}", "private": True, "dependencies": dependencies,
    }, indent=2) + "\n")
    run(["npm", "install", "--ignore-scripts", "--no-audit", "--no-fund"], fixture)
    if not migrated:
        config["dependencies"] = []
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    return fixture, revision


def build(fixture):
    binary = fixture / "node_modules" / ".bin" / "rescript"
    started = time.perf_counter_ns()
    log = run([str(binary), "build"], fixture)
    return (time.perf_counter_ns() - started) / 1_000_000, log


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--seed", type=int, default=20260417)
    parser.add_argument("--candidate-ref", default="HEAD")
    parser.add_argument("--output", default="benchmarks/results/current-30.json")
    args = parser.parse_args()
    if args.runs != 30:
        parser.error("The requested comparison requires exactly 30 runs per mode")
    prepared = {}
    for name, (compiler, ref, migrated) in CONFIGS.items():
        prepared[name] = prepare(name, compiler, ref, migrated, args.candidate_ref)
    result = {
        "method": "30 balanced randomized rounds; one warmup per fixture; clean, cached no-op, single-file edit",
        "seed": args.seed, "upstream_commit": UPSTREAM,
        "environment": {
            "platform": platform.platform(), "cpu_count": os.cpu_count(),
            "node": run(["node", "--version"], ROOT).strip(),
            "npm": run(["npm", "--version"], ROOT).strip(),
        },
        "candidate_commit": run(
            ["git", "rev-parse", f"{args.candidate_ref}^{{commit}}"], ROOT
        ).strip(),
        "configurations": {}, "samples": [], "warmups_ms": {},
    }
    fingerprints = {}
    for name, (compiler, ref, migrated) in CONFIGS.items():
        fixture, revision = prepared[name]
        paths = list((fixture / "src").rglob("*.res")) + list((fixture / "src").rglob("*.resi"))
        paths += [fixture / "rescript.json", fixture / "package.json",
                  fixture / "package-lock.json"]
        fingerprint, inputs = digest(paths, fixture)
        fingerprints[name] = fingerprint
        result["configurations"][name] = {
            "react_commit": revision, "compiler": COMPILER_VERSIONS[compiler],
            "input_sha256": fingerprint, "inputs": inputs,
            "config": json.loads((fixture / "rescript.json").read_text()),
            "package_lock_sha256": hashlib.sha256(
                (fixture / "package-lock.json").read_bytes()).hexdigest(),
        }
        elapsed, _ = build(fixture)
        result["warmups_ms"][name] = elapsed
    randomizer = random.Random(args.seed)
    order = list(CONFIGS)
    for round_number in range(1, args.runs + 1):
        randomizer.shuffle(order)
        for name in order:
            fixture, _ = prepared[name]
            edited = fixture / "src" / "ReactDOMStyle.res"
            original = edited.read_bytes()
            run([str(fixture / "node_modules/.bin/rescript"), "clean"], fixture)
            for mode in ("clean", "cached", "edit"):
                if mode == "clean":
                    run([str(fixture / "node_modules/.bin/rescript"), "clean"], fixture)
                elif mode == "edit":
                    edited.write_bytes(original + f"\nlet benchmarkIteration = {round_number}\n".encode())
                elapsed, log = build(fixture)
                result["samples"].append({
                    "round": round_number, "configuration": name,
                    "mode": mode, "ms": elapsed, "log": log,
                })
                print(f"{round_number:02d} {name} {mode}: {elapsed:.2f} ms", flush=True)
                if mode == "edit":
                    edited.write_bytes(original)
    for name in CONFIGS:
        fixture, _ = prepared[name]
        paths = list((fixture / "src").rglob("*.res")) + list((fixture / "src").rglob("*.resi"))
        paths += [fixture / "rescript.json", fixture / "package.json",
                  fixture / "package-lock.json"]
        if digest(paths, fixture)[0] != fingerprints[name]:
            raise RuntimeError(f"Inputs changed during timed runs: {name}")
    summary = {}
    for name in CONFIGS:
        summary[name] = {}
        for mode in ("clean", "cached", "edit"):
            values = [s["ms"] for s in result["samples"]
                      if s["configuration"] == name and s["mode"] == mode]
            summary[name][mode] = {
                "n": len(values), "median_ms": statistics.median(values),
                "mean_ms": statistics.mean(values), "min_ms": min(values),
                "max_ms": max(values), "stdev_ms": statistics.stdev(values),
                "median_95ci_bootstrap_ms": bootstrap_median_ci(values, args.seed),
            }
    result["summary"] = summary
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    FIXTURE_TEMP.cleanup()


def bootstrap_median_ci(values, seed):
    rng = random.Random(seed)
    medians = sorted(statistics.median(rng.choices(values, k=len(values))) for _ in range(10000))
    return [medians[249], medians[9749]]


if __name__ == "__main__":
    main()
