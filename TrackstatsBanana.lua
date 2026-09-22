getgenv().AnimeDiceAutoChangeConfig = {
    Enabled  = true,
    Interval = 3,
    Item   = "Jackpot Spin",
    Amount = 1,
    Backend = "api",
    Api = {
        Url = "https://accountops.org",
        Key = "ak_d5001c83bb5fe8ecd64423c496c3c3aed4b6daf19c1ebd98d42cee3f07c83bf6",
        AuthMode = "x-api-key",
        Username = "loisprite",
        Option   = 1,
        RetryEvery = 60,
    },
    FromFolder = "",
    ToFolder   = "",
    Replace    = false,
    RetryOnFail = true,
    Log = true,
    UI = { Enabled = true, ToggleKey = Enum.KeyCode.RightAlt },
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/quoc12092008/Chuiroblox2/refs/heads/main/change.lua"))()
