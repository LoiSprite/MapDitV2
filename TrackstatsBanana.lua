-- Game Ugc (PlaceId 8304191830): level comes from _stats.player_xp.
-- Formula verified in the dumped LevelServiceCore.calculate_level.
local Config = {
    FromFolder = "5178455e59d2d46de062cdc3349eaf0abdc0f5e7579b0bdb3a5d617badece1bf", -- ID folder hien tai
    ToFolder = "215faab22bf854c8513721a6616406919c77bea54e78831bb4508fb3bb0fd98d",   -- ID folder dich
    Replace = false,
    ConfigId = nil,
    TargetLevel = 20,
}

if Config.FromFolder == "" or Config.ToFolder == "" then
    warn("[FarmSync] Dien FromFolder va ToFolder truoc khi chay")
    return
end

local env = getgenv()
local key = "__FarmSync_Level40Watcher"
if env[key] then
    warn("[FarmSync] Da co watcher hoac da goi doi acc trong phien nay")
    return
end

local state = { attempted = false }
env[key] = state

task.spawn(function()
    local ok, err = pcall(function()
        local players = game:GetService("Players")
        while not players.LocalPlayer do task.wait(1) end
        local player = players.LocalPlayer
        print("[FarmSync] Dang cho level >= " .. Config.TargetLevel)

        while not state.attempted do
            local stats = player:FindFirstChild("_stats")
            local xp = stats and stats:FindFirstChild("player_xp")
            local value = xp and tonumber(xp.Value)
            if value and value >= 0 then
                local level = math.floor((math.sqrt(56 * value + 37249) - 179) / 14)
                local client = env.client
                if level >= Config.TargetLevel and client
                    and type(client.ChangeToFolder) == "function" then
                    -- Mark before calling: never submit twice, even on error/nil.
                    state.attempted = true
                    print("[FarmSync] Level " .. level .. ": gui yeu cau doi acc")
                    local changed = client:ChangeToFolder(
                        Config.FromFolder, Config.ToFolder,
                        Config.Replace == true, Config.ConfigId
                    )
                    if changed then
                        print("[FarmSync] Da gui yeu cau sang folder " .. Config.ToFolder)
                    else
                        warn("[FarmSync] API tra false/nil; khong tu goi lai")
                    end
                    return
                end
            end
            task.wait(2)
        end
    end)
    if not ok then
        if not state.attempted and env[key] == state then env[key] = nil end
        warn("[FarmSync] " .. tostring(err))
    end
end)
