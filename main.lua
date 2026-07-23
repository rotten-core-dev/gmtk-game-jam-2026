local Gamestate = require "lib.hump.gamestate"
local moonshine = require "lib.moonshine"
local push = require "lib.push"

-- local shakes = require "src.system.shakes"

-- Load your sequential states
local IntroState = require "src.states.intro"

-- Virtual resolution (design resolution)
local VIRTUAL_WIDTH = 640
local VIRTUAL_HEIGHT = 480

-- Actual window size (can be any size)
--WINDOW_WIDTH = 640
--WINDOW_HEIGHT = 480


local effect

function love.load()

    WINDOW_HEIGHT = love.graphics.getHeight()
    WINDOW_WIDTH = love.graphics.getWidth()

    --fonts--
    font = love.graphics.newFont("lib/fonts/Lightshadow.otf", 13)
    smallfont = love.graphics.newFont("lib/fonts/CooperHewitt-OTF-public/CooperHewitt-Bold.otf", 13)
    largefont = love.graphics.newFont("lib/fonts/Lightshadow.otf", 20)
    menulargefont = love.graphics.newFont("lib/fonts/Lightshadow.otf", 25)
    titlefont = love.graphics.newFont("lib/fonts/pixel.ttf", 115)
    biggertitlefont = love.graphics.newFont("lib/fonts/pixel.ttf", 135)
    menutitlefont = love.graphics.newFont("lib/fonts/pixel.ttf", 115)
    biggermenutitlefont = love.graphics.newFont("lib/fonts/pixel.ttf", 120)
    gameoverfont = love.graphics.newFont("lib/fonts/pixel.ttf", 80)
    biggergameoverfont = love.graphics.newFont("lib/fonts/pixel.ttf", 85)
    scorefont = love.graphics.newFont("lib/fonts/Lightshadow.otf", 13)
    settingsfont = love.graphics.newFont("lib/fonts/pixel.ttf", 20)

    love.graphics.setFont(font)


    
    -- Set up Push with your virtual resolution vs physical window size
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        pixelperfect = true -- Ensures sharp pixels, no blurry scaling
    })
    
    -- Initialize your shader stack (e.g., CRT and Vignette effect)
    effect = moonshine(moonshine.effects.crt)
                      .chain(moonshine.effects.vignette)
    
    -- Direct HUMP to automatically hook into love.update, love.draw, etc.
    Gamestate.registerEvents()
    
    -- Start the sequence!
    Gamestate.switch(IntroState)
end

function love.update(dt)
    
    CurrentTime = love.timer.getTime()
end

-- Override love.draw so Moonshine wraps around whatever HUMP is currently drawing
function love.draw()
    effect(function()
        push:start()
        
            Gamestate.current():draw()
       
        push:finish()
    end)

end

-- Crucial: Pass window adjustments directly to the push lib
function love.resize(w, h)
    push:resize(w, h)
end

