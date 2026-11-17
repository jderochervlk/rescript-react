## @rescript/react

> The Official [ReScript](https://rescript-lang.org) Bindings for [ReactJS](https://react.dev/)

- [Introduction](https://rescript-lang.org/docs/react/latest/introduction)
- [Installation](https://rescript-lang.org/docs/react/latest/installation)

### Versions

| @rescript/react | ReScript                           | ReactJS | Documentation                                                     |
| --------------- | ---------------------------------- | ------- | ----------------------------------------------------------------- |
| 0.16.x          | 13.0+                              | 19      |     
| 0.15.x          | 12.0+                              | 19      |                                                                   |
| 0.14.x          | 11.0+ (JSX4 + uncurried mode only) | 19      |                                                                   |
| 0.12.x, 0.13.x  | 11.0+                              | 18      | [Link](https://rescript-lang.org/docs/react/latest/introduction)  |
| 0.11.0          | 10.1                               | 18      | [Link](https://rescript-lang.org/docs/react/v0.11.0/introduction) |
| 0.10.3          | 8.3                                | 16.8.1+ | [Link](https://rescript-lang.org/docs/react/v0.10.0/introduction) |

### Development

```
npm install

# Starts the ReScript compiler in watch mode
npm start
```

See [the WebAPI profiling report](benchmarks/README.md) for the built-in DOM
migration, build measurements, and local-link reproduction commands.

The intrinsic DOM props and ref types are owned by `ReactDOM`, not by the built-in
`JsxDOM` module. Use `ReactDOM.domProps`, `ReactDOM.domRef`, and the
`ReactDOM.Ref` helpers instead of explicitly annotating values with `JsxDOM` types.
Popover constructors now live here too, for example `ReactDOM.Auto` and `ReactDOM.Toggle`.
The separate `JsxDOMStyle` and `JsxEvent` aliases are not migrated yet.

Run the DOM props regression checks with Node.js and Python 3 available:

```sh
npm run test:dom-props
```

This checks the complete prop surface against the pinned compiler's definitions,
then builds a disposable consumer with the `JsxDOM` module removed from a private
runtime copy. It checks JSX and server-rendering behavior, plus rejection of
invalid props, styles, event handlers, and refs. Shared dependencies are not modified.

Event targets, native events, and FormData files now use WebAPI's core types.
`currentTarget` and UI/pointer `view` return options to handle absent values.
Clipboard data is an optional WebAPI DataTransfer, touch getters return
WebAPI TouchList values, and ReactDOM.FormData.t shares WebAPI.FormData.t's
identity. The narrow data features bring the WebAPI selection to 27 modules.
See [type migration notes](benchmarks/webapi-type-strengthening.md) for the
public type changes and remaining feature-isolation work.

### Acknowledgements

This project is the next evolution of the original [reason-react](https://github.com/reasonml/reason-react) bindings.
