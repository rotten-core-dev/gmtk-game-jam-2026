--sounds

local sounds = {}
--music
sounds.beat = love.audio.newSource("lib/sounds/beat_v3.ogg", "stream")
sounds.beat:setLooping(true)


--sound effects
sounds.crash = love.audio.newSource("lib/sounds/crash.ogg", "static")
sounds.get_points = love.audio.newSource("lib/sounds/get_points.ogg", "static")
sounds.hit_foe = love.audio.newSource("lib/sounds/hitfoe.ogg", "static")
sounds.extralife = love.audio.newSource("lib/sounds/extalife.ogg", "static")
    --need replacing--
    
    sounds.glove_hit_wall = love.audio.newSource("lib/sounds/glove_hitwall.ogg", "static")
    sounds.thwump = love.audio.newSource("lib/sounds/glove_trig.ogg", "static")
        

--menu--
sounds.menu_switching = love.audio.newSource("lib/sounds/blip.ogg", "static")
sounds.menu_sel = love.audio.newSource("lib/sounds/menusel.ogg", "static")

return sounds