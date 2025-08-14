--
-- LÖVE 12.0 COMPUTE SHADER BOIDS
-- Using correct API from documentation
--

local computeShader = nil
local posBuffer = nil
local velBuffer = nil
local MAX_BOIDS = 16384
local boidCount = 0

-- CPU arrays for initial data
local positions = {}
local velocities = {}

function love.load()
    print("LÖVE 12.0 COMPUTE SHADER BOIDS (CORRECT API)")
    print("=============================================")
    
    -- Check compute shader support
    local ok = pcall(love.graphics.newComputeShader, 
                     "layout(local_size_x=1)in;void computemain(){}")
    if not ok then
        error("No compute shader support!")
    end
    
    -- Skip limits check for now
    
    -- Initialize arrays
    for i = 1, MAX_BOIDS * 2 do
        positions[i] = 0
        velocities[i] = 0
    end
    
    -- Create SSBOs with correct API
    posBuffer = love.graphics.newBuffer("float", MAX_BOIDS * 2, {shaderstorage = true})
    velBuffer = love.graphics.newBuffer("float", MAX_BOIDS * 2, {shaderstorage = true})
    
    -- Create compute shader (no binding= in GLSL!)
    local shaderCode = [[
        #pragma language glsl4
        
        layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
        
        // No binding= specified, LÖVE handles it
        layout(std430) buffer PositionBuffer {
            float positions[];
        };
        
        layout(std430) buffer VelocityBuffer {
            float velocities[];
        };
        
        uniform int boidCount;
        uniform float dt;
        uniform vec2 screenSize;
        
        void computemain() {
            uint id = gl_GlobalInvocationID.x;
            if (id >= boidCount) return;
            
            // Read position and velocity (2 floats each)
            vec2 pos = vec2(positions[id * 2], positions[id * 2 + 1]);
            vec2 vel = vec2(velocities[id * 2], velocities[id * 2 + 1]);
            
            // Boids algorithm
            vec2 separation = vec2(0.0);
            vec2 alignment = vec2(0.0);
            vec2 cohesion = vec2(0.0);
            int neighbors = 0;
            
            for (uint i = 0; i < boidCount; i++) {
                if (i == id) continue;
                
                vec2 otherPos = vec2(positions[i * 2], positions[i * 2 + 1]);
                vec2 otherVel = vec2(velocities[i * 2], velocities[i * 2 + 1]);
                
                vec2 diff = pos - otherPos;
                float dist = length(diff);
                
                if (dist < 100.0 && dist > 0.0) {
                    // Separation
                    if (dist < 50.0) {
                        separation += normalize(diff) / dist;
                    }
                    
                    // Alignment & Cohesion
                    alignment += otherVel;
                    cohesion += otherPos;
                    neighbors++;
                }
            }
            
            // Apply rules
            if (neighbors > 0) {
                alignment /= float(neighbors);
                cohesion = (cohesion / float(neighbors)) - pos;
                
                vel += separation * 50.0 * dt;
                vel += normalize(alignment - vel) * 20.0 * dt;
                vel += normalize(cohesion) * 10.0 * dt;
            }
            
            // Limit speed
            float speed = length(vel);
            if (speed > 300.0) {
                vel = normalize(vel) * 300.0;
            }
            
            // Update position
            pos += vel * dt;
            
            // Wrap around
            if (pos.x < 0.0) pos.x = screenSize.x;
            if (pos.x > screenSize.x) pos.x = 0.0;
            if (pos.y < 0.0) pos.y = screenSize.y;
            if (pos.y > screenSize.y) pos.y = 0.0;
            
            // Write back
            positions[id * 2] = pos.x;
            positions[id * 2 + 1] = pos.y;
            velocities[id * 2] = vel.x;
            velocities[id * 2 + 1] = vel.y;
        }
    ]]
    
    computeShader = love.graphics.newComputeShader(shaderCode)
    
    -- Check for warnings
    local warnings = computeShader:getWarnings()
    if warnings ~= "" then
        print("Shader warnings:", warnings)
    else
        print("✅ Compute shader compiled with no warnings!")
    end
    
    print("\nControls:")
    print("- Click: Add boids")
    print("- Space: Add 100 boids")
    print("- C: Clear")
end

function addBoid(x, y)
    if boidCount >= MAX_BOIDS then return end
    
    local idx = boidCount * 2
    positions[idx + 1] = x
    positions[idx + 2] = y
    velocities[idx + 1] = love.math.random(-150, 150)
    velocities[idx + 2] = love.math.random(-150, 150)
    boidCount = boidCount + 1
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
        -- Upload data to GPU using setArrayData (correct function!)
        posBuffer:setArrayData(positions)
        velBuffer:setArrayData(velocities)
        
        -- Send uniforms
        computeShader:send("boidCount", boidCount)
        computeShader:send("dt", dt)
        computeShader:send("screenSize", {love.graphics.getDimensions()})
        
        -- Send buffers (no binding= needed!)
        computeShader:send("PositionBuffer", posBuffer)
        computeShader:send("VelocityBuffer", velBuffer)
        
        -- Dispatch compute shader
        local workgroups = math.ceil(boidCount / 64)
        love.graphics.dispatchThreadgroups(computeShader, workgroups, 1, 1)
        
        -- Read back for rendering
        local posData = love.graphics.readbackBuffer(posBuffer)
        local velData = love.graphics.readbackBuffer(velBuffer)
        
        -- Update CPU arrays from GPU data
        for i = 0, boidCount - 1 do
            positions[i * 2 + 1] = posData:getFloat(i * 8)      -- x at byte offset i*8
            positions[i * 2 + 2] = posData:getFloat(i * 8 + 4)  -- y at byte offset i*8+4
            velocities[i * 2 + 1] = velData:getFloat(i * 8)
            velocities[i * 2 + 2] = velData:getFloat(i * 8 + 4)
        end
    end
end

function love.draw()
    love.graphics.clear(0.02, 0.02, 0.08)
    
    -- Draw boids
    for i = 0, boidCount - 1 do
        local x = positions[i * 2 + 1]
        local y = positions[i * 2 + 2]
        local vx = velocities[i * 2 + 1]
        local vy = velocities[i * 2 + 2]
        
        -- Color based on velocity
        local speed = math.sqrt(vx * vx + vy * vy)
        love.graphics.setColor(0, speed / 300, 1, 0.8)
        love.graphics.circle("fill", x, y, 3)
        
        -- Draw direction
        if speed > 0 then
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
    love.graphics.print("GPU COMPUTE SHADER BOIDS", 10, 10)
    love.graphics.print(string.format("FPS: %.0f", love.timer.getFPS()), 10, 30)
    love.graphics.print(string.format("Boids: %d / %d", boidCount, MAX_BOIDS), 10, 50)
    
    if boidCount > 1000 then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("✅ RUNNING ON GPU!", 10, 70)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        boidCount = 0
        for i = 1, MAX_BOIDS * 2 do
            positions[i] = 0
            velocities[i] = 0
        end
    elseif key == "space" then
        local w, h = love.graphics.getDimensions()
        for i = 1, 100 do
            addBoid(love.math.random(0, w), love.math.random(0, h))
        end
    end
end
