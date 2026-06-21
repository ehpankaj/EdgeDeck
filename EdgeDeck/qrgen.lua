-- Minimal incremental QR generator for EdgeDeck GPS payloads.
-- Version 2-L, byte mode, mask 3. Produces a 25x25 row table of "0"/"1".

local M = {}

local QR_SIZE = 25
local DATA_CODEWORDS = 34
local ECC_CODEWORDS = 10
local PAYLOAD_MAX = 31
local GEN = { 216, 194, 159, 111, 199, 94, 95, 113, 157, 193 }
local FORMAT_L_MASK3 = 0x789D

local EXP, LOG, GF_READY = nil, nil, false
local GF_I, GF_COPY_I, GF_X = 0, 255, 1

local function bitAt(v, i)
  return math.floor(v / (2 ^ i)) % 2
end

local function bxorN(a, b, n)
  local out, bit = 0, 1
  for _ = 1, n do
    if (a % 2) ~= (b % 2) then out = out + bit end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return out
end

local function appendBits(bits, value, count)
  for i = count - 1, 0, -1 do
    bits[#bits + 1] = bitAt(value, i)
  end
end

local function gfReset()
  EXP, LOG = {}, {}
  GF_READY = false
  GF_I, GF_COPY_I, GF_X = 0, 255, 1
end

local function gfStep(limit)
  if GF_READY then return true end
  if not EXP or not LOG then gfReset() end
  limit = limit or 16
  while limit > 0 and GF_I <= 254 do
    EXP[GF_I] = GF_X
    LOG[GF_X] = GF_I
    GF_X = GF_X * 2
    if GF_X >= 256 then GF_X = bxorN(GF_X, 285, 9) end
    GF_I = GF_I + 1
    limit = limit - 1
  end
  while limit > 0 and GF_COPY_I <= 508 do
    EXP[GF_COPY_I] = EXP[GF_COPY_I - 255]
    GF_COPY_I = GF_COPY_I + 1
    limit = limit - 1
  end
  if GF_I > 254 and GF_COPY_I > 508 then
    GF_READY = true
    return true
  end
  return false
end

local function gfMul(a, b)
  if a == 0 or b == 0 then return 0 end
  return EXP[LOG[a] + LOG[b]]
end

local function setFunction(mods, funcs, x, y, val)
  if x < 0 or y < 0 or x >= QR_SIZE or y >= QR_SIZE then return end
  mods[y][x] = val
  funcs[y][x] = true
end

local function addFinder(mods, funcs, x, y)
  for dy = -1, 7 do
    for dx = -1, 7 do
      local xx, yy = x + dx, y + dy
      if xx >= 0 and yy >= 0 and xx < QR_SIZE and yy < QR_SIZE then
        funcs[yy][xx] = true
        if dx >= 0 and dx <= 6 and dy >= 0 and dy <= 6
           and (dx == 0 or dx == 6 or dy == 0 or dy == 6
                or (dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4)) then
          mods[yy][xx] = 1
        else
          mods[yy][xx] = 0
        end
      end
    end
  end
end

local function addPatterns(job)
  addFinder(job.mods, job.funcs, 0, 0)
  addFinder(job.mods, job.funcs, QR_SIZE - 7, 0)
  addFinder(job.mods, job.funcs, 0, QR_SIZE - 7)
  for i = 8, QR_SIZE - 9 do
    setFunction(job.mods, job.funcs, i, 6, (i % 2 == 0) and 1 or 0)
    setFunction(job.mods, job.funcs, 6, i, (i % 2 == 0) and 1 or 0)
  end
  for dy = -2, 2 do
    for dx = -2, 2 do
      local ring = math.max(math.abs(dx), math.abs(dy))
      setFunction(job.mods, job.funcs, 18 + dx, 18 + dy, (ring == 0 or ring == 2) and 1 or 0)
    end
  end
  setFunction(job.mods, job.funcs, 8, 17, 1)
  for i = 0, 8 do
    if i ~= 6 then
      job.funcs[8][i] = true
      job.funcs[i][8] = true
    end
  end
  for i = 0, 7 do
    job.funcs[8][QR_SIZE - 1 - i] = true
    job.funcs[QR_SIZE - 1 - i][8] = true
  end
end

local function initMatrixRow(job)
  local y = job.initY or 0
  job.mods[y], job.funcs[y] = {}, {}
  for x = 0, QR_SIZE - 1 do
    job.mods[y][x] = 0
    job.funcs[y][x] = false
  end
  job.initY = y + 1
  return job.initY > QR_SIZE - 1
end

local function finishOneRow(job)
  local y = job.rowY or 0
  local chars = {}
  for x = 0, QR_SIZE - 1 do
    chars[#chars + 1] = (job.mods[y][x] == 1) and "1" or "0"
  end
  job.rows[#job.rows + 1] = table.concat(chars)
  job.rowY = y + 1
  return job.rowY > QR_SIZE - 1
end

function M.start(payload)
  if type(payload) ~= "string" or #payload == 0 then return nil, "NO PAYLOAD" end
  if #payload > PAYLOAD_MAX then return nil, "QR PAYLOAD TOO LONG" end

  local bits = {}
  appendBits(bits, 4, 4)
  appendBits(bits, #payload, 8)
  for i = 1, #payload do appendBits(bits, string.byte(payload, i), 8) end
  local capBits = DATA_CODEWORDS * 8
  local term = math.min(4, capBits - #bits)
  for _ = 1, term do bits[#bits + 1] = 0 end
  while (#bits % 8) ~= 0 do bits[#bits + 1] = 0 end

  local data = {}
  for i = 1, #bits, 8 do
    local v = 0
    for j = 0, 7 do v = v * 2 + bits[i + j] end
    data[#data + 1] = v
  end
  local pad = true
  while #data < DATA_CODEWORDS do
    data[#data + 1] = pad and 236 or 17
    pad = not pad
  end

  local ecc = {}
  for i = 1, ECC_CODEWORDS do ecc[i] = 0 end
  return { phase = "gf", data = data, ecc = ecc, idx = 1 }, nil
end

function M.step(job, budget)
  budget = budget or 8
  while budget > 0 do
    if job.phase == "gf" then
      if gfStep(6) then job.phase = "ecc" end
      return false, nil, "QR BUILDING"
    elseif job.phase == "ecc" then
      local d = job.data[job.idx]
      if d then
        local factor = bxorN(d, job.ecc[1], 8)
        for i = 1, ECC_CODEWORDS - 1 do job.ecc[i] = job.ecc[i + 1] end
        job.ecc[ECC_CODEWORDS] = 0
        for i = 1, ECC_CODEWORDS do
          job.ecc[i] = bxorN(job.ecc[i], gfMul(GEN[i], factor), 8)
        end
        job.idx = job.idx + 1
        return false, nil, "QR BUILDING"
      end
      job.phase = "matrix"
    elseif job.phase == "matrix" then
      local codeBits = {}
      for _, v in ipairs(job.data) do appendBits(codeBits, v, 8) end
      for _, v in ipairs(job.ecc) do appendBits(codeBits, v, 8) end
      job.codeBits = codeBits
      job.mods, job.funcs = {}, {}
      job.initY = 0
      job.phase = "initrows"
    elseif job.phase == "initrows" then
      if initMatrixRow(job) then
        addPatterns(job)
        job.phase = "place"
      end
      return false, nil, "QR BUILDING"
    elseif job.phase == "place" then
      if not job.x then
        job.x, job.upward, job.bitIndex = QR_SIZE - 1, true, 1
      end
      if job.x >= 1 then
        if job.x == 6 then job.x = job.x - 1 end
        local yStart, yEnd, yStep = QR_SIZE - 1, 0, -1
        if not job.upward then yStart, yEnd, yStep = 0, QR_SIZE - 1, 1 end
        local y = yStart
        while true do
          for dx = 0, 1 do
            local xx = job.x - dx
            if not job.funcs[y][xx] then
              local bit = job.codeBits[job.bitIndex] or 0
              job.bitIndex = job.bitIndex + 1
              if ((xx + y) % 3) == 0 then bit = 1 - bit end
              job.mods[y][xx] = bit
            end
          end
          if y == yEnd then break end
          y = y + yStep
        end
        job.upward = not job.upward
        job.x = job.x - 2
        return false, nil, "QR BUILDING"
      end
      job.phase = "format"
    elseif job.phase == "format" then
      for i = 0, 14 do
        local bit = bitAt(FORMAT_L_MASK3, i)
        local fx, fy
        if i < 6 then fx, fy = 8, i
        elseif i < 8 then fx, fy = 8, i + 1
        else fx, fy = 14 - i, 8 end
        job.mods[fy][fx] = bit
        if i < 8 then fx, fy = QR_SIZE - 1 - i, 8
        else fx, fy = 8, QR_SIZE - 15 + i end
        job.mods[fy][fx] = bit
      end
      job.rows = {}
      job.rowY = 0
      job.phase = "rows"
      return false, nil, "QR BUILDING"
    elseif job.phase == "rows" then
      if finishOneRow(job) then
        return true, job.rows, nil
      end
      return false, nil, "QR BUILDING"
    else
      return true, nil, "QR BUILD FAILED"
    end
    budget = budget - 1
  end
  return false, nil, "QR BUILDING"
end

return M
