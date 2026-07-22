
local themes = {}

themes.list = {
    {
        name       = "HACKER",
        unlocked   = true,
        primary    = { 0, 1, 0, 1 },
        secondary  = { 0, 0.5, 0, 1 },
        background = { 0.05, 0.05, 0.05, 1 },
    },
    {
        name        = "MONOCHROME",
        unlocked    = true,
        primary     = { 0, 0, 0, 1 },
        secondary   = { 0.2, 0.2, 0.2, 1 },
        background  = { 0.6, 0.6, 0.6, 1 }
    },
    {
        name        = "NEON NIGHT",
        unlocked    = true,
        primary     = { 0.8, 0, 0.8, 1 },
        secondary   = { 0, 1, 1, 1 },
        background  = { 0.05, 0.05, 0.05, 1 }
    },
    {
        name        = "SHADES OF BLUE",
        unlocked    = true,
        primary     = { 0, 0, 1, 1 },
        secondary   = { 0, 1, 1, 1 },
        background  = { 0.8, 0.8, 1, 1 }
    },
    {
        name        = "SPORTS BALL",
        unlocked    = true,
        primary     = { 1, 1, 1, 1 },
        secondary   = { 0.2, 0.2, 1, 0.8 },
        background  = { 0.1, 0.1, 0.1, 1 },
    },
    {
        name        = "THWUMP",
        unlocked    = true,
        primary     = { 1, 1, 1, 1 },
        secondary   = { 1, 0, 0, 1 },
        background  = { 0.05, 0.05, 0.05, 1 }
    },
    {
        name        = "TRON",
        unlocked    = true,
        primary     = { 0.49, 0.99, 0.99, 1},
        secondary   = { 0.95, 0.69, 0.18, 1},
        background  = { 0.05, 0.05, 0.05, 1 }
    },
    {
        name        = "YRB",
        unlocked    = true,
        primary     = { 1, 1, 0, 1},
        secondary   = { 1, 0, 0, 1 },
        background  = { 0.05, 0.05, 0.05, 1 }
    },

}
themes.current = themes.list[7]

function themes.set(index)
    themes.current = themes.list[index]
end

function themes.get()
    return themes.current
end

function themes.getByName(name)
    for _, theme in ipairs(themes.list) do
        if theme.name == name then
            return theme
        end
    end
end

return themes
