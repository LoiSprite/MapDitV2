--==================================================================
--  AUTO SEND MAIL (SEED) — script ĐỘC LẬP
--  Gửi seed qua Mailbox tới 1 acc, ĐẾM tới đủ Target thì dừng.
--  Mỗi lần gửi THÀNH CÔNG -> update "còn cần gửi" trên GUI + Webhook.
--  Remote/kho lấy từ source thật: Networking.Mailbox.SendBatch / LookupPlayer,
--  replica.Data.Inventory.Seeds (PlayerStateClient).  Item: {Category="Seeds", ItemKey, Count<=20}.
--==================================================================

--============================ CONFIG (chỉnh ở đây) ============================
local CONFIG = {
    Recipient       = "LoiSpriteIsGOD", -- username acc NHẬN
    RecipientUserId = 0,                 -- >0 = dùng luôn UserId này (bỏ qua lookup theo tên)

    Target          = 2000,             -- GỬI ĐỦ bao nhiêu SEED thì dừng (vd 11000 = 11k)
    Seeds           = {"Rainbow", "Gold"},                -- CHỈ gửi các loại này (rỗng {} = TẤT CẢ loại seed đang có)
                                         -- vd: { "Carrot", "Bamboo", "Rainbow" }
    Note            = "map",   -- ghi chú đính kèm mail

    BatchSize       = 2,                -- số seed mỗi lần SendBatch (game giới hạn ~20; muốn thử cao hơn cứ chỉnh)
    DelayBetween    = 0.8,               -- nghỉ giữa mỗi lần gửi (giây)
    StopWhenEmpty   = false,             -- true = HẾT seed thì DỪNG luôn; false = CHỜ thêm seed (vừa farm vừa gửi)
    IdleDelay       = 5,                 -- khi hết seed mà StopWhenEmpty=false thì chờ mấy giây rồi quét lại

    ShowGui         = true,              -- hiện bảng tiến độ trên màn
    WebhookUrl      = "",                -- DÁN webhook Discord vào đây (rỗng = không gửi webhook)
    Mention         = "",                -- vd "<@123456789012345678>" để ping (rỗng = không)
    WebhookEvery    = 1,                 -- gửi webhook mỗi N lần batch thành công (1 = mỗi lần; 5 = đỡ spam)
}
--=============================================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local LocalPlayer        = Players.LocalPlayer

local function log(...) print("[SEND-MAIL]", ...) end

--========================= require module thật =========================
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
        if ok2 then PlayerStateClient = res2 else log("LỖI require PlayerStateClient:", res2) end
    end
end

if not Networking or not Networking.Mailbox then
    log("KHÔNG có Networking.Mailbox -> dừng.")
    return
end

--========================= helper kho seed =========================
local function getReplica()
    if not PlayerStateClient then return nil end
    local ok, rep = pcall(function()
        return PlayerStateClient:GetLocalReplica() or PlayerStateClient:WaitForLocalReplica(5)
    end)
    return ok and rep or nil
end

-- map allow-list (rỗng = nhận tất cả)
local allow = {}
local allowActive = false
for _, n in ipairs(CONFIG.Seeds) do
    if type(n) == "string" and n ~= "" then allow[string.lower(n)] = true; allowActive = true end
end

-- trả về { {ItemKey, Count}, ... } seed đang có (đã lọc allow-list)
local function getSeeds()
    local rep = getReplica()
    local inv = rep and rep.Data and rep.Data.Inventory
    local seeds = inv and inv.Seeds
    if type(seeds) ~= "table" then return {} end
    local out = {}
    for key, count in pairs(seeds) do
        local n = math.floor(tonumber(count) or 0)
        if type(key) == "string" and key ~= "" and n > 0 then
            if (not allowActive) or allow[string.lower(key)] then
                table.insert(out, { ItemKey = key, Count = n })
            end
        end
    end
    return out
end

--========================= resolve người nhận =========================
local function resolveRecipient()
    if type(CONFIG.RecipientUserId) == "number" and CONFIG.RecipientUserId > 0 then
        return CONFIG.RecipientUserId, CONFIG.Recipient
    end
    local name = CONFIG.Recipient
    if type(name) ~= "string" or name == "" then return nil end
    local p = Networking.Mailbox.LookupPlayer
    local ok, userId, displayName = pcall(function() return p:Fire(name) end)
    if ok and type(userId) == "number" and userId > 0 then
        return userId, displayName or name
    end
    log("Không tìm được acc nhận:", name, "-", tostring(userId))
    return nil
end

--========================= GUI =========================
local Gui = {}
do
    if CONFIG.ShowGui then
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "AutoSendMailGui"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sg.Parent = parent

        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromOffset(300, 120)
        frame.Position = UDim2.fromScale(0.5, 0.12)
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = sg
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 0, 24)
        title.Position = UDim2.fromOffset(5, 4)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextColor3 = Color3.fromRGB(120, 200, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = "📬 AUTO SEND SEED"
        title.Parent = frame

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -10, 1, -56)
        body.Position = UDim2.fromOffset(5, 28)
        body.BackgroundTransparency = 1
        body.Font = Enum.Font.Gotham
        body.TextSize = 14
        body.TextColor3 = Color3.fromRGB(235, 235, 235)
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.Text = "Đang khởi động..."
        body.Parent = frame

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size = UDim2.new(1, -10, 0, 22)
        stopBtn.Position = UDim2.new(0, 5, 1, -26)
        stopBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        stopBtn.BorderSizePixel = 0
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.TextSize = 14
        stopBtn.TextColor3 = Color3.new(1, 1, 1)
        stopBtn.Text = "DỪNG"
        stopBtn.Parent = frame
        local bcorner = Instance.new("UICorner"); bcorner.CornerRadius = UDim.new(0, 6); bcorner.Parent = stopBtn

        Gui.Body = body
        Gui.StopBtn = stopBtn
    end
    function Gui.set(text)
        if Gui.Body then Gui.Body.Text = text end
    end
end

--========================= webhook =========================
local httpRequest = (syn and syn.request) or (http and http.request) or http_request
    or (fluxus and fluxus.request) or request
local function postWebhook(content)
    if CONFIG.WebhookUrl == "" or not httpRequest then return end
    pcall(function()
        httpRequest({
            Url = CONFIG.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ content = content }),
        })
    end)
end

--========================= MAIN =========================
local STOPPED = false
if Gui.StopBtn then
    Gui.StopBtn.MouseButton1Click:Connect(function() STOPPED = true end)
end

task.spawn(function()
    local userId, recipientName = resolveRecipient()
    if not userId then
        Gui.set("❌ Không tìm được acc nhận: " .. tostring(CONFIG.Recipient))
        return
    end
    if userId == LocalPlayer.UserId then
        Gui.set("❌ Người nhận là CHÍNH acc này. Đổi Recipient.")
        return
    end

    local target = math.floor(tonumber(CONFIG.Target) or 0)
    local batchSize = math.max(math.floor(tonumber(CONFIG.BatchSize) or 20), 1)
    local sendP = Networking.Mailbox.SendBatch
    local note = tostring(CONFIG.Note or "")

    local sentTotal = 0
    local batchCount = 0

    local function remainingText()
        if target > 0 then
            return ("Còn cần gửi: %d"):format(math.max(target - sentTotal, 0))
        else
            return "Còn cần gửi: (gửi hết kho)"
        end
    end
    local function refreshGui(status, lastSeed)
        Gui.set(("👤 Nhận: %s\n✅ Đã gửi: %d%s\n%s\n%s"):format(
            tostring(recipientName or userId),
            sentTotal,
            target > 0 and (" / " .. target) or "",
            remainingText(),
            (status or "") .. (lastSeed and (" ["..lastSeed.."]") or "")))
    end

    refreshGui("Bắt đầu...")
    postWebhook(("📬 **Bắt đầu gửi seed** -> `%s`\nMục tiêu: **%s** seed"):format(
        tostring(recipientName or userId), target > 0 and tostring(target) or "hết kho"))

    while not STOPPED do
        if target > 0 and sentTotal >= target then break end

        local entries = getSeeds()
        local availableNow = 0
        for _, e in ipairs(entries) do availableNow = availableNow + e.Count end

        if availableNow == 0 then
            if CONFIG.StopWhenEmpty then
                refreshGui("Hết seed -> DỪNG.")
                break
            end
            refreshGui("Hết seed, chờ thêm...")
            if not task.wait(CONFIG.IdleDelay) then end
            -- vẫn loop tiếp để chờ seed mới
        else
            local progressed = false
            for _, e in ipairs(entries) do
                if STOPPED then break end
                if target > 0 and sentTotal >= target then break end
                local avail = e.Count
                while avail > 0 and not STOPPED do
                    if target > 0 and sentTotal >= target then break end
                    local chunk = math.min(avail, batchSize)
                    if target > 0 then chunk = math.min(chunk, target - sentTotal) end
                    if chunk <= 0 then break end

                    local items = { { Category = "Seeds", ItemKey = e.ItemKey, Count = chunk } }
                    local ok, success, msg = pcall(function() return sendP:Fire(userId, items, note) end)
                    if ok and success then
                        sentTotal = sentTotal + chunk
                        avail = avail - chunk
                        progressed = true
                        batchCount = batchCount + 1
                        refreshGui("Đang gửi", e.ItemKey .. " x" .. chunk)
                        if (batchCount % math.max(CONFIG.WebhookEvery, 1)) == 0 then
                            postWebhook(("✅ Gửi **%s x%d** -> `%s`\nĐã gửi: **%d**%s | %s"):format(
                                e.ItemKey, chunk, tostring(recipientName or userId),
                                sentTotal, target > 0 and (" / " .. target) or "", remainingText()))
                        end
                    else
                        refreshGui("⚠️ Gửi lỗi/hết: " .. tostring(msg ~= nil and msg or "fail"), e.ItemKey)
                        break -- ngừng loại seed này (hết seed thật hoặc server từ chối)
                    end
                    if not task.wait(CONFIG.DelayBetween) then end
                end
            end
            if not progressed then
                -- 1 pass mà không gửi được gì (server reject / replica chưa cập nhật)
                if CONFIG.StopWhenEmpty then
                    refreshGui("Không gửi thêm được -> DỪNG.")
                    break
                end
                if not task.wait(CONFIG.IdleDelay) then end
            end
        end
    end

    local doneMsg = STOPPED and "⏹️ ĐÃ DỪNG (thủ công)" or "🎉 XONG"
    refreshGui(doneMsg)
    postWebhook(("%s — tổng đã gửi **%d** seed -> `%s`%s"):format(
        STOPPED and "⏹️ Đã dừng" or "🎉 Hoàn tất",
        sentTotal, tostring(recipientName or userId),
        (CONFIG.Mention ~= "" and ("\n" .. CONFIG.Mention) or "")))
    log(doneMsg, "tong gui =", sentTotal)
end)

log("Sẵn sàng. Nhận:", CONFIG.Recipient, "| Target:", CONFIG.Target)
