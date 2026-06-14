local RECIPIENT_USERNAME = "LoiSpriteIsGOD"
local RECIPIENT_USERID   = 4786405140
local MAIL_NOTE          = "muthulap"
local SEND_COUNT         = 5
local DELAY_BEFORE_SEND  = 30
local LOOP_ENABLED       = false
local INTERVAL_SEC       = 30
local SKIP_RESENT_KEY    = true
local LOG_PREFIX         = "[MailboxRainbowTest]"
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local function log(...)
    print(LOG_PREFIX, ...)
end

local Networking
do
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local netMod = shared and shared:FindFirstChild("Networking")
    if not (netMod and netMod:IsA("ModuleScript")) then
        log("LOI: Khong tim thay ReplicatedStorage.SharedModules.Networking")
        return
    end
    local ok, mod = pcall(require, netMod)
    if not ok then
        log("LOI: require Networking that bai:", mod)
        return
    end
    Networking = mod
end

if not (Networking.Mailbox and Networking.Mailbox.SendBatch and Networking.Mailbox.LookupPlayer) then
    log("LOI: Networking.Mailbox.SendBatch / LookupPlayer khong ton tai")
    return
end

local function hasRainbowText(value)
    if type(value) ~= "string" then return false end
    return string.find(string.lower(value), "rainbow", 1, true) ~= nil
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getAllTools()
    local out = {}
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(out, item)
            end
        end
    end
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(getCharacter())
    return out
end

local function isRainbowSeedTool(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    local hasSeedSignal = tool:GetAttribute("SeedTool") ~= nil
        or tool:GetAttribute("SeedPack") ~= nil
        or tool:GetAttribute("RainbowSeed") == true
    if not hasSeedSignal then return false end
    if tool:GetAttribute("RainbowSeed") == true then return true end
    if hasRainbowText(tool.Name) then return true end
    if hasRainbowText(tool:GetAttribute("SeedTool")) then return true end
    if hasRainbowText(tool:GetAttribute("SeedPack")) then return true end
    return false
end

local function findRainbowSeedTool()
    for _, tool in ipairs(getAllTools()) do
        if isRainbowSeedTool(tool) then
            return tool
        end
    end
    return nil
end

local function resolveSeedItemKey(tool)
    local clientMods = ReplicatedStorage:FindFirstChild("ClientModules")
    local psMod = clientMods and clientMods:FindFirstChild("PlayerStateClient")
    if psMod and psMod:IsA("ModuleScript") then
        local ok, PlayerStateClient = pcall(require, psMod)
        if ok and PlayerStateClient and PlayerStateClient.GetLocalReplica then
            local ok2, replica = pcall(function()
                return PlayerStateClient:GetLocalReplica()
            end)
            if ok2 and replica and replica.Data and type(replica.Data.Inventory) == "table" then
                local seeds = replica.Data.Inventory.Seeds
                if type(seeds) == "table" then
                    for key, count in pairs(seeds) do
                        if type(key) == "string" and (tonumber(count) or 0) > 0 and hasRainbowText(key) then
                            return key, tonumber(count) or 0
                        end
                    end
                end
            end
        end
    end
    if tool then
        local st = tool:GetAttribute("SeedTool")
        if type(st) == "string" and st ~= "" then
            return st, nil
        end
    end
    return "Rainbow", nil
end

local function lookupUserId(username)
    local ok, userId, name = pcall(function()
        return Networking.Mailbox.LookupPlayer:Fire(username)
    end)
    if not ok then
        log("LOI: LookupPlayer that bai:", userId)
        return nil
    end
    if type(userId) ~= "number" or userId <= 0 then
        log("LOI: Khong tim thay user '" .. tostring(username) .. "' (userId=" .. tostring(userId) .. ")")
        return nil
    end
    log(("LookupPlayer OK: %s -> userId=%d name=%s"):format(username, userId, tostring(name)))
    return userId
end

local function resolveRecipientUserId()
    if type(RECIPIENT_USERID) == "number" and RECIPIENT_USERID > 0 then
        log(("Dung userId hardcode: %d"):format(RECIPIENT_USERID))
        return RECIPIENT_USERID
    end
    if type(RECIPIENT_USERNAME) == "string" and RECIPIENT_USERNAME ~= "" then
        return lookupUserId(RECIPIENT_USERNAME)
    end
    log("LOI: Chua cau hinh RECIPIENT_USERID lan RECIPIENT_USERNAME")
    return nil
end

local function sendSeed(userId, itemKey)
    local items = {
        { Category = "Seeds", ItemKey = itemKey, Count = SEND_COUNT },
    }
    log(("Gui SendBatch -> userId=%d | Category=Seeds ItemKey=%s Count=%d")
        :format(userId, tostring(itemKey), SEND_COUNT))
    local ok, success, msg = pcall(function()
        return Networking.Mailbox.SendBatch:Fire(userId, items, MAIL_NOTE)
    end)
    if not ok then
        log("LOI: SendBatch that bai (pcall):", success)
        return false
    end
    if success then
        log("THANH CONG: da gui seed. msg=" .. tostring(msg ~= "" and msg or "Gift sent!"))
        return true
    else
        log("THAT BAI tu server: " .. tostring(msg ~= "" and msg or "Could not send gift"))
        return false
    end
end

local sentKeys = {}

local function watchOnce()
    local tool = findRainbowSeedTool()
    if not tool then
        log("Khong phat hien rainbow seed trong Backpack/Character.")
        return false
    end
    log(("PHAT HIEN rainbow seed: Tool='%s' Parent='%s' RainbowSeedAttr=%s")
        :format(tool.Name, tostring(tool.Parent and tool.Parent.Name or "-"),
                tostring(tool:GetAttribute("RainbowSeed") == true)))

    local itemKey, invCount = resolveSeedItemKey(tool)
    log(("ItemKey se gui = '%s' (kho hien co: %s)")
        :format(tostring(itemKey), invCount and tostring(invCount) or "khong doc duoc"))

    if SKIP_RESENT_KEY and sentKeys[itemKey] then
        log(("Bo qua: key '%s' da gui thanh cong truoc do trong phien nay."):format(tostring(itemKey)))
        return false
    end

    log(("Doi %d giay roi gui..."):format(DELAY_BEFORE_SEND))
    task.wait(DELAY_BEFORE_SEND)

    local userId = resolveRecipientUserId()
    if not userId then return false end

    local ok = sendSeed(userId, itemKey)
    if ok and SKIP_RESENT_KEY then
        sentKeys[itemKey] = true
    end
    return ok
end

task.spawn(function()
    log("Bat dau test nhan dien rainbow seed...")
    if LOOP_ENABLED then
        log(("Che do LOOP: canh moi %d giay."):format(INTERVAL_SEC))
        while true do
            pcall(watchOnce)
            task.wait(INTERVAL_SEC)
        end
    else
        watchOnce()
        log("Xong (che do chay 1 lan).")
    end
end)
