--sounds

local sounds = {}
--music
sounds.boop = love.audio.newSource("lib/audio/music/boop.ogg", "stream")
sounds.boop:setLooping(true)

sounds.dritx = love.audio.newSource("lib/audio/music/dritx.ogg", "stream")
sounds.dritx:setLooping(true)

sounds.jb = love.audio.newSource("lib/audio/music/jb.ogg", "stream")
sounds.jb:setLooping(true)

sounds.jbmenu = love.audio.newSource("lib/audio/music/jbmenu.ogg", "stream")
sounds.jbmenu:setLooping(true)



--sound effects
sounds.crash = love.audio.newSource("lib/sounds/crash.ogg", "static")
sounds.get_points = love.audio.newSource("lib/audio/sfx/point.mp3", "static")
sounds.get_points:setVolume(0.5)
sounds.hit_foe = love.audio.newSource("lib/sounds/hitfoe.ogg", "static")
sounds.extralife = love.audio.newSource("lib/sounds/extalife.ogg", "static")
    --need replacing--
    
    sounds.glove_hit_wall = love.audio.newSource("lib/sounds/glove_hitwall.ogg", "static")
    sounds.thwump = love.audio.newSource("lib/sounds/glove_trig.ogg", "static")
        

--menu--
sounds.menu_switching = love.audio.newSource("lib/sounds/blip.ogg", "static")
sounds.menu_sel = love.audio.newSource("lib/sounds/menusel.ogg", "static")

return sounds