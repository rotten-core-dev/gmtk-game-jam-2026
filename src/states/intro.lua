local Gamestate = require "lib.hump.gamestate"
local Timer = require "lib.hump.timer"
local SplashState = require "src.states.splash"

local intro = {}

function intro:enter()
    -- Wait 1 second, then switch states
    Timer.after(1.0, function()
        Gamestate.switch(SplashState)
    end)
end

function intro:update(dt)
    Timer.update(dt)
end

function intro:draw()
    -- Keep it blank
    love.graphics.clear(0, 0, 0)
end

return intro
