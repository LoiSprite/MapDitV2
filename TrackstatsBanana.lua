getgenv().MailboxCombinedConfig = getgenv().MailboxCombinedConfig or {
    Language = "vi",

    Manual = {
        ClaimDelay = 0.05,
        MaxClaimsPerCycle = 50,
        ClaimItemDelay = 0,
        DefaultNote = "",
        ClaimDefaultOn = true,
        BatchSize = 100000,
        SendCooldown = 10,
    },

    Queue = {
        Recipient = "loispriteisreal", -- acc main nhận seed
        AutoStart = true,           -- load script là tự chạy hàng chờ
        Note = "mapthulu",

        SendSeeds = true,
        Seeds = {
            "Rainbow",
            "Gold",
        },

        SeedAmount = 0,       -- 0 = gửi hết số seed match
        SeedThreshold = 2,    -- chỉ gửi khi Rainbow/Gold >= 2, tức là > 1

        SendPets = false,
        Pets = {},
        PetAmount = 0,
        PetThreshold = 0,

        BatchSize = 100000,
        DelayBetween = 10,
        LoopInterval = 5,

        WebhookUrl = "",
        Mention = "",
    },

    AntiAfk = {
        Enabled = true,
        Log = false,
    },

    AutoReconnect = {
        Enabled = true,
        Delay = 3,
        SameServer = false,
    },
}
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/8f7376a9396d020206a4c1dfd8babf7e.lua"))()
