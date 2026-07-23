local Timer = require "lib.hump.timer"
local MenuState = require "src.states.menu"
local themes = require "src.preferences.themes"
local shakes = require "src.system.shakes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local title = {}

function title:enter()
    self.showText = true
    sounds.crash:play()
end

function title:update(dt)
    Timer.update(dt)
    CurrentTime = love.timer.getTime()
    shakes.trigger(shakes.current.power,0.5,CurrentTime)
    Timer.after(1.5, function()
        state.switch(MenuState)
    end)
    
end

function title:draw()
    love.graphics.clear(themes.current.background) 
    shakes.drawShakeScreen(shakes.current.power, CurrentTime)
    
    love.graphics.setFont(titlefont)
    love.graphics.setColor(themes.current.primary)
    love.graphics.print("COUNTEROIDS", (love.graphics.getWidth( )/2-menutitlefont:getWidth("COUNTEROIDS")/2-60), WINDOW_HEIGHT/2-240)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return title
