# Contributing to EdgeDeck

Thanks for taking the time to improve EdgeDeck. This project runs on memory- and
CPU-constrained EdgeTX radios, so small, boring changes are usually better than
large rewrites.

## Development Setup

Install Lua 5.4 locally if available. The widget is written for EdgeTX Lua, so a
desktop Lua check only catches syntax errors; final behavior still needs the
EdgeTX simulator or a radio.

Basic syntax check:

```sh
lua -e 'assert(loadfile("EdgeDeck/main.lua")); assert(loadfile("EdgeDeck/qrgen.lua"))'
```

Avoid compiling `EdgeDeck/main.lua` into `main.luac` as part of normal
development. The radio loads `/WIDGETS/EdgeDeck/main.lua` directly, and bytecode
can vary by Lua build.

## Project Layout

- `EdgeDeck/main.lua` contains the EdgeTX widget UI, telemetry handling,
  logging, alerts, GPS save logic, and configuration.
- `EdgeDeck/qrgen.lua` contains the incremental QR generator used by the GPS
  tab.
- `README.md` is the user-facing guide.
- `README_technical.md` is the maintainer-facing guide.
- `examples/` contains sanitized examples of runtime files created on the radio.

## Runtime Files

The radio creates these files in the widget folder:

- `sessions.log`
- `gps_last.txt`

They can contain flight history and coordinates, so they should not be committed.
Use the files in `examples/` when documenting formats or testing parsers.

## Pull Requests

Before opening a pull request:

- Run the Lua syntax check above.
- Test in the EdgeTX simulator when the change affects UI, touch, paging, QR, or
  telemetry display.
- Test on a radio when the change touches CPU-heavy paths, LVGL scrolling,
  physical keys, logging, or QR generation.
- Keep unrelated refactors out of feature or bug-fix patches.
- Update `README.md`, `README_technical.md`, or `CHANGELOG.md` when behavior
  changes.

## Coding Notes

- Keep configurable values in the top-level `CFG` table where practical.
- Prefer defensive `pcall` guards around EdgeTX APIs that may vary by firmware.
- Avoid periodic full UI rebuilds; they are much more expensive on the radio
  than in the simulator.
- Avoid adding dependencies. The radio cannot install packages at runtime.
- Keep QR generation incremental so it does not hit EdgeTX CPU limits.
