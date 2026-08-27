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

Run the desktop EdgeTX/LVGL contract harness:

```sh
lua tests/edgetx_widget_harness.lua
```

The harness loads compact and full-screen layouts at 480×272 and 800×480,
switches through every tab, checks LVGL geometry and callback budgets, runs
repeated sparkline updates without rebuilding, and verifies the one-shot
safe-mode fallback. It does not replace Companion or hardware testing.

Avoid compiling `EdgeDeck/main.lua` into `main.luac` as part of normal
development. The radio loads `/WIDGETS/EdgeDeck/main.lua` directly, and bytecode
can vary by Lua build.

## Project Layout

- `EdgeDeck/main.lua` contains the EdgeTX widget UI, telemetry handling,
  logging, alerts, GPS save logic, and configuration.
- `EdgeDeck/qrgen.lua` contains the incremental QR generator used by the GPS
  tab.
- `tests/edgetx_widget_harness.lua` provides desktop startup and layout
  regression coverage for TX16S and TX16S MK3 dimensions.
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
- Run `lua tests/edgetx_widget_harness.lua`.
- Test in the EdgeTX simulator when the change affects UI, touch, paging, QR, or
  telemetry display. Use both TX16S 480×272 and TX16S MK3 800×480 profiles for
  shared full-screen code.
- Test on a radio when the change touches CPU-heavy paths, LVGL scrolling,
  physical keys, logging, or QR generation. Use stable EdgeTX 2.12.0 or newer
  for the TX16S MK3 and bench-test while disarmed.
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
