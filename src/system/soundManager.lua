
--[[add to main file

    require("src/system/soundManager.lua")

    soundManager:load()

    soundManager:update(dt)

    soundManager:draw()

]]

soundManager = {}

function soundManager:load()

    sounds = {}
    --music
    sounds.boop = love.audio.newSource("lib/audio/music/boop.ogg", "stream")
    sounds.boop:setLooping(true)

    sounds.dritx = love.audio.newSource("lib/audio/music/dritx.ogg", "stream")
    sounds.dritx:setLooping(true)
   

    --sound effects
    sounds.xplow = {love.audio.newSource("lib/audio/sfx/xplow1.ogg", "static"),
                    love.audio.newSource("lib/audio/sfx/xplow2.mp3", "static"),
                    love.audio.newSource("lib/audio/sfx/xplow3.mp3", "static"),
                    love.audio.newSource("lib/audio/sfx/xplow4.mp3", "static"),
                    love.audio.newSource("lib/audio/sfx/xplow5.mp3", "static"),
                    love.audio.newSource("lib/audio/sfx/xplow6.ogg", "static"),
                    }

    sounds.roidSmash = love.audio.newSource("lib/audio/sfx/roidSmash.ogg", "static")
    sounds.powerUp = love.audio.newSource("lib/audio/sfx/powerup.mp3", "static")
    sounds.point = love.audio.newSource("lib/audio/sfx/point.mp3", "static")
    sounds.nextLevel = love.audio.newSource("lib/audio/sfx/nextlevel.ogg", "static")
    sounds.laser = love.audio.newSource("lib/audio/sfx/laser.mp3", "static")
    sounds.boom = love.audio.newSource("lib/audio/sfx/boom.mp3", "static")
    sounds.bip = love.audio.newSource("lib/audio/sfx/bip.mp3", "static")
    sounds.shoot = love.audio.newSource("lib/audio/sfx/laserShoot.ogg", "static")
    sounds.crash = love.audio.newSource("lib/audio/sfx/crash.ogg", "static")
    sounds.crash2 = love.audio.newSource("lib/audio/sfx/crash2.ogg", "static")
    sounds.crash3 = love.audio.newSource("lib/audio/sfx/crash3.ogg", "static")
    sounds.jets = love.audio.newSource("lib/audio/sfx/jets2.ogg", "static")
    
    --menu--
    sounds.menuError = love.audio.newSource("lib/audio/sfx/menu_error.mp3", "static")

    local CurrentTime = love.timer.getTime()
    jetsCounter  = CurrentTime
    
    
    function setvolume()
        masterVolume = 1
        menueffectVolume = 1
        effectVolume = 1
        musicVolume = 1
        jetVolume = 0.1

        --master--
        
        --menu sounds--
        sounds.menuError:setVolume(masterVolume * menueffectVolume)

        --effects--
        for i = 1,#sounds.xplow do
            sounds.xplow[i]:setVolume(masterVolume * effectVolume)
        end
        sounds.roidSmash:setVolume(masterVolume * effectVolume)
        sounds.powerUp:setVolume(masterVolume * effectVolume)
        sounds.point:setVolume(masterVolume * effectVolume)
        sounds.nextLevel:setVolume(masterVolume * effectVolume)
        sounds.laser:setVolume(masterVolume * effectVolume)
        sounds.bip:setVolume(masterVolume * effectVolume)
        sounds.boom:setVolume(masterVolume * effectVolume)
        sounds.shoot:setVolume(masterVolume * effectVolume)
        sounds.crash:setVolume(masterVolume * effectVolume)
        sounds.crash2:setVolume(masterVolume * effectVolume)
        sounds.crash3:setVolume(masterVolume * effectVolume)
        sounds.jets:setVolume(masterVolume * effectVolume * jetVolume)

        --music--
        sounds.boop:setVolume(masterVolume * musicVolume)
        sounds.dritx:setVolume(masterVolume * musicVolume)
       
    end

    setvolume()

end
function playXplow()
    local n = love.math.random(1,#sounds.xplow)
    local s = sounds.xplow[n]:clone()
    local pitch = love.math.random() * 0.12 + 0.98
    s:setPitch(pitch)
    s:play()
end

function playShoot()
    local s = sounds.shoot:clone()
    local pitch = love.math.random() * 0.12 + 0.98
    s:setPitch(pitch)
    s:play()
end

function playJetsSound()
    local jetsRepeat  = 0.05
    local CurrentTime = love.timer.getTime()
    if CurrentTime > jetsCounter + jetsRepeat then
        local s = sounds.jets:clone()
        local pitch = love.math.random() * 0.12 + 0.98
        s:setPitch(pitch)
        s:play()
        jetsCounter = CurrentTime
    end
end

function playSound(soundName, pitchRng)
    -- Use a string as the default, not the sound object itself
    soundName = soundName or "menuError"  -- Pass the string key
    pitchRng = pitchRng or 1
    local pitch = 1
    if pitchRng < 1 then
        pitch = love.math.random(1 * pitchRng,1) -- this is not right
    end
    
    local sound = sounds[soundName]
    if not sound then
        error("Sound '" .. soundName .. "' not found")
        return
    end
    
    local s = sound:clone()
    s:setPitch(pitch)
    s:play()
end

function soundManager:update (dt)

end

function soundManager:draw()

end