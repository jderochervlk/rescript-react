import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { renderToStaticMarkup } from "react-dom/server";

const fixture = process.argv[2];
const values = await import(pathToFileURL(path.join(fixture, "src/DomPropsChecks.res.js")).href);

assert.equal(values.empty.type, "div");
assert.equal(values.single.props.id, "single");
assert.equal(values.single.props.children, "child");
assert.equal(values.multiple.props.children.length, 2);
assert.equal(values.keyed.key, "one");
assert.equal(values.keyedMultiple.key, "many");
assert.equal(values.keyedMultiple.props.children.length, 2);
assert.equal(values.optionalKey(undefined).key, null);
assert.equal(values.optionalKey("optional").key, "optional");
assert.equal(values.spreadOnly.props.id, "base");
assert.equal(values.spreadOverride.props.id, "overridden");
assert.equal(values.spreadOverride.props.title, "kept");

assert.deepEqual(values.styled.props.style, { color: "red", marginTop: "2px", display: "block" });
assert.equal(values.styled.props["aria-label"], "example");
assert.equal(values.styled.props["aria-hidden"], true);
assert.equal(values.styled.props["data-testid"], "styled");
assert.equal(values.customStyle.props.style["--accent"], "blue");
assert.equal(values.svg.props.viewBox, "0 0 10 10");
assert.equal(values.svg.props.children.props.strokeWidth, "2");
assert.equal(values.popover.props.popover, "auto");
assert.equal(values.popover.props.popoverTargetAction, "toggle");
assert.equal(renderToStaticMarkup(values.rawHtml), "<div><b>raw</b></div>");
assert.match(renderToStaticMarkup(values.styled), /style="color:red;margin-top:2px;display:block"/);
assert.match(renderToStaticMarkup(values.styled), /aria-label="example"/);
assert.match(renderToStaticMarkup(values.svg), /stroke-width="2"/);

assert.equal(values.objectRef.current, null);
assert.equal(values.withObjectRef.props.ref, values.objectRef);
assert.equal(values.withCallbackRef.props.ref, values.callbackRef);
assert.equal(typeof values.callbackRef(null), "function");
assert.doesNotThrow(values.callbackRef({}));

for (const [element, handlerName] of [
  [values.clicked, "onClick"],
  [values.changed, "onChange"],
  [values.pointer, "onPointerDown"],
  [values.keyboard, "onKeyDown"],
  [values.focused, "onFocus"],
  [values.toggled, "onToggle"],
  [values.beforeToggle, "onBeforeToggleCapture"],
]) {
  const calls = [];
  element.props[handlerName]({ preventDefault: () => calls.push("prevented") });
  assert.deepEqual(calls, ["prevented"]);
}

const source = {};
assert.equal(values.toggleSource({ source }), source);
assert.equal(values.toggleSource({ source: null }), undefined);
assert.equal(values.toggleSource({}), undefined);
assert.deepEqual(values.toggleState({ oldState: "closed", newState: "open" }), ["closed", "open"]);

assert.equal(values.direct.props.id, "direct");
assert.equal(values.directKeyed.key, "direct-key");
assert.equal(values.directMany.props.children.length, 2);
assert.equal(values.directManyKeyed.key, "direct-many-key");
assert.equal(values.directManyKeyed.props.children.length, 2);
assert.equal(values.created.props.id, "created");
assert.equal(values.createdVariadic.props.id, "variadic");
assert.equal(values.created.props.children, values.single);
assert.equal(values.createdVariadic.props.children, values.single);

console.log("PASS: JSX props, styles, events, refs, keys, children, entry points, and SSR");
