-- Lightweight EdgeTX/LVGL contract harness for desktop Lua 5.4.
-- It validates registration, first refresh, all tab builds, callback count,
-- named sparkline updates, and the one-shot safe-mode fallback.

local MAIN = "EdgeDeck/main.lua"

local function options()
  return {
    AccentColor = 0x3366ff,
    LQ_Warn = 80,
    LQ_Crit = 50,
    RSSI_Warn = -98,
    RSSI_Crit = -103,
    CellV_Warn = 350,
    CellV_Crit = 330,
    Audio = 0,
    AutoTab = 0,
  }
end

local function makeEnvironment(width, height, full, failFirstBuild, fwMajor, fwMinor)
  local now = 0
  local maj = fwMajor or 2
  local min = fwMinor or 11
  local isStaticFw = (width >= 720 and height >= 400)
    or maj > 2 or (maj == 2 and min >= 12)
  local apiFullScreen = full
  local stats = {
    builds = 0,
    clears = 0,
    callbacks = 0,
    objects = 0,
    named = 0,
    constructedRectangles = 0,
    sets = 0,
    maxBuildCallbacks = 0,
    lastRootW = nil,
    lastRootH = nil,
    failNext = failFirstBuild == true,
  }

  local env = setmetatable({}, { __index = _G })
  env.LCD_W, env.LCD_H = width, height
  env.COLOR, env.VALUE = 1, 2
  env.COLOR_THEME_FOCUS, env.COLOR_THEME_WARNING = 0x3366ff, 0xff0000
  env.LEFT, env.RIGHT, env.CENTER = 0, 1, 2
  env.BOLD, env.SMLSIZE, env.DBLSIZE, env.WHITE = 4, 8, 16, 0xffffff
  env.EVT_TOUCH_TAP = 100
  env.lcd = {
    RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
    drawText = function() end,
  }
  env.getTime = function() return now end
  env.getValue = function() return 0 end
  env.getFieldInfo = function() return nil end
  env.getGeneralSettings = function() return {} end
  env.getVersion = function()
    return string.format("%d.%d.0", maj, min), "tx16s-simu", maj, min, 0, "EdgeTX"
  end
  env.playTone = function() end
  env.playNumber = function() end
  env.playHaptic = function() end

  local lvglRefs = {}

  local function objectRef()
    return {
      set = function(_, values)
        stats.sets = stats.sets + 1
        assert(type(values) == "table", "LVGL set requires a table")
      end,
    }
  end

  local function validate(node, path, refs)
    assert(type(node) == "table", path .. ": LVGL object must be a table")
    stats.objects = stats.objects + 1

    for _, key in ipairs({ "x", "y", "w", "h" }) do
      local value = node[key]
      if type(value) == "function" then
        stats.callbacks = stats.callbacks + 1
        value = value()
      end
      if value ~= nil then
        assert(type(value) == "number" and value == value,
          path .. ": invalid " .. key)
      end
      if (key == "w" or key == "h") and value ~= nil then
        assert(value > 0, path .. ": non-positive " .. key)
      end
    end

    for _, key in ipairs({ "text", "color", "visible", "pos", "size" }) do
      if type(node[key]) == "function" then
        stats.callbacks = stats.callbacks + 1
        assert(node[key]() ~= nil, path .. ": nil " .. key .. " callback")
      end
    end

    if node.type == "label" and isStaticFw then
      assert(node.scrollBar == nil and node.scrollDir == nil,
        path .. ": static LVGL labels must not set scrollBar/scrollDir")
    end

    if node.name then
      stats.named = stats.named + 1
      refs[node.name] = objectRef()
    end

    if node.children then
      for i, child in ipairs(node.children) do
        validate(child, path .. ".children[" .. i .. "]", refs)
      end
    end
  end

  env.lvgl = {
    SCROLL_NONE = 0,
    SCROLL_VERTICAL = 1,
    isFullScreen = function() return apiFullScreen end,
    clear = function()
      stats.clears = stats.clears + 1
      lvglRefs = {}
    end,
    rectangle = function(settings)
      stats.constructedRectangles = stats.constructedRectangles + 1
      validate(settings, "rectangle[" .. stats.constructedRectangles .. "]", {})
      return objectRef()
    end,
    build = function(tree)
      stats.builds = stats.builds + 1
      if stats.failNext then
        stats.failNext = false
        error("injected LVGL build failure")
      end
      local callbacksBefore = stats.callbacks
      local refs = {}
      for i, node in ipairs(tree) do
        validate(node, "root[" .. i .. "]", refs)
      end
      stats.maxBuildCallbacks = math.max(
        stats.maxBuildCallbacks, stats.callbacks - callbacksBefore)
      stats.lastRootW = tree[1] and tree[1].w or nil
      stats.lastRootH = tree[1] and tree[1].h or nil
      lvglRefs = refs
      return refs
    end,
  }

  local function simulateCallRefs()
    for _, ref in pairs(lvglRefs) do
      if ref.set then pcall(ref.set, ref, {}) end
    end
  end

  return env, stats, function(value) now = value end, simulateCallRefs,
    function(value) apiFullScreen = value end
end

local function loadWidget(env)
  local chunk, err = loadfile(MAIN, "t", env)
  assert(chunk, err)
  local widget = chunk()
  assert(type(widget) == "table" and widget.useLvgl == true,
    "widget did not register as an LVGL widget")
  return widget
end

local function runResolution(width, height, full, fwMajor, fwMinor)
  fwMajor = fwMajor or 2
  fwMinor = fwMinor or 11
  local isHighRes = width >= 720 and height >= 400
  local isStatic = isHighRes or fwMajor > 2 or (fwMajor == 2 and fwMinor >= 12)
  local env, stats, setTime = makeEnvironment(width, height, full, false, fwMajor, fwMinor)
  local widget = loadWidget(env)
  local instance = widget.create({ x = 0, y = 0, w = width, h = height }, options())
  widget.refresh(instance, 0, nil)

  assert(stats.builds == 1, "first refresh should build exactly once")
  assert(stats.lastRootW == width and stats.lastRootH == height,
    "root background must cover the target resolution")

  if full and isHighRes then
    widget.refresh(instance, 0, nil)
    assert(stats.builds == 2, "MK3 bootstrap should defer the full layout")
    assert(stats.constructedRectangles == 0,
      "MK3 sparkline must stay inside lvgl.build, not lvgl.rectangle")
    assert(stats.maxBuildCallbacks <= 5,
      "MK3 full layout must avoid LVGL getter callbacks")
  end

  if full and isStatic and not isHighRes then
    assert(stats.maxBuildCallbacks <= 5,
      "TX16S 2.12+ must avoid LVGL getter callbacks: " .. stats.maxBuildCallbacks)
  end

  if full and not isStatic then
    assert(stats.constructedRectangles == 0,
      "TX16S 2.11 spark bars must come from lvgl.build, not lvgl.rectangle")
  end

  setTime(100)
  widget.refresh(instance, 0, nil)
  if full and not isStatic then
    for second = 2, 61 do
      setTime(second * 100)
      widget.refresh(instance, 0, nil)
    end
    assert(stats.builds == 1,
      "history updates must not rebuild the LVGL tree")
    assert(stats.sets == 0,
      "TX16S 2.11 sparkline must use LVGL callbacks, not label:set()")
  end
  if full and isStatic and not isHighRes then
    assert(stats.sets > 0,
      "TX16S 2.12+ refresh must push live values via label:set()")
  end

  if full then
    local scale = isHighRes and (width / 480) or 1
    local buildsBeforeTabs = stats.builds
    for tab = 0, 4 do
      setTime(7000 + tab * 100)
      local x = (8 + tab * 60 + 20) * scale
      local y = 16 * scale
      widget.refresh(instance, env.EVT_TOUCH_TAP,
        { x = x, y = y, startX = x, startY = y })
      widget.refresh(instance, 0, nil)
    end
    local expectedTabBuilds = isHighRes and 7 or 6
    assert(stats.builds == expectedTabBuilds,
      "startup plus five tab selections should rebuild the expected count; got "
        .. stats.builds)
    if isHighRes or (isStatic and not isHighRes) then
      assert(stats.maxBuildCallbacks <= 5,
        "static LVGL tab must not use getter callbacks: " .. stats.maxBuildCallbacks)
      assert(stats.sets > 0,
        "static LVGL refresh must push live values via label:set()")
    else
      assert(stats.maxBuildCallbacks >= 90,
        "TX16S 2.11 FLY tab should use sparkline pos/size/color callbacks")
    end
  end

  io.write(string.format(
    "ok %dx%d fw=%d.%d full=%s builds=%d objects=%d callbacks=%d max/build=%d rects=%d sets=%d\n",
    width, height, fwMajor, fwMinor, tostring(full), stats.builds, stats.objects,
    stats.callbacks, stats.maxBuildCallbacks, stats.constructedRectangles,
    stats.sets))
end

local function runFallback()
  local env, stats, setTime = makeEnvironment(800, 480, true, true)
  local widget = loadWidget(env)
  local instance = widget.create({ x = 0, y = 0, w = 800, h = 480 }, options())
  widget.refresh(instance, 0, nil)
  assert(stats.builds == 2, "failed layout should build one safe-mode fallback")
  widget.refresh(instance, 0, nil)
  assert(stats.builds == 2, "failed layout must not retry every refresh")
  setTime(100)
  widget.refresh(instance, env.EVT_TOUCH_TAP,
    { x = 30, y = 20, startX = 30, startY = 20 })
  assert(stats.builds == 2,
    "dirty state changes must not escape the safe-mode latch")
  io.write("ok injected build failure enters one-shot safe mode\n")
end

local function runMultiInstanceFallback()
  local env, stats, setTime = makeEnvironment(800, 480, true, false)
  local widget = loadWidget(env)
  local healthy = widget.create({ x = 0, y = 0, w = 800, h = 480 }, options())
  widget.refresh(healthy, 0, nil)
  widget.refresh(healthy, 0, nil)
  assert(stats.builds == 2, "healthy instance should finish MK3 bootstrap")

  local failed = widget.create({ x = 0, y = 0, w = 800, h = 480 }, options())
  stats.failNext = true
  widget.refresh(failed, 0, nil)
  assert(stats.builds == 4, "failed instance should enter safe mode")

  setTime(100)
  widget.refresh(failed, env.EVT_TOUCH_TAP,
    { x = 30, y = 20, startX = 30, startY = 20 })
  widget.refresh(healthy, 0, nil)
  assert(stats.builds == 5,
    "failed instance must not consume a healthy instance's dirty rebuild")
  io.write("ok safe mode preserves shared dirty state for healthy instances\n")
end

local function runSettingsExit()
  local env, stats, setTime, simulateCallRefs, setFullScreen =
    makeEnvironment(800, 480, true, false)
  local widget = loadWidget(env)
  local instance = widget.create({ x = 0, y = 0, w = 800, h = 480 }, options())
  widget.refresh(instance, 0, nil)
  widget.refresh(instance, 0, nil)
  assert(stats.builds == 2, "settings test should finish MK3 bootstrap")
  assert(instance.isFull == true, "MK3 boot should latch fullscreen layout")

  local buildsAfterBoot = stats.builds
  local clearsBeforeUpdate = stats.clears
  setFullScreen(false)
  local newOpts = options()
  newOpts.LQ_Warn = 75
  widget.update(instance, newOpts)
  assert(stats.clears == clearsBeforeUpdate,
    "settings update must not lvgl.clear() on MK3")
  simulateCallRefs()
  widget.refresh(instance, 0, nil)
  assert(stats.builds == buildsAfterBoot,
    "settings exit must not rebuild when isFullScreen lies")
  assert(instance.isFull == true,
    "settings exit must keep fullscreen layout on MK3")
  setFullScreen(true)
  widget.update(instance, options())
  simulateCallRefs()
  widget.refresh(instance, 0, nil)
  assert(stats.builds == buildsAfterBoot,
    "settings exit without changes must not rebuild")
  io.write("ok widget settings exit keeps fullscreen on MK3\n")
end

runResolution(480, 272, false)
runResolution(480, 272, true, 2, 11)
runResolution(480, 272, true, 2, 12)
runResolution(800, 480, false)
runResolution(800, 480, true)
runFallback()
runMultiInstanceFallback()
runSettingsExit()
