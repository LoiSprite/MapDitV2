local VirtualInputManager = game:GetService("VirtualInputManager")
while true do
    wait(60)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.L, false, game)
    wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.L, false, game)
    print("concac")
end
