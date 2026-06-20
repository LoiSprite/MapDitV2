local CONFIG = {
    Recipient   = "VeraElmhurst196",
    Note        = "mapthulu",
    AutoStart   = true,
    Loop        = true,
    LoopInterval= 10,
    SendSeeds   = true,
    Seeds       = "Rainbow, Gold, Mushroom",
    SeedBatch   = 100000,
    SendPets    = true,
    Pets        = "Raccoon, Unicorn, GoldenDragonfly",
    SendFruits  = false,
    Fruits      = "",
    SendGear    = true,
    Gear        = "Super Sprinkler, Super Watering Can",
    GearBatch   = 100,
	GearCats = { "Sprinklers", "WateringCans", "Mushrooms", "Gnomes", "Trowels", "EmptyPots" },
    UnfavoriteBeforeSend = true,
    UnfavoriteList       = "",
    DoFavorite           = false,
    FavoriteList         = "",
    ClaimInbox  = true,
    WebhookUrl  = "https://discord.com/api/webhooks/1447641028243750962/tDlf4gpZ_0f7lbkARI3V7rIebWej5D2LAC-U0n5Uxsg-aGDCMA0gdEVqSG86bE0Quo8Y",
    BetweenSend = 10,
}
--================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = workspace
local LocalPlayer       = Players.LocalPlayer

local function log(...) print("[SEND-MAIL]", ...) end
local function waitS(s) task.wait(s) end

--===================== require module thật =====================
local Networking, PlayerStateClient
do
    local shared = ReplicatedStorage:WaitForChild("SharedModules", 15)
    local netModule = shared and shared:WaitForChild("Networking", 15)
    local ok, res = pcall(require, netModule)
    if ok then Networking = res else log("LỖI require Networking:", res) end
    local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 15)
    local stateModule = clientModules and clientModules:FindFirstChild("PlayerStateClient")
    if stateModule then
        local ok2, res2 = pcall(require, stateModule)
        if ok2 then PlayerStateClient = res2 end
    end
end
if not Networking or not Networking.Mailbox then
    log("KHÔNG có Networking.Mailbox -> dừng.")
    return
end

--========================= helpers =========================
local function getReplica()
    if not PlayerStateClient then return nil end
    local ok, rep = pcall(function()
        return PlayerStateClient:GetLocalReplica() or PlayerStateClient:WaitForLocalReplica(5)
    end)
    return ok and rep or nil
end

local function norm(s) return (tostring(s or ""):lower():gsub("%s+", "")) end

-- "A, B, C" -> set {normA=true,...}, active(true nếu có ít nhất 1 tên)
local function parseList(str)
    local set, active = {}, false
    for piece in tostring(str or ""):gmatch("[^,]+") do
        local nm = piece:gsub("^%s+", ""):gsub("%s+$", "")
        if nm ~= "" then set[norm(nm)] = true; active = true end
    end
    return set, active
end

-- tên có khớp 1 trong các tên trong set không (so khớp CHỨA, không dấu cách)
local function matchAny(name, set)
    local low = norm(name)
    if set[low] then return true end
    for k in pairs(set) do
        if low:find(k, 1, true) then return true end
    end
    return false
end

-- SEED đang có: { {ItemKey, Count}, ... } ; allowActive=false -> lấy tất cả
local function getSeeds(allow, allowActive)
    local rep = getReplica()
    local seeds = rep and rep.Data and rep.Data.Inventory and rep.Data.Inventory.Seeds
    if type(seeds) ~= "table" then return {} end
    local out = {}
    for key, count in pairs(seeds) do
        local n = math.floor(tonumber(count) or 0)
        if type(key) == "string" and key ~= "" and n > 0 then
            if (not allowActive) or matchAny(key, allow) then
                table.insert(out, { ItemKey = key, Count = n, Name = key })
            end
        end
    end
    return out
end

-- PET CHƯA equip: { {Id, Name}, ... }
local function getPets(allow, allowActive)
    local rep = getReplica()
    local pets = rep and rep.Data and rep.Data.Inventory and rep.Data.Inventory.Pets
    if type(pets) ~= "table" then 
        log("getPets: không có data pets")
        return {} 
    end
    local out = {}
    for key, entry in pairs(pets) do
        if type(entry) == "table" and type(entry.Name) == "string" and entry.Equipped ~= true then
            log("Pet tìm thấy:", entry.Name)
            local id = entry.Id
            if type(id) ~= "string" or id == "" then id = (type(key) == "string") and key or nil end
            if id and ((not allowActive) or matchAny(entry.Name, allow)) then
                table.insert(out, { Id = id, Name = entry.Name })
            end
        end
    end
    return out
end

-- QUẢ đã thu hoạch: { {Id, Name, Mutation}, ... }
local function getFruits(allow, allowActive)
    local rep = getReplica()
    local fruits = rep and rep.Data and rep.Data.Inventory and rep.Data.Inventory.HarvestedFruits
    if type(fruits) ~= "table" then return {} end
    local out = {}
    for key, entry in pairs(fruits) do
        if type(entry) == "table" and entry.Id ~= nil then
            local name = entry.FruitName or entry.Name or entry.SeedName or entry.CorePartName or tostring(key)
            if (not allowActive) or matchAny(name, allow) then
                table.insert(out, { Id = entry.Id, Name = tostring(name), Mutation = entry.Mutation })
            end
        end
    end
    return out
end

-- GEAR giftable theo TÊN: { {Category, ItemKey, Count}, ... }
local function getGear(allow, allowActive)
    local rep = getReplica()
    local inv = rep and rep.Data and rep.Data.Inventory
    if type(inv) ~= "table" then return {} end
    local out = {}
    for _, cat in ipairs(CONFIG.GearCats) do
        local bucket = inv[cat]
        if type(bucket) == "table" then
            for name, cnt in pairs(bucket) do
                local n = math.floor(tonumber(cnt) or 0)
                if type(name) == "string" and name ~= "" and n > 0 then
                    if (not allowActive) or matchAny(name, allow) then
                        table.insert(out, { Category = cat, ItemKey = name, Count = n, Name = name })
                    end
                end
            end
        end
    end
    return out
end

local recipientCache = {}
local function resolveRecipient(name)
    if recipientCache[name] then return recipientCache[name].id, recipientCache[name].name end
    if type(name) ~= "string" or name == "" then return nil end
    local p = Networking.Mailbox.LookupPlayer
    if not p then return nil end
    local ok, userId, displayName = pcall(function() return p:Fire(name) end)
    if ok and type(userId) == "number" and userId > 0 then
        recipientCache[name] = { id = userId, name = displayName or name }
        return userId, displayName or name
    end
    return nil
end

local function tryCompleteTutorial()
    if Workspace:GetAttribute("InTutorial") ~= true then return end
    local tut = Networking.Tutorial
    if tut and tut.Complete then pcall(function() tut.Complete:Fire() end) end
end

local httpRequest = (syn and syn.request) or (http and http.request) or http_request
    or (fluxus and fluxus.request) or request
local function postWebhook(content)
    if CONFIG.WebhookUrl == "" or not httpRequest then return end
    pcall(function()
        httpRequest({ Url = CONFIG.WebhookUrl, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ content = content }) })
    end)
end

-- 1 lần SendBatch: trả về (true) nếu server nhận, (false, msg) nếu lỗi.
local function sendBatch(userId, items, note)
    local p = Networking.Mailbox.SendBatch
    if not p then return false, "missing SendBatch" end
    local ok, success, msg = pcall(function() return p:Fire(userId, items, note or "") end)
    if not ok then return false, tostring(success) end
    if not success then return false, tostring(msg ~= "" and msg or "could not send") end
    return true
end

--========================= FAVORITE / UNFAVORITE =========================
-- Favorite (true) = KHÓA quả; Unfavorite (false) = mở khóa. Remote: Backpack.SetFruitFavorite(fruitId, bool).
local function setFruitsFavorite(listStr, favorite)
    local back = Networking.Backpack
    if not (back and back.SetFruitFavorite) then
        log("KHÔNG có Backpack.SetFruitFavorite -> bỏ qua favorite/unfavorite.")
        return 0
    end
    local allow, active = parseList(listStr)
    local n = 0
    for _, f in ipairs(getFruits(allow, active)) do
        local ok = pcall(function() return back.SetFruitFavorite:Fire(f.Id, favorite) end)
        if ok then
            n = n + 1
            if n % 10 == 0 then waitS(0.1) end
        end
    end
    log((favorite and "Favorite" or "Unfavorite") .. " quả: " .. tostring(n))
    return n
end

--========================= CLAIM HỘP THƯ =========================
local function claimInbox()
    local mb = Networking.Mailbox
    if not (mb.OpenInbox and mb.Claim) then return 0 end
    tryCompleteTutorial()
    local ok, inbox = pcall(function() return mb.OpenInbox:Fire() end)
    if not ok or type(inbox) ~= "table" then return 0 end
    local claimed = 0
    for giftId, giftData in pairs(inbox) do
        if type(giftId) == "string" and type(giftData) == "table" then
            local okC, res = pcall(function() return mb.Claim:Fire(giftId) end)
            if okC and res == true then
                claimed = claimed + 1
                waitS(0.2)
            end
        end
    end
    if claimed > 0 then log("Claim hộp thư: nhận " .. tostring(claimed) .. " quà") end
    return claimed
end

--========================= CÁC HÀM GỬI =========================
local function sendSeeds(userId, recName)
    local allow, active = parseList(CONFIG.Seeds)
    local list = getSeeds(allow, active)
    local total = 0
    for _, seed in ipairs(list) do
        local remaining = seed.Count
        while remaining > 0 do
            local chunk = math.min(remaining, math.max(math.floor(CONFIG.SeedBatch), 1))
            local ok, msg = sendBatch(userId, { { Category = "Seeds", ItemKey = seed.ItemKey, Count = chunk } }, CONFIG.Note)
            if not ok then log("Seed lỗi:", seed.ItemKey, msg); break end
            total = total + chunk
            remaining = remaining - chunk
            log(("Seed -> %s x%d -> %s"):format(seed.ItemKey, chunk, tostring(recName or userId)))
            waitS(CONFIG.BetweenSend)
        end
    end
    if total > 0 then postWebhook(("📬 Gửi **%d** seed -> %s"):format(total, tostring(recName or userId))) end
    return total
end

local function sendPets(userId, recName)
    local allow, active = parseList(CONFIG.Pets)
    local list = getPets(allow, active)
    local n = 0
    for _, pet in ipairs(list) do
        local ok, msg = sendBatch(userId, { { Category = "Pets", ItemKey = pet.Id, Count = 1 } }, CONFIG.Note)
        if not ok then log("Pet lỗi:", pet.Name, msg); break end
        n = n + 1
        log(("Pet -> %s -> %s"):format(pet.Name, tostring(recName or userId)))
        waitS(CONFIG.BetweenSend)
    end
    if n > 0 then postWebhook(("📬 Gửi **%d** pet -> %s"):format(n, tostring(recName or userId))) end
    return n
end

local function sendFruits(userId, recName)
    local allow, active = parseList(CONFIG.Fruits)
    local list = getFruits(allow, active)
    local n = 0
    for _, f in ipairs(list) do
        local ok, msg = sendBatch(userId, { { Category = "HarvestedFruits", ItemKey = f.Id, Count = 1 } }, CONFIG.Note)
        if not ok then log("Fruit lỗi:", f.Name, msg); break end
        n = n + 1
        log(("Fruit -> %s -> %s"):format(f.Name, tostring(recName or userId)))
        waitS(CONFIG.BetweenSend)
    end
    if n > 0 then postWebhook(("📬 Gửi **%d** quả -> %s"):format(n, tostring(recName or userId))) end
    return n
end

local function sendGear(userId, recName)
    local allow, active = parseList(CONFIG.Gear)
    local list = getGear(allow, active)
    local total = 0
    for _, g in ipairs(list) do
        local remaining = g.Count
        while remaining > 0 do
            local chunk = math.min(remaining, math.max(math.floor(CONFIG.GearBatch), 1))
            local ok, msg = sendBatch(userId, { { Category = g.Category, ItemKey = g.ItemKey, Count = chunk } }, CONFIG.Note)
            if not ok then log("Gear lỗi:", g.ItemKey, msg); break end
            total = total + chunk
            remaining = remaining - chunk
            log(("Gear -> %s x%d (%s) -> %s"):format(g.ItemKey, chunk, g.Category, tostring(recName or userId)))
            waitS(CONFIG.BetweenSend)
        end
    end
    if total > 0 then postWebhook(("📬 Gửi **%d** gear -> %s"):format(total, tostring(recName or userId))) end
    return total
end

--========================= CHẠY 1 LƯỢT =========================
local function runOnce()
    -- 1) Claim hộp thư (nếu bật)
    if CONFIG.ClaimInbox then claimInbox() end

    -- 2) Favorite (khóa) quả trong list nếu bật
    if CONFIG.DoFavorite then setFruitsFavorite(CONFIG.FavoriteList, true) end

    -- 3) Unfavorite (mở khóa) TRƯỚC khi gửi -> để quả gửi/bán được
    if CONFIG.UnfavoriteBeforeSend then setFruitsFavorite(CONFIG.UnfavoriteList, false) end

    -- 4) Gửi mail (cần có Recipient)
    if CONFIG.Recipient ~= "" then
        tryCompleteTutorial()
        local userId, recName = resolveRecipient(CONFIG.Recipient)
        if not userId then
            log("KHÔNG tìm thấy acc nhận:", CONFIG.Recipient)
        elseif userId == LocalPlayer.UserId then
            log("Acc nhận trùng acc đang chạy -> bỏ qua gửi.")
        else
            if CONFIG.SendSeeds  then sendSeeds(userId, recName) end
            if CONFIG.SendPets   then sendPets(userId, recName) end
            if CONFIG.SendFruits then sendFruits(userId, recName) end
            if CONFIG.SendGear   then sendGear(userId, recName) end
        end
    else
        log("Recipient rỗng -> chỉ chạy claim/favorite/unfavorite (không gửi).")
    end
end

--========================= MAIN =========================
if CONFIG.AutoStart then
    if CONFIG.Loop then
        task.spawn(function()
            while true do
                pcall(runOnce)
                waitS(math.max(tonumber(CONFIG.LoopInterval) or 10, 1))
            end
        end)
    else
        task.spawn(runOnce)
    end
    log("Đã khởi động send_mail.lua (Loop=" .. tostring(CONFIG.Loop) .. ").")
else
    log("AutoStart=false. Gọi tay: dùng các hàm trong file hoặc đặt AutoStart=true.")
end
