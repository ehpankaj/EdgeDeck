-- =============================================================================
-- EdgeDeck -- FPV dashboard for RadioMaster TX16S running EdgeTX 2.11+ / ELRS
-- Path on SD card: /WIDGETS/EdgeDeck/main.lua
--
-- Tabs:  PRE | FLY | STAT | LOG | GPS
-- Design: shadcn-inspired dark card layout with rounded corners.
-- Arm and flight mode are driven by Betaflight's CRSF "FM" telemetry sensor.
-- =============================================================================

-- ============================================================================
-- WIDGET OPTIONS (edit from the radio's widget settings page)
-- ============================================================================
-- All VALUE options are INTEGERS — EdgeTX's widget-option keyboard has no
-- decimal point. Per-cell voltages are entered in CENTIVOLTS (×100):
-- 350 for 3.50V, 330 for 3.30V, etc. The script divides by 100 at the
-- comparison site.
--
-- IMPORTANT: option ORDER matters. EdgeTX maps stored model values by
-- POSITION, not by name. Adding/removing/reordering options will shift
-- existing models' stored values to the wrong slots — re-enter values
-- after upgrading.
local options = {
  { "AccentColor",   COLOR, COLOR_THEME_FOCUS },
  -- Link thresholds (LQ in %, RSSI in dBm)
  { "LQ_Warn",       VALUE, 80,   0,   100 },
  { "LQ_Crit",       VALUE, 50,   0,   100 },
  { "RSSI_Warn",     VALUE, -98,  -130, 0   },
  { "RSSI_Crit",     VALUE, -103, -130, 0   },
  -- Drone pack per-cell voltage (centivolts — 350 = 3.50V).
  -- Live colors change immediately; audible alerts require a sustained hold.
  { "CellV_Warn",    VALUE, 350,  280,  420 },
  { "CellV_Crit",    VALUE, 330,  280,  420 },
  -- Audio enum: 0 = silent, 1 = beeps only, 2 = beeps + voice callouts
  { "Audio",         VALUE, 2,    0,    2 },
  -- Auto tab switching: 1 = on (jump to FLY on arm, PRE on connect, STAT on
  -- link loss), 0 = off (tabs only change through manual input).
  { "AutoTab",       VALUE, 0,    0,    1 },
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- Values that are likely to be customized are grouped here. QR generation stays
-- in qrgen.lua; the rest of the widget is intentionally kept in this file.
local CFG = {
  paths = {
    sessionLog = "/WIDGETS/EdgeDeck/sessions.log",
    gpsLastCandidates = {
      "/WIDGETS/EdgeDeck/gps_last.txt",
      "/MODELS/EdgeDeck_gps_last.txt",
      "/SCRIPTS/EdgeDeck_gps_last.txt",
      "/LOGS/EdgeDeck_gps_last.txt",
    },
    qrHelperCandidates = {
      "/WIDGETS/EdgeDeck/qrgen.lua",
      "qrgen.lua",
    },
  },

  telemetry = {
    txVoltage = "tx-voltage",
    rxBattery = "RxBt",
    uplinkLq = "RQly",
    rssi = { "1RSS", "2RSS", "RSSI" },
    txPower = "TPWR",
    rfMode = "RFMD",
    current = "Curr",
    capacity = "Capa",
    gpsSats = { "Sats", "Sat", "GPS Sats" },
    gpsAlt = { "GAlt", "Alt" },
    gpsSpeed = { "GSpd", "Gspd", "GPS Speed" },
    gpsDistance = { "Dist", "GPS Dist" },
    gpsPosition = { "GPS", "Gps", "gps", "GPSC", "GPos" },
    gpsLat = { "Lat", "LAT", "Latitude", "GLat", "GPSLat" },
    gpsLon = { "Lon", "LON", "Lng", "Longitude", "GLon", "GPSLon" },
    fm = { "FM", "Fm", "fm", "Mode", "FltMode", "FlMd", "FMod" },
    rfmdRate = {
      [0]  = 4,    [1]  = 25,   [2]  = 50,    [3]  = 100,   [4]  = 100,
      [5]  = 150,  [6]  = 200,  [7]  = 250,   [8]  = 333,   [9]  = 500,
      [10] = 1000,
    },
    fmDisplay = {
      AIR  = "ACRO",
      ACRO = "ACRO",
      STAB = "ANGLE",
      ANGL = "ANGLE",
      HOR  = "HORIZ",
      HRZN = "HORIZ",
      RTH  = "RTH",
      RT   = "RTH",
      WAIT = "WAIT",
      PASS = "PASS",
      ["FS"] = "FAILSAFE",
    },
  },

  battery = {
    -- TX values are fallbacks. Normal runtime uses EdgeTX battWarn/battMax.
    txCellWarn = 3.50,
    txCellCrit = 3.40,
    txCritDrop = 0.10,
    droneCellMin = 2.8,
    droneCellMax = 4.4,
    detectCellMin = 3.5,
    detectCellMax = 4.25,
    maxCells = 8,
    lionPct = {
      {4.20,100},{4.10, 90},{4.00, 80},{3.90, 70},{3.80, 60},
      {3.70, 50},{3.65, 40},{3.60, 30},{3.50, 20},{3.40, 10},
      {3.30,  5},{3.20,  0},
    },
  },

  logging = {
    pageSize = 10,
    maxSessions = 100,
    rowStep = 28,
    rowHeight = 22,
  },

  gps = {
    autosaveCs = 200,
    coordinatePrecision = 6,
    zeroThreshold = 0.000001,
    maxLat = 90,
    maxLon = 180,
    scaleLarge = 10000000,
    scaleMedium = 1000000,
    qrSize = 25,
    qrStepBudget = 8,
  },

  runtime = {
    centisPerSecond = 100,
    gcIntervalCs = 6000,
    historySamples = 60,
    historySampleCs = 100,
    fileReadChunk = 1024,
    minPersistedLineLen = 5,
    timestampLen = 15,
  },

  debug = {
    -- When true, overwrite this small marker at startup/build boundaries.
    -- It is intentionally off for normal use to avoid extra SD writes.
    startupTrace = false,
    startupTracePath = "/WIDGETS/EdgeDeck/debug.log",
  },

  session = {
    armCurrentA = 1.0,
    swapMinCapa = 30,
    swapResetCapa = 5,
    closeLossTicks = 300,
    forgetDisconnectedTicks = 20,
    statSwitchLossTicks = 50,
  },

  alerts = {
    none = 0,
    warn = 2,
    crit = 3,
    holdCs = 500,
    warningRepeatCs = 1500,
    criticalRepeatCs = 500,
    multiCriticalRepeatCs = 200,
    muteCs = 3000,
    warnPulseCount = 2,
    critPulseCount = 4,
    warnToneHz = 660,
    critToneHz = 880,
    pulseHapticMs = 25,
    pulseToneMs = 90,
    pulsePauseMs = 35,
  },

  voice = {
    lqRepeatCs = 500,
    packRepeatCs = 6000,
    telemetryLostRepeatCs = 1000,
    telemetryLostToneHz = 220,
    telemetryLostToneMs = 300,
  },

  touch = {
    tabStride = 60,
    tabWidth = 54,
    moveThreshold = 12,
    sameSpotPx = 8,
    sameSpotCs = 20,
    tapBlockCs = 40,
    rebuildBlockCs = 80,
  },

  layout = {
    radius = 8,
    pageMargin = 8,
    pageGap = 4,
    tabBarH = 40,
    flyStatusH = 30,
    flyCardsH = 100,
    flyStatsH = 46,
    flyFooterH = 34,
    cardPadX = 10,
    cardPadL = 12,
    cardPadR = 8,
  },

  colors = {
    bg       = lcd.RGB(0x0A, 0x0A, 0x10),
    card     = lcd.RGB(0x18, 0x18, 0x24),
    cardHi   = lcd.RGB(0x22, 0x22, 0x30),
    muted    = lcd.RGB(0x8A, 0x8A, 0xA0),
    text     = lcd.RGB(0xF0, 0xF0, 0xF5),
    qrLight  = lcd.RGB(0xFF, 0xFF, 0xFF),
    qrDark   = lcd.RGB(0x00, 0x00, 0x00),
    red      = lcd.RGB(0xEF, 0x44, 0x44),
    yellow   = lcd.RGB(0xF5, 0xB8, 0x1B),
    green    = lcd.RGB(0x22, 0xC5, 0x5E),
    blue     = lcd.RGB(0x3B, 0x82, 0xF6),
    redDim   = lcd.RGB(0x7F, 0x1D, 0x1D),
  },

  icons = {
    OK         = "\xEF\x80\x8C", -- F00C
    HOME       = "\xEF\x80\x95", -- F015
    REFRESH    = "\xEF\x80\xA1", -- F021
    MUTE       = "\xEF\x80\xA6", -- F026
    WARNING    = "\xEF\x81\xB1", -- F071
    PLAY       = "\xEF\x81\x8B", -- F04B
    UP         = "\xEF\x81\xB7", -- F077
    LEFT       = "\xEF\x81\x93", -- F053
    RIGHT      = "\xEF\x81\x94", -- F054
    WIFI       = "\xEF\x87\xAB", -- F1EB
    GPS        = "\xEF\x84\xA4", -- F124
    CHARGE     = "\xEF\x83\xA7", -- F0E7
    BAT_FULL   = "\xEF\x89\x80", -- F240
    BAT_3      = "\xEF\x89\x81", -- F241
    BAT_2      = "\xEF\x89\x82", -- F242
    BAT_1      = "\xEF\x89\x83", -- F243
    BAT_EMPTY  = "\xEF\x89\x84", -- F244
  },
}

-- The original TX16S uses a 480x272 logical canvas. The TX16S MK3 reports
-- 800x480; render that target through a 480x288 logical canvas and scale the
-- resulting LVGL geometry uniformly. Uniform scaling keeps circles and QR
-- modules square while using the whole MK3 screen.
local compat = {
  pixelW = (type(LCD_W) == "number" and LCD_W) or 480,
  pixelH = (type(LCD_H) == "number" and LCD_H) or 272,
}
compat.highRes = compat.pixelW >= 720 and compat.pixelH >= 400
compat.scale = compat.highRes and (compat.pixelW / 480) or 1
do
  -- EdgeTX 2.12+ hard-faults when callRefs evaluates many LVGL getter
  -- callbacks (PR #7119 class). Companion 2.11 sim still tolerates them.
  local maj, min = 2, 11
  if type(getVersion) == "function" then
    local ok, ver, _, m, n = pcall(getVersion)
    if ok then
      if type(m) == "number" then
        maj, min = m, (type(n) == "number" and n) or 0
      elseif type(ver) == "string" then
        local a, b = string.match(ver, "(%d+)%.(%d+)")
        if a then maj, min = tonumber(a), tonumber(b) or 0 end
      end
    end
  end
  compat.fwMajor = maj
  compat.fwMinor = min
  compat.staticLvgl = compat.highRes
    or maj > 2 or (maj == 2 and min >= 12)
end
local SCR_W = compat.highRes and 480 or compat.pixelW
local SCR_H = compat.highRes and math.floor(compat.pixelH / compat.scale + 0.5) or compat.pixelH

-- Local aliases keep the rendering code compact while editable values remain
-- easy to find in CFG above.
local BG       = CFG.colors.bg
local CARD     = CFG.colors.card
local CARD_HI  = CFG.colors.cardHi
local MUTED    = CFG.colors.muted
local TEXT     = CFG.colors.text
local QR_LIGHT = CFG.colors.qrLight
local QR_DARK  = CFG.colors.qrDark
local RED      = CFG.colors.red
local YELLOW   = CFG.colors.yellow
local GREEN    = CFG.colors.green
local BLUE     = CFG.colors.blue
local RED_DIM  = CFG.colors.redDim

local RADIUS       = CFG.layout.radius
local PAGE_MARGIN  = CFG.layout.pageMargin
local PAGE_GAP     = CFG.layout.pageGap
local TAB_BAR_H    = CFG.layout.tabBarH
local CONTENT_Y    = TAB_BAR_H + 2
local FLY_STATUS_H = CFG.layout.flyStatusH
local FLY_CARDS_H  = CFG.layout.flyCardsH
local FLY_STATS_H  = CFG.layout.flyStatsH
local FLY_FOOTER_H = CFG.layout.flyFooterH
local FLY_FOOTER_Y = SCR_H - PAGE_MARGIN - FLY_FOOTER_H
local CARD_PAD_X   = CFG.layout.cardPadX
local CARD_PAD_L   = CFG.layout.cardPadL
local CARD_PAD_R   = CFG.layout.cardPadR
local NO_SCROLL    = (lvgl and lvgl.SCROLL_NONE) or nil

-- LVGL bitmap fonts ship with a Font Awesome subset baked in. References use
-- their UTF-8 byte sequences in label text. If a glyph renders as a box on a
-- firmware build, swap the icon value in CFG.icons.
local SYM = CFG.icons

-- Battery icon by per-cell voltage. Five buckets covering the usable
-- LiPo range (4.20V full → 3.30V dead). Voltage-driven so it stays
-- meaningful even without an mAh capacity estimate.
local function batIcon(cv)
  if cv >= 4.00 then return SYM.BAT_FULL  end
  if cv >= 3.85 then return SYM.BAT_3     end
  if cv >= 3.70 then return SYM.BAT_2     end
  if cv >= 3.55 then return SYM.BAT_1     end
  return SYM.BAT_EMPTY
end

-- LCD dimensions: fall back if globals are missing on a given firmware build.
-- Page grid. Keep left/right gutters mathematically symmetric; hardware
-- padding issues should be fixed in the card layout, not by shifting the
-- entire screen.
local PAGE_X = PAGE_MARGIN
local PAGE_R = PAGE_MARGIN
local PAGE_W = SCR_W - PAGE_X - PAGE_R
local LOG_PAGE_SIZE = CFG.logging.pageSize
local QR_SIZE = CFG.gps.qrSize
-- LOG_ROW_STEP is the y stride from one row to the next. LOG_ROW_H is the
-- native row button height; any difference between them becomes row gap.
local LOG_ROW_STEP = CFG.logging.rowStep
local LOG_ROW_H    = CFG.logging.rowHeight

-- ============================================================================
-- PERSISTENT STATE
-- ============================================================================
local state = {
  tab          = 1,        -- 0=Preflight  1=Flight  2=Stats  3=Log  4=GPS
  cellCount    = 0,
  armed        = false,
  armSince     = 0,
  flightSecs   = 0,
  muteUntil    = 0,
  history      = {},
  histN        = CFG.runtime.historySamples,
  lastSample   = 0,
  stats = { minLQ=nil, minRSSI=nil, minPackV=nil, maxCurr=0, maxAlt=0, maxSpd=0, maxDist=0 },
  lastVoice = { lq=0, batt=0, tlost=0 },
  dirty = true,
  layoutError = nil,
  layoutErrorStage = nil,
  _lastHash = "",
  _lastBeep = 0,
  droneSeen = false,
  -- Session tracking. A "session" = single battery cycle, from first arm
  -- after FC power-up until FC powers down. Multiple arm/disarm cycles
  -- within one battery are accumulated into a SINGLE log entry.
  currentSession = nil,    -- table while a session is being recorded
  sessions       = nil,    -- lazy-loaded cache from session log file
  logPage        = 1,      -- pagination cursor for the LOG tab
  logCursor      = nil,    -- 1..N focused row index on LOG list (nil = inactive)
  logPageHasNext = false,  -- has-next state from the rendered LOG page
  logPageChecked = nil,    -- page number that logPageHasNext belongs to
  selectedSess   = nil,    -- session table shown in LOG detail view
  gps = {
    loaded       = false,
    liveLat      = nil,
    liveLon      = nil,
    savedLat     = nil,
    savedLon     = nil,
    savedTs      = nil,
    savedSats    = nil,
    lastSaveAt   = 0,
    showQr       = false,
    qrPayload    = nil,
    qrRows       = nil,
    qrLat        = nil,
    qrLon        = nil,
    qrTs         = nil,
    qrErr        = nil,
    qrBuildPending = false,
    qrJob        = nil,
  },
  prevCapa       = 0,      -- tracks Capa to detect FC reboot
  _lastTouchAt   = 0,
  _lastTouchX    = -9999,
  _lastTouchY    = -9999,
  _touchBlockUntil = 0,
  -- True after a tap was consumed, until a refresh tick arrives with NO
  -- touch event (= finger lifted). This is the finger-press-aware version
  -- of the touch block: time-based windows fail when the finger is held
  -- longer than the window, but a "wait for finger up" sentinel can never
  -- be skipped no matter how long the press lasts.
  _eatingTouch     = false,
}
for i = 1, state.histN do state.history[i] = 0 end

-- ============================================================================
-- SAFE WRAPPERS (no callback can ever crash the widget)
-- ============================================================================
local function safeStr(fn, fb)
  return function()
    local ok, v = pcall(fn); if ok and v ~= nil then return v end
    return fb or "--"
  end
end
local function safeColor(fn, fb)
  return function()
    local ok, v = pcall(fn); if ok and v ~= nil then return v end
    return fb or MUTED
  end
end

function compat.shortError(err)
  local s = tostring(err or "unknown error")
  -- EdgeTX Lua strings do not support method-call syntax (s:gsub); use
  -- string.* and plain literal patterns instead of character-class escapes.
  s = string.gsub(s, "\r", " ")
  s = string.gsub(s, "\n", " ")
  if string.len(s) > 96 then s = string.sub(s, 1, 93) .. "..." end
  return s
end

function compat.traceStartup(stage, detail)
  if not CFG.debug.startupTrace then return end
  local line = "EdgeDeck " .. tostring(stage)
  if detail ~= nil then line = line .. ": " .. compat.shortError(detail) end
  if type(print) == "function" then pcall(print, line) end
  pcall(function()
    local f = io.open(CFG.debug.startupTracePath, "a")
    if not f then return end
    io.write(f, line .. "\n")
    io.close(f)
  end)
end

-- MK3 (800x480) firmware hard-faults when callRefs evaluates many LVGL getter
-- callbacks (EdgeTX PR #7119 class of bug). Build with static label values and
-- push live telemetry through named label:set() in refresh instead.
function compat.mk3Eval(fn, fb)
  local ok, v = pcall(fn)
  if ok and v ~= nil then return v end
  return fb
end

function compat.mk3BeginBuild(wgt)
  if not compat.staticLvgl or not wgt then return end
  compat._mk3BuildWgt = wgt
  wgt._mk3Dyn = {}
  compat._mk3DynSeq = 0
end

function compat.mk3Track(textFn, colorFn)
  local wgt = compat._mk3BuildWgt
  if not wgt then return nil end
  compat._mk3DynSeq = (compat._mk3DynSeq or 0) + 1
  local name = "m" .. compat._mk3DynSeq
  wgt._mk3Dyn[name] = { textFn = textFn, colorFn = colorFn }
  return name
end

function compat.noteLayoutBuilt(wgt, full)
  if not wgt then return end
  wgt._builtTab = state.tab
  wgt._builtFull = full
  wgt._builtLogSel = state.selectedSess
  wgt._builtLogPage = state.logPage
  wgt._builtGpsQr = state.gps.showQr
end

function compat.mk3NeedsRebuild(wgt, full)
  if wgt._builtFull ~= full then return true end
  if wgt._builtTab ~= state.tab then return true end
  if state.tab == 3 then
    if wgt._builtLogSel ~= state.selectedSess then return true end
    if (wgt._builtLogPage or 1) ~= (state.logPage or 1) then return true end
  end
  if state.tab == 4 and wgt._builtGpsQr ~= state.gps.showQr then return true end
  return false
end

function compat.refreshMk3Dynamics(wgt)
  if not compat.staticLvgl or not wgt or not wgt.ui or not wgt._mk3Dyn then return end
  for name, spec in pairs(wgt._mk3Dyn) do
    local obj = wgt.ui[name]
    if obj and type(obj.set) == "function" then
      local upd = {}
      if spec.textFn then
        local ok, v = pcall(spec.textFn)
        if ok and v ~= nil then upd.text = v end
      end
      if spec.colorFn then
        local ok, v = pcall(spec.colorFn)
        if ok and v ~= nil then upd.color = v end
      end
      if next(upd) ~= nil then pcall(obj.set, obj, upd) end
    end
  end
end

-- ============================================================================
-- TELEMETRY HELPERS
-- ============================================================================
local function nameList(names)
  if type(names) == "table" then return names end
  return { names }
end

local function hasTelemetryField(names)
  for _, name in ipairs(nameList(names)) do
    if type(getFieldInfo) == "function" then
      local ok, info = pcall(getFieldInfo, name)
      if ok and type(info) == "table" and info.id then return true end
    end
    local ok, v = pcall(getValue, name)
    if ok and v ~= nil and v ~= 0 and v ~= "" then return true end
  end
  return false
end

local function readTelemetryValue(name)
  if name == nil then return nil end
  local ok, v = pcall(getValue, name)
  if ok and v ~= nil and v ~= 0 and v ~= "" then return v end
  if type(getFieldInfo) == "function" then
    local ok2, info = pcall(getFieldInfo, name)
    if ok2 and type(info) == "table" and info.id then
      local ok3, v2 = pcall(getValue, info.id)
      if ok3 and v2 ~= nil then return v2 end
    end
  end
  if ok then return v end
  return nil
end

local function getNum(name, def)
  local v = readTelemetryValue(name)
  if type(v) == "number" then return v end
  return def or 0
end

local function getNumAny(names, def)
  for _, name in ipairs(nameList(names)) do
    local v = readTelemetryValue(name)
    if type(v) == "number" and v ~= 0 then return v end
  end
  return def or 0
end

local function txVoltage() return getNum(CFG.telemetry.txVoltage, 0) end
local function rxBat()  return getNum(CFG.telemetry.rxBattery, 0) end
local function lq()     return getNum(CFG.telemetry.uplinkLq, 0) end
local function rssiVal() return getNumAny(CFG.telemetry.rssi, 0) end
local function txPwr()  return getNum(CFG.telemetry.txPower, 0) end
local function rfMode() return getNum(CFG.telemetry.rfMode, 0) end
local function curr()   return getNum(CFG.telemetry.current, 0) end
local function capa()   return getNum(CFG.telemetry.capacity, 0) end
-- GPS telemetry. Sensor names vary slightly across EdgeTX/CRSF builds, so a
-- couple of spellings are tried for satellite count. GAlt/GSpd/Dist are the same
-- sensors the session-stats recorder samples.
local function gpsSats() return getNumAny(CFG.telemetry.gpsSats, 0) end
local function gpsAlt()  return getNumAny(CFG.telemetry.gpsAlt, 0) end
local function gpsSpd()  return getNumAny(CFG.telemetry.gpsSpeed, 0) end
local function gpsDist() return getNumAny(CFG.telemetry.gpsDistance, 0) end
local function readTelemetryAny(names)
  for _, name in ipairs(nameList(names)) do
    local v = readTelemetryValue(name)
    if v ~= nil and v ~= 0 and v ~= "" then return v, name end
  end
  return nil, nil
end

local function coordNumber(v)
  if type(v) == "table" then
    return coordNumber(v.value or v.val or v[1])
  end
  if type(v) == "string" then
    return coordNumber(tonumber(v))
  end
  if type(v) ~= "number" then return nil end
  local a = math.abs(v)
  if a <= CFG.gps.maxLon then return v end
  local scaled = v / CFG.gps.scaleLarge
  if math.abs(scaled) <= CFG.gps.maxLon then return scaled end
  scaled = v / CFG.gps.scaleMedium
  if math.abs(scaled) <= CFG.gps.maxLon then return scaled end
  return nil
end

local function parseCoordPair(s)
  if type(s) ~= "string" then return nil, nil end
  local nums = {}
  for n in string.gmatch(s, "[-+]?%d+%.?%d*") do
    nums[#nums + 1] = tonumber(n)
    if #nums >= 2 then break end
  end
  if #nums < 2 then return nil, nil end
  return coordNumber(nums[1]), coordNumber(nums[2])
end

local function gpsCoord()
  local v = readTelemetryAny(CFG.telemetry.gpsPosition)
  local lat, lon = nil, nil
  if type(v) == "table" then
    lat = coordNumber(v.lat or v.Lat or v.latitude or v.Latitude or v[1])
    lon = coordNumber(v.lon or v.Lon or v.lng or v.Lng
                     or v.longitude or v.Longitude or v[2])
  elseif type(v) == "string" then
    lat, lon = parseCoordPair(v)
  else
    local latRaw = readTelemetryAny(CFG.telemetry.gpsLat)
    local lonRaw = readTelemetryAny(CFG.telemetry.gpsLon)
    lat = coordNumber(latRaw)
    lon = coordNumber(lonRaw)
  end
  if not lat or not lon then return nil end
  if math.abs(lat) > CFG.gps.maxLat or math.abs(lon) > CFG.gps.maxLon then return nil end
  if math.abs(lat) < CFG.gps.zeroThreshold
     and math.abs(lon) < CFG.gps.zeroThreshold then return nil end
  return { lat = lat, lon = lon, sats = gpsSats() }
end

local function gpsSensorsConfigured()
  return hasTelemetryField(CFG.telemetry.gpsPosition)
    or hasTelemetryField(CFG.telemetry.gpsSats)
    or hasTelemetryField(CFG.telemetry.gpsAlt)
    or hasTelemetryField(CFG.telemetry.gpsSpeed)
    or hasTelemetryField(CFG.telemetry.gpsDistance)
end

local linkUp

-- True when GPS telemetry is active enough to show values. A stationary quad can
-- legitimately report 0 speed/distance, so configured GPS sensors plus an active
-- link should still be shown while the coordinate fix is acquiring.
local function gpsPresent()
  return gpsSats() > 0 or gpsAlt() ~= 0 or gpsSpd() ~= 0 or gpsDist() ~= 0
    or gpsCoord() ~= nil or (linkUp() and gpsSensorsConfigured())
end

function linkUp()
  local v = getValue(CFG.telemetry.uplinkLq)
  return type(v) == "number" and v > 0
end

-- ELRS RFMD is the packet-rate INDEX, not Hz. Unknown indices fall back to the
-- raw value with no translation.
local function rfModeHz()
  local idx = rfMode()
  return CFG.telemetry.rfmdRate[idx] or idx
end

local function clockStr()
  local ok, d = pcall(getDateTime)
  if ok and type(d) == "table" and d.hour and d.min then
    return string.format("%02d:%02d", d.hour, d.min)
  end
  return "--:--"
end

-- Option lookup with nil-guard so callbacks never crash even if a saved
-- model doesn't yet have these option keys (e.g. after upgrading).
local function opt(wgt, key, default)
  if wgt and wgt.options and wgt.options[key] ~= nil then return wgt.options[key] end
  return default
end

-- Betaflight CRSF telemetry sensor "FM" reports the actual flight mode string.
-- Observed examples:
--   "AIR"   = armed acro
--   "AIR*"  = DISARMED acro  (trailing '*' is the disarmed marker)
--   "STAB"  = armed self-level
--   "STAB*" = disarmed self-level
--   "ANGL", "HOR", "WAIT", "!FS!", "!ERR" etc.
--
-- The convention is: TRAILING '*' means motors disarmed. Leading or wrapped
-- '!' indicates failsafe / error. Discover the sensor on the radio first:
--   BF Configurator → CLI: set crsf_telemetry_mode = NATIVE; save
--   Radio → Model → Telemetry → Discover sensors

-- Telemetry sensor read with fallbacks. EdgeTX recommends using
-- getFieldInfo(name) to resolve a sensor to its numeric id, then
-- getValue(id) to read it — direct getValue(name) doesn't always work for
-- string sensors. We try several spellings and both lookup styles.
local function readSensor(names)
  for _, name in ipairs(names) do
    -- 1) direct name lookup
    local ok, v = pcall(getValue, name)
    if ok and type(v) == "string" and v ~= "" then return v, name end
    if ok and type(v) == "number" and v ~= 0 then return tostring(v), name end
    -- 2) field-info → id lookup (more reliable for string sensors)
    local ok2, info = pcall(getFieldInfo, name)
    if ok2 and type(info) == "table" and info.id then
      local ok3, v2 = pcall(getValue, info.id)
      if ok3 and type(v2) == "string" and v2 ~= "" then return v2, name end
      if ok3 and type(v2) == "number" and v2 ~= 0 then return tostring(v2), name end
    end
  end
  return nil, nil
end

local function fmRaw()
  return readSensor(CFG.telemetry.fm)
end

-- Strip any of the disarmed/failsafe decorator characters out of a string.
-- Implemented as a manual char loop to avoid Lua patterns entirely — some
-- EdgeTX Lua builds throw on certain pattern escapes.
local function stripDecorators(s)
  if type(s) ~= "string" then return "" end
  local out = {}
  for i = 1, #s do
    local c = string.sub(s, i, i)
    if c ~= "*" and c ~= "!" and c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      out[#out + 1] = c
    end
  end
  return table.concat(out)
end

-- Char-by-char "does s contain ch?" check (no patterns, no string.find).
local function containsChar(s, ch)
  if type(s) ~= "string" then return false end
  for i = 1, #s do
    if string.sub(s, i, i) == ch then return true end
  end
  return false
end

-- True iff the FM sensor indicates the FC is armed. Returns nil when the
-- sensor is not available (caller falls back to current/switch logic).
-- Zero Lua patterns used anywhere in this path.
local function fmIsArmed()
  local raw = fmRaw()
  if raw == nil then return nil end
  if type(raw) ~= "string" then return nil end
  if #raw == 0 then return false end
  -- Trailing '*' = motors disarmed (canonical BF convention)
  if string.sub(raw, -1) == "*" then return false end
  -- '!' anywhere in the string = failsafe / error wrapper
  if containsChar(raw, "!") then return false end
  -- Explicit "WAIT" state means not armed
  local stripped = stripDecorators(raw)
  if stripped == "" then return false end
  if string.upper(stripped) == "WAIT" then return false end
  return true
end

-- Stripped mode name suitable for display. Zero Lua patterns.
local function fmModeName()
  local raw = fmRaw()
  if raw == nil then return nil end
  if type(raw) ~= "string" then return nil end
  local s = stripDecorators(raw)
  if s == "" then return nil end
  s = string.upper(s)
  return CFG.telemetry.fmDisplay[s] or s
end

-- Mode label from Betaflight's FM telemetry sensor. Returns "----" when
-- no FM telemetry is available.
local function modeName()
  return fmModeName() or "----"
end

-- ============================================================================
-- TX RADIO BATTERY
-- ============================================================================
local function txGeneralSettings()
  if type(getGeneralSettings) ~= "function" then return nil end
  local ok, g = pcall(getGeneralSettings)
  if ok and type(g) == "table" then return g end
  return nil
end

local function normalizedTxVoltage(v)
  if type(v) ~= "number" or v <= 0 then return nil end
  if v > 20 then v = v / 10 end -- some firmware reports decivolts
  return v
end

-- Estimate the TX pack's cell count from EdgeTX's configured battMax (the
-- configured "full charge" voltage in the radio's battery settings). Dividing
-- by 4.2V/cell and rounding handles 1S (~4.2V), 2S (~8.4V, default for
-- TX16S 18650s), 3S (~12.6V), etc. Defaults to 2S if battMax is missing.
local function txCellCount()
  local g = txGeneralSettings()
  if g then
    local hi = normalizedTxVoltage(g.battMax)
    if hi then
      local n = math.floor(hi / 4.2 + 0.5)
      if n >= 1 then return n end
    end
  end
  return 2  -- TX16S default
end

local function txWarnCellV()
  local g = txGeneralSettings()
  local warn = g and normalizedTxVoltage(g.battWarn)
  if warn then return warn / txCellCount() end
  return CFG.battery.txCellWarn
end

local function txCritCellV()
  local warn = txWarnCellV()
  if warn then return math.max(0, warn - CFG.battery.txCritDrop) end
  return CFG.battery.txCellCrit
end

local function txCellV()
  local v = txVoltage(); if v <= 0 then return 0 end
  return v / txCellCount()
end

-- TX state-of-charge from the Li-Ion discharge curve. Per-cell voltage
-- is stable enough on Li-Ion that a curve-based percent is meaningful
-- (unlike LiPo packs under heavy load, where voltage sag makes %
-- noisy, so it is not used for the drone pack).
local function txBatPct()
  local cv = txCellV()
  local curve = CFG.battery.lionPct
  if cv <= 0              then return 0 end
  if cv >= curve[1][1]    then return 100 end
  for i = 1, #curve - 1 do
    local a, b = curve[i], curve[i+1]
    if cv >= b[1] then
      local frac = (cv - b[1]) / (a[1] - b[1])
      return math.floor(b[2] + frac * (a[2] - b[2]) + 0.5)
    end
  end
  return 0
end

-- ============================================================================
-- PACK BATTERY INTELLIGENCE
-- ============================================================================
-- Auto-detect LiPo cell count from rxBat. Sticks to a known count once
-- found unless the per-cell drifts outside a sane range (handles battery
-- swap). All battery health is derived from per-cell voltage. Percentages are
-- not computed from mAh or voltage curves because both have significant
-- accuracy problems in real flight.
local function detectCells()
  local v = rxBat()
  if v <= 0 then return state.cellCount end
  if state.cellCount > 0 then
    local pc = v / state.cellCount
    if pc >= CFG.battery.droneCellMin
       and pc <= CFG.battery.droneCellMax then return state.cellCount end
  end
  for n = 1, CFG.battery.maxCells do
    local pc = v / n
    if pc >= CFG.battery.detectCellMin
       and pc <= CFG.battery.detectCellMax then state.cellCount = n; return n end
  end
  return state.cellCount
end

local function perCellV()
  local n = detectCells()
  if n <= 0 then return 0 end
  return rxBat() / n
end

local function loggedPerCellV(v)
  -- Saved sessions store total pack voltage, but warning thresholds are
  -- configured per-cell. Infer the most plausible cell count for coloring.
  if not v or v <= 0 then return nil end
  local best, bestDelta = nil, nil
  for n = 1, CFG.battery.maxCells do
    local pc = v / n
    if pc >= CFG.battery.droneCellMin
       and pc <= CFG.battery.droneCellMax then
      local d = math.abs(pc - 3.7)
      if best == nil or d < bestDelta then
        best, bestDelta = pc, d
      end
    end
  end
  return best
end

local function fmtSecs(s)
  if s == nil or s < 0 then return "--:--" end
  return string.format("%d:%02d", math.floor(s/60), s % 60)
end

-- ============================================================================
-- SESSION PERSISTENCE
-- ============================================================================
-- File format: one session per line on SD card.
--   /WIDGETS/EdgeDeck/sessions.log
--   YYYYMMDD-HHMMSS,D,M,LQ,RS,MV,MA,AL,SP,DI,PW,HZ
-- Compact CSV keeps more sessions inside EdgeTX's small file-read window.
-- Logs are kept only in the widget's own folder. Newest entries are written at
-- the top so EdgeTX radios that only read the first part of a file still show
-- the latest flights.
local _resolvedPath = nil
local function sessionLogPath()
  if _resolvedPath then return _resolvedPath end
  pcall(function()
    local f = io.open(CFG.paths.sessionLog, "a")
    if f then io.close(f) end
  end)
  _resolvedPath = CFG.paths.sessionLog
  return _resolvedPath
end
local SESSION_MAX = CFG.logging.maxSessions

-- Split helpers (no Lua patterns — EdgeTX Lua throws on some pattern escapes).
local function splitPlain(s, sep)
  local out, start = {}, 1
  while true do
    local i = string.find(s, sep, start, true)
    if not i then table.insert(out, string.sub(s, start)); return out end
    table.insert(out, string.sub(s, start, i-1))
    start = i + #sep
  end
end

local _resolvedGpsPath = nil
local function gpsLogPath()
  if _resolvedGpsPath then return _resolvedGpsPath end
  for _, p in ipairs(CFG.paths.gpsLastCandidates) do
    local ok = pcall(function()
      local f = io.open(p, "a")
      if not f then error("nil") end
      io.close(f)
    end)
    if ok then _resolvedGpsPath = p; return p end
  end
  _resolvedGpsPath = CFG.paths.gpsLastCandidates[1]
  return _resolvedGpsPath
end

local function formatTimestamp()
  local ok, d = pcall(getDateTime)
  if not ok or type(d) ~= "table" then return "00000000-000000" end
  return string.format("%04d%02d%02d-%02d%02d%02d",
    d.year or 0, d.mon or 0, d.day or 0, d.hour or 0, d.min or 0, d.sec or 0)
end

local function gpsToLine(g)
  return string.format("TS=%s|LAT=%.7f|LON=%.7f|SATS=%d",
    g.ts or "00000000-000000",
    g.lat or 0,
    g.lon or 0,
    g.sats or 0)
end

local function parseGpsLine(line)
  if type(line) ~= "string" or #line < CFG.runtime.minPersistedLineLen then return nil end
  local out = {}
  for _, kv in ipairs(splitPlain(line, "|")) do
    local eq = string.find(kv, "=", 1, true)
    if eq then
      local k = string.sub(kv, 1, eq - 1)
      local v = string.sub(kv, eq + 1)
      if k == "TS" then out.ts = v
      elseif k == "LAT" then out.lat = tonumber(v)
      elseif k == "LON" then out.lon = tonumber(v)
      elseif k == "SATS" then out.sats = tonumber(v) or 0
      end
    end
  end
  if not out.lat or not out.lon then return nil end
  if math.abs(out.lat) > CFG.gps.maxLat or math.abs(out.lon) > CFG.gps.maxLon then return nil end
  return out
end

-- Format a session table for writing.
local function sessionToLine(s)
  return table.concat({
    s.ts or "00000000-000000",
    tostring(s.dur or 0),
    tostring(s.mAh or 0),
    tostring(s.minLQ   or ""),
    tostring(s.minRSSI or ""),
    s.minV and string.format("%.2f", s.minV) or "",
    string.format("%.1f", s.maxA or 0),
    string.format("%.0f", s.maxAl or 0),
    string.format("%.0f", s.maxSp or 0),
    string.format("%.0f", s.maxDi or 0),
    tostring(s.maxPwr or ""),
    tostring(s.rfHz   or ""),
    s.startLat and string.format("%.7f", s.startLat) or "",
    s.startLon and string.format("%.7f", s.startLon) or "",
  }, ",")
end

-- Parse a single log line into a session table. Returns nil on parse failure.
local function parseSessionLine(line)
  if type(line) ~= "string" or #line < CFG.runtime.minPersistedLineLen then return nil end
  if string.find(line, "|", 1, true) then return nil end
  local p = splitPlain(line, ",")
  if #p < 10 then return nil end
  local sess = {
    ts      = p[1],
    dur     = tonumber(p[2]) or 0,
    mAh     = tonumber(p[3]) or 0,
    minLQ   = tonumber(p[4]),
    minRSSI = tonumber(p[5]),
    minV    = tonumber(p[6]),
    maxA    = tonumber(p[7]) or 0,
    maxAl   = tonumber(p[8]) or 0,
    maxSp   = tonumber(p[9]) or 0,
    maxDi   = tonumber(p[10]) or 0,
    maxPwr  = tonumber(p[11]),
    rfHz    = tonumber(p[12]),
    startLat = tonumber(p[13]),
    startLon = tonumber(p[14]),
  }
  if not sess.ts or sess.ts == "" then return nil end
  return sess
end

-- Read file content using EdgeTX's function-style io.read(file, n).
-- f:lines() and f:read("*a") are standard-Lua method calls that may not
-- exist on EdgeTX's custom io library.
local function readWholeFile(path)
  local f = io.open(path, "r")
  if not f then return nil, "open(r) nil" end
  local parts = {}
  while true do
    local chunk = io.read(f, CFG.runtime.fileReadChunk)
    if chunk == nil or chunk == "" then break end
    parts[#parts + 1] = chunk
  end
  io.close(f)
  return table.concat(parts)
end

local function loadSavedGps()
  if state.gps.loaded then return end
  state.gps.loaded = true
  pcall(function()
    local content = readWholeFile(gpsLogPath())
    if content == nil then return end
    local last = nil
    for _, line in ipairs(splitPlain(content, "\n")) do
      if #line > 0 then
        local g = parseGpsLine(line)
        if g then last = g end
      end
    end
    if last then
      state.gps.savedLat  = last.lat
      state.gps.savedLon  = last.lon
      state.gps.savedTs   = last.ts
      state.gps.savedSats = last.sats
    end
  end)
end

local function gpsQrText(lat, lon)
  return string.format("%." .. CFG.gps.coordinatePrecision .. "f,%."
    .. CFG.gps.coordinatePrecision .. "f", lat, lon)
end

-- Keep QR generation in a small helper file so the main dashboard can still
-- load if the helper is missing or fails to compile on the radio.
local _qrHelper = nil
local _qrHelperTried = false
local function qrHelper()
  if _qrHelperTried then return _qrHelper end
  _qrHelperTried = true
  for _, path in ipairs(CFG.paths.qrHelperCandidates) do
    local ok, mod = pcall(function()
      local loader = nil
      if type(loadScript) == "function" then loader = loadScript(path) end
      if not loader and type(loadfile) == "function" then loader = loadfile(path) end
      if type(loader) == "function" then return loader() end
      return nil
    end)
    if ok and type(mod) == "table" and type(mod.start) == "function"
       and type(mod.step) == "function" then
      _qrHelper = mod
      return _qrHelper
    end
  end
  return nil
end

local function invalidateGpsQr()
  state.gps.qrPayload = nil
  state.gps.qrRows = nil
  state.gps.qrLat = nil
  state.gps.qrLon = nil
  state.gps.qrTs = nil
  state.gps.qrErr = nil
  state.gps.qrBuildPending = false
  state.gps.qrJob = nil
end

local function persistGpsCoord(coord)
  if not coord or not coord.lat or not coord.lon then return false end
  loadSavedGps()
  local g = {
    ts = formatTimestamp(),
    lat = coord.lat,
    lon = coord.lon,
    sats = coord.sats or gpsSats(),
  }
  local ok = pcall(function()
    local f = io.open(gpsLogPath(), "w")
    if not f then return end
    io.write(f, gpsToLine(g) .. "\n")
    io.close(f)
  end)
  if not ok then return false end
  state.gps.savedLat  = g.lat
  state.gps.savedLon  = g.lon
  state.gps.savedTs   = g.ts
  state.gps.savedSats = g.sats
  if not state.gps.showQr then invalidateGpsQr() end
  return true
end

local function sampleGps()
  local coord = gpsCoord()
  if coord then
    state.gps.liveLat = coord.lat
    state.gps.liveLon = coord.lon
  else
    state.gps.liveLat = nil
    state.gps.liveLon = nil
  end
  return coord
end

local function captureSessionStartGps(s)
  if not s or s.startLat or s.startLon then return end
  local coord = sampleGps()
  if not coord then return end
  s.startLat = coord.lat
  s.startLon = coord.lon
end

local function autoSaveGps()
  local coord = sampleGps()
  if not coord then return end
  local now = getTime()
  if (now - (state.gps.lastSaveAt or 0)) < CFG.gps.autosaveCs then return end
  if persistGpsCoord(coord) then
    state.gps.lastSaveAt = now
  end
end

-- Internal snapshot used when QR is opened before the periodic autosave has
-- captured a coordinate.
local function saveGpsSnapshot()
  local coord = sampleGps()
  if not coord then return false end
  state.gps.lastSaveAt = getTime()
  local ok = persistGpsCoord(coord)
  if ok then state.dirty = true end
  return ok
end

local function toggleGpsQr()
  if state.gps.showQr then
    state.gps.showQr = false
    invalidateGpsQr()
    state.dirty = true
    return true
  end

  loadSavedGps()
  if not state.gps.savedLat or not state.gps.savedLon then
    saveGpsSnapshot()
  end
  if state.gps.savedLat and state.gps.savedLon then
    local payload = gpsQrText(state.gps.savedLat, state.gps.savedLon)
    local err = nil
    local helper = qrHelper()
    local job = nil
    if helper then
      local ok, jOrErr, startErr = pcall(helper.start, payload)
      if ok then job, err = jOrErr, startErr else err = tostring(jOrErr) end
    else
      err = "QR HELPER MISSING"
    end
    state.gps.qrPayload = payload
    state.gps.qrRows = nil
    state.gps.qrLat = state.gps.savedLat
    state.gps.qrLon = state.gps.savedLon
    state.gps.qrTs = state.gps.savedTs
    state.gps.qrErr = err or "QR BUILDING"
    state.gps.qrJob = job
    state.gps.qrBuildPending = job ~= nil
    state.gps.showQr = true
    state.dirty = true
    return true
  end
  return false
end

local function buildPendingGpsQr()
  if not state.gps.qrBuildPending or not state.gps.qrJob then return end
  local helper = qrHelper()
  if not helper then
    state.gps.qrErr = "QR HELPER MISSING"
    state.gps.qrBuildPending = false
    state.gps.qrJob = nil
    state.dirty = true
    return
  end
  local ok, done, rows, err = pcall(helper.step, state.gps.qrJob, CFG.gps.qrStepBudget)
  if not ok then
    state.gps.qrErr = tostring(done or "QR BUILD FAILED")
    state.gps.qrBuildPending = false
    state.gps.qrJob = nil
    state.dirty = true
    return
  end
  if done then
    state.gps.qrRows = rows
    state.gps.qrErr = err
    state.gps.qrBuildPending = false
    state.gps.qrJob = nil
    state.dirty = true
  else
    state.gps.qrErr = err or "QR BUILDING"
    state.dirty = true
  end
end

local function loadSessions()
  if state.sessions ~= nil then return end
  state.sessions = {}
  local byTs = {}
  local function addLoadedSession(s)
    if not s or not s.ts then return end
    local existingIdx = byTs[s.ts]
    if existingIdx then
      state.sessions[existingIdx] = s
      return
    end
    table.insert(state.sessions, s)
    byTs[s.ts] = #state.sessions
  end
  pcall(function()
    local content = readWholeFile(sessionLogPath())
    if content == nil then return end
    for _, line in ipairs(splitPlain(content, "\n")) do
      if #line > 0 then
        addLoadedSession(parseSessionLine(line))
      end
    end
  end)
  table.sort(state.sessions, function(a, b)
    return tostring(a.ts or "") < tostring(b.ts or "")
  end)
  while #state.sessions > SESSION_MAX do
    table.remove(state.sessions, 1)
  end
end

local function persistSessions()
  if state.sessions == nil then return end
  while #state.sessions > SESSION_MAX do
    table.remove(state.sessions, 1)
    if state.currentSession and state.currentSession.savedIdx then
      state.currentSession.savedIdx = state.currentSession.savedIdx - 1
    end
  end
  pcall(function()
    -- Use EdgeTX's function-style io API per their docs: io.write(file, str)
    -- and io.close(file). The standard-Lua method syntax (f:write, f:close)
    -- may succeed silently in their compat shim but never sync to SD.
    local f = io.open(sessionLogPath(), "w")
    if not f then return end
    for i = #state.sessions, 1, -1 do
      io.write(f, sessionToLine(state.sessions[i]) .. "\n")
    end
    -- io.close performs the FATFS directory entry flush. EdgeTX's io
    -- library doesn't expose a separate flush() — close is the sync point.
    io.close(f)
  end)
end

-- Commit the current session to the in-memory list and persist to SD card.
-- If the session was already committed during this battery (savedIdx set),
-- update that entry in memory; otherwise append a new row. The file is rewritten
-- newest-first so the latest flights stay at the top.
local function commitSession(s)
  if not s then return end
  s.dur = s.flightSecs or 0
  s.mAh = math.max(0, (s.lastCapa or 0) - (s.startCapa or 0))
  loadSessions()  -- hydrate state.sessions before mutation
  if s.savedIdx and state.sessions[s.savedIdx] then
    state.sessions[s.savedIdx] = s
  else
    table.insert(state.sessions, s)
    s.savedIdx = #state.sessions
  end
  persistSessions()
  state.dirty = true   -- repaint LOG tab if it's open
end

-- Open a new battery session. Called by noteArm on the FIRST arm after FC
-- power-up. A "battery session" spans one FC power-on cycle — the pilot may
-- arm/disarm many times within it. Each arm contributes to the same
-- session's totals; the session is finalized when the FC reboots (Capa
-- resets) or telemetry is lost for long enough.
local function openSession()
  local c = capa()
  state.currentSession = {
    ts        = formatTimestamp(),
    startCapa = c,
    lastCapa  = c,           -- updated each tick; used at close to compute mAh
    armCount  = 0,           -- how many times armed during this battery
    flightSecs= 0,           -- accumulated armed time
    armSince  = 0,           -- 0 = not currently armed
    minLQ     = nil,
    minRSSI   = nil,
    minV      = nil,         -- min pack voltage seen under load
    maxA      = 0,
    maxAl     = 0,
    maxSp     = 0,
    maxDi     = 0,
    maxPwr    = nil,
    rfHz      = nil,
  }
end

-- Close the current battery session. Only persisted if the FC was actually
-- armed at least once during this battery — otherwise discard it.
local function closeSession()
  local s = state.currentSession; state.currentSession = nil
  if not s then return nil end
  if (s.armCount or 0) == 0 then
    return nil  -- never armed; discard
  end
  -- If closing while still armed, add the in-progress segment.
  if s.armSince and s.armSince > 0 then
    s.flightSecs = s.flightSecs
      + math.floor((getTime() - s.armSince) / CFG.runtime.centisPerSecond)
  end
  -- Final commit. commitSession recomputes dur/mAh from lastCapa, so no
  -- assignment is needed to set them here.
  commitSession(s)
  return s
end

-- Update min/max trackers for the current battery session (called while armed).
local function updateCurrentSession(L, R, I, alt, spd, dst, pv, pwr, hz)
  local s = state.currentSession; if not s then return end
  if s.minLQ   == nil or L < s.minLQ   then s.minLQ   = L end
  if s.minRSSI == nil or R < s.minRSSI then s.minRSSI = R end
  if pv and pv > 0 and (s.minV == nil or pv < s.minV) then s.minV = pv end
  if I   > s.maxA  then s.maxA  = I   end
  if alt > s.maxAl then s.maxAl = alt end
  if spd > s.maxSp then s.maxSp = spd end
  if dst > s.maxDi then s.maxDi = dst end
  if pwr and pwr > 0 and (s.maxPwr == nil or pwr > s.maxPwr) then s.maxPwr = pwr end
  if hz and hz > 0 then s.rfHz = hz end
end

local function updateGpsMaxTrackers()
  local alt = gpsAlt()
  local spd = gpsSpd()
  local dst = gpsDist()
  if alt > state.stats.maxAlt then state.stats.maxAlt = alt end
  if spd > state.stats.maxSpd then state.stats.maxSpd = spd end
  if dst > state.stats.maxDist then state.stats.maxDist = dst end
  local s = state.currentSession
  if s then
    captureSessionStartGps(s)
    if alt > s.maxAl then s.maxAl = alt end
    if spd > s.maxSp then s.maxSp = spd end
    if dst > s.maxDi then s.maxDi = dst end
  end
  return alt, spd, dst
end

-- Hook called on every arm transition (in tickFlight). Records start of an
-- arm segment within the current battery session.
--
-- First arm after FC power-up also opens the battery session. By design,
-- a "battery session" starts at first arm and ends at FC power-down; it
-- spans all the arm/disarm cycles in between as a SINGLE log entry.
local function noteArm(now)
  if not state.currentSession then openSession() end
  local s = state.currentSession; if not s then return end
  s.armSince = now
  s.armCount = (s.armCount or 0) + 1
  captureSessionStartGps(s)
end

-- Hook called on every disarm transition. Accumulates the just-ended arm
-- segment's duration into the battery session's total.
local function noteDisarm(now)
  local s = state.currentSession; if not s then return end
  if s.armSince and s.armSince > 0 then
    s.flightSecs = s.flightSecs
      + math.floor((now - s.armSince) / CFG.runtime.centisPerSecond)
    s.armSince = 0
  end
  -- Persist on every disarm so the latest state survives a radio power-off.
  -- The FC-reboot/telemetry-loss close path only fires if the radio stays on
  -- long enough — disarm is the reliable moment to commit.
  commitSession(s)
end

-- ============================================================================
-- FLIGHT SESSION TRACKER
-- ============================================================================
local function tickFlight(wgt)
  local now = getTime()
  -- Invalidate the alert cache so alertSnapshot recomputes once this tick.
  -- All label callbacks fired by LVGL between now and the next tickFlight
  -- will hit the cache instead of rebuilding the table.
  state._alertCache = nil

  -- Force a full GC every 60s. EdgeTX's underlying heap allocator doesn't
  -- compact, so over multi-hour sessions the small-string churn from
  -- per-render label callbacks can fragment free space enough that a
  -- moderately-sized allocation (like lvgl.build's widget tree) fails.
  -- An explicit collectgarbage("collect") runs the GC sweep and coalesces
  -- freelist entries, keeping fragmentation bounded. Cost is ~2-5ms once
  -- per minute — imperceptible during normal use, but prevents the long-session hang.
  state._lastGc = state._lastGc or now
  if (now - state._lastGc) > CFG.runtime.gcIntervalCs then
    pcall(collectgarbage, "collect")
    state._lastGc = now
  end

  pcall(autoSaveGps)
  pcall(buildPendingGpsQr)

  local i = curr()
  local wasArmed = state.armed
  -- Armed-state priority:
  --   1. Betaflight FM telemetry sensor (authoritative when present)
  --   2. Motor current over CFG.session.armCurrentA (motors spinning)
  local nowArmed
  local fmArm = fmIsArmed()
  if fmArm ~= nil then
    nowArmed = fmArm
  else
    nowArmed = (i > CFG.session.armCurrentA)
  end
  -- ---- Battery-cycle session lifecycle ----------------------------------
  --   Open  : on FIRST ARM (handled inside noteArm, not here)
  --   Close : (a) link comes back live AND capa reads near zero while the
  --              session's peak capa was substantial — that's an FC reboot
  --              (almost always means a battery swap), or
  --          (b) link has been LOST for ~30s straight (battery unplugged
  --              and pilot did not reconnect within the window)
  --
  -- Critically, linkUp() (RQly>0) — not rxBat() — is the telemetry-
  -- presence signal. When the battery is unplugged, rxBat may still return
  -- its last-known value from EdgeTX's sensor cache, which would mask the
  -- power-down. RQly drops to 0 immediately when ELRS packets stop, so it's
  -- the reliable "is there a live link right now" indicator.
  local c        = capa()
  local link     = linkUp()
  local linkRose = link and not (state._prevLink or false)
  if link then state.droneSeen = true end
  if linkRose then
    state._lastHash = ""
    state._lastBeep = 0
  end

  -- Track lifecycle events used by the auto-tab-switch block below.
  local closedBySwap = false

  if state.currentSession and link
     and (state.currentSession.lastCapa or 0) > CFG.session.swapMinCapa
     and c < CFG.session.swapResetCapa then
    -- Telemetry is live again and capa is near zero — but the session
    -- already saw substantial capa, so the FC must have rebooted. That's
    -- a new battery. Finalize the previous session; next arm opens a new one.
    closedBySwap = true
    closeSession()
  end

  -- Track peak capa for the current session so closeSession can compute mAh
  -- correctly even when the close fires AFTER an FC reboot has zeroed capa().
  -- Only update when link is live, otherwise stale cached values could pollute.
  if state.currentSession and link and c > (state.currentSession.lastCapa or 0) then
    state.currentSession.lastCapa = c
  end

  -- Do not force periodic rebuilds here. Rebuilding the LOG tab on a timer can
  -- drive thousands of lvgl.clear() + lvgl.build() cycles over a long session and
  -- saturate the LVGL widget pool. The dirty flag set by commitSession on disarm
  -- is sufficient because that is when new log entries can appear.

  -- Sustained link loss → close the session (FC powered down). The 30s
  -- threshold is for SESSION integrity (don't end a session over a brief
  -- RF blip). The TAB switch to STAT fires sooner (see auto-switch below).
  if not link then
    state.telemLostTicks = (state.telemLostTicks or 0) + 1
    if state.currentSession and state.telemLostTicks > CFG.session.closeLossTicks then
      closeSession()
      state.telemLostTicks = 0
    end
    if state.droneSeen and not state.armed
       and state.telemLostTicks > CFG.session.forgetDisconnectedTicks then
      state.droneSeen = false
      state._lastHash = ""
      state._lastBeep = 0
    elseif state.droneSeen and state.telemLostTicks > CFG.session.closeLossTicks
       and not state.currentSession then
      state.droneSeen = false
      state._lastHash = ""
      state._lastBeep = 0
    end
  else
    state.telemLostTicks = 0
    state._statSwitchFired = false  -- reset so next loss can fire STAT again
  end
  state.prevCapa = c

  -- ---- Arm / disarm transitions -----------------------------------------
  if nowArmed and not wasArmed then
    state.armed = true; state.armSince = now
    noteArm(now)
  elseif (not nowArmed) and wasArmed then
    state.armed = false
    state.flightSecs = state.flightSecs
      + math.floor((now - state.armSince) / CFG.runtime.centisPerSecond)
    noteDisarm(now)
  end

  -- ---- Auto-switch tabs on key lifecycle events -------------------------
  -- Design:
  --   * "armSwitchPending" flag is set on any battery-connect signal
  --     (link false→true OR capa-reset swap). The NEXT arm event consumes
  --     the flag and switches to FLY. This is decoupled from session
  --     state — it works even when session-close heuristics fail
  --     to detect the swap (e.g. short flight where lastCapa never
  --     exceeded CFG.session.swapMinCapa, OR ELRS RQly stays cached at non-zero across the
  --     swap so neither closedBySwap NOR linkRose fires).
  --   * STAT switch fires after 5s of link loss — independent of the 30s
  --     session-close threshold. Gives fast visual feedback when battery
  --     is unplugged. One-shot per loss event (reset on link return).
  --   * LOG (tab 3) and GPS (tab 4) are never auto-switched to — manual by design.
  --   * Priority when multiple fire same tick: arm > connect > loss.
  if linkRose or closedBySwap then
    state._armSwitchPending = true
  end
  local doArmSwitch  = nowArmed and not wasArmed
                       and (state._armSwitchPending or false)
  local doStatSwitch = (state.droneSeen or state.currentSession ~= nil)
                       and (state.telemLostTicks or 0) >= CFG.session.statSwitchLossTicks
                       and not (state._statSwitchFired or false)

  -- AutoTab option gates the actual tab changes. The pending/
  -- fired bookkeeping below still runs either way so re-enabling mid-session
  -- doesn't replay a stale event.
  local autoTab = opt(wgt, "AutoTab", 0) ~= 0
  if doArmSwitch then
    if autoTab then state.tab = 1; state.dirty = true end
    state._armSwitchPending = false
  elseif closedBySwap or linkRose then
    if autoTab then state.tab = 0; state.dirty = true end
  elseif doStatSwitch then
    if autoTab then state.tab = 2; state.dirty = true end
    state._statSwitchFired = true
  end
  state._prevLink = link

  local alt, spd, dst = 0, 0, 0
  if gpsPresent() then
    alt, spd, dst = updateGpsMaxTrackers()
  end

  -- ---- Live stats while armed -------------------------------------------
  if state.armed then
    local L = lq();    if state.stats.minLQ   == nil or L < state.stats.minLQ   then state.stats.minLQ   = L end
    local R = rssiVal(); if state.stats.minRSSI == nil or R < state.stats.minRSSI then state.stats.minRSSI = R end
    -- Min pack voltage under load. Standard CRSF telemetry doesn't carry
    -- BF's OSD "min battery" value (BF tracks it FC-side and never sends
    -- it over the link), so rxBat() is sampled at refresh rate.
    -- Only count non-zero readings — getValue returns 0 when telemetry is
    -- stale, which would falsely set min to zero.
    local pv = rxBat()
    if pv > 0 and (state.stats.minPackV == nil or pv < state.stats.minPackV) then
      state.stats.minPackV = pv
    end
    if i > state.stats.maxCurr then state.stats.maxCurr = i end
    updateCurrentSession(L, R, i, alt, spd, dst, pv, txPwr(), rfModeHz())
  end
end

local function totalFlightSecs()
  local s = state.flightSecs
  if state.armed then
    s = s + math.floor((getTime() - state.armSince) / CFG.runtime.centisPerSecond)
  end
  return s
end

local function resetStats()
  state.stats = { minLQ=nil, minRSSI=nil, minPackV=nil, maxCurr=0, maxAlt=0, maxSpd=0, maxDist=0 }
  state.flightSecs = 0; state.armSince = getTime()
end

-- Format a timestamp string ("YYYYMMDD-HHMMSS") into a friendly "MM-DD HH:MM".
local function fmtSessionTime(ts)
  if type(ts) ~= "string" or #ts < CFG.runtime.timestampLen then return "--" end
  local mo  = string.sub(ts, 5, 6)
  local day = string.sub(ts, 7, 8)
  local hh  = string.sub(ts, 10, 11)
  local mm  = string.sub(ts, 12, 13)
  return mo .. "/" .. day .. " " .. hh .. ":" .. mm
end

local function fmtCoord(v)
  if type(v) ~= "number" then return "--.------" end
  return string.format("%.6f", v)
end

local function sampleHistory()
  local now = getTime()
  if (now - state.lastSample) < CFG.runtime.historySampleCs then return false end
  state.lastSample = now
  for i = 1, state.histN - 1 do state.history[i] = state.history[i+1] end
  state.history[state.histN] = lq()
  return true
end

-- ============================================================================
-- CENTRAL ALERT + COLOR STATE
-- ============================================================================
local ALERT_NONE = CFG.alerts.none
local ALERT_WARN = CFG.alerts.warn
local ALERT_CRIT = CFG.alerts.crit
local ALERT_HOLD_CS = CFG.alerts.holdCs

local function thresholdRank(v, warn, crit)
  if type(v) ~= "number" then return ALERT_NONE end
  if type(crit) == "number" and v <= crit then return ALERT_CRIT end
  if type(warn) == "number" and v <= warn then return ALERT_WARN end
  return ALERT_NONE
end

local function rankColor(rank, mutedWhenNone)
  if rank >= ALERT_CRIT then return RED end
  if rank >= ALERT_WARN then return YELLOW end
  if mutedWhenNone then return MUTED end
  return GREEN
end

local function thresholdColor(v, warn, crit)
  return rankColor(thresholdRank(v, warn, crit), type(v) ~= "number")
end

local function addAlert(list, id, text, rank)
  if rank and rank > ALERT_NONE then
    table.insert(list, { id = id, text = text, rank = rank })
  end
end

local function heldAlertRank(id, rawRank)
  -- LQ/RSSI/pack alerts must remain in the same warn/crit band for
  -- ALERT_HOLD_CS before they become audible/visible alert items. Live value
  -- colors still use the immediate rank from thresholdRank().
  if rawRank <= ALERT_NONE then
    if state._alertHold then state._alertHold[id] = nil end
    return ALERT_NONE
  end

  state._alertHold = state._alertHold or {}
  local now = getTime()
  local h = state._alertHold[id]
  if not h or h.rank ~= rawRank then
    h = { rank = rawRank, since = now }
    state._alertHold[id] = h
    return ALERT_NONE
  end
  if (now - (h.since or now)) < ALERT_HOLD_CS then
    return ALERT_NONE
  end
  return rawRank
end

local function clearHeldLinkAlerts()
  if not state._alertHold then return end
  state._alertHold.lq = nil
  state._alertHold.rssi = nil
  state._alertHold.pack = nil
end

-- One source of truth for alert state. `*Rank` fields are immediate for live
-- colors; `*AlertRank` fields are held for audio/footer alert behavior.
local function alertSnapshot(wgt)
  if state._alertCache then return state._alertCache end

  local snap = {
    items = {},
    maxRank = ALERT_NONE,
    critCount = 0,
    hash = "",
    noTelemetry = false,
    link = linkUp(),
    lqRank = ALERT_NONE,
    rssiRank = ALERT_NONE,
    packRank = ALERT_NONE,
    lqAlertRank = ALERT_NONE,
    rssiAlertRank = ALERT_NONE,
    packAlertRank = ALERT_NONE,
    txRank = ALERT_NONE,
  }

  if snap.link then
    snap.lqRank = thresholdRank(lq(), opt(wgt, "LQ_Warn", 80), opt(wgt, "LQ_Crit", 50))
    snap.lqAlertRank = heldAlertRank("lq", snap.lqRank)
    addAlert(snap.items, "lq", snap.lqAlertRank >= ALERT_CRIT and ("LINK CRIT " .. lq() .. "%") or "LINK WARN", snap.lqAlertRank)

    snap.rssiRank = thresholdRank(rssiVal(), opt(wgt, "RSSI_Warn", -98), opt(wgt, "RSSI_Crit", -103))
    snap.rssiAlertRank = heldAlertRank("rssi", snap.rssiRank)
    addAlert(snap.items, "rssi", snap.rssiAlertRank >= ALERT_CRIT and "RSSI CRIT" or "RSSI WARN", snap.rssiAlertRank)

    local pc = perCellV()
    snap.packRank = thresholdRank(pc, opt(wgt, "CellV_Warn", 350) / 100, opt(wgt, "CellV_Crit", 330) / 100)
    snap.packAlertRank = heldAlertRank("pack", snap.packRank)
    addAlert(snap.items, "pack", snap.packAlertRank >= ALERT_CRIT and "PACK LOW" or "PACK WARN", snap.packAlertRank)
  elseif state.armed then
    clearHeldLinkAlerts()
    snap.noTelemetry = true
    addAlert(snap.items, "telem", "NO TELEMETRY", ALERT_CRIT)
  else
    clearHeldLinkAlerts()
  end

  local txCv = txCellV()
  if txCv > 0 then
    snap.txRank = thresholdRank(txCv, txWarnCellV(), txCritCellV())
    addAlert(snap.items, "txbat", snap.txRank >= ALERT_CRIT and "TX BAT LOW" or "TX BAT WARN", snap.txRank)
  end

  local parts = {}
  for i, item in ipairs(snap.items) do
    if item.rank > snap.maxRank then snap.maxRank = item.rank end
    if item.rank >= ALERT_CRIT then snap.critCount = snap.critCount + 1 end
    parts[i] = item.id .. ":" .. item.rank .. ":" .. item.text
  end
  snap.hash = table.concat(parts, "|")

  state._alertCache = snap
  return snap
end

-- ============================================================================
-- COLOR CODING
-- ============================================================================
local function lqColor(wgt)
  if not linkUp() then return MUTED end
  return rankColor(alertSnapshot(wgt).lqRank, false)
end

local function rssiColor(wgt)
  if not linkUp() then return MUTED end
  return rankColor(alertSnapshot(wgt).rssiRank, false)
end

local function txBatColor(wgt)
  local cv = txCellV(); if cv <= 0 then return MUTED end
  return rankColor(alertSnapshot(wgt).txRank, false)
end

local function packPctColor(wgt)
  local pc = perCellV(); if pc <= 0 then return MUTED end
  return rankColor(alertSnapshot(wgt).packRank, false)
end

local function telemetryText(wgt)
  local snap = alertSnapshot(wgt)
  if snap.noTelemetry then return " " .. SYM.WARNING .. " NO TELEMETRY" end
  if snap.link then return " " .. SYM.OK .. " TELEMETRY" end
  return ""
end

local function alertFgColor(wgt)
  if state.muteUntil > 0 and getTime() < state.muteUntil then return MUTED end
  local rank = alertSnapshot(wgt).maxRank
  if rank >= ALERT_CRIT then return RED end
  if rank >= ALERT_WARN then return YELLOW end
  return GREEN
end

-- ============================================================================
-- AUDIO + VOICE
-- ============================================================================
local _PREC2 = PREC2 or 32
local _UNIT_VOLTS   = 1
local _UNIT_PERCENT = 13

local function voiceOK() return state.muteUntil == 0 or getTime() > state.muteUntil end

local function alertPulse(count, freq)
  for i = 1, count do
    local pause = (i < count) and CFG.alerts.pulsePauseMs or 0
    pcall(playHaptic, CFG.alerts.pulseHapticMs, pause, 0)
    pcall(playTone, freq, CFG.alerts.pulseToneMs, pause)
  end
end

local function maybeBeep(wgt)
  if not wgt then return end
  -- Audio enum: 0=silent, 1=beeps only, 2=beeps + voice
  if opt(wgt, "Audio", 2) < 1 then return end
  if not voiceOK() then return end
  local ok, now = pcall(getTime); if not ok or type(now) ~= "number" then return end
  local snap = alertSnapshot(wgt)
  local hash = snap.hash
  if hash == "" then state._lastHash = ""; state._lastBeep = 0; return end

  local changed = hash ~= state._lastHash
  local repeatCs = CFG.alerts.warningRepeatCs
  if snap.maxRank >= ALERT_CRIT then
    repeatCs = (snap.critCount >= 2)
      and CFG.alerts.multiCriticalRepeatCs
      or CFG.alerts.criticalRepeatCs
  end
  local shouldRepeat = (now - (state._lastBeep or 0)) > repeatCs
  if changed or shouldRepeat then
    state._lastHash = hash; state._lastBeep = now

    -- Warn repeats every 15s. Critical repeats every 5s, or every 2s when
    -- multiple critical alerts are active. Critical always has priority.
    if snap.maxRank >= ALERT_CRIT then
      alertPulse(CFG.alerts.critPulseCount, CFG.alerts.critToneHz)
    else
      alertPulse(CFG.alerts.warnPulseCount, CFG.alerts.warnToneHz)
    end
  end
end

local function maybeVoice(wgt)
  -- Voice only fires when Audio enum is 2 (beeps + voice).
  if opt(wgt, "Audio", 2) < 2 then return end
  if not voiceOK() then return end
  local now = getTime()
  local snap = alertSnapshot(wgt)
  local L = lq()
  if state.droneSeen and linkUp() and snap.lqAlertRank > ALERT_NONE
     and (now - state.lastVoice.lq) > CFG.voice.lqRepeatCs then
    pcall(playNumber, L, _UNIT_PERCENT, 0)
    state.lastVoice.lq = now
  end
  local pc = perCellV()
  if linkUp() and pc > 0 and snap.packAlertRank > ALERT_NONE
     and (now - state.lastVoice.batt) > CFG.voice.packRepeatCs then
    pcall(playNumber, math.floor(pc * 100 + 0.5), _UNIT_VOLTS, _PREC2)
    state.lastVoice.batt = now
  end
  if state.droneSeen and state.armed and not linkUp()
     and (now - state.lastVoice.tlost) > CFG.voice.telemetryLostRepeatCs then
    state.lastVoice.tlost = now
    pcall(playTone, CFG.voice.telemetryLostToneHz, CFG.voice.telemetryLostToneMs, 0)
  end
end

-- ============================================================================
-- TOUCH HANDLERS
-- ============================================================================
local function setTab(wgt, n)
  local oldTab = state.tab
  state.tab = n
  if n == 3 and oldTab ~= 3 then
    state.selectedSess = nil
    state.logCursor = nil
    state.logPage = 1
    state.logPageHasNext = false
    state.logPageChecked = nil
    state.sessions = nil
  end
  state.dirty = true
end
local function muteAlerts(wgt) state.muteUntil = getTime() + CFG.alerts.muteCs end
local logPagePrev, logPageNext, logBack

-- Hit-test rectangle-based "buttons" against an absolute screen tap.
-- Returns true if a button was hit (consumed) so the caller can stop.
local function inRect(x, y, bx, by, bw, bh)
  return x >= bx and x <= bx+bw and y >= by and y <= by+bh
end

local function gpsFooterRects()
  local y = SCR_H - PAGE_MARGIN - 32
  return PAGE_X, y, PAGE_W, 32
end

local function handleTouch(wgt, x, y)
  if type(x) ~= "number" or type(y) ~= "number" then return false end

  -- Tab buttons: 5 tabs @ 60px stride. Hit-test spans the full 40px tabBar
  -- height (visible button is y=0..32 but extending to 40 gives forgiving
  -- bottom-edge taps).
  for n = 0, 4 do
    if inRect(x, y, PAGE_X + n*CFG.touch.tabStride, 0,
              CFG.touch.tabWidth, TAB_BAR_H) then
      setTab(wgt, n)
      return true
    end
  end

  if state.tab == 1 then
    -- MUTE button (FLY tab footer)
    if inRect(x, y, SCR_W-PAGE_R-40, FLY_FOOTER_Y, 40, FLY_FOOTER_H) then muteAlerts(wgt); return true end
  elseif state.tab == 2 then
    -- RESET button follows the STAT tab's shared page grid.
    if inRect(x, y, PAGE_X, SCR_H-PAGE_MARGIN-32, PAGE_W, 32) then resetStats(); return true end
  elseif state.tab == 3 then
    -- LOG tab. Two modes: list view + detail view.
    if state.selectedSess then
      -- Back-to-list button
      if inRect(x, y, PAGE_X, SCR_H-PAGE_MARGIN-32, PAGE_W, 32) then
        return logBack()
      end
    else
      -- Row taps and pager buttons are native lvgl.button widgets in LOG.
    end
  elseif state.tab == 4 then
    -- GPS footer actions are native lvgl.button callbacks.
  end
  return false
end

-- ============================================================================
-- UI PRIMITIVES (shadcn-flavored cards)
-- ============================================================================
local plainLabel

function compat.scalePx(v)
  if not compat.highRes or type(v) ~= "number" then return v end
  if v <= 0 then return v end
  return math.floor(v * compat.scale + 0.5)
end

function compat.scaleFullTree(tree)
  if not compat.highRes then return tree end
  local function scaleNode(node)
    if type(node) ~= "table" then return end
    for _, key in ipairs({ "x", "y", "w", "h", "rounded", "cornerRadius" }) do
      if type(node[key]) == "number" then
        -- Negative child offsets (tab bookmarks) must stay small; scaling
        -- them for 800x480 has triggered LVGL faults on MK3 firmware.
        if (key == "x" or key == "y") and node[key] < 0 then
          -- keep literal offset
        else
          node[key] = compat.scalePx(node[key])
        end
      end
    end
    if type(node.children) == "table" then
      for _, child in ipairs(node.children) do scaleNode(child) end
    end
  end
  for _, node in ipairs(tree) do scaleNode(node) end
  return tree
end

-- Card primitive. Rounded corners enabled (LVGL accepts 'rounded' on
-- rectangle on EdgeTX 2.11 builds; the sim confirms it renders).
local function cardOutlined(x, y, w, h, children, color)
  local colorFn = type(color) == "function" and color or nil
  local node = {
    type = "rectangle", x = x, y = y, w = w, h = h,
    filled = true, rounded = RADIUS,
    children = children or {},
  }
  if compat.staticLvgl then
    if colorFn then
      node.name = compat.mk3Track(nil, colorFn)
      node.color = compat.mk3Eval(colorFn, CARD)
    else
      node.color = color or CARD
    end
  else
    node.color = color or CARD
  end
  return node
end

local function scrollCard(x, y, w, h, children, color)
  local node = {
    type = "rectangle", x = x, y = y, w = w, h = h,
    color = color or CARD, filled = true, rounded = RADIUS,
    children = children or {},
  }
  if not compat.highRes then
    node.scrollBar = true
    node.scrollDir = lvgl.SCROLL_VERTICAL
  end
  return node
end

local function bgFill()
  return { type = "rectangle", x = 0, y = 0, w = SCR_W, h = SCR_H,
           color = BG, filled = true }
end

-- Build a "button" as a filled rectangle + centered label. Taps are
-- detected via the widget's refresh touch handler — not via LVGL's button
-- widget — so no LVGL theme border ring is painted.
--
-- Height must comfortably fit the label's bounding box (LVGL pads ~4px on
-- top and bottom even for the default font), otherwise the rectangle marks
-- itself as scrollable and shows the side scrollbar. Tuned values:
--   - default font label visual ≈ 14px tall, padding ≈ 4px → need h ≥ ~22
--   - vertical center via (h - 16)/2 hits the visible glyph centerline.
local function flatButton(x, y, w, h, txt, fillFn, fgColor)
  local s       = tostring(txt or "")
  local approxW = math.max(1, #s) * 7   -- UTF-8 byte-based approximation
  local labelX  = math.max(2, math.floor((w - approxW) / 2))
  local labelY  = math.max(2, math.floor((h - 16) / 2))
  local node = {
    type = "rectangle", x = x, y = y, w = w, h = h, rounded = RADIUS,
    filled = true, color = fillFn,
    children = {
      plainLabel(labelX, labelY, math.max(1, w - labelX), math.max(18, h - labelY),
        nil, fgColor or TEXT, txt, LEFT),
    },
  }
  if not compat.highRes then node.scrollBar = false end
  return node
end

function plainLabel(x, y, w, h, font, color, text, align)
  if not compat.staticLvgl then
    return {
      type = "label", x = x, y = y, w = w, h = h,
      font = font, color = color, text = text, align = align or LEFT,
      scrollBar = false, scrollDir = NO_SCROLL,
    }
  end
  local textFn = type(text) == "function" and text or nil
  local colorFn = type(color) == "function" and color or nil
  local node = {
    type = "label", x = x, y = y, w = w, h = h,
    font = font, align = align or LEFT,
  }
  node.text = textFn and compat.mk3Eval(textFn, "--") or (text or "")
  node.color = colorFn and compat.mk3Eval(colorFn, MUTED) or (color or TEXT)
  if textFn or colorFn then
    node.name = compat.mk3Track(textFn, colorFn)
  end
  return node
end

local function tabBar(wgt)
  -- "Bookmark" tabs: the rectangle extends from y=-RADIUS to y=32, so the
  -- top rounded portion is above the screen edge and gets clipped away by
  -- the LCD. Visible result: flat top (clipped) + rounded bottom — looks
  -- like a file-tab/bookmark hanging from the top of the screen.
  -- Label sits at absolute y=10 (matches the right-side labels) by being
  -- offset inside the over-tall rectangle.
  local function tab(n, label)
    local w        = 54
    -- LVGL labels have a few px of implicit left padding that pushes the
    -- text visually right of geometric center. We compensate by shifting
    -- labelX left by 2px. The `* 7` per-char estimate is an upper bound
    -- for the default font on uppercase glyphs.
    local approxW  = math.max(1, #label) * 7
    local labelX   = math.max(2, math.floor((w - approxW) / 2) - 2)
    local tabColorFn = function()
      if state.tab == n then return wgt.options.AccentColor end
      return BG
    end
    local tabNode = {
      type = "rectangle",
      x = PAGE_X + n*60, y = -RADIUS, w = w, h = 32 + RADIUS,
      rounded = RADIUS, filled = true,
      children = {
        plainLabel(labelX, RADIUS + 10, w - labelX, 20, nil, TEXT, label, LEFT),
      },
    }
    if compat.staticLvgl then
      tabNode.name = "tab" .. n
      tabNode.color = compat.mk3Eval(tabColorFn, BG)
      if wgt._mk3Dyn then wgt._mk3Dyn["tab" .. n] = { colorFn = tabColorFn } end
    else
      tabNode.color = safeColor(tabColorFn, BG)
    end
    return tabNode
  end
  return {
    type = "rectangle", x = 0, y = 0, w = SCR_W, h = 40,
    color = BG, filled = true,
    children = {
      tab(0, "PRE"), tab(1, "FLY"), tab(2, "STAT"), tab(3, "LOG"), tab(4, "GPS"),
      -- Right-side info: TX battery icon (color-coded) + voltage/percent
      -- merged with a middle-dot separator, then clock. Merging into one
      -- label removes the large gap between V and % and keeps both
      -- color-coded together.
      plainLabel(SCR_W-160, 10, 28, 20, nil,
        safeColor(function() return txBatColor(wgt) end, MUTED),
        safeStr(function() return batIcon(txCellV()) end, SYM.BAT_EMPTY), LEFT),
      plainLabel(SCR_W-130, 10, 74, 22, BOLD,
        safeColor(function() return txBatColor(wgt) end, MUTED),
        safeStr(function()
          return string.format("%.1fV \xC2\xB7 %d%%", txVoltage(), txBatPct())
        end, "--V \xC2\xB7 --%"), LEFT),
      plainLabel(SCR_W-55, 10, 52, 20, nil, MUTED, safeStr(clockStr, "--:--"), LEFT),
    }
  }
end

-- ============================================================================
-- PREFLIGHT TAB
-- ============================================================================
local function buildPreflight(wgt)
  local kids = { bgFill(), tabBar(wgt) }
  local fullW    = PAGE_W
  local bannerY  = CONTENT_Y
  local bannerH  = 58
  local cardsY   = bannerY + bannerH + PAGE_GAP
  local cardsH   = 90
  local row3Y    = cardsY + cardsH + PAGE_GAP
  local row3H    = SCR_H - PAGE_MARGIN - row3Y
  local colW     = math.floor((fullW - 2*PAGE_GAP) / 3)
  local col1X    = PAGE_X
  local col2X    = col1X + colW + PAGE_GAP
  local col3X    = col2X + colW + PAGE_GAP
  local col3W    = SCR_W - col3X - PAGE_R
  local wideW    = colW * 2 + PAGE_GAP
  local sideX    = PAGE_X + wideW + PAGE_GAP
  local sideW    = SCR_W - sideX - PAGE_R

  -- ARMED / DISARMED banner. Single full-width row: status left, mode right.
  -- Card color flips red when armed (preserved from original behaviour).
  local bannerInnerW = fullW - CARD_PAD_L - CARD_PAD_R
  table.insert(kids, cardOutlined(PAGE_X, bannerY, fullW, bannerH, {
    plainLabel(CARD_PAD_L, 10, math.floor(bannerInnerW * 0.65), 42, DBLSIZE, TEXT,
      safeStr(function()
        if state.armed then return SYM.CHARGE .. " ARMED" end
        return SYM.OK .. " DISARMED"
      end, "DISARMED"), LEFT),
    plainLabel(CARD_PAD_L + math.floor(bannerInnerW * 0.65), 10, math.ceil(bannerInnerW * 0.35), 42,
      DBLSIZE, BLUE, safeStr(function() return modeName() end, "----"), RIGHT),
  }, safeColor(function() return state.armed and RED_DIM or CARD end, CARD)))

  -- Row 2: three compact cards (PACK / LINK / RSSI). Each uses fixed label
  -- positions tuned to avoid LVGL overflow scrollbars on the radio.
  local PACK_W = colW - CARD_PAD_L - CARD_PAD_R

  -- PRE PACK/LINK/RSSI labels: title + DBLSIZE hero + compact subtitle.
  -- The y positions leave just enough vertical slack inside the 90px cards.

  -- PACK card. Subtitle uses SMLSIZE so "4S 3.36V/c 1500mAh" fits the
  -- 128px inner width on one line — STDSIZE wraps it onto a second line
  -- which pushes content past the card edge (visible scroll).
  table.insert(kids, cardOutlined(col1X, cardsY, colW, cardsH, {
    plainLabel(CARD_PAD_L, 7, PACK_W, 20, nil, MUTED,
      safeStr(function() return batIcon(perCellV()) .. " PACK" end, "PACK"), LEFT),
    plainLabel(CARD_PAD_L, 29, PACK_W, 40, DBLSIZE,
      safeColor(function() return packPctColor(wgt) end, GREEN),
      safeStr(function() return string.format("%.2fV", rxBat()) end, "--.--V"), LEFT),
    plainLabel(CARD_PAD_L, 68, PACK_W, 20, SMLSIZE, MUTED,
      safeStr(function()
        return string.format("%dS  %.2fV/c", detectCells(), perCellV())
      end, "-- --V/c"), LEFT),
  }))

  -- LINK card (LQ + PWR/RATE subtitle). Subtitle mirrors the battery card:
  -- compact SMLSIZE text with values pinned to the two ends.
  table.insert(kids, cardOutlined(col2X, cardsY, colW, cardsH, {
    plainLabel(CARD_PAD_L, 7, PACK_W, 20, nil, MUTED, SYM.WIFI .. " LINK", LEFT),
    plainLabel(CARD_PAD_L, 29, PACK_W, 40, DBLSIZE,
      safeColor(function() return lqColor(wgt) end, MUTED),
      safeStr(function() return string.format("%d%%", lq()) end, "--%"), LEFT),
    plainLabel(CARD_PAD_L, 68, PACK_W, 20, SMLSIZE, MUTED,
      safeStr(function()
        return string.format("%d mW  %d Hz", txPwr(), rfModeHz())
      end, "-- mW  -- Hz"), LEFT),
  }))

  -- RSSI card (RSSI value with units inline).
  local RSSI_W = col3W - CARD_PAD_L - CARD_PAD_R
  table.insert(kids, cardOutlined(col3X, cardsY, col3W, cardsH, {
    plainLabel(CARD_PAD_L, 7, RSSI_W, 20, nil, MUTED, "RSSI", LEFT),
    plainLabel(CARD_PAD_L, 29, RSSI_W, 40, DBLSIZE,
      safeColor(function() return rssiColor(wgt) end, MUTED),
      safeStr(function() return string.format("%d dBm", rssiVal()) end, "-- dBm"), LEFT),
  }))

  -- Row 3: GPS (left, wider) + READY (right).
  -- Title row carries the satellite count (color-coded by fix quality); the
  -- second row shows altitude / ground speed / distance in three columns.
  local GPS_W = wideW - CARD_PAD_L - CARD_PAD_R
  local GPS_THIRD = math.floor(GPS_W / 3)
  table.insert(kids, cardOutlined(PAGE_X, row3Y, wideW, row3H, {
    plainLabel(CARD_PAD_L, 8, GPS_THIRD, 20, nil, MUTED, SYM.GPS .. " GPS", LEFT),
    -- Satellite count, right-aligned in the title row. Green = usable 3D fix
    -- (>=6 sats), yellow = acquiring (1-5), muted = none.
    plainLabel(CARD_PAD_L + GPS_THIRD, 8, GPS_W - GPS_THIRD, 20, BOLD,
      safeColor(function()
        local n = gpsSats()
        if n >= 6 then return GREEN end
        if n >  0 then return YELLOW end
        return MUTED
      end, MUTED),
      safeStr(function()
        if not gpsPresent() then return "no GPS" end
        return string.format("%d sats", gpsSats())
      end, "no GPS"), RIGHT),
    -- Second row: ALT / SPD / DIST.
    plainLabel(CARD_PAD_L, 34, GPS_THIRD, 22, BOLD, TEXT,
      safeStr(function()
        if not gpsPresent() then return "ALT --" end
        return string.format("ALT %.0fm", gpsAlt())
      end, "ALT --"), LEFT),
    plainLabel(CARD_PAD_L + GPS_THIRD, 34, GPS_THIRD, 22, BOLD, TEXT,
      safeStr(function()
        if not gpsPresent() then return "SPD --" end
        return string.format("SPD %.0f km/h", gpsSpd())
      end, "SPD --"), CENTER),
    plainLabel(CARD_PAD_L + 2 * GPS_THIRD, 34, GPS_W - 2 * GPS_THIRD, 22, BOLD, TEXT,
      safeStr(function()
        if not gpsPresent() then return "DIST --" end
        return string.format("DIST %.0fm", gpsDist())
      end, "DIST --"), RIGHT),
  }))

  -- READY status: single big GO / CHECK label, centered inside the card.
  -- READY threshold uses the configurable per-cell warning (CellV_Warn).
  local function readyOk()
    local cellWarn = opt(wgt, "CellV_Warn", 350) / 100
    return linkUp() and rxBat() > 0 and perCellV() >= cellWarn
  end
  local READY_W = sideW - CARD_PAD_L - CARD_PAD_R
  table.insert(kids, cardOutlined(sideX, row3Y, sideW, row3H, {
    plainLabel(CARD_PAD_L, 20, READY_W, 42, DBLSIZE,
      safeColor(function() return readyOk() and GREEN or YELLOW end, YELLOW),
      safeStr(function()
        if readyOk() then return SYM.OK .. " GO" end
        return SYM.WARNING .. " CHECK"
      end, "CHECK"), CENTER),
  }))

  return kids
end

-- ============================================================================
-- FLIGHT TAB (live dashboard)
-- ============================================================================
local function appendSparklineBars(kids, wgt, footerY)
  local sparkH = 26
  local sparkBaseX = PAGE_X + 76
  local sparkBaseY = footerY + math.floor((FLY_FOOTER_H - sparkH) / 2)
  if compat.staticLvgl then
    -- Static bars on 2.12+ and MK3. pos/size callbacks hard-fault when callRefs
    -- evaluates many getters on real hardware (simulator 2.11 still tolerates them).
    for i = 1, 30 do
      table.insert(kids, {
        type = "rectangle", filled = true,
        x = sparkBaseX + (i - 1) * 4, y = sparkBaseY + sparkH - 1, w = 3, h = 1,
        color = MUTED,
      })
    end
    return
  end
  -- Original TX16S path: pos/size/color callbacks (verified on 480x272 hardware).
  for i = 1, 30 do
    table.insert(kids, {
      type = "rectangle", filled = true,
      x = sparkBaseX + (i - 1) * 4, y = sparkBaseY + sparkH - 1, w = 3, h = 1,
      color = safeColor(function()
        local h = state.history[(state.histN - 30) + i] or 0
        if h <= opt(wgt, "LQ_Crit", 50) then return RED    end
        if h <= opt(wgt, "LQ_Warn", 80) then return YELLOW end
        return GREEN
      end, MUTED),
      pos = function()
        local h = state.history[(state.histN - 30) + i] or 0
        local bh = math.floor(h * sparkH / 100); if bh < 1 then bh = 1 end
        return sparkBaseX + (i - 1) * 4, sparkBaseY + sparkH - bh
      end,
      size = function()
        local h = state.history[(state.histN - 30) + i] or 0
        local bh = math.floor(h * sparkH / 100); if bh < 1 then bh = 1 end
        return 3, bh
      end,
    })
  end
end

local function buildFlight(wgt)
  local kids = { bgFill(), tabBar(wgt) }
  local fullW    = PAGE_W
  local topY     = CONTENT_Y
  local statusY  = topY
  local cardsY   = statusY + FLY_STATUS_H + PAGE_GAP
  local statsY   = cardsY + FLY_CARDS_H + PAGE_GAP
  local footerY  = FLY_FOOTER_Y
  local leftW    = math.floor((fullW - PAGE_GAP) * 2 / 3)
  local rightX   = PAGE_X + leftW + PAGE_GAP
  local rightW   = SCR_W - rightX - PAGE_R

  -- Status bar: pure-value layout. No static labels — values are self-evident
  -- (timer has ':', ARMED is text, mode names are text, A/% are suffixes).
  -- This avoids label/value collisions seen at TX16S font widths.
  -- Status bar: 4 BOLD fields in equal-width absolute label slots. Row h=24
  -- gives BOLD glyphs (+ LVGL's implicit padding) room without scrolling.
  local STATUS_INNER_W = fullW - CARD_PAD_L - CARD_PAD_R
  local statusW = math.floor(STATUS_INNER_W / 4)
  table.insert(kids, cardOutlined(PAGE_X, statusY, fullW, FLY_STATUS_H, {
    plainLabel(CARD_PAD_L, 4, statusW, 22, BOLD, TEXT,
      safeStr(function() return fmtSecs(totalFlightSecs()) end, "0:00"), LEFT),
    plainLabel(CARD_PAD_L + statusW, 4, statusW, 22, BOLD,
      safeColor(function() return state.armed and RED or MUTED end, MUTED),
      safeStr(function()
          if state.armed then return SYM.CHARGE .. " ARMED" end
          return "DISARMED"
        end, "DISARMED"), CENTER),
    plainLabel(CARD_PAD_L + statusW * 2, 4, statusW, 22, BOLD, BLUE,
      safeStr(function() return modeName() end, "----"), CENTER),
    plainLabel(CARD_PAD_L + statusW * 3, 4, STATUS_INNER_W - statusW * 3, 22, BOLD, TEXT,
      safeStr(function() return string.format("%.1f A", curr()) end, "-- A"), RIGHT),
  }))

  -- LINK card — all radio-link metrics in one card:
  -- title + min stats / LQ + RSSI heroes / compact PWR+RATE line.
  -- Row heights tuned to observed effective label heights on hardware:
  -- STDSIZE/BOLD ~22, DBLSIZE ~40, SMLSIZE ~16.
  local LINK_INNER_W = leftW - CARD_PAD_L - CARD_PAD_R
  local LINK_HALF    = math.floor(LINK_INNER_W / 2)
  table.insert(kids, cardOutlined(PAGE_X, cardsY, leftW, FLY_CARDS_H, {
    plainLabel(CARD_PAD_L, 7, LINK_HALF, 20, nil, MUTED, SYM.WIFI .. " LINK", LEFT),
    plainLabel(CARD_PAD_L + LINK_HALF, 7, LINK_INNER_W - LINK_HALF, 20, nil, MUTED,
      safeStr(function()
          local lqs   = state.stats.minLQ   and (state.stats.minLQ   .. "%") or "--"
          local rssis = state.stats.minRSSI and tostring(state.stats.minRSSI) or "--"
          return "min " .. lqs .. " / " .. rssis
        end, "min -- / --"), RIGHT),
    plainLabel(CARD_PAD_L, 30, LINK_HALF, 42, DBLSIZE,
      safeColor(function() return lqColor(wgt) end, MUTED),
      safeStr(function() return string.format("LQ %d%%", lq()) end, "LQ --%"), LEFT),
    plainLabel(CARD_PAD_L + LINK_HALF, 30, LINK_INNER_W - LINK_HALF, 42, DBLSIZE,
      safeColor(function() return rssiColor(wgt) end, MUTED),
      safeStr(function() return string.format("%d dBm", rssiVal()) end, "-- dBm"), RIGHT),
    plainLabel(CARD_PAD_L, 76, LINK_HALF, 20, nil, MUTED,
      safeStr(function() return string.format("%d mW", txPwr()) end, "-- mW"), LEFT),
    plainLabel(CARD_PAD_L + LINK_HALF, 76, LINK_INNER_W - LINK_HALF, 20, nil, MUTED,
      safeStr(function() return string.format("%d Hz", rfModeHz()) end, "-- Hz"), RIGHT),
  }))

  -- PACK card (narrow right column on FLY tab) — matches LINK card height.
  -- Three rows: icon / big voltage / "Ns X.XXV/c" subtitle.
  local FLY_PACK_W = rightW - CARD_PAD_L - CARD_PAD_R
  table.insert(kids, cardOutlined(rightX, cardsY, rightW, FLY_CARDS_H, {
    plainLabel(CARD_PAD_L, 8, FLY_PACK_W, 20, nil, MUTED,
      safeStr(function() return batIcon(perCellV()) end, SYM.BAT_EMPTY), LEFT),
    plainLabel(CARD_PAD_L, 31, FLY_PACK_W, 42, DBLSIZE,
      safeColor(function() return packPctColor(wgt) end, GREEN),
      safeStr(function() return string.format("%.1fV", rxBat()) end, "--V"), LEFT),
    plainLabel(CARD_PAD_L, 76, FLY_PACK_W, 20, nil, MUTED,
      safeStr(function()
          return string.format("%dS  %.2fV/c", detectCells(), perCellV())
        end, "-- --V/c"), LEFT),
  }))

  -- Stats strip: session aggregates only (PWR/RATE are in the LINK card).
  -- Use absolute labels; hardware EdgeTX can still make child boxes scrollable
  -- even when scrollBar=false, but labels stay inert.
  local STRIP_INNER_W = fullW - 2*CARD_PAD_X
  local statW = math.floor(STRIP_INNER_W / 5)
  local sx = CARD_PAD_L
  local function flyStat(idx, label, valFn, def, align, colorFn)
    local x = sx + (idx - 1) * statW
    local w = (idx == 5) and (STRIP_INNER_W - (idx - 1) * statW) or statW
    return {
      plainLabel(x, 2, w, 20, SMLSIZE, MUTED, label, align),
      plainLabel(x, 23, w, 22, BOLD,
        colorFn and safeColor(colorFn, TEXT) or TEXT,
        safeStr(valFn, def or "--"), align),
    }
  end
  local statKids = {}
  local function addStat(t)
    for _, child in ipairs(t) do table.insert(statKids, child) end
  end
  addStat(flyStat(1, "mAh", function() return string.format("%d", capa()) end, "0", LEFT))
  addStat(flyStat(2, "max A", function() return string.format("%.1f A", state.stats.maxCurr) end, "-- A", CENTER))
  addStat(flyStat(3, "max ALT", function()
    if state.stats.maxAlt == 0 then return "--" end
    return string.format("%.0f m", state.stats.maxAlt)
  end, "--", CENTER))
  addStat(flyStat(4, "max SPD", function()
    if state.stats.maxSpd == 0 then return "--" end
    return string.format("%.0f", state.stats.maxSpd)
  end, "--", CENTER))
  addStat(flyStat(5, "min V", function()
    if state.stats.minPackV == nil then return "--" end
    return string.format("%.1fV", state.stats.minPackV)
  end, "--", RIGHT))
  table.insert(kids, cardOutlined(PAGE_X, statsY, fullW, FLY_STATS_H, statKids))

  -- Sparkline + alert bar combined. MK3 uses static bars; TX16S keeps the
  -- original pos/size callbacks that are verified on 480x272 hardware.
  local footerTextY = math.floor((FLY_FOOTER_H - 16) / 2)
  table.insert(kids, cardOutlined(PAGE_X, footerY, fullW, FLY_FOOTER_H, {
    plainLabel(CARD_PAD_L, footerTextY, 80, 20, nil, MUTED, "LQ 60s", LEFT),
  }))
  appendSparklineBars(kids, wgt, footerY)
  -- Telemetry status + mute button on right side of the same row.
  table.insert(kids, plainLabel(PAGE_X + 206, footerY + footerTextY, 220, 22, BOLD,
    safeColor(function() return alertFgColor(wgt) end, MUTED),
    safeStr(function() return telemetryText(wgt) end, ""), LEFT))
  -- MUTE: icon-only to avoid the LVGL overflow scrollbar in the compact footer.
  table.insert(kids, flatButton(SCR_W-PAGE_R-40, footerY + 4, 40, FLY_FOOTER_H - 8, SYM.MUTE,
    CARD_HI, TEXT))

  return kids
end

-- ============================================================================
-- STATS TAB
-- ============================================================================
local function buildStats(wgt)
  local kids = { bgFill(), tabBar(wgt) }
  local fullW  = PAGE_W
  local listY  = CONTENT_Y
  local resetY = SCR_H - PAGE_MARGIN - 32
  local listH  = resetY - PAGE_GAP - listY

  -- List-style stats: one row per metric (icon + label + right-aligned value).

  local STATS_INNER_W = fullW - CARD_PAD_L - CARD_PAD_R
  local rows = {}
  local function statRow(idx, icon, label, valFn, def, colorFn)
    local y = 4 + (idx - 1) * 20
    table.insert(rows, plainLabel(CARD_PAD_L, y, 24, 20, SMLSIZE, MUTED, icon, LEFT))
    table.insert(rows, plainLabel(CARD_PAD_L + 28, y, STATS_INNER_W - 148, 20, SMLSIZE, MUTED, label, LEFT))
    table.insert(rows, plainLabel(CARD_PAD_L + STATS_INNER_W - 120, y, 120, 20,
      SMLSIZE, colorFn and safeColor(colorFn, TEXT) or TEXT,
      safeStr(valFn, def or "--"), RIGHT))
  end
  statRow(1, SYM.PLAY,   "Flight time", function() return fmtSecs(totalFlightSecs()) end, "--",
    function() return state.armed and GREEN or TEXT end)
  statRow(2, SYM.CHARGE, "mAh used",    function() return string.format("%d mAh", capa()) end, "--")
  statRow(3, SYM.CHARGE, "Max current", function() return string.format("%.1f A", state.stats.maxCurr) end, "--")
  statRow(4, SYM.BAT_1,  "Min pack V",  function()
    if state.stats.minPackV == nil then return "--" end
    return string.format("%.2fV", state.stats.minPackV)
  end, "--")
  statRow(5, SYM.WIFI,   "Min LQ",      function() return state.stats.minLQ and (state.stats.minLQ .. "%") or "--%" end,
    "--%", function()
      return thresholdColor(state.stats.minLQ, opt(wgt, "LQ_Warn", 80), opt(wgt, "LQ_Crit", 50))
    end)
  statRow(6, SYM.WIFI,   "Min RSSI",    function() return state.stats.minRSSI and (state.stats.minRSSI .. " dBm") or "-- dBm" end,
    "-- dBm", function()
      return thresholdColor(state.stats.minRSSI, opt(wgt, "RSSI_Warn", -98), opt(wgt, "RSSI_Crit", -103))
    end)
  statRow(7, SYM.UP,     "Max altitude", function()
    if state.stats.maxAlt == 0 then return "(no GPS)" end
    return string.format("%.0f m", state.stats.maxAlt)
  end, "--")
  statRow(8, SYM.RIGHT,  "Max speed",   function()
    if state.stats.maxSpd == 0 then return "(no GPS)" end
    return string.format("%.0f km/h", state.stats.maxSpd)
  end, "--")
  statRow(9, SYM.GPS,    "Max distance", function()
    if state.stats.maxDist == 0 then return "(no GPS)" end
    return string.format("%.0f m", state.stats.maxDist)
  end, "--")

  table.insert(kids, cardOutlined(PAGE_X, listY, fullW, listH, rows))

  -- RESET button — full-width footer with proper button height (h=32 so the
  -- label has the same padding as other action buttons in the widget).
  table.insert(kids, flatButton(PAGE_X, resetY, fullW, 32, SYM.REFRESH .. " RESET SESSION",
    RED, WHITE))

  return kids
end

local function readLogPage(page)
  local out = {}
  local targetStart = (page - 1) * LOG_PAGE_SIZE + 1
  local targetEnd = targetStart + LOG_PAGE_SIZE - 1
  local seen = 0
  local hasNext = false
  pcall(function()
    local content = readWholeFile(sessionLogPath())
    if content == nil then return end
    for _, line in ipairs(splitPlain(content, "\n")) do
      if #line > 0 then
        local s = parseSessionLine(line)
        if s then
          seen = seen + 1
          if seen >= targetStart and seen <= targetEnd then
            table.insert(out, { idx = seen, sess = s })
          elseif seen > targetEnd then
            hasNext = true
            return
          end
        end
      end
    end
  end)
  return out, hasNext, seen
end

local function currentLogPage()
  if state.logPage < 1 then state.logPage = 1 end
  local entries, hasNext, seen = readLogPage(state.logPage)
  if #entries == 0 and state.logPage > 1 then
    state.logPage = state.logPage - 1
    entries, hasNext, seen = readLogPage(state.logPage)
  end
  return entries, hasNext, seen
end

local function logHasNextPage()
  local _, hasNext = currentLogPage()
  return hasNext
end

local function logHeaderText(page, hasNext, seen)
  if page == 1 and not hasNext then
    return seen .. " sessions  page 1"
  end
  return "page " .. page .. (hasNext and " ->" or "")
end

logPagePrev = function()
  if state.logPage > 1 then
    state.logPage = state.logPage - 1
    state.logCursor = 1
    state.logPageHasNext = false
    state.logPageChecked = nil
    state.dirty = true
  end
end
logPageNext = function()
  local hasNext = state.logPageChecked == state.logPage
    and state.logPageHasNext == true
  if not hasNext then hasNext = logHasNextPage() end
  if hasNext then
    state.logPage = state.logPage + 1
    state.logCursor = 1
    state.logPageHasNext = false
    state.logPageChecked = nil
    state.dirty = true
  end
end

logBack = function()
  if state.tab == 3 and state.selectedSess then
    state.selectedSess = nil
    -- Mode-changing actions (back, anything that swaps which UI is on
    -- screen) get a long 800ms touch block so the trailing event from the
    -- same finger press can never land on the rebuilt list. Do not
    -- reset _lastTouchX/Y here — leaving them at the consumed-tap coords
    -- means the sameSpot dedupe also blocks any follow-up event at that
    -- exact spot inside the next 200ms, redundant safety.
    state._touchBlockUntil = math.max(state._touchBlockUntil or 0,
      getTime() + CFG.touch.rebuildBlockCs)
    state.dirty = true
    return true
  end
  return false
end

local function eventIs(event, ...)
  for i = 1, select("#", ...) do
    local ev = select(i, ...)
    if ev ~= nil and event == ev then return true end
  end
  return false
end

local function buildLog(wgt)
  local kids = { bgFill(), tabBar(wgt) }

  local fullW = PAGE_W
  local headerY = CONTENT_Y
  local listY = headerY + 32 + PAGE_GAP
  local footerY = SCR_H - PAGE_MARGIN - 28
  local listH = footerY - PAGE_GAP - listY
  local backY = SCR_H - PAGE_MARGIN - 32
  local detailH = backY - PAGE_GAP - listY
  local LOG_INNER_W = fullW - CARD_PAD_L - CARD_PAD_R

  -- If a detail-view is selected, show that instead of the list.
  if state.selectedSess then
    local s = state.selectedSess

    -- Detail header: timestamp (left) + "Xs · YY mAh" (right).
    table.insert(kids, cardOutlined(PAGE_X, headerY, fullW, 32, {
      plainLabel(CARD_PAD_L, 5, math.floor(LOG_INNER_W/2), 22, BOLD, TEXT,
        safeStr(function() return fmtSessionTime(s.ts) end, "--"), LEFT),
      plainLabel(CARD_PAD_L + math.floor(LOG_INNER_W/2), 5,
        LOG_INNER_W - math.floor(LOG_INNER_W/2), 22, nil, MUTED,
        safeStr(function() return fmtSecs(s.dur) .. "  " .. (s.mAh or 0) .. " mAh" end, "--"), RIGHT),
    }))

    -- Detail grid: two columns keep labels close to their values and let all
    -- recorded session metrics fit above the back button without scrolling.
    local detailRows = {}
    local colGap = 8
    local colW = math.floor((LOG_INNER_W - colGap) / 2)
    local function detailRow(col, row, icon, label, valFn, def, colorFn)
      local x = CARD_PAD_L + (col - 1) * (colW + colGap)
      local y = 4 + (row - 1) * 22
      table.insert(detailRows, plainLabel(x, y, 18, 20, SMLSIZE, MUTED, icon, LEFT))
      table.insert(detailRows, plainLabel(x + 22, y, 88, 20, SMLSIZE, MUTED, label, LEFT))
      table.insert(detailRows, plainLabel(x + 112, y, colW - 112, 20,
        SMLSIZE, colorFn and safeColor(colorFn, TEXT) or TEXT,
        safeStr(valFn, def or "--"), RIGHT))
    end
    -- Order (left→right, then next row):
    --   Time, Max curr / Used, Min pack / Min LQ, Min RSSI / Pwr, Rate /
    --   Start lat, Start lon / Max alt, Max speed / Max dist
    detailRow(1, 1, SYM.PLAY,   "Time",      function() return fmtSecs(s.dur or 0) end, "--")
    detailRow(2, 1, SYM.CHARGE, "Max curr",  function() return string.format("%.1f A", s.maxA or 0) end, "--")
    detailRow(1, 2, SYM.CHARGE, "Used",      function() return (s.mAh or 0) .. " mAh" end, "--",
      function() return wgt.options.AccentColor end)
    detailRow(2, 2, SYM.BAT_1,  "Min pack",  function() return s.minV and string.format("%.2fV", s.minV) or "--" end, "--",
      function()
        local pc = loggedPerCellV(s.minV)
        return thresholdColor(pc, opt(wgt, "CellV_Warn", 350) / 100, opt(wgt, "CellV_Crit", 330) / 100)
      end)
    detailRow(1, 3, SYM.WIFI,   "Min LQ",    function() return s.minLQ and (s.minLQ .. "%") or "--%" end, "--%",
      function() return thresholdColor(s.minLQ, opt(wgt, "LQ_Warn", 80), opt(wgt, "LQ_Crit", 50)) end)
    detailRow(2, 3, SYM.WIFI,   "Min RSSI",  function() return s.minRSSI and (s.minRSSI .. " dBm") or "-- dBm" end, "-- dBm",
      function() return thresholdColor(s.minRSSI, opt(wgt, "RSSI_Warn", -98), opt(wgt, "RSSI_Crit", -103)) end)
    detailRow(1, 4, SYM.WIFI,   "Pwr", function()
      return s.maxPwr and string.format("%.0f mW", s.maxPwr) or "-- mW"
    end, "-- mW")
    detailRow(2, 4, SYM.WIFI,   "Rate", function()
      return s.rfHz and string.format("%.0f Hz", s.rfHz) or "-- Hz"
    end, "-- Hz")
    detailRow(1, 5, SYM.GPS,    "Start lat", function()
      return fmtCoord(s.startLat)
    end, "--")
    detailRow(2, 5, SYM.GPS,    "Start lon", function()
      return fmtCoord(s.startLon)
    end, "--")
    detailRow(1, 6, SYM.UP,     "Max alt", function()
      return (s.maxAl and s.maxAl > 0) and string.format("%.0f m", s.maxAl) or "(no GPS)"
    end, "--")
    detailRow(2, 6, SYM.RIGHT,  "Max speed", function()
      return (s.maxSp and s.maxSp > 0) and string.format("%.0f km/h", s.maxSp) or "(no GPS)"
    end, "--")
    detailRow(1, 7, SYM.GPS,    "Max dist", function()
      return (s.maxDi and s.maxDi > 0) and string.format("%.0f m", s.maxDi) or "(no GPS)"
    end, "--")
    table.insert(kids, cardOutlined(PAGE_X, listY, fullW, detailH, detailRows))

    -- Back to list button (unchanged)
    table.insert(kids, flatButton(PAGE_X, backY, fullW, 32, SYM.LEFT .. " BACK TO LIST",
      CARD_HI, TEXT))
    return kids
  end

  -- List view. Read the page once and use the same snapshot for header,
  -- rows, and pager buttons so UI text and button state cannot drift apart.
  local entries, hasNext, seen = currentLogPage()
  local page = state.logPage
  local total = seen
  state.logPageHasNext = hasNext == true
  state.logPageChecked = page

  -- Header bar: title (left) + session count + page indicator (right).
  -- Same h=24 as detail header to keep BOLD glyphs clear of row bounds.
  table.insert(kids, cardOutlined(PAGE_X, headerY, fullW, 32, {
    plainLabel(CARD_PAD_L, 5, math.floor(LOG_INNER_W/2), 22, BOLD, MUTED,
      SYM.HOME .. " FLIGHT LOG", LEFT),
    plainLabel(CARD_PAD_L + math.floor(LOG_INNER_W/2), 5,
      LOG_INNER_W - math.floor(LOG_INNER_W/2), 22, nil, MUTED,
      logHeaderText(page, hasNext, seen), RIGHT),
  }))

  if total == 0 then
    -- Empty state: two stacked MUTED labels, vertically centered.
    table.insert(kids, cardOutlined(PAGE_X, listY, fullW, listH, {
      plainLabel(CARD_PAD_L, 52, LOG_INNER_W, 20, nil, MUTED, "No sessions logged yet.", LEFT),
      plainLabel(CARD_PAD_L, 74, LOG_INNER_W, 20, nil, MUTED, "Connect a battery and arm at least once.", LEFT),
    }))
    return kids
  end

  local rows = {}
  -- Clamp the persisted highlight to the current page size in case the
  -- last record fell off (e.g. log was trimmed while detail was open).
  if state.logCursor and state.logCursor > #entries then
    state.logCursor = #entries > 0 and #entries or nil
  end
  for i, entry in ipairs(entries) do
    local s = entry.sess
    local y = 6 + (i - 1) * LOG_ROW_STEP
    local rowIdx   = i          -- capture for closure
    -- Full-row lvgl.button. The EdgeTX button theme draws a thin button
    -- background/border around it regardless of the color setting, so the
    -- theme border doubles as the row separator.
    table.insert(rows, {
      type = "button", x = 4, y = y - 2, w = fullW - 8, h = LOG_ROW_H,
      text = "", color = CARD, textColor = CARD, cornerRadius = 4,
      press = function()
        state.selectedSess = s
        state.logCursor    = rowIdx
        state._eatingTouch = true
        state.dirty = true
      end,
    })
    table.insert(rows, plainLabel(12,  y, 108, 22, BOLD, TEXT, fmtSessionTime(s.ts), LEFT))
    table.insert(rows, plainLabel(132, y, 56,  22, nil,  TEXT, fmtSecs(s.dur or 0), LEFT))
    table.insert(rows, plainLabel(202, y, 92,  22, nil,  wgt.options.AccentColor, (s.mAh or 0) .. " mAh", LEFT))
    table.insert(rows, plainLabel(306, y, 66,  22, nil,  TEXT, string.format("%.1fA", s.maxA or 0), LEFT))
    table.insert(rows, plainLabel(388, y, 24,  22, nil, MUTED, "LQ", LEFT))
    table.insert(rows, plainLabel(412, y, 36,  22, nil,
      safeColor(function() return thresholdColor(s.minLQ, opt(wgt, "LQ_Warn", 80), opt(wgt, "LQ_Crit", 50)) end, MUTED),
      s.minLQ and tostring(s.minLQ) or "--", RIGHT))
  end
  table.insert(kids, scrollCard(PAGE_X, listY, fullW, listH, rows))

  -- Only render available pager directions. Hidden unavailable buttons avoid
  -- LVGL's disabled gray style and make the footer state unambiguous.
  if page > 1 then
    table.insert(kids, {
      type = "button", x = PAGE_X, y = footerY, w = 80, h = 28,
      text = SYM.LEFT, color = CARD_HI, textColor = TEXT, cornerRadius = 4,
      press = function()
        logPagePrev()
        state._eatingTouch = true
      end,
    })
  end
  if hasNext then
    table.insert(kids, {
      type = "button", x = SCR_W-PAGE_R-80, y = footerY, w = 80, h = 28,
      text = SYM.RIGHT, color = CARD_HI, textColor = TEXT, cornerRadius = 4,
      press = function()
        logPageNext()
        state._eatingTouch = true
      end,
    })
  end

  return kids
end

-- ============================================================================
-- GPS TAB
-- ============================================================================
local function fmtGpsTime(ts)
  if type(ts) ~= "string" or #ts < CFG.runtime.timestampLen then return "--" end
  return fmtSessionTime(ts)
end

local function fmtSavedGpsTime()
  return fmtGpsTime(state.gps.savedTs)
end

local function gpsFixText()
  local n = gpsSats()
  if state.gps.liveLat and state.gps.liveLon then
    return string.format("%d sats  FIX", n)
  end
  if n > 0 then return string.format("%d sats  ACQ", n) end
  if gpsPresent() then return "0 sats  ACQ" end
  return "no GPS"
end

local function gpsFixColor()
  local n = gpsSats()
  if state.gps.liveLat and state.gps.liveLon and n >= 6 then return GREEN end
  if n > 0 then return YELLOW end
  if gpsPresent() then return YELLOW end
  return MUTED
end

local function qrLoadingText()
  local n = math.floor((getTime() or 0) / 40) % 4
  local dots = ""
  for _ = 1, n do dots = dots .. "." end
  return "QR BUILDING" .. dots
end

local function qrLoadingProgress()
  local n = math.floor((getTime() or 0) / 20) % 8
  return n
end

local function addQr(kids, rows, x, y, module)
  local quiet = 4
  local px = (QR_SIZE + quiet * 2) * module
  local qrErr = state.gps.qrErr
  table.insert(kids, { type = "rectangle", x = x, y = y, w = px, h = px,
    color = QR_LIGHT, filled = true, rounded = 0 })
  if not rows then
    state.gps.qrErr = qrErr or "QR NOT READY"
    table.insert(kids, plainLabel(x + 8, y + 8, px - 16, 24, SMLSIZE, QR_DARK, "QR ERR", CENTER))
    return false
  end
  for row = 1, QR_SIZE do
    local col = 1
    while col <= QR_SIZE do
      if string.sub(rows[row], col, col) == "1" then
        local start = col
        while col <= QR_SIZE and string.sub(rows[row], col, col) == "1" do
          col = col + 1
        end
        table.insert(kids, {
          type = "rectangle", filled = true, color = QR_DARK, rounded = 0,
          x = x + (start - 1 + quiet) * module,
          y = y + (row - 1 + quiet) * module,
          w = (col - start) * module,
          h = module,
        })
      else
        col = col + 1
      end
    end
  end
  return true
end

local function addQrLoading(kids, x, y, w, h, payload)
  local innerW = w - CARD_PAD_L - CARD_PAD_R
  local progressW = 128
  local progressX = CARD_PAD_L + math.floor((innerW - progressW) / 2)
  local progressY = 120
  local step = qrLoadingProgress()
  local fillW = 18 + step * 14
  if fillW > progressW then fillW = progressW end
  table.insert(kids, cardOutlined(x, y, w, h, {
    plainLabel(CARD_PAD_L, 6, w - CARD_PAD_L - CARD_PAD_R, 20, BOLD, MUTED,
      SYM.GPS .. " QR", LEFT),
    plainLabel(CARD_PAD_L, 34, w - CARD_PAD_L - CARD_PAD_R, 22, BOLD, TEXT,
      safeStr(function()
        return fmtCoord(state.gps.qrLat or state.gps.savedLat) .. ", "
          .. fmtCoord(state.gps.qrLon or state.gps.savedLon)
      end, "--"), LEFT),
    plainLabel(CARD_PAD_L, 62, w - CARD_PAD_L - CARD_PAD_R, 20, SMLSIZE, MUTED,
      payload or "--", LEFT),
    plainLabel(CARD_PAD_L, 91, w - CARD_PAD_L - CARD_PAD_R, 22, BOLD, ACCENT,
      safeStr(qrLoadingText, "QR BUILDING"), CENTER),
    { type = "rectangle", x = progressX, y = progressY, w = progressW, h = 8,
      rounded = 4, filled = true, color = CARD_HI },
    { type = "rectangle", x = progressX, y = progressY, w = fillW, h = 8,
      rounded = 4, filled = true, color = ACCENT },
  }))
end

local function addQrFallback(kids, x, y, w, h, payload)
  table.insert(kids, cardOutlined(x, y, w, h, {
    plainLabel(CARD_PAD_L, 6, w - CARD_PAD_L - CARD_PAD_R, 20, BOLD, MUTED,
      SYM.GPS .. " QR", LEFT),
    plainLabel(CARD_PAD_L, 34, w - CARD_PAD_L - CARD_PAD_R, 22, BOLD, TEXT,
      safeStr(function()
        return fmtCoord(state.gps.qrLat or state.gps.savedLat) .. ", "
          .. fmtCoord(state.gps.qrLon or state.gps.savedLon)
      end, "--"), LEFT),
    plainLabel(CARD_PAD_L, 62, w - CARD_PAD_L - CARD_PAD_R, 20, SMLSIZE, MUTED,
      payload or "--", LEFT),
    plainLabel(CARD_PAD_L, 86, w - CARD_PAD_L - CARD_PAD_R, 20, SMLSIZE, RED,
      safeStr(function() return state.gps.qrErr or "QR BUILD FAILED" end, "QR BUILD FAILED"), LEFT),
  }))
end

local function shortQrErr(s)
  s = tostring(s or state.gps.qrErr or "QR BUILD FAILED")
  if #s > 48 then return string.sub(s, 1, 48) end
  return s
end

local function buildGps(wgt)
  loadSavedGps()
  sampleGps()
  local kids = { bgFill(), tabBar(wgt) }
  local fullW = PAGE_W
  local footerY = SCR_H - PAGE_MARGIN - 32
  local qx, qy, qw, qh = gpsFooterRects()

  if state.gps.showQr and state.gps.qrPayload then
    local cardY = CONTENT_Y
    local cardH = footerY - PAGE_GAP - cardY
    local payload = state.gps.qrPayload
    local module = 4
    local qrPx = (QR_SIZE + 8) * module
    local qrX = PAGE_X + math.floor((fullW - qrPx) / 2)
    local qrY = cardY + 32 + math.floor((cardH - 32 - qrPx) / 2)
    table.insert(kids, cardOutlined(PAGE_X, cardY, fullW, cardH, {
      plainLabel(CARD_PAD_L, 6, 120, 20, BOLD, MUTED, SYM.GPS .. " QR", LEFT),
      plainLabel(CARD_PAD_L + 130, 6, fullW - CARD_PAD_L - CARD_PAD_R - 130, 20,
        SMLSIZE, MUTED, safeStr(function() return fmtGpsTime(state.gps.qrTs) end, "--"), RIGHT),
    }))
    if state.gps.qrBuildPending and not state.gps.qrRows then
      addQrLoading(kids, PAGE_X, cardY, fullW, cardH, payload)
    else
      local ok, rendered = pcall(addQr, kids, state.gps.qrRows, qrX, qrY, module)
      if not ok then state.gps.qrErr = shortQrErr(rendered) end
      if not ok or not rendered then
        addQrFallback(kids, PAGE_X, cardY, fullW, cardH, payload)
      end
    end
  else
    local headerY = CONTENT_Y
    local headerH = 38
    local liveY = headerY + headerH + PAGE_GAP
    local liveH = 76
    local savedY = liveY + liveH + PAGE_GAP
    local savedH = footerY - PAGE_GAP - savedY
    local innerW = fullW - CARD_PAD_L - CARD_PAD_R
    local halfW = math.floor(innerW / 2)
    local thirdW = math.floor(innerW / 3)

    table.insert(kids, cardOutlined(PAGE_X, headerY, fullW, headerH, {
      plainLabel(CARD_PAD_L, 8, halfW, 22, BOLD, MUTED, SYM.GPS .. " GPS", LEFT),
      plainLabel(CARD_PAD_L + halfW, 8, innerW - halfW, 22, BOLD,
        safeColor(gpsFixColor, MUTED), safeStr(gpsFixText, "no GPS"), RIGHT),
    }))

    table.insert(kids, cardOutlined(PAGE_X, liveY, fullW, liveH, {
      plainLabel(CARD_PAD_L, 6, halfW, 18, SMLSIZE, MUTED, "LIVE LAT", LEFT),
      plainLabel(CARD_PAD_L + halfW, 6, innerW - halfW, 18, SMLSIZE, MUTED, "LIVE LON", RIGHT),
      plainLabel(CARD_PAD_L, 27, halfW, 24, BOLD, TEXT,
        safeStr(function() return fmtCoord(state.gps.liveLat) end, "--.------"), LEFT),
      plainLabel(CARD_PAD_L + halfW, 27, innerW - halfW, 24, BOLD, TEXT,
        safeStr(function() return fmtCoord(state.gps.liveLon) end, "--.------"), RIGHT),
      plainLabel(CARD_PAD_L, 55, thirdW, 18, SMLSIZE, MUTED,
        safeStr(function() return string.format("ALT %.0fm", gpsAlt()) end, "ALT --"), LEFT),
      plainLabel(CARD_PAD_L + thirdW, 55, thirdW, 18, SMLSIZE, MUTED,
        safeStr(function() return string.format("SPD %.0f km/h", gpsSpd()) end, "SPD --"), CENTER),
      plainLabel(CARD_PAD_L + thirdW * 2, 55, innerW - thirdW * 2, 18, SMLSIZE, MUTED,
        safeStr(function() return string.format("DIST %.0fm", gpsDist()) end, "DIST --"), RIGHT),
    }))

    table.insert(kids, cardOutlined(PAGE_X, savedY, fullW, savedH, {
      plainLabel(CARD_PAD_L, 7, halfW, 20, BOLD, MUTED, "LAST SAVED", LEFT),
      plainLabel(CARD_PAD_L + halfW, 7, innerW - halfW, 20, SMLSIZE, MUTED,
        safeStr(function()
          local s = state.gps.savedSats and (state.gps.savedSats .. " sats") or "-- sats"
          return fmtSavedGpsTime() .. "  " .. s
        end, "--"), RIGHT),
      plainLabel(CARD_PAD_L, 34, halfW, 22, BOLD, TEXT,
        safeStr(function() return fmtCoord(state.gps.savedLat) end, "--.------"), LEFT),
      plainLabel(CARD_PAD_L + halfW, 34, innerW - halfW, 22, BOLD, TEXT,
        safeStr(function() return fmtCoord(state.gps.savedLon) end, "--.------"), RIGHT),
    }))
  end

  table.insert(kids, {
    type = "button", x = qx, y = qy, w = qw, h = qh,
    text = state.gps.showQr and "HIDE QR" or "QR",
    color = CARD_HI, textColor = TEXT, cornerRadius = RADIUS,
    press = function()
      toggleGpsQr()
      state._eatingTouch = true
    end,
  })

  return kids
end

-- ============================================================================
-- LAYOUT DISPATCH
-- ============================================================================
local FULL_SCREEN_BUILDERS = {
  [0] = buildPreflight,
  [1] = buildFlight,
  [2] = buildStats,
  [3] = buildLog,
  [4] = buildGps,
}

local function buildMk3Bootstrap(wgt)
  lvgl.clear()
  wgt.ui = lvgl.build(compat.scaleFullTree({
    bgFill(),
    plainLabel(PAGE_X, CONTENT_Y + 48, PAGE_W - 2 * PAGE_MARGIN, 28,
      BOLD, TEXT, "EdgeDeck", CENTER),
  })) or {}
  wgt._deferFullLayout = true
end

local function buildFullScreen(wgt)
  if compat.highRes then
    -- One splash ever, then direct full builds (including tab changes).
    if not wgt._mk3BootSplashDone then
      wgt._mk3BootSplashDone = true
      buildMk3Bootstrap(wgt)
      return
    end
    if wgt._deferFullLayout then
      wgt._deferFullLayout = false
    end
    compat.traceStartup("build-full-tab-" .. tostring(state.tab))
    compat.mk3BeginBuild(wgt)
    lvgl.clear()
    local builder = FULL_SCREEN_BUILDERS[state.tab] or buildFlight
    local tree = compat.scaleFullTree(builder(wgt))
    wgt.ui = lvgl.build(tree) or {}
    wgt._mk3FullReady = true
    compat.noteLayoutBuilt(wgt, true)
    return
  end

  lvgl.clear()
  local builder = FULL_SCREEN_BUILDERS[state.tab] or buildFlight
  if compat.staticLvgl then
    compat.mk3BeginBuild(wgt)
    wgt.ui = lvgl.build(builder(wgt)) or {}
    wgt._mk3FullReady = true
    compat.noteLayoutBuilt(wgt, true)
  else
    lvgl.build(builder(wgt))
  end
end

-- Focus-mode zone layout. This is not a mini full-screen dashboard; it keeps
-- only the high-signal flight checks visible in a regular model-screen zone:
-- arm/mode, pack health, link health, and telemetry status.
local function buildZone(wgt)
  if compat.staticLvgl then compat.mk3BeginBuild(wgt) end
  lvgl.clear()
  local zx, zy, zw, zh = wgt.zone.x, wgt.zone.y, wgt.zone.w, wgt.zone.h
  local gap = PAGE_GAP
  local pad = math.max(6, math.floor(math.min(zw, zh) * 0.035))
  local fullW = zw - 2*pad
  local topH = 30
  local bottomH = 28
  local mainY = zy + pad + topH + gap
  local mainH = math.max(70, zh - 2*pad - topH - bottomH - 2*gap)
  local colW = math.floor((fullW - gap) / 2)
  local rightX = zx + pad + colW + gap
  local innerW = colW - CARD_PAD_L - CARD_PAD_R
  local bottomY = mainY + mainH + gap
  local topInnerW = fullW - CARD_PAD_L - CARD_PAD_R
  local satW = math.min(110, math.floor(topInnerW * 0.26))
  local armW = math.min(150, math.floor(topInnerW * 0.36))
  local modeX = CARD_PAD_L + armW + 8
  local modeW = math.max(40, topInnerW - armW - satW - 16)
  local bottomHalf = math.floor(topInnerW / 2)

  local zoneTree = {
    { type = "rectangle", x = zx, y = zy, w = zw, h = zh,
      color = BG, filled = true, rounded = RADIUS },

    cardOutlined(zx + pad, zy + pad, fullW, topH, {
      plainLabel(CARD_PAD_L, 4, armW, 22, BOLD,
        safeColor(function() return state.armed and RED or MUTED end, MUTED),
        safeStr(function()
            if state.armed then return SYM.CHARGE .. " ARMED" end
            return "DISARMED"
          end, "DISARMED"), LEFT),
      plainLabel(modeX, 4, modeW, 22, BOLD, BLUE,
        safeStr(function() return modeName() end, "----"), LEFT),
      plainLabel(CARD_PAD_L + topInnerW - satW, 4, satW, 22, BOLD,
        safeColor(gpsFixColor, MUTED),
        safeStr(function()
          if not gpsPresent() then return SYM.GPS .. " --" end
          return string.format("%s %d", SYM.GPS, gpsSats())
        end, SYM.GPS .. " --"), RIGHT),
    }),

    cardOutlined(zx + pad, mainY, colW, mainH, {
      plainLabel(CARD_PAD_L, 8, innerW, 20, nil, MUTED,
        safeStr(function() return batIcon(perCellV()) .. " PACK" end, "PACK"), LEFT),
      plainLabel(CARD_PAD_L, 34, innerW, 42, DBLSIZE,
        safeColor(function() return packPctColor(wgt) end, GREEN),
        safeStr(function() return string.format("%.1fV", rxBat()) end, "--V"), LEFT),
      plainLabel(CARD_PAD_L, mainH - 28, innerW, 22, nil, MUTED,
        safeStr(function()
          return string.format("%dS  %.2fV/c", detectCells(), perCellV())
        end, "-- --V/c"), LEFT),
    }),

    cardOutlined(rightX, mainY, colW, mainH, {
      plainLabel(CARD_PAD_L, 8, innerW, 20, nil, MUTED, SYM.WIFI .. " LINK", LEFT),
      plainLabel(CARD_PAD_L, 34, innerW, 42, DBLSIZE,
        safeColor(function() return lqColor(wgt) end, MUTED),
        safeStr(function() return string.format("LQ %d%%", lq()) end, "LQ --%"), LEFT),
      plainLabel(CARD_PAD_L, mainH - 28, innerW, 22, nil,
        safeColor(function() return rssiColor(wgt) end, MUTED),
        safeStr(function() return string.format("%d dBm", rssiVal()) end, "-- dBm"), LEFT),
    }),

    cardOutlined(zx + pad, bottomY, fullW, bottomH, {
      plainLabel(CARD_PAD_L, 4, bottomHalf, 20, nil, MUTED,
        safeStr(function() return string.format("%d mW", txPwr()) end, "-- mW"), LEFT),
      plainLabel(CARD_PAD_L + bottomHalf, 4, topInnerW - bottomHalf, 20,
        nil, safeColor(function() return alertFgColor(wgt) end, MUTED),
        safeStr(function() return telemetryText(wgt) end, ""), RIGHT),
    }),
  }
  if compat.staticLvgl then
    wgt.ui = lvgl.build(zoneTree) or {}
    compat.noteLayoutBuilt(wgt, false)
  else
    lvgl.build(zoneTree)
  end
end

-- ============================================================================
-- WIDGET API
-- ============================================================================
local function create(zone, opts)
  return {
    zone = zone,
    options = opts,
    isFull = nil,
    ui = nil,
    layoutFailed = false,
    _mk3BootSplashDone = false,
    _mk3FullReady = false,
    _deferFullLayout = false,
  }
end

local function update(wgt, opts)
  wgt.options = opts
  if not compat.staticLvgl then
    wgt.isFull = nil
    state.dirty = true
    return
  end
  compat.traceStartup("update")
  -- Widget settings always call update() on close (even without changes).
  -- Options are dynamic; structural layout does not change. Suppress rebuild.
  if wgt.layoutFailed then
    local wasFull = wgt.isFull == true
    wgt.layoutFailed = false
    wgt.ui = nil
    wgt.isFull = nil
    state.layoutError = nil
    state.layoutErrorStage = nil
    wgt._latchFullLayout = compat.highRes or wasFull
    state.dirty = true
  else
    state.dirty = false
    if wgt.isFull == true then wgt._latchFullLayout = true end
  end
end

local function isFullScreen()
  if lvgl == nil or lvgl.isFullScreen == nil then return false end
  local ok, v = pcall(lvgl.isFullScreen); return ok and v == true
end

-- lvgl.isFullScreen() can read false on MK3 during widget-settings exit (and
-- briefly at startup) even though the dashboard is fullscreen. Picking zone
-- layout there builds the wrong tree and has triggered hard faults.
local function layoutFullScreen(wgt)
  local apiFull = isFullScreen()
  if apiFull then
    if wgt then wgt._latchFullLayout = false end
    return true
  end
  if not wgt then return false end
  if wgt._latchFullLayout and wgt.isFull == true then
    compat.traceStartup("full-latch-after-settings")
    return true
  end
  if compat.highRes then
    if wgt._mk3FullReady or wgt.isFull == true then return true end
    local zw = wgt.zone and wgt.zone.w or 0
    local zh = wgt.zone and wgt.zone.h or 0
    if zw >= math.floor(compat.pixelW * 0.85)
       and zh >= math.floor(compat.pixelH * 0.85) then
      return true
    end
  end
  return false
end

function compat.buildLayoutFallback(wgt, full, stage, err)
  local zx, zy, zw, zh = 0, 0, compat.pixelW, compat.pixelH
  if not full and wgt.zone then
    zx, zy = wgt.zone.x or 0, wgt.zone.y or 0
    zw, zh = wgt.zone.w or compat.pixelW, wgt.zone.h or compat.pixelH
  end
  local width = math.max(1, zw - 16)
  lvgl.clear()
  wgt.ui = lvgl.build({
    { type = "rectangle", x = zx, y = zy, w = zw, h = zh,
      color = BG, filled = true, children = {
        { type = "label", x = 8, y = 8, w = width, h = 28,
          color = RED, font = BOLD, text = "EdgeDeck safe mode" },
        { type = "label", x = 8, y = 40, w = width, h = 24,
          color = TEXT, text = "Stage: " .. tostring(stage or "layout") },
        { type = "label", x = 8, y = 68, w = width, h = math.max(24, zh - 76),
          color = MUTED, text = compat.shortError(err) },
      } },
  }) or {}
end

local function ensureLayoutLegacy(wgt)
  local full = isFullScreen()
  if full ~= wgt.isFull or state.dirty then
    local ok = pcall(function()
      if full then buildFullScreen(wgt) else buildZone(wgt) end
    end)
    if ok then
      wgt.isFull = full
      state.dirty = false
    else
      pcall(collectgarbage, "collect")
    end
  end
  return false
end

local function ensureLayout(wgt)
  if not compat.staticLvgl then
    return ensureLayoutLegacy(wgt)
  end
  local full = compat.highRes and layoutFullScreen(wgt) or isFullScreen()
  if wgt.layoutFailed then
    -- State changes elsewhere (notably incremental QR generation) may mark
    -- the shared layout dirty. Safe mode must remain latched until EdgeTX
    -- calls update() or the widget is reloaded. Do not consume the shared
    -- dirty flag here; another healthy EdgeDeck instance may still need it.
    return false
  end
  if compat.highRes and wgt._mk3BootSplashDone and state.dirty and state._eatingTouch then
    compat.traceStartup("rebuild-deferred-touch")
    return false
  end
  if full ~= wgt.isFull or state.dirty then
    if wgt._mk3FullReady and state.dirty and full == wgt.isFull then
      if not compat.mk3NeedsRebuild(wgt, full) then
        state.dirty = false
        return false
      end
    end
    local stage = full and "build-full" or "build-zone"
    compat.traceStartup(stage .. "-begin")
    local ok, err = pcall(function()
      if full then buildFullScreen(wgt) else buildZone(wgt) end
    end)
    if ok then
      wgt.isFull = full
      wgt.layoutFailed = false
      state.layoutError = nil
      state.layoutErrorStage = nil
      if wgt._deferFullLayout then
        state.dirty = true
      else
        state.dirty = false
      end
      compat.traceStartup(stage .. "-ok")
      return true
    else
      -- Do not repeat a failed clear/build every refresh. On affected H7
      -- firmware that retry loop can turn a recoverable Lua error into an
      -- LVGL allocation storm or hard fault.
      state.layoutError = compat.shortError(err)
      state.layoutErrorStage = stage
      state.dirty = false
      wgt.layoutFailed = true
      wgt.ui = nil
      compat.traceStartup(stage .. "-error", err)
      pcall(collectgarbage, "collect")
      local fallbackOk, fallbackErr = pcall(compat.buildLayoutFallback, wgt, full, stage, err)
      if not fallbackOk then compat.traceStartup("fallback-error", fallbackErr) end
      return false
    end
  end
  return false
end

local function refresh(wgt, event, touchState)
  if lvgl == nil then
    lcd.drawText(0, 0, "EdgeTX 2.11+ required (LVGL)", COLOR_THEME_WARNING)
    return
  end
  local exitBack = eventIs(event,
    EVT_VIRTUAL_EXIT, EVT_EXIT_BREAK, EVT_RTN_BREAK, EVT_KEY_EXIT)
  local pageNext = eventIs(event,
    EVT_VIRTUAL_NEXT_PAGE, EVT_PAGE_NEXT, EVT_PAGEDN_BREAK,
    EVT_PAGE_BREAK, EVT_VIRTUAL_PAGE)
  local pagePrev = eventIs(event,
    EVT_VIRTUAL_PREV_PAGE, EVT_PAGE_PREV, EVT_PAGEUP_BREAK,
    EVT_PAGE_LONG, EVT_VIRTUAL_PAGE_LONG)
  -- LOG rows and pager buttons are native lvgl.button widgets, so their
  -- touch presses come through LVGL callbacks.
  if exitBack then
    pcall(logBack)
  elseif state.tab == 3 and not state.selectedSess and pageNext then
    pcall(logPageNext)
  elseif state.tab == 3 and not state.selectedSess and pagePrev then
    pcall(logPagePrev)
  end
  -- "Finger up" detection. touchState is delivered by EdgeTX whenever a
  -- finger is on the screen. When it's nil the finger has lifted, so any
  -- previously-consumed tap's followup sequence is fully drained and the
  -- NEXT real press can register again. This is finger-state aware —
  -- it doesn't care how long the finger was held, unlike a time block.
  if state._eatingTouch and touchState == nil then
    state._eatingTouch = false
  end
  -- Manual touch handling for rectangle-based controls (tabs + flat buttons).
  -- Native lvgl.button rows/pagers consume their own touches.
  if touchState and type(touchState) == "table" then
    if (EVT_TOUCH_TAP and event == EVT_TOUCH_TAP)
       or (EVT_TOUCH_BREAK and event == EVT_TOUCH_BREAK) then
      local x = touchState.x or touchState.tapX or touchState.startX
      local y = touchState.y or touchState.tapY or touchState.startY
      if type(x) == "number" and type(y) == "number" then
        local sx = touchState.startX or x
        local sy = touchState.startY or y
        if compat.highRes and isFullScreen() then
          x, y = x / compat.scale, y / compat.scale
          sx, sy = sx / compat.scale, sy / compat.scale
        end
        local moved = math.abs(x - sx) > CFG.touch.moveThreshold
                   or math.abs(y - sy) > CFG.touch.moveThreshold
        local blocked = getTime() < (state._touchBlockUntil or 0)
        -- Skip every touch event until a clean refresh tick has occurred.
        -- This is the strict finger-press fence: any follow-up event from
        -- the same finger press is dropped until the finger physically
        -- lifts (= refresh tick with no touch event).
        if not moved and not blocked and not state._eatingTouch then
          local now = getTime()
          local sameSpot = math.abs(x - state._lastTouchX) <= CFG.touch.sameSpotPx
                        and math.abs(y - state._lastTouchY) <= CFG.touch.sameSpotPx
          if not (sameSpot and (now - state._lastTouchAt) < CFG.touch.sameSpotCs) then
            state._lastTouchAt = now
            state._lastTouchX = x
            state._lastTouchY = y
            local ok, consumed = pcall(handleTouch, wgt, x, y)
            if ok and consumed then
              -- Defense in depth: keep the time-based block as a
              -- secondary fence in case the eat flag gets
              -- cleared early. Either fence alone is sufficient.
              state._touchBlockUntil = math.max(state._touchBlockUntil or 0,
                getTime() + CFG.touch.tapBlockCs)
              state._eatingTouch = true
            end
          end
        end
      end
    end
  end
  pcall(tickFlight, wgt)
  if compat.staticLvgl then
    local sampleOk, sampleChanged = pcall(sampleHistory)
    local layoutOk, rebuilt = pcall(ensureLayout, wgt)
    if not layoutOk then
      state.layoutError = compat.shortError(rebuilt)
      state.layoutErrorStage = "ensure-layout"
      compat.traceStartup("ensure-layout-error", rebuilt)
    end
    if not rebuilt then
      pcall(compat.refreshMk3Dynamics, wgt)
    end
  else
    pcall(sampleHistory)
    pcall(ensureLayout, wgt)
  end
  pcall(maybeBeep, wgt)
  pcall(maybeVoice, wgt)
end

local function background(wgt)
  pcall(tickFlight, wgt)
  pcall(maybeBeep, wgt)
  pcall(maybeVoice, wgt)
end

return {
  name       = "EdgeDeck",
  options    = options,
  create     = create,
  update     = update,
  refresh    = refresh,
  background = background,
  useLvgl    = true,
}
