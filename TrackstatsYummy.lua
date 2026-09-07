

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Http    = game:GetService("HttpService")
local LP      = Players.LocalPlayer

local GENV = (type(getgenv) == "function") and getgenv() or _G

local AutoSwap = {}
AutoSwap.PREFIX = "[AutoSwap] "

--==============================================================================
-- CONFIG MAC DINH
--==============================================================================
AutoSwap.DEFAULT = {
    -- ===== API (CHUA XAC NHAN trong source — chong cung cap) =====
    Url             = "https://accountops.org/api/accounts/autoswap-complete",
    ApiKey          = "ak_d5001c83bb5fe8ecd64423c496c3c3aed4b6daf19c1ebd98d42cee3f07c83bf6",          -- BAT BUOC
    Username        = "loisprite",          -- de trong -> LocalPlayer.Name
    Option          = 1,           -- so Rule On-Demand tren web accountops (chi 1 rule)

    -- ===== Nhip chay =====
    LoopSeconds  = 60,   -- bao lau kiem tra dieu kien 1 lan
    DelaySeconds = 60,   -- du dieu kien roi cho bao lau moi ban (cho server game luu data)
    MaxTries     = 0,    -- 0 = thu lai VO HAN khi gap loi TAM

    -- ===== Dieu kien mac dinh (chi dung khi KHONG truyen ShouldSwap) =====
    Scan = {
        Base            = true,    -- quet pet dang tha trong chuong (AssetRoster.ReadOwnerPen)
        Inventory       = false,   -- quet ca tui do (Save.Get().Inventory)
        Rarities        = { "Secret", "Eternal", "Divine" },   -- loc theo TEN _id
        MinRarityNumber = 8,       -- HOAC loc theo nguong so (Secret tro len). 0 = tat
        MatchMode       = "any",   -- "any" = 1 trong 2 cach la duoc | "name" | "number"
        MinCount        = 1,       -- can bao nhieu con moi doi acc
    },
    Debug = true,
}

--==============================================================================
-- TIEN ICH
--==============================================================================
local function log(msg)   print(AutoSwap.PREFIX .. tostring(msg)) end
local function warnLog(msg) warn(AutoSwap.PREFIX .. tostring(msg)) end

function AutoSwap.dbg(msg)
    if AutoSwap.Cfg and AutoSwap.Cfg.Debug then
        print(AutoSwap.PREFIX .. "[dbg] " .. tostring(msg))
    end
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepCopy(v) end
    return r
end

local function deepMerge(dst, src)
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            deepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function toSet(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

--==============================================================================
-- HAM HTTP CUA EXECUTOR  (NGOAI SOURCE GAME)
--==============================================================================
function AutoSwap.resolveRequest()
    local cands = {}
    local a = rawget(GENV, "http_request"); if type(a) == "function" then cands[#cands+1] = a end
    local b = rawget(GENV, "request");      if type(b) == "function" then cands[#cands+1] = b end
    local s = rawget(GENV, "syn");    if type(s) == "table" and type(s.request) == "function" then cands[#cands+1] = s.request end
    local h = rawget(GENV, "http");   if type(h) == "table" and type(h.request) == "function" then cands[#cands+1] = h.request end
    local f = rawget(GENV, "fluxus"); if type(f) == "table" and type(f.request) == "function" then cands[#cands+1] = f.request end
    for _, fn in ipairs(cands) do
        if type(fn) == "function" then return fn end
    end
    return nil
end

--==============================================================================
-- DOC PET (chi dung path DA XAC NHAN trong source)
--==============================================================================
function AutoSwap.getModule(path)
    local node = RS
    for name in string.gmatch(path, "[^%.]+") do
        if node == nil then return nil end
        node = node:FindFirstChild(name)
    end
    if node == nil then return nil end
    local ok, mod = pcall(require, node)
    if not ok then return nil end
    return mod
end

-- tra ve: rarityId(string?), rarityNumber(number)
function AutoSwap.rarityOf(category)
    if type(category) ~= "string" then return nil, 0 end
    local Assets = AutoSwap.getModule("Data.Assets")
    if Assets == nil or type(Assets.Directory) ~= "table" then return nil, 0 end
    local cfg = Assets.Directory[category]
    if cfg == nil or cfg.Rarity == nil then return nil, 0 end
    return cfg.Rarity._id, tonumber(cfg.Rarity.RarityNumber) or 0
end

-- Gom pet can xet -> { { uid, category, source }, ... }
function AutoSwap.collectPets()
    local out = {}
    local S = AutoSwap.Cfg.Scan

    if S.Base then
        local AssetRoster = AutoSwap.getModule("Client.AssetRoster")
        if AssetRoster ~= nil and type(AssetRoster.ReadOwnerPen) == "function" then
            local ok, pen = pcall(AssetRoster.ReadOwnerPen, LP.UserId)
            if ok and type(pen) == "table" then
                for uid, rec in pairs(pen) do
                    local item = (type(rec) == "table") and rec.ItemData or nil
                    if type(item) == "table" and type(item.Category) == "string" then
                        out[#out+1] = { uid = uid, category = item.Category, source = "base" }
                    end
                end
            else
                AutoSwap.dbg("ReadOwnerPen loi: " .. tostring(pen))
            end
        else
            warnLog("Khong nap duoc ReplicatedStorage.Client.AssetRoster -> bo qua quet BASE")
        end
    end

    if S.Inventory then
        local Save = AutoSwap.getModule("Shared.Save")
        if Save ~= nil and type(Save.Get) == "function" then
            local ok, data = pcall(Save.Get)
            if ok and type(data) == "table" and type(data.Inventory) == "table" then
                for uid, item in pairs(data.Inventory) do
                    if type(item) == "table" and type(item.Category) == "string" then
                        out[#out+1] = { uid = uid, category = item.Category, source = "inventory" }
                    end
                end
            end
        else
            warnLog("Khong nap duoc ReplicatedStorage.Shared.Save -> bo qua quet INVENTORY")
        end
    end

    return out
end

local function matchRarity(category, rarSet, minNum, mode)
    local id, num = AutoSwap.rarityOf(category)
    local byName = (rarSet ~= nil) and (id ~= nil) and (rarSet[id] == true)
    local byNum  = (type(minNum) == "number" and minNum > 0) and (num >= minNum)
    if mode == "name"   then return byName end
    if mode == "number" then return byNum end
    return byName or byNum          -- "any"
end

-- Quet base/inventory -> dat(boolean), danhSachTrung(table)
function AutoSwap.scan()
    local S = AutoSwap.Cfg.Scan
    local rarSet = toSet(S.Rarities)
    local mode   = S.MatchMode or "any"

    local hits = {}
    for _, p in ipairs(AutoSwap.collectPets()) do
        if matchRarity(p.category, rarSet, S.MinRarityNumber, mode) then
            local id, num = AutoSwap.rarityOf(p.category)
            hits[#hits+1] = string.format("%s [%s/%d] (%s)", p.category, tostring(id), num, p.source)
        end
    end
    return (#hits >= (S.MinCount or 1)), hits
end

--==============================================================================
-- GOI API
--==============================================================================
-- KHONG duoc chi pcall: pcall chi bat crash, API tra 500/429 van "thanh cong".
-- Phai doc res.StatusCode roi phan loai: "ok" | "retry" | "fatal"
function AutoSwap.classify(pcallOk, res)
    if not pcallOk then
        return "retry", "pcall fail (timeout/mat mang): " .. tostring(res)
    end
    if type(res) ~= "table" then
        return "retry", "executor tra ve " .. typeof(res) .. ", khong phai bang ket qua"
    end
    local code = tonumber(res.StatusCode) or tonumber(res.Status) or 0
    local body = tostring(res.Body or "")
    if code >= 200 and code < 300 then
        return "ok", string.format("HTTP %d | %s", code, body:sub(1, 200))
    end
    if code == 408 or code == 429 or (code >= 500 and code < 600) or code == 0 then
        return "retry", string.format("HTTP %d (loi TAM) | %s", code, body:sub(1, 200))
    end
    if code >= 400 and code < 500 then
        return "fatal", string.format("HTTP %d (sai key/rule/username - retry vo ich) | %s", code, body:sub(1, 300))
    end
    return "retry", string.format("HTTP %d (khong ro) | %s", code, body:sub(1, 200))
end

-- Goi API 1 lan -> verdict("ok"|"retry"|"fatal"), chiTiet(string)
function AutoSwap.CallApi(option)
    local C = AutoSwap.Cfg
    if C == nil then return "fatal", "chua Start() nen chua co config" end
    if type(C.ApiKey) ~= "string" or C.ApiKey == "" then
        return "fatal", "chua dien ApiKey"
    end
    local req = AutoSwap.resolveRequest()
    if req == nil then
        return "fatal", "executor khong co request/http_request/syn.request/http.request"
    end

    local username = C.Username
    if type(username) ~= "string" or username == "" then username = LP.Name end

    local payload = { username = username, option = tonumber(option) or tonumber(C.Option) or 1 }
    local okEnc, body = pcall(function() return Http:JSONEncode(payload) end)
    if not okEnc then return "fatal", "JSONEncode loi: " .. tostring(body) end

    AutoSwap.State.Tries = AutoSwap.State.Tries + 1
    log(string.format("Gui swap: username=%s option=%s (lan thu %d)",
        username, tostring(payload.option), AutoSwap.State.Tries))

    local t0 = os.clock()
    local pcallOk, res = pcall(req, {
        Url     = C.Url,
        Method  = "POST",
        Headers = {
            ["X-Api-Key"]    = C.ApiKey,
            ["Content-Type"] = "application/json",
        },
        Body = body,
    })
    local took = os.clock() - t0

    local verdict, detail = AutoSwap.classify(pcallOk, res)
    AutoSwap.State.LastVerdict = verdict
    AutoSwap.State.LastDetail  = detail
    AutoSwap.State.LastError   = (verdict == "ok") and nil or detail
    AutoSwap.State.LastAt      = os.time()

    local line = string.format("Ket qua: %s | %.1fs | %s", string.upper(verdict), took, tostring(detail))
    if verdict == "ok" then log(line) else warnLog(line) end
    return verdict, detail
end

--==============================================================================
-- VONG CHAY
--==============================================================================
AutoSwap.State = {
    Running     = false,
    Busy        = false,   -- dang trong 1 luot (cho + gui) -> vong sau bo qua, khong ban chong
    Done        = false,   -- da 2xx -> dung han
    Fatal       = false,   -- loi cau hinh -> dung han
    Tries       = 0,
    LastVerdict = nil,
    LastDetail  = nil,
    LastError   = nil,
    LastAt      = nil,
}

function AutoSwap.GetState()
    return deepCopy(AutoSwap.State)
end

-- 1 luot: CHECK -> cho DelaySeconds -> REQUEST
function AutoSwap.swapOnce()
    local C = AutoSwap.Cfg
    local S = AutoSwap.State
    if S.Done or S.Fatal or S.Busy then return end

    -- 1) CHECK dieu kien
    local should, hits
    if type(C.ShouldSwap) == "function" then
        local ok, r = pcall(C.ShouldSwap)
        if not ok then warnLog("ShouldSwap loi: " .. tostring(r)) return end
        should, hits = (r == true), {}
    else
        should, hits = AutoSwap.scan()
    end

    if not should then
        AutoSwap.dbg("Chua du dieu kien doi acc")
        return
    end

    S.Busy = true
    if #hits > 0 then
        log("DU DIEU KIEN DOI ACC -> trung: " .. table.concat(hits, ", "))
    else
        log("DU DIEU KIEN DOI ACC (theo ShouldSwap tu dinh nghia)")
    end

    -- 2) Cho server game luu data
    local wait = tonumber(C.DelaySeconds) or 60
    if wait > 0 then
        log(string.format("Cho %ds cho server luu data roi moi goi API...", math.floor(wait)))
        local t0 = os.clock()
        while os.clock() - t0 < wait do
            if GENV.AUTOSWAP_STOP then S.Busy = false return end
            task.wait(0.5)
        end
    end

    -- 3) REQUEST
    local verdict = AutoSwap.CallApi(C.Option)

    if verdict == "ok" then
        S.Done = true
        log("SWAP THANH CONG -> dung han.")
    elseif verdict == "fatal" then
        S.Fatal = true
        warnLog("Loi FATAL -> dung han (retry vo ich).")
    else
        local maxT = tonumber(C.MaxTries) or 0
        if maxT > 0 and S.Tries >= maxT then
            S.Fatal = true
            warnLog(string.format("Da thu %d lan van loi -> dung.", S.Tries))
        else
            warnLog(string.format("Loi TAM -> vong sau (%ds) gui lai.",
                math.floor(tonumber(C.LoopSeconds) or 60)))
        end
    end

    S.Busy = false
end

function AutoSwap.Start(userCfg)
    if AutoSwap.State.Running then
        warnLog("Da chay roi -> bo qua Start()")
        return AutoSwap
    end

    AutoSwap.Cfg = deepMerge(deepCopy(AutoSwap.DEFAULT), userCfg)
    GENV.AUTOSWAP_STOP = false
    GENV.AUTOSWAP = AutoSwap
    AutoSwap.State.Running = true

    if type(AutoSwap.Cfg.ApiKey) ~= "string" or AutoSwap.Cfg.ApiKey == "" then
        warnLog("CHUA DIEN ApiKey -> van check dieu kien nhung KHONG goi duoc API.")
    end
    if AutoSwap.resolveRequest() == nil then
        warnLog("Executor khong co ham request() -> KHONG goi duoc API.")
    end

    local S = AutoSwap.Cfg.Scan
    if type(AutoSwap.Cfg.ShouldSwap) == "function" then
        log("Bat dau. Dung ShouldSwap do chong tu dinh nghia.")
    else
        log(string.format("Bat dau. Quet base=%s inventory=%s | rarity=%s | minNum=%s | can >=%d con",
            tostring(S.Base), tostring(S.Inventory),
            table.concat(S.Rarities or {}, "/"), tostring(S.MinRarityNumber), S.MinCount or 1))
    end

    task.spawn(function()
        while not GENV.AUTOSWAP_STOP do
            -- boc pcall NGOAI: loi bat ngo khong duoc lam ket Busy = true vinh vien
            local ok, err = pcall(AutoSwap.swapOnce)
            if not ok then
                AutoSwap.State.Busy = false
                warnLog("swapOnce loi bat ngo: " .. tostring(err))
            end
            if AutoSwap.State.Done or AutoSwap.State.Fatal then break end

            local loop = tonumber(AutoSwap.Cfg.LoopSeconds) or 60
            local t0 = os.clock()
            while os.clock() - t0 < loop and not GENV.AUTOSWAP_STOP do
                task.wait(0.5)
            end
        end
        AutoSwap.State.Running = false
        log("Da dung vong AutoSwap.")
    end)

    return AutoSwap
end

function AutoSwap.Stop()
    GENV.AUTOSWAP_STOP = true
end

return AutoSwap
