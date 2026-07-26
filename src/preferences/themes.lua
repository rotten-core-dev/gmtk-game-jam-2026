
local themes = {}

themes.list = {
    {
        name       = "HACKER",
        unlocked   = true,
        primary    = { 0, 1, 0, 1 },
        secondary  = { 0, 0.5, 0, 1 },
        background = { 0.05, 0.05, 0.05, 1 },
        primary_name = "LIGHT GREEN",
        secondary_name = "DARK GREEN",
    },
    {
        name        = "MONOCHROME",
        unlocked    = true,
        primary     = { 0, 0, 0, 1 },
        secondary   = { 0.2, 0.2, 0.2, 1 },
        background  = { 0.6, 0.6, 0.6, 1 },
        primary_name = "BLACK",
        secondary_name = "GREY",
    },
    {
        name        = "NEON NIGHT",
        unlocked    = true,
        primary     = { 0.8, 0, 0.8, 1 },
        secondary   = { 0, 1, 1, 1 },
        background  = { 0.05, 0.05, 0.05, 1 },
        primary_name = "PURPLE",
        secondary_name = "BLUE",
    },
    {
        name        = "PASTELS",
        unlocked    = true,
        primary     = { 1.0, 0.750, 0.850, 1 },
        secondary   = { 0.650, 0.500, 0.950, 1 },
        background  = { 0.05, 0.05, 0.05, 1 },
        primary_name = "PINK",
        secondary_name = "PURPLE",
    },
    {
        name        = "SHADES OF BLUE",
        unlocked    = true,
        primary     = { 0, 0, 1, 1 },
        secondary   = { 0, 1, 1, 1 },
        background  = { 0.8, 0.8, 1, 1 },
        primary_name = "DARK BLUE",
        secondary_name = "LIGHT BLUE",
    },
    {
        name        = "SPORTS BALL",
        unlocked    = true,
        primary     = { 1, 1, 1, 1 },
        secondary   = { 0.2, 0.2, 1, 0.8 },
        background  = { 0.1, 0.1, 0.1, 1 },
        primary_name = "WHITE",
        secondary_name = "BLUE",
    },
    {
        name        = "THWUMP",
        unlocked    = true,
        primary     = { 1, 1, 1, 1 },
        secondary   = { 1, 0, 0, 1 },
        background  = { 0.05, 0.05, 0.05, 1 },
        primary_name = "WHITE",
        secondary_name = "RED",
    },
    {
        name        = "TRON",
        unlocked    = true,
        primary     = { 0.49, 0.99, 0.99, 1},
        secondary   = { 0.95, 0.69, 0.18, 1},
        background  = { 0.05, 0.05, 0.05, 1 },
        primary_name = "BLUE",
        secondary_name = "ORANGE",
    },
    {
        name        = "YRB",
        unlocked    = true,
        primary     = { 1, 1, 0, 1},
        secondary   = { 1, 0, 0, 1 },
        background  = { 0.05, 0.05, 0.05, 1 },
        primary_name = "YELLOW",
        secondary_name = "RED",
    },

}
themes.current = themes.list[8]

function themes.set(index)
    themes.current = themes.list[index]
end

function themes.get()
    return themes.current
end

function themes.setByName(themeName)
    for _, theme in ipairs(themes.list) do
        if theme.name == themeName then
            themes.current = theme
            return theme
        end
    end

    return nil
end

themes.setThemeByName = themes.setByName

function themes.getByName(name)
    for _, theme in ipairs(themes.list) do
        if theme.name == name then
            return theme
        end
    end
end

return themes
