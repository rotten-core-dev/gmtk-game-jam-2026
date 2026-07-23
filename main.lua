local moonshine = require "lib.moonshine"
local push = require "lib.push"
local state = require "src.state"

-- local shakes = require "src.system.shakes"

-- Load your sequential states
local IntroState = require "src.states.intro"
local MenuState = require "src.states.menu"

-- Virtual resolution (design resolution)
local VIRTUAL_WIDTH = 640
local VIRTUAL_HEIGHT = 480

-- Actual window size (can be any size)
--WINDOW_WIDTH = 640
--WINDOW_HEIGHT = 480


local effect

function love.load()

    debug = {
        invn = true,
    }

    love.window.setTitle("COUNTEROIDS")

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
        .chain(moonshine.effects.scanlines)
    -- .chain(moonshine.effects.chromasep)
    --.chain(moonshine.effects.posterize)
    
    --.chain(moonshine.effects.desaturate)
    --.chain(moonshine.effects.vignette)
    
        
    -- effect.pixelate.size = {4,4}
    -- effect.pixelate.feedback = 0.5
    -- effect.posterize.num_bands = 10

    -- effect.glow.strength = 0
    -- effect.chromasep.angle = 20
    -- effect.chromasep.radius = 0--chromasep_base
    effect.scanlines.thickness = 0.6
    effect.scanlines.opacity = 0.2
    effect.scanlines.width = 2
    effect.crt.distortionFactor = {1.01,1.01}
    effect.crt.scaleFactor = {1,1}--{0.95,0.95}
    effect.crt.feather = 0.01 --0.02
    
    -- Start the sequence!
    state.switch(MenuState)
end

function love.update(dt)
    local current = state.current()
    if current and current.update then
        current:update(dt)
    end

    CurrentTime = love.timer.getTime()
end

-- Override love.draw so Moonshine wraps around whatever HUMP is currently drawing
function love.draw()

        push:start()
            effect(function()
                local current = state.current()
                if current and current.draw then
                    current:draw()
                end
           end)
        push:finish()


end

-- Crucial: Pass window adjustments directly to the push lib
function love.resize(w, h)
    push:resize(w, h)
end

