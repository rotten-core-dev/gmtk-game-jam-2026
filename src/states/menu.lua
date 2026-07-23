local themes = require "src.preferences.themes"
local shakes = require "src.system.shakes"
local push = require "lib.push"
local sounds = require "src.system.sounds"
local state = require "src.state"
local GameplayState = require "src.states.gameplay"

local menu = {}

function menu:enter()
    sounds.crash:stop()
    sounds.crash:play()
    -- Define your exact list of choices
    self.options = {"Play", "Options", "Exit"}
    self.selected = 1 -- Start highlighted on item 1
    self.timer = 0
    self.showJoinText = true
    self.optionBounds = {}
    self.mouseWasDown = false
        self.upWasDown = false
        self.downWasDown = false
        self.selectWasDown = false
end

function menu:getOptionAtPosition(x, y)
    for i, bounds in ipairs(self.optionBounds or {}) do
        if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
            return i
        end
    end

    return nil
end

function menu:update(dt)
    CurrentTime = love.timer.getTime()
    -- update flashing join text
    self.timer = (self.timer or 0) + dt
    if self.timer >= 0.6 then
        self.timer = self.timer - 0.6
        self.showJoinText = not self.showJoinText
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = push:toGame(mouseX, mouseY)
    local hoveredOption = nil

    if gameX and gameY then
        hoveredOption = self:getOptionAtPosition(gameX, gameY)
    end

    if hoveredOption then
        self.selected = hoveredOption
    end

    local mouseIsDown = love.mouse.isDown(1)
    if mouseIsDown and not self.mouseWasDown and hoveredOption then
        self.selected = hoveredOption
        self:executeChoice()
    end

    self.mouseWasDown = mouseIsDown

        local downIsDown = love.keyboard.isDown("down")
        if downIsDown and not self.downWasDown then
            shakes.trigger(shakes.current.power,0.25,CurrentTime)
            self.selected = self.selected + 1
            if self.selected > #self.options then self.selected = 1 end
        end

        local upIsDown = love.keyboard.isDown("up")
        if upIsDown and not self.upWasDown then
            shakes.trigger(shakes.current.power,0.25,CurrentTime)
            self.selected = self.selected - 1
            if self.selected < 1 then self.selected = #self.options end
        end

        local selectIsDown = love.keyboard.isDown("return") or love.keyboard.isDown("space")
        if selectIsDown and not self.selectWasDown then
            self:executeChoice()
        end

        self.downWasDown = downIsDown
        self.upWasDown = upIsDown
        self.selectWasDown = selectIsDown

end


function menu:draw()
    love.graphics.clear(themes.current.background)
    shakes.drawShakeScreen(shakes.current.power, CurrentTime)
    
    local startY = 200
    local spacing = 50
    self.optionBounds = {}

    love.graphics.setFont(titlefont)
    love.graphics.setColor(themes.current.primary)
    love.graphics.print("COUNTEROIDS", (love.graphics.getWidth( )/2-menutitlefont:getWidth("COUNTEROIDS")/2-60), WINDOW_HEIGHT/2-240)
    
    
    for i, option in ipairs(self.options) do
        local y = startY + (i * spacing)
        self.optionBounds[i] = {
            x = 300,
            y = y - 8,
            w = 160,
            h = 28,
        }

        if i == self.selected then
            -- Highlighted item: Larger font size (or simulated styling)
            love.graphics.setFont(menulargefont)
            love.graphics.setColor(themes.current.primary) 
            love.graphics.print("> " .. option, 300, y)
        else
            -- Normal item: Smaller font size
            love.graphics.setFont(largefont)
            love.graphics.setColor(themes.current.secondary) -- White
            love.graphics.print(option, 320, y)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function menu:executeChoice()
    local choice = self.options[self.selected]
    if choice == "Exit" then
        love.event.quit()
    elseif choice == "Play" then
        state.switch(GameplayState)
    elseif choice == "Options" then
        -- Gamestate.switch(OptionsMenuState)
    end
end

return menu
