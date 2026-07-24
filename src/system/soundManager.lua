
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
          
    
    --menu--
    sounds.menuError = love.audio.newSource("lib/audio/sfx/menu_error.mp3", "static")

 
    
    function setvolume()
        masterVolume = 1
        menueffectVolume = 1
        effectVolume = 1
        musicVolume = 1

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

function playSound(soundName,pitchRng)
    local soundName = soundName or sounds.menuError
    local pitch = pitchRng * love.math.random() or 1
    local s = soundName:clone()
    s:setPitch(pitch)
    s:play()
end

function soundManager:update (dt)

end

function soundManager:draw()

end