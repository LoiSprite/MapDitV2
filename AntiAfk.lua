local VirtualInputManager = game:GetService("VirtualInputManager")
while true do
    wait(60)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    print("concac")
end
