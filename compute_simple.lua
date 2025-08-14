function love.load()
    print("Testing LÖVE 12.0 Compute Shaders...")
    
    -- Simplest possible compute shader
    local computeCode = [[
        #pragma language glsl4
        
        layout(local_size_x = 1) in;
        
        void computemain() {
            // Do nothing
        }
    ]]
    
    local success, shader = pcall(love.graphics.newComputeShader, computeCode)
    if success then
        print("✅ Basic compute shader compiled!")
        
        -- Try to dispatch it
        love.graphics.setShader(shader)
        local success2, err = pcall(love.graphics.dispatchThreadgroups, 1, 1, 1)
        if success2 then
            print("✅ Compute shader dispatched!")
        else
            print("❌ Dispatch failed:", err)
        end
        love.graphics.setShader()
    else
        print("❌ Compute shader compilation failed:", shader)
    end
    
    -- Create a simple CPU boids simulation instead
    print("\nRunning CPU boids simulation...")
end

local boids = {}
local MAX_BOIDS = 1000

function addBoid(x, y)
    if #boids >= MAX_BOIDS then return end
    
    table.insert(boids, {
        x = x,
        y = y,
        vx = love.math.random(-100, 100),
        vy = love.math.random(-100, 100),
        r = love.math.random() * 0.5 + 0.5,
        g = love.math.random() * 0.5 + 0.5,
        b = love.math.random() * 0.5 + 0.5
    })
end

function love.update(dt)
    -- Add boids on click
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        for i = 1, 5 do
            addBoid(mx + love.math.random(-20, 20), my + love.math.random(-20, 20))
        end
    end
    
    local w, h = love.graphics.getDimensions()
    
    -- Update boids
    for i, boid in ipairs(boids) do
        -- Simple flocking
        local sep_x, sep_y = 0, 0
        local ali_x, ali_y = 0, 0
        local coh_x, coh_y = 0, 0
        local count = 0
        
        for j, other in ipairs(boids) do
            if i ~= j then
                local dx = boid.x - other.x
                local dy = boid.y - other.y
                local dist = math.sqrt(dx*dx + dy*dy)
                
                if dist < 50 and dist > 0 then
                    -- Separation
                    sep_x = sep_x + dx / dist
                    sep_y = sep_y + dy / dist
                    
                    -- Alignment
                    ali_x = ali_x + other.vx
                    ali_y = ali_y + other.vy
                    
                    -- Cohesion
                    coh_x = coh_x + other.x
                    coh_y = coh_y + other.y
                    
                    count = count + 1
                end
            end
        end
        
        if count > 0 then
            ali_x = ali_x / count
            ali_y = ali_y / count
            coh_x = coh_x / count - boid.x
            coh_y = coh_y / count - boid.y
            
            boid.vx = boid.vx + sep_x * 2 + ali_x * 0.01 + coh_x * 0.001
            boid.vy = boid.vy + sep_y * 2 + ali_y * 0.01 + coh_y * 0.001
        end
        
        -- Limit speed
        local speed = math.sqrt(boid.vx * boid.vx + boid.vy * boid.vy)
        if speed > 200 then
            boid.vx = boid.vx * 200 / speed
            boid.vy = boid.vy * 200 / speed
        end
        
        -- Update position
        boid.x = boid.x + boid.vx * dt
        boid.y = boid.y + boid.vy * dt
        
        -- Wrap around
        if boid.x < 0 then boid.x = w end
        if boid.x > w then boid.x = 0 end
        if boid.y < 0 then boid.y = h end
        if boid.y > h then boid.y = 0 end
    end
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.15)
    
    -- Draw boids
    for _, boid in ipairs(boids) do
        love.graphics.setColor(boid.r, boid.g, boid.b, 0.8)
        love.graphics.circle("fill", boid.x, boid.y, 4)
        
        -- Draw direction
        local angle = math.atan2(boid.vy, boid.vx)
        love.graphics.push()
        love.graphics.translate(boid.x, boid.y)
        love.graphics.rotate(angle)
        love.graphics.polygon("fill", 6, 0, -3, -2, -3, 2)
        love.graphics.pop()
    end
    
    -- UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("LÖVE 12.0 Boids (CPU Simulation)", 10, 10)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 30)
    love.graphics.print("Boids: " .. #boids .. " / " .. MAX_BOIDS, 10, 50)
    love.graphics.print("Click to add boids", 10, 70)
    
    if #boids > 500 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Note: Compute shaders would make this MUCH faster!", 10, 90)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        boids = {}  -- Clear
    end
end
