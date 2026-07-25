local themes = require "src.preferences.themes"
local shakes = require "src.system.shakes"
local sounds = require "src.system.sounds"
local GameplayState = require "src.states.gameplay"
local HerdingState = require "src.states.gameplay_herding"
local CountdownState = require "src.states.gameplay_countdown"
local SurvivalState = require "src.states.gameplay_survival"
local BattleState = require "src.states.gameplay_battle"
local BilliardsState = require "src.states.gameplay_billiards"
local state = require "src.state"

local menu = {}

function menu:enter()
    sounds.crash:stop()
    sounds.crash:play()
    -- Define your exact list of choices
    self.options = {"Play","Countdown","Herding Cats", "Survival","Battle", "Billiards" ,"Options", "Exit"}
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
    local hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
    local menuSound = "menuError"
    local menuSoundPitch = 0.99

    
    if hoveredOption then
        if self.selected ~= hoveredOption then
            playSound(menuSound,menuSoundPitch)
        end
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
            playSound(menuSound,menuSoundPitch)
            if self.selected > #self.options then self.selected = 1 end
        end

        local upIsDown = love.keyboard.isDown("up")
        if upIsDown and not self.upWasDown then
            shakes.trigger(shakes.current.power,0.25,CurrentTime)
            self.selected = self.selected - 1
            playSound(menuSound,menuSoundPitch)
            if self.selected < 1 then self.selected = #self.options end
        end

        local selectIsDown = love.keyboard.isDown("return") or love.keyboard.isDown("space")
        if selectIsDown and not self.selectWasDown then
            playSound(menuSound,menuSoundPitch)
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
    love.graphics.setColor(themes.current.secondary)
    love.graphics.print("COUNTEROIDS", (love.graphics.getWidth( )/2-menutitlefont:getWidth("COUNTEROIDS")/2-60), WINDOW_HEIGHT/2-240+8)
    love.graphics.setColor(themes.current.primary)
    love.graphics.print("COUNTEROIDS", (love.graphics.getWidth( )/2-menutitlefont:getWidth("COUNTEROIDS")/2-60), WINDOW_HEIGHT/2-240)
    
    
    for i, option in ipairs(self.options) do
        local y = startY + (i * spacing)
        local w = menulargefont:getWidth("> " .. option) or 160
        self.optionBounds[i] = {
            x = 300,
            y = y - 6,
            w = w,
            h = 28 + 6,
        }

        local pp = self.optionBounds[i]
        -- love.graphics.rectangle("line",pp.x,pp.y,pp.w,pp.h)
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
    elseif choice == "Countdown" then
        state.switch(CountdownState)
    elseif choice == "Herding Cats" then
        state.switch(HerdingState)
    elseif choice == "Survival" then
        state.switch(SurvivalState)
    elseif choice == "Battle" then
        state.switch(BattleState)
    elseif choice == "Billiards" then
        state.switch(BilliardsState)
    elseif choice == "Options" then
        -- state.switch(OptionsMenuState)
    end
end

return menu
