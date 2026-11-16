#!/usr/bin/env python3
"""Compile and run a real React consumer with the built-in JsxDOM unavailable."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
CASES = ROOT / "tests" / "dom-props"


def copy_sources(source, destination):
    destination.mkdir(parents=True)
    for name in ("package.json", "rescript.json"):
        shutil.copy(source / name, destination / name)
    for path in (source / "src").rglob("*"):
        if path.suffix in (".res", ".resi"):
            target = destination / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(path, target)


def prepare(fixture):
    packages = fixture / "node_modules"
    packages.mkdir()
    scoped = packages / "@rescript"
    scoped.mkdir()
    copy_sources(ROOT, scoped / "react")
    copy_sources((ROOT / "node_modules/@rescript/webapi").resolve(), scoped / "webapi")
    shutil.copytree(
        ROOT / "node_modules/@rescript/runtime", scoped / "runtime",
        ignore=shutil.ignore_patterns("JsxDOM.*"),
    )
    # The CLI resolves its runtime relative to itself, so it must not be a symlink
    # back to the shared compiler package and its intact runtime.
    shutil.copytree(ROOT / "node_modules/rescript", packages / "rescript")
    for name in ("react", "react-dom"):
        (packages / name).symlink_to((ROOT / "node_modules" / name).resolve(), target_is_directory=True)
    config = {
        "name": "react-dom-props-check",
        "sources": ["src"],
        "jsx": {"version": 4},
        "dependencies": [
            "@rescript/react",
            json.loads((ROOT / "rescript.json").read_text())["dependencies"][0],
        ],
        "package-specs": {"module": "esmodule", "in-source": True},
        "suffix": ".res.js",
    }
    (fixture / "rescript.json").write_text(json.dumps(config, indent=2) + "\n")
    (fixture / "package.json").write_text('{"name":"react-dom-props-check","private":true,"type":"module"}\n')
    (fixture / "src").mkdir()
    shutil.copy(CASES / "DomPropsChecks.res", fixture / "src")


def build(fixture):
    compiler = fixture / "node_modules/rescript/cli/rescript.js"
    result = subprocess.run(["node", str(compiler), "build"], cwd=fixture, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def require_build(fixture):
    code, log = build(fixture)
    if code:
        raise RuntimeError(f"Consumer compilation failed:\n{log}")


def verify_rejection(fixture, name, expected):
    target = fixture / "src" / name
    shutil.copy(CASES / name, target)
    try:
        code, log = build(fixture)
        if code == 0 or not all(text in log for text in expected):
            raise RuntimeError(f"Expected {name} rejection matching {expected}:\n{log}")
        print(f"PASS: expected rejection of {name}")
    finally:
        target.unlink()
    require_build(fixture)


def normalize_record(source):
    match = re.search(r"^type domProps = \{\n(.*?)^\}", source, flags=re.M | re.S)
    if not match:
        raise RuntimeError("Could not find the concrete domProps record")
    without_comments = re.sub(r"/\*.*?\*/|//[^\n]*", "", match[1], flags=re.S)
    return re.sub(r"\s+", "", without_comments)


def verify_prop_surface():
    original = (ROOT / "node_modules/@rescript/runtime/lib/ocaml/JsxDOM.res").read_text()
    expected = original.replace("JsxEvent.", "ReactEvent.").replace("Jsx.element", "React.element")
    actual = (ROOT / "src/ReactDOM.res").read_text().replace("Jsx.element", "React.element")
    if normalize_record(actual) != normalize_record(expected):
        raise RuntimeError("Local prop fields differ from the pinned runtime beyond ownership changes")
    if re.search(r"\bJsxDOM\b", re.sub(r"/\*.*?\*/|//[^\n]*", "", actual, flags=re.S)):
        raise RuntimeError("ReactDOM still references the built-in JsxDOM module")
    print("PASS: full pinned prop surface preserved with local type ownership")


def main():
    verify_prop_surface()
    with tempfile.TemporaryDirectory(prefix=".dom-props-", dir=ROOT / "node_modules") as directory:
        fixture = Path(directory)
        prepare(fixture)
        require_build(fixture)
        print("PASS: consumer and React sources compile without the JsxDOM interface")
        for name, expected in (
            ("ForbiddenJsxDOM.res", ("JsxDOM", "can't be found")),
            ("InvalidProp.res", ("definitelyNotAProp", "field")),
            ("InvalidStyle.res", ("int", "string")),
            ("InvalidEvent.res", ("Keyboard", "Mouse")),
            ("InvalidRef.res", ("int", "domRef")),
        ):
            verify_rejection(fixture, name, expected)
        subprocess.run(["node", str(CASES / "runtime.mjs"), str(fixture)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
