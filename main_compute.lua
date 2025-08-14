--
-- Boids simulation using LÖVE 12.0 compute shaders
-- Requires LÖVE 12.0 nightly build
--

local ffi = require("ffi")

-- Define boid structure matching the compute shader
ffi.cdef[[
    typedef struct {
        float x, y;      // position
        float vx, vy;    // velocity  
        float radius;
        float mass;
        float fraction;
        float hp;
    } Boid;
]]

local MAX_BOIDS = 65536  -- Can handle MANY more boids with compute shaders!
local boidCount = 0
local boidData = ffi.new("Boid[?]", MAX_BOIDS)
local boidBuffer = nil
local computeShader = nil
local drawShader = nil

local game = {
    pause = false,
    spawnRate = 10,
    sight = 50,
    ruleCohesion = 30,
    ruleAlignment = 10, 
    ruleSeparation = 20,
    limitVelocity = 100
}

function love.load()
    if not love.graphics.getTextureFormats then
        error("This demo requires LÖVE 12.0 with compute shader support!\n" ..
              "Download nightly builds from: https://github.com/love2d/love/actions")
    end
    
    -- Create storage buffer for boids
    boidBuffer = love.graphics.newBuffer({
        format = {
            {name = "position", format = "floatvec2"},
            {name = "velocity", format = "floatvec2"},
            {name = "radius", format = "float"},
            {name = "mass", format = "float"},
            {name = "fraction", format = "float"},
            {name = "hp", format = "float"}
        },
        size = MAX_BOIDS,
        usage = {"vertex", "storage"}
    })
    
    -- Load compute shader
    local shaderCode = love.filesystem.read("boids_compute.glsl")
    computeShader = love.graphics.newComputeShader(shaderCode)
    
    -- Create draw shader for rendering
    drawShader = love.graphics.newShader([[
        #pragma language glsl3
        
        layout(location = 0) in vec2 position;
        layout(location = 1) in vec2 velocity;
        layout(location = 2) in float radius;
        
        uniform mat4 projection;
        
        #ifdef VERTEX
        vec4 position(mat4 transform, vec4 vertex) {
            vec4 pos = vec4(position + vertex.xy * radius, 0.0, 1.0);
            return projection * pos;
        }
        #endif
        
        #ifdef PIXEL
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            float dist = length(uv - vec2(0.5));
            if (dist > 0.5) discard;
            
            float intensity = 1.0 - dist * 2.0;
            return vec4(intensity, intensity * 0.5, intensity * 0.8, intensity);
        }
        #endif
    ]])
    
    print("LÖVE 12.0 Compute Shader Boids Demo")
    print("Controls:")
    print("- Left/Right click: Add boids")
    print("- Space: Pause")
    print("- 1/2: Adjust spawn rate")
    print("- Q/W: Adjust sight range")
    print("Max boids: " .. MAX_BOIDS)
end

function addBoid(x, y, vx, vy)
    if boidCount >= MAX_BOIDS then return end
    
    local boid = boidData[boidCount]
    boid.x = x
    boid.y = y
    boid.vx = vx or love.math.random(-50, 50)
    boid.vy = vy or love.math.random(-50, 50)
    boid.radius = love.math.random(3, 6)
    boid.mass = math.sqrt(boid.radius)
    boid.fraction = love.mouse.isDown(2) and 1 or 2
    boid.hp = 1
    
    boidCount = boidCount + 1
end

function love.update(dt)
    if game.pause then
        dt = 0
    end
    
    -- Add boids on mouse click
    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        local mx, my = love.mouse.getPosition()
        for i = 1, game.spawnRate do
            addBoid(
                mx + love.math.random(-20, 20),
                my + love.math.random(-20, 20)
            )
        end
    end
    
    if boidCount > 0 and computeShader then
        -- Upload boid data to GPU buffer
        boidBuffer:setData(ffi.string(boidData, ffi.sizeof(boidData[0]) * boidCount))
        
        -- Set compute shader uniforms
        computeShader:send("boidCount", boidCount)
        computeShader:send("dt", dt)
        computeShader:send("worldSize", {love.graphics.getDimensions()})
        computeShader:send("sight", game.sight)
        computeShader:send("ruleCohesion", game.ruleCohesion)
        computeShader:send("ruleAlignment", game.ruleAlignment)
        computeShader:send("ruleSeparation", game.ruleSeparation)
        computeShader:send("limitVelocity", game.limitVelocity)
        
        -- Bind buffer to compute shader
        computeShader:sendBuffer("boidBuffer", boidBuffer)
        
        -- Run compute shader
        love.graphics.setShader(computeShader)
        love.graphics.dispatchThreadgroups(math.ceil(boidCount / 64), 1, 1)
        love.graphics.setShader()
        
        -- Read back data (optional, for CPU access)
        if false then  -- Set to true if you need CPU-side data
            local data = love.graphics.readbackBuffer(boidBuffer)
            ffi.copy(boidData, data, ffi.sizeof(boidData[0]) * boidCount)
        end
    end
end

function love.draw()
    love.graphics.clear(0.05, 0.05, 0.1)
    
    -- Draw boids using instanced rendering
    if boidCount > 0 and drawShader then
        love.graphics.setShader(drawShader)
        
        -- Create simple circle mesh
        local vertices = {}
        local segments = 16
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            table.insert(vertices, {math.cos(angle), math.sin(angle)})
        end
        local mesh = love.graphics.newMesh(vertices, "fan")
        
        -- Set projection matrix
        local w, h = love.graphics.getDimensions()
        local projection = {
            2/w, 0, 0, -1,
            0, -2/h, 0, 1,
            0, 0, 1, 0,
            0, 0, 0, 1
        }
        drawShader:send("projection", projection)
        
        -- Draw all boids in one call!
        mesh:setVertexAttribute("position", boidBuffer, 1)
        mesh:setVertexAttribute("velocity", boidBuffer, 2)
        mesh:setVertexAttribute("radius", boidBuffer, 3)
        love.graphics.drawInstanced(mesh, boidCount)
        
        love.graphics.setShader()
    end
    
    -- UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Boids: " .. boidCount .. " / " .. MAX_BOIDS, 10, 30)
    love.graphics.print("Spawn Rate: " .. game.spawnRate, 10, 50)
    love.graphics.print("Sight Range: " .. game.sight, 10, 70)
    
    if boidCount > 10000 then
        love.graphics.print("Handling " .. boidCount .. " boids with compute shaders!", 10, 100)
        love.graphics.print("Try this with the fragment shader version!", 10, 120)
    end
end

function love.keypressed(key)
    if key == "space" then
        game.pause = not game.pause
    elseif key == "1" then
        game.spawnRate = math.max(1, game.spawnRate - 5)
    elseif key == "2" then
        game.spawnRate = math.min(100, game.spawnRate + 5)
    elseif key == "q" then
        game.sight = math.max(10, game.sight - 10)
    elseif key == "w" then
        game.sight = math.min(200, game.sight + 10)
    elseif key == "escape" then
        love.event.quit()
    end
end
