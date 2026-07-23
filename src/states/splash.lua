local Timer = require "lib.hump.timer"
local TitleState = require "src.states.title"
local shakes = require "src.system.shakes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local splash = {}

WINDOW_WIDTH = 640
WINDOW_HEIGHT = 480

function splash:enter()
    -- Load your logo image asset here
    sounds.crash:play()
    self.logo = love.graphics.newImage("lib/assets/rottenlogo.png")
    
    -- Sequence: Fade In (1s) -> Stay (1.5s) -> Fade Out (1s) -> Switch State
    --Timer.tween(1.0, self, {alpha = 1}, 'linear', function()
        Timer.after(1.0, function()
            shakes.trigger(2*shakes.current.power,1.0,CurrentTime)
                Timer.after(1.0, function()
                            state.switch(TitleState)
            end)
        end)
    --end)
end

function splash:update(dt)
    Timer.update(dt) -- Keep HUMP's timer ticking
    CurrentTime = love.timer.getTime()
end

function splash:draw()
    love.graphics.clear(0, 0, 0, 1) -- Pure black background
    shakes.drawShakeScreen(shakes.current.power, CurrentTime)

    
    -- Set drawing color with the dynamic transparency value
    love.graphics.setColor(1, 1, 1, self.alpha)
    
    -- Draw text placeholder (or replace with love.graphics.draw(self.logo, ...))
    --love.graphics.setNewFont(16)
    --love.graphics.printf("COMPANY LOGO HERE", 0, 140, 400, "center")

    love.graphics.draw(self.logo,WINDOW_WIDTH/2 - (self.logo:getWidth()), WINDOW_HEIGHT/2 - (self.logo:getHeight()),0,1,1,0,0)
    
    
    -- Always reset color back to full white so it doesn't bleed into other draws
    love.graphics.setColor(1, 1, 1, 1)
end

return splash
