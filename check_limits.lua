function love.load()
    local limits = love.graphics.getSystemLimits()
    print("Maximum texture size: " .. limits.texturesize)
    print("Maximum particles possible: " .. limits.texturesize)
    love.event.quit()
end
