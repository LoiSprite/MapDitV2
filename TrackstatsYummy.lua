repeat task.wait() until game:IsLoaded() 

repeat task.wait() until game:GetService('Players') and game:GetService('Players').LocalPlayer and game:GetService('Players').LocalPlayer.Character

local Players = game:GetService('Players')
local Client = Players.LocalPlayer

_G.EnableFriendRequest = true
_G.EnableAutoAcceptFriendRequest = true

local interval = 60

local function SendFriendRequests()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Client then  
            Client:RequestFriendship(player)
            warn("Đã gửi yêu cầu kết bạn tới:", player.Name)
        end
        wait(10) 
    end
end

local function AutoAcceptFriendRequests()

    Client.FriendRequestEvent:Connect(function(requestingPlayer)
        if _G.EnableAutoAcceptFriendRequest then
            print(requestingPlayer)
            Client:RequestFriendship(requestingPlayer) 
            warn("Đã chấp nhận yêu cầu kết bạn từ:", requestingPlayer.Name)
        end
    end)
end

local function MainLoop()
    while true do
        if _G.EnableFriendRequest then
            SendFriendRequests()
        end
        wait(interval)
    end
end


local messages = {
    'add me ill give u fruit',
    'can u help me farming some boss',
    'give me fruit pls, ty',
    'who want team with me and farming together',
}
local intervalChat = 3600

function sendMessage()
    local msg = messages[math.random(#messages)] 
    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All") 
    wait(intervalChat)
    sendMessage()
end


task.spawn(function()
    AutoAcceptFriendRequests()
end)

task.spawn(function()
    MainLoop()
end)

task.spawn(function()
    wait(5) 
    sendMessage()
end)

Client.Idled:connect(function()
    local VirtualUser = game:GetService('VirtualUser')
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)
