# EdgeDeck — FPV dashboard widget for RadioMaster TX16S

A full-screen Lua widget for EdgeTX aimed at FPV pilots flying
ExpressLRS with a Betaflight (or iNav / EmuFlight) flight controller. It draws a
shadcn-inspired dark card layout and is driven entirely by CRSF/ELRS telemetry —
no switch or channel mapping required.

Five tabs, switched with the touch buttons across the top:

- **PRE** — pre-flight check: ARMED/DISARMED banner with flight mode, PACK
  (voltage + cell count + per-cell), LINK (LQ + power/rate), RSSI, GPS status
  (satellite count + altitude / ground speed / distance), and a big GO / CHECK
  readiness indicator.
- **FLY** — live dashboard: flight timer, arm state, mode, current; a LINK card
  (LQ + RSSI heroes, session min LQ/RSSI, TX power, packet rate); a
  PACK card (voltage + cell count + per-cell); a session-stats strip (mAh, max
  current, max altitude/speed, min pack V); a 60-second LQ sparkline; telemetry
  status; and a MUTE button.
- **STAT** — current battery session totals: flight time, mAh used, max current,
  min pack V, min LQ / RSSI, max altitude / speed / distance (GPS auto-detected),
  plus a RESET SESSION button.
- **LOG** — flight log persisted to the SD card. One entry per battery cycle,
  newest first, paginated. Tap a row (or click the rotary wheel) to open a detail
  view with every recorded metric.
- **GPS** — live coordinate view with last-saved coordinates and an offline QR
  code for the last saved position.

## Requirements

- RadioMaster TX16S / TX16S MK2 at 480×272 with **EdgeTX 2.11 or newer**.
- RadioMaster TX16S MK3 at 800×480 with **stable EdgeTX 2.12.0 or newer** and
  matching `c800x480` SD-card contents. Early MK3 factory and pre-release 2.12
  builds predate important Lua/LVGL object-creation and callback-reference fixes.
- The widget uses the LVGL-for-Lua API. On older firmware it renders nothing but
  an "EdgeTX 2.11+ required" message; upgrade first.
- An ExpressLRS TX module with a bound receiver, so telemetry sensors exist.
- A flight controller sending CRSF telemetry. Arm detection and the mode label
  work best with Betaflight's `FM` flight-mode sensor (see below).

## Install

1. Open the radio SD card using USB storage mode or a card reader.
2. Copy the `EdgeDeck` folder from this repository into the SD card's
   `/WIDGETS/` folder.
3. The final radio SD-card path should look like this:

   ```text
   /WIDGETS/EdgeDeck/main.lua
   /WIDGETS/EdgeDeck/qrgen.lua
   ```

4. Re-insert the card or exit USB storage mode.
5. Long-press a screen → **Edit** → tap an empty zone → choose **EdgeDeck**.
6. For the full five-tab dashboard, run it full screen (long-press the widget →
   "Full screen", or place it on a layout with one large zone). In a smaller zone
   it falls back to a compact focus view (arm/mode, pack, link, telemetry).

For upgrades, copy the repository's `EdgeDeck` folder over
`/WIDGETS/EdgeDeck/`. Runtime files such as `sessions.log` and `gps_last.txt`
can be left in place.

Only the `EdgeDeck` folder is needed on the radio. Repository files such as
`README.md`, `examples/`, and `.github/` are for development and do not need to
be copied to the SD card.

## Telemetry sensors used

Discover sensors first via **MDL → Telemetry → Discover new sensors** with the
model powered on. The widget reads these names (missing sensors degrade to
`0` / `--` rather than crashing):

| Field        | Sensor              | Notes                                            |
| ------------ | ------------------- | ------------------------------------------------ |
| Uplink LQ    | `RQly`              | Link quality (%); also used as the live-link flag |
| RSSI         | `1RSS` / `2RSS` / `RSSI` | First non-zero is used, in dBm              |
| TX power     | `TPWR`              | mW                                               |
| Packet rate  | `RFMD`              | ELRS rate *index*, translated to Hz internally   |
| Current      | `Curr`              | Amps; also a fallback arm signal                 |
| Consumption  | `Capa`              | mAh used; also detects FC reboots / battery swaps |
| Pack voltage | `RxBt`              | Receiver/pack voltage                            |
| Flight mode  | `FM`                | Betaflight mode string (drives arm + mode label) |
| TX battery   | `tx-voltage`        | Radio internal battery (read via `getValue`)     |
| GPS          | `GPS` or Lat/Lon variants / `Sats` / `GAlt` or `Alt` / `GSpd` / `Dist` | Coordinates, satellite count, altitude, speed, distance |

## How "armed" detection works

The widget prefers Betaflight's CRSF `FM` flight-mode sensor, which reports a
string such as `AIR` (armed acro), `AIR*` (disarmed acro — the trailing `*` is
the disarmed marker), `STAB`/`STAB*`, `WAIT`, `!FS!`, etc. The rules:

- trailing `*` → disarmed,
- a `!` anywhere → failsafe / error,
- `WAIT` → not armed,
- otherwise → armed.

To make the `FM` sensor available, set Betaflight to native CRSF telemetry, then
re-discover sensors on the radio:

```
BF Configurator → CLI:  set crsf_telemetry_mode = NATIVE
                        save
Radio → Model → Telemetry → Discover new sensors
```

If no `FM` sensor is present, the widget falls back to motor current: it treats
the craft as armed when `Curr` exceeds 1 A. The mode label shows the cleaned-up
`FM` string (e.g. `AIR`→`ACRO`, `STAB`/`ANGL`→`ANGLE`, `HOR`→`HORIZ`), or `----`
when no mode telemetry is available.

## Battery handling

Pack health is derived from **per-cell voltage**, not from mAh or a voltage
curve — both are too inaccurate under flight load. The cell count is auto-detected
from `RxBt` (1S–8S) and held stable across the flight, re-detecting only if the
per-cell drifts out of a sane range (battery swap). The PACK card shows total
voltage, cell count, and per-cell, color-coded against configured warning/critical
thresholds.

The **TX (radio) battery** uses the radio's own battery settings where EdgeTX
exposes them through `getGeneralSettings()`. Cell count is inferred from
`battMax`, warning comes from `battWarn`, and critical is derived as 0.10 V/cell
below warning. If those fields are unavailable, the fallback values in
`CFG.battery` are used. Percentage still comes from the configured battery range
and the Li-Ion discharge curve.

## Flight log (LOG tab)

Sessions are stored in `/WIDGETS/EdgeDeck/sessions.log` as compact CSV, one
snapshot per line, with the newest entries written first. The file is created in
the widget folder if it is missing. A
**session = one battery cycle**: it opens on the first arm after the FC powers up
and spans every arm/disarm in between as a single entry. It's finalized (and
re-saved) on each disarm, and closed when an FC reboot is detected (a battery
swap) or telemetry is lost for ~30 s. Sessions that were never armed are
discarded. The LOG tab reads one page of rows at a time and shows a next-page
indicator instead of relying on a full-file count.

Each entry records duration, mAh used, min LQ / RSSI, min pack voltage, max
current, max altitude / speed / distance, max TX power, packet rate, and the
first-arm latitude/longitude when a coordinate fix is available.

The repository keeps sanitized examples in `examples/`. Live `sessions.log`
files should stay local because they can contain private flight history.

## GPS coordinates (GPS tab)

Coordinates are read from the `GPS` telemetry sensor and normalized defensively
for decimal-degree or scaled integer values. The widget auto-saves the latest
valid coordinate about every 2 seconds to the first writable path among
`/WIDGETS/EdgeDeck/gps_last.txt`, `/MODELS/`, `/SCRIPTS/`, `/LOGS/`.

Live `gps_last.txt` files should stay local because they may contain a real
coordinate. Use `examples/gps_last.example.txt` for documentation and parser
tests.

The QR view is generated offline in Lua by `EdgeDeck/qrgen.lua`, which must be
installed beside `EdgeDeck/main.lua`. It encodes compact `lat,lon` text for the
last saved latitude/longitude and renders the QR modules as LVGL rectangles, so
no network or web API is needed on the radio.

QR generation is incremental across refresh ticks to stay under the EdgeTX CPU
limit. Opening the QR view freezes the current saved coordinate into a build job;
new autosaved coordinates do not change the displayed QR until the QR view is
closed and opened again.

## Configurable options

Widget settings expose these options (long-press the widget → **Edit**).

| Option        | Default | Meaning                                                |
| ------------- | ------- | ------------------------------------------------------ |
| `AccentColor` | theme focus | Accent color for the active tab and highlights     |
| `LQ_Warn`     | 80      | LQ % at/below which link quality turns yellow          |
| `LQ_Crit`     | 50      | LQ % at/below which it turns red                       |
| `RSSI_Warn`   | -98     | RSSI dBm at/below which RSSI turns yellow (more negative is worse) |
| `RSSI_Crit`   | -103    | RSSI dBm at/below which it turns red                   |
| `CellV_Warn`  | 350     | Per-cell warning, in **centivolts** (350 = 3.50 V); also the GO/CHECK threshold |
| `CellV_Crit`  | 330     | Per-cell critical, in centivolts (330 = 3.30 V)        |
| `Audio`       | 2       | 0 = silent, 1 = beeps + haptic only, 2 = beeps + voice callouts |
| `AutoTab`     | 0       | 1 = auto-switch tabs (FLY on arm, PRE on connect, STAT on link loss); 0 = tabs only change through manual input |

Notes:

- All numeric options are **integers** — EdgeTX's option keyboard has no decimal
  point, so per-cell voltages are entered in centivolts (×100).
- **Option order matters.** EdgeTX maps stored model values by position, so
  adding, removing, or reordering options shifts existing models' values into the
  wrong slots. Values should be re-entered after such an upgrade.
- Live value colors react immediately to the thresholds; audible/visible *alerts*
  require the condition to hold for ~5 s before they fire (avoids chirping on
  brief RF blips).
- LQ warning matches Betaflight's link-quality OSD alarm default. RSSI defaults
  are tuned for ExpressLRS 2.4 GHz 250Hz LoRa / RFMD 27 (-108 dBm sensitivity
  limit): warning is 10 dB above the limit and critical is 5 dB above it.
  Pack-voltage defaults follow Betaflight's per-cell warning and minimum-voltage
  defaults.

## Audio and voice alerts

With `Audio = 1` or `2`, warning conditions play a short beep + haptic pulse,
repeating roughly every 15 s; critical conditions play a stronger pulse repeating
every 5 s (2 s when more than one critical alert is active). With `Audio = 2` the
widget also speaks LQ percentage and pack voltage when those alerts are active,
and plays a tone when telemetry is lost while armed. The **MUTE** button on the
FLY tab silences everything for 30 seconds.

Alert sounds can be swapped by replacing the `playTone(...)` calls in `maybeBeep` with
`playFile("/SOUNDS/en/alert.wav")`.

## Touch and rotary interactions

- **PRE / FLY / STAT / LOG / GPS** buttons at the top — switch tabs.
- **MUTE** (FLY tab footer) — silence audio + voice alerts for 30 s.
- **RESET SESSION** (STAT tab) — clear the session min/max recorders and timer.
- **LOG list** — tap a row, or spin the rotary wheel to a row and click, to open
  its detail view. **PREV / NEXT** (or the page up/down keys) paginate.
- **BACK TO LIST** (LOG detail) or the EXIT key — return to the list.
- **QR / HIDE QR** (GPS tab footer) — toggle the QR view for the last saved
  coordinate.

When `AutoTab` is on, the widget auto-switches tabs on key events: to **FLY** on
arm, to **PRE** on battery connect, and to **STAT** after ~5 s of link loss. The
LOG and GPS tabs are never auto-switched to — they are manual only.
`AutoTab` defaults to 0, keeping tabs fixed until changed manually.

## Customizing the look

Most dashboard code lives in `EdgeDeck/main.lua`. Commonly changed values are
grouped in the top-level `CFG` table near the top of the file:

- `CFG.paths` for `sessions.log`, `gps_last.txt`, and the QR helper path.
- `CFG.telemetry` for sensor names, RFMD rate mapping, and FM display names.
- `CFG.battery`, `CFG.alerts`, `CFG.logging`, and `CFG.gps` for fallback
  thresholds, timings, paging, GPS save cadence, and QR build budget.
- `CFG.runtime`, `CFG.session`, `CFG.voice`, and `CFG.touch` for history
  sampling, session lifecycle thresholds, voice repeat timing, and touch
  debounce behavior.
- `CFG.layout`, `CFG.colors`, and `CFG.icons` for the visual system.

The layout entry points are clearly marked:

- `buildFullScreen(wgt)` dispatches to `buildPreflight` / `buildFlight` /
  `buildStats` / `buildLog` / `buildGps` — the full five-tab dashboard.
- `buildZone(wgt)` — the compact view used in a small widget zone.

`EdgeDeck/qrgen.lua` contains the standalone incremental QR builder used by the
GPS tab.

Full-screen builders use a 480-pixel-wide logical canvas. On 480×272 radios the
coordinates are used directly. On 800×480 radios the canvas becomes 480×288 and
the complete LVGL tree is uniformly scaled to physical pixels; touch coordinates
are mapped back to the same logical space. Compact mode continues to use the
actual `wgt.zone` dimensions.

The FLY sparkline retains 30 LVGL rectangle references on 480×272 radios and
updates them once per history sample. On 800×480 MK3-class radios the sparkline
is static (no post-build `lvgl.rectangle`, no live updates) because both paths
hard-fault some EdgeTX 2.12 H7 firmware builds. Full-screen MK3 startup also uses
a one-frame bootstrap screen before building the full FLY layout, which avoids
allocating the entire LVGL tree during widget registration.

## Troubleshooting

- **Blank screen / "EdgeTX 2.11+ required"** → upgrade EdgeTX.
- **TX16S MK3 crash / Emergency Mode** → use stable EdgeTX 2.12.0 or newer,
  install matching `c800x480` SD contents, and retest with the aircraft disarmed.
- **"EdgeDeck safe mode"** → the layout build threw an error. EdgeDeck displays
  the failed stage once and does not retry the unsafe build every refresh.
- **Need the last startup stage on hardware** → set
  `CFG.debug.startupTrace = true`, reproduce once, and read
  `/WIDGETS/EdgeDeck/debug.log`. Disable tracing afterward to avoid extra SD
  writes.
- **All values are 0 / `--`** → telemetry isn't being received. Check binding,
  antenna, and that the receiver has discovered sensors.
- **Arm state or mode is wrong** → the `FM` sensor isn't present. Set
  `crsf_telemetry_mode = NATIVE` in Betaflight and re-discover sensors; without
  it the widget falls back to motor current.
- **TX battery % or warning is wrong** → set the correct min/max and warning in
  **Radio Settings → Battery range** so cell count, percentage, and warning map
  correctly.
- **Alerts are too noisy** → set `Audio` to 0, or raise the thresholds.

## API reference

- LVGL for Lua: <https://luadoc.edgetx.org/lua-api-reference/lvgl-for-lua>
- Key/touch events: <https://luadoc.edgetx.org/lua-api-programming/using-key-and-touch-events>
- ELRS Lua telemetry: <https://www.expresslrs.org/software/lua-doc/>
