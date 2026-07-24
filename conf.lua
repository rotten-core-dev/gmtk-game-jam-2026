function love.conf(t)
    -- Window settings
    t.window.width = 1024
    t.window.height = 768
    t.window.title = ""
    t.window.icon = nil  -- Path to icon file
    
    -- Window options
    t.window.resizable = true   -- Allow resizing
    t.window.fullscreen = false -- Start in windowed mode
    t.window.borderless = true -- Show window borders
    t.window.highdpi = false    -- Enable high DPI mode
    t.window.vsync = 1          -- Vertical sync (1 = on, 0 = off)
    t.window.msaa = 0           -- Multisample anti-aliasing (0, 2, 4, 8)
    
    -- Other settings
    t.window.minwidth = 400     -- Minimum window width (if resizable)
    t.window.minheight = 300    -- Minimum window height (if resizable)
    
    -- Console
    t.console = false           -- Open console window (for debugging)
    
    -- Version
    t.version = "11.4"          -- LÖVE version (optional)
end