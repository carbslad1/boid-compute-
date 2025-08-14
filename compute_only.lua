--
-- PURE GPU COMPUTE SHADER BOIDS
-- No CPU simulation bullshit
--

local computeShader = nil
local dataTexture = nil
local MAX_BOIDS = 4096
local boidCount = 0
local textureData = nil

function love.load()
    print("LÖVE 12.0 PURE COMPUTE SHADER BOIDS")
    print("=====================================")
    
    if not love.graphics.newComputeShader then
        error("NO COMPUTE SHADERS - GET LÖVE 12.0!")
    end
    
    -- Create data texture to store boid state
    -- R,G = position X,Y
    -- B,A = velocity X,Y  
    textureData = love.image.newImageData(MAX_BOIDS, 1, "rgba32f")
    dataTexture = love.graphics.newTexture(textureData, {
        computewrite = true,
        format = "rgba32f"
    })
    
    -- Compute shader that actually updates boids
    local shaderCode = [[
        #pragma language glsl4
        
        layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;
        
        layout(rgba32f, binding = 0) uniform image2D boidData;
        
        uniform int boidCount;
        uniform float dt;
        uniform vec2 screenSize;
        
        void computemain() {
            uint id = gl_GlobalInvocationID.x;
            if (id >= boidCount) return;
            
            // Read current boid state
            vec4 data = imageLoad(boidData, ivec2(id, 0));
            vec2 pos = data.xy;
            vec2 vel = data.zw;
            
            // Boids algorithm
            vec2 separation = vec2(0.0);
            vec2 alignment = vec2(0.0);
            vec2 cohesion = vec2(0.0);
            int neighbors = 0;
            
            for (uint i = 0; i < boidCount; i++) {
                if (i == id) continue;
                
                vec4 otherData = imageLoad(boidData, ivec2(i, 0));
                vec2 otherPos = otherData.xy;
                vec2 otherVel = otherData.zw;
                
                vec2 diff = pos - otherPos;
                float dist = length(diff);
                
                if (dist < 100.0 && dist > 0.0) {
                    // Separation
                    if (dist < 30.0) {
                        separation += normalize(diff) * (30.0 - dist) / 30.0;
                    }
                    
                    // Alignment and cohesion
                    alignment += otherVel;
                    cohesion += otherPos;
                    neighbors++;
                }
            }
            
            // Apply rules
            if (neighbors > 0) {
                alignment = alignment / float(neighbors);
                cohesion = (cohesion / float(neighbors)) - pos;
                
                vel += separation * 100.0 * dt;
                vel += normalize(alignment - vel) * 50.0 * dt;
                vel += normalize(cohesion) * 30.0 * dt;
            }
            
            // Limit speed
            float speed = length(vel);
            if (speed > 200.0) {
                vel = normalize(vel) * 200.0;
            }
            
            // Update position
            pos += vel * dt;
            
            // Wrap around screen
            if (pos.x < 0.0) pos.x += screenSize.x;
            if (pos.x > screenSize.x) pos.x -= screenSize.x;
            if (pos.y < 0.0) pos.y += screenSize.y;
            if (pos.y > screenSize.y) pos.y -= screenSize.y;
            
            // Write back
            imageStore(boidData, ivec2(id, 0), vec4(pos, vel));
        }
    ]]
    
    computeShader = love.graphics.newComputeShader(shaderCode)
    print("✅ COMPUTE SHADER COMPILED!")
    
    print("\nControls:")
    print("- Click: Add boids") 
    print("- Space: Add 100 boids")
    print("- C: Clear all")
    print("- ESC: Quit")
end

function addBoid(x, y)
    if boidCount >= MAX_BOIDS then return end
    
    -- Set pixel in texture
    textureData:setPixel(boidCount, 0, 
        x, y,  -- position
        love.math.random(-100, 100), love.math.random(-100, 100)  -- velocity
    )
    boidCount = boidCount + 1
    
    -- Update texture
    dataTexture:replacePixels(textureData)
end

function love.update(dt)
    -- Add boids on mouse
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        for i = 1, 5 do
            addBoid(
                mx + love.math.random(-30, 30),
                my + love.math.random(-30, 30)
            )
        end
    end
    
    if boidCount > 0 then
        -- RUN THE COMPUTE SHADER
        love.graphics.setShader(computeShader)
        computeShader:send("boidCount", boidCount)
        computeShader:send("dt", dt)
        computeShader:send("screenSize", {love.graphics.getDimensions()})
        computeShader:sendTexture("boidData", dataTexture)
        
        -- Dispatch compute work groups
        local workgroups = math.ceil(boidCount / 32)
        love.graphics.dispatchThreadgroups(workgroups)
        
        love.graphics.setShader()
        
        -- Read back for rendering (this sucks but necessary for now)
        textureData = dataTexture:newImageData()
    end
end

function love.draw()
    love.graphics.clear(0.02, 0.02, 0.05)
    
    -- Draw all boids
    love.graphics.setColor(0, 1, 1, 0.8)
    for i = 0, boidCount - 1 do
        local r, g, b, a = textureData:getPixel(i, 0)
        local x, y = r, g
        local vx, vy = b, a
        
        -- Draw boid
        love.graphics.circle("fill", x, y, 3)
        
        -- Draw direction arrow
        if vx ~= 0 or vy ~= 0 then
            local angle = math.atan2(vy, vx)
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(angle)
            love.graphics.polygon("fill", 7, 0, -4, -3, -4, 3)
            love.graphics.pop()
        end
    end
    
    -- UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PURE GPU COMPUTE BOIDS", 10, 10)
    love.graphics.print(string.format("FPS: %.0f", love.timer.getFPS()), 10, 30)
    love.graphics.print(string.format("Boids: %d / %d", boidCount, MAX_BOIDS), 10, 50)
    
    if boidCount > 1000 then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("ALL COMPUTED ON GPU!", 10, 70)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        boidCount = 0
        textureData = love.image.newImageData(MAX_BOIDS, 1, "rgba32f")
        dataTexture:replacePixels(textureData)
    elseif key == "space" then
        -- Add 100 random boids
        local w, h = love.graphics.getDimensions()
        for i = 1, 100 do
            addBoid(love.math.random(0, w), love.math.random(0, h))
        end
    end
end
