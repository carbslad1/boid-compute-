--
-- Optimized for LÖVE 11.5
-- Copyright DrJamgo@hotmail.com 2020, optimizations 2024
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end
  if pcall(require, "mobdebug") then require("mobdebug").start() end
end

Class = require "hump.class" 
gWiggleValues = require 'wiggle'

require "physics.boids"
require "physics.world"

-- Get maximum texture size but cap it for performance
local maxTextureSize = love.graphics.getSystemLimits().texturesize
-- Cap at 16384 for better performance/memory balance
local particleLimit = math.min(maxTextureSize, 16384)
print("GPU Maximum texture size: " .. maxTextureSize)
print("Setting particle limits to: " .. particleLimit)

gWorld = World(love.graphics.getDimensions())
gBoids = Boids(gWorld, particleLimit)
gBalls = Dynamic(gWorld, particleLimit)
gGame = {
  pause = false,
  spawnRate = 5,  -- Adjustable spawn rate
  useBloomEffect = false  -- Toggle fancy effects
}

-- Create persistent canvases with proper formats
local w, h = love.graphics.getDimensions()
local canvasSettings = {format = 'rgba8', dpiscale = 1}
local canvas1 = love.graphics.newCanvas(w, h, canvasSettings)
local canvas2 = love.graphics.newCanvas(w, h, canvasSettings)
local currentCanvas = 1

function love.load()
  gWiggleValues:add('p', gGame, 'pause')
  gWiggleValues:add('r', gGame, 'spawnRate')
  
  -- Set graphics optimizations
  love.graphics.setDefaultFilter("nearest", "nearest")
  
  print("Controls:")
  print("- Right click: Add Boids")
  print("- Left click: Add Balls")
  print("- P: Pause")
  print("- R: Adjust spawn rate")
  print("- C/A/S/V: Adjust boid rules")
end

local FPS
local FRAME = 0
local spawnTimer = 0

function love.update(dt)
  local f = 0.05
  FPS = (FPS or (1/f)) * (1-f) + (1/dt) * f
  FRAME = FRAME + 1

  local dt = math.min(dt, 1/30)
  if gGame.pause then
    dt = 0
  end

  -- Batch spawning with timer to reduce per-frame overhead
  spawnTimer = spawnTimer + dt
  if spawnTimer > 0.016 then  -- 60fps tick rate
    local r = love.math.random(2,5)
    local mass = math.sqrt(r)
    
    if love.mouse.isDown(2) then
      local x,y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
      for i=1,gGame.spawnRate do
        gBoids:add({
          x=x+love.math.random(-10,10),
          y=y+love.math.random(-10,10),
          m=mass,r=r,fraction=1,hp=1
        })
      end
    elseif love.mouse.isDown(1) then
      local x,y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
      for i=1,gGame.spawnRate do
        gBalls:add({
          x=x+love.math.random(-10,10),
          y=y+love.math.random(-10,10),
          m=mass,r=r,fraction=1,hp=1
        })
      end
    end
    spawnTimer = 0
  end

  gBoids:update(dt)
  gBoids:renderToWorld()

  gBalls:update(dt)
  gBalls:renderToWorld()
  gWorld:update()
end

function love.draw()
  -- Use double buffering for trails effect
  local sourceCanvas = currentCanvas == 1 and canvas1 or canvas2
  local targetCanvas = currentCanvas == 1 and canvas2 or canvas1
  
  love.graphics.setCanvas({targetCanvas, stencil=false, depth=false})
  love.graphics.clear(0, 0, 0, 0)
  
  -- Draw previous frame with fade
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.setColor(1, 1, 1, 0.98)
  love.graphics.draw(sourceCanvas)
  
  -- Draw new particles
  love.graphics.setBlendMode("add", "premultiplied")
  gBoids:draw()
  gBalls:draw()
  
  -- Draw to screen
  love.graphics.setCanvas()
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(targetCanvas)
  
  currentCanvas = currentCanvas == 1 and 2 or 1
  
  -- UI
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setColor(1, 1, 1, 1)
  
  love.graphics.print({{1,0,0,1},'Right-click',{1,1,1,1},' to add Boids'},10,25)
  love.graphics.printf(string.format('Boids: %d / %d',gBoids.size, gBoids.capacity),10,40,300,'left')
  
  love.graphics.print({{1,0,0,1},'Left-click',{1,1,1,1},' to add Balls'},10,65)
  love.graphics.printf(string.format('Balls: %d / %d',gBalls.size, gBalls.capacity),10,80,300,'left')
  
  love.graphics.printf(string.format('FPS: %.1f',FPS),10,120,200,'left',0,1.5)
  love.graphics.printf(string.format('Spawn Rate: %d',gGame.spawnRate),10,140,200,'left')
  
  if gBoids.size > 1000 or gBalls.size > 1000 then
    love.graphics.print("Performance tip: Reduce 'sight' (V key) for better FPS", 10, 160)
  end
  
  gWiggleValues:draw(10,love.graphics.getHeight()-100,300)
end

function love.keypressed(key)
  gWiggleValues:keypressed(key)
  
  if key == "1" then
    gGame.spawnRate = math.max(1, gGame.spawnRate - 1)
  elseif key == "2" then
    gGame.spawnRate = math.min(50, gGame.spawnRate + 1)
  end
end

function love.resize(w, h)
  -- Recreate canvases on resize
  canvas1 = love.graphics.newCanvas(w, h, canvasSettings)
  canvas2 = love.graphics.newCanvas(w, h, canvasSettings)
end
