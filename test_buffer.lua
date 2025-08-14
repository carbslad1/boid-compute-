function love.load()
    print("Testing LÖVE 12.0 Buffer API...")
    
    -- Try different buffer creation methods
    local success, buffer
    
    -- Method 1: Old style
    success, buffer = pcall(love.graphics.newBuffer, "dynamic", {
        {name = "position", format = "floatvec2"}
    }, 100)
    
    if success then
        print("✅ Method 1 worked")
    else
        print("❌ Method 1 failed:", buffer)
    end
    
    -- Method 2: New style (maybe?)
    success, buffer = pcall(love.graphics.newBuffer, {
        {name = "position", format = "floatvec2"}
    }, 100, "dynamic")
    
    if success then
        print("✅ Method 2 worked")
    else  
        print("❌ Method 2 failed:", buffer)
    end
    
    -- Method 3: Simplest
    success, buffer = pcall(love.graphics.newBuffer, 100)
    
    if success then
        print("✅ Method 3 worked (simple buffer)")
    else
        print("❌ Method 3 failed:", buffer)
    end
    
    love.event.quit()
end
