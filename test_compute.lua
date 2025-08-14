function love.load()
    print("LÖVE Version: " .. love.getVersion())
    
    if love.graphics.newComputeShader then
        print("✅ Compute shader support: AVAILABLE")
        print("This build supports compute shaders!")
    else
        print("❌ Compute shader support: NOT AVAILABLE")
        print("This LÖVE 12.0 build doesn't have compute shader support yet.")
        print("Compute shaders may still be in development.")
    end
    
    print("\nAvailable graphics features:")
    if love.graphics.getTextureFormats then
        print("- getTextureFormats: YES")
    end
    if love.graphics.newTexture then
        print("- newTexture: YES")
    end
    if love.graphics.newBuffer then
        print("- newBuffer: YES")
    end
    if love.graphics.dispatchThreadgroups then
        print("- dispatchThreadgroups: YES") 
    end
    
    love.event.quit()
end
