#!/usr/bin/env python3
"""Check downstream type interoperability and transitive feature exclusion."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT / "node_modules" / ".bin" / "rescript"


def build(fixture):
    result = subprocess.run(
        [str(COMPILER), "build"], cwd=fixture, capture_output=True, text=True
    )
    return result.returncode, result.stdout + result.stderr


def prepare(fixture):
    (fixture / "src").mkdir()
    packages = fixture / "node_modules" / "@rescript"
    packages.mkdir(parents=True)
    (packages / "react").symlink_to(ROOT, target_is_directory=True)
    (packages / "webapi").symlink_to(
        (ROOT / "node_modules" / "@rescript" / "webapi").resolve(), target_is_directory=True
    )
    write_config(fixture, [])
    (fixture / "package.json").write_text('{"name":"webapi-react-consumer-check","private":true}\n')
    shutil.copy(ROOT / "benchmarks" / "consumer" / "ReactOnly.res", fixture / "src")


def write_config(fixture, extra_dependencies):
    config = {
        "name": "webapi-react-consumer-check",
        "sources": ["src"],
        "jsx": {"version": 4},
        "dependencies": ["@rescript/react", *extra_dependencies],
        "package-specs": {"module": "esmodule", "in-source": True},
        "suffix": ".res.js",
    }
    (fixture / "rescript.json").write_text(json.dumps(config, indent=2) + "\n")


def assert_narrow_inventory():
    library = ROOT / "node_modules" / "@rescript" / "webapi" / "lib" / "bs"
    for module in ("Window", "Document", "OffscreenCanvas"):
        if list(library.rglob(f"{module}-WebAPI.cmj")):
            raise RuntimeError(f"Excluded {module} compiler artifact is still present")


def require_build(fixture, description):
    code, log = build(fixture)
    if code:
        raise RuntimeError(f"{description}:\n{log}")
    print(f"PASS: {description}")


def verify(fixture):
    require_build(fixture, "downstream consumer builds with only @rescript/react")
    assert_narrow_inventory()
    config = json.loads((ROOT / "rescript.json").read_text())
    dependency = next(dep for dep in config["dependencies"] if dep["name"] == "@rescript/webapi")
    write_config(fixture, [dependency])
    shutil.copy(ROOT / "benchmarks" / "consumer" / "Interop.res", fixture / "src")
    require_build(fixture, "narrow WebAPI types interoperate with React")
    window = {"name": "@rescript/webapi", "features": ["WebAPI.Window"]}
    for name, source, expanded in (
        ("Window", "ExcludedWindow.res", window),
        ("Document", "ExcludedDocument.res", window),
        ("OffscreenCanvas", "Excluded.res", "@rescript/webapi"),
    ):
        verify_exclusion(fixture, dependency, name, source, expanded)
    verify_window_consumer(fixture, dependency, window)


def verify_exclusion(fixture, dependency, module, source, expanded):
    excluded = fixture / "src" / source
    shutil.copy(ROOT / "benchmarks" / "consumer" / source, excluded)
    try:
        code, log = build(fixture)
        if code == 0 or module not in log or "can't be found" not in log:
            raise RuntimeError(f"Expected an excluded-module error, got:\n{log}")
        print(f"PASS: WebAPI.{module} is excluded by the narrow selection")
        write_config(fixture, [expanded])
        require_build(fixture, f"broader direct dependency enables WebAPI.{module}")
    finally:
        excluded.unlink()
        write_config(fixture, [dependency])
    require_build(fixture, f"narrow consumer recovers after {module} check")
    assert_narrow_inventory()


def verify_window_consumer(fixture, dependency, window):
    source = fixture / "src" / "WindowInterop.res"
    shutil.copy(ROOT / "benchmarks" / "consumer" / source.name, source)
    try:
        write_config(fixture, [window])
        require_build(fixture, "Window consumer retains Document, Window, History and Location interop")
    finally:
        source.unlink()
        write_config(fixture, [dependency])
    require_build(fixture, "narrow consumer recovers after Window interop check")
    assert_narrow_inventory()


def main():
    with tempfile.TemporaryDirectory(prefix=".webapi-consumer-", dir=ROOT / "node_modules") as path:
        fixture = Path(path)
        prepare(fixture)
        verify(fixture)


if __name__ == "__main__":
    main()
