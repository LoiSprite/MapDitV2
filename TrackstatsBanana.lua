kaitun getgenv().AnimeDiceAutoChangeConfig = {
	Enabled  = true,
	Interval = 3,
	Item   = "Jackpot Spin",
	Amount = 1,
	FromFolder = "5178455e59d2d46de062cdc3349eaf0abdc0f5e7579b0bdb3a5d617badece1bf",           -- ID folder acc chính
	ToFolder   = "2bc83f3a30d9bce6d7cc71df2d7acc1f7d5c2cbc488bc6b95fb51b9ba5e816c2",           -- ID folder acc thay thế
	Replace = false,           -- tham số 3 của ChangeToFolder
	RetryOnFail = true,
	Log = true,
	UI = { Enabled = true, ToggleKey = Enum.KeyCode.RightAlt },
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/quoc12092008/Chuiroblox2/refs/heads/main/change.lua"))()
