local shakes = {}

shakes.Duration = 0
shakes.Length = 0.1 
shakes.Magnitude = 0

shakes.list = {
        {name = "NONE",
        power = 0},
        {name = "WEAK SAUCE",
        power = 0.01},
        {name = "AVE JOE",
        power = 0.1},
        {name = "JUICEY",
        power = 0.3},
        {name = "OVER 9000",
        power = 1},
    }

shakes.current = shakes.list[3]

function shakes.set(index)
    shakes.current = shakes.list[index]
end

function shakes.get()
    return shakes.current
end

function shakes.getByName(name)
    for _, shake in ipairs(shakes.list) do
        if shake.name == name then
            return shake
        end
    end
end

function shakes.drawShakeScreen(shakeMagnitude, CurrentTime)
    if shakeMagnitude < shakes.current.power then
        shakeMagnitude = shakes.current.power
    end
    if CurrentTime < shakes.Duration then
        local dx = love.math.random(-shakeMagnitude, shakeMagnitude)
        local dy = love.math.random(-shakeMagnitude, shakeMagnitude)
        love.graphics.translate(dx, dy)
    else
        shakes.Duration = 0
    end
end

function shakes.trigger(magnitude,duration,CurrentTime)
    if magnitude > shakes.Magnitude then
        shakes.Magnitude = magnitude
    end
    if CurrentTime + duration > shakes.Duration then
        shakes.Duration = CurrentTime + duration
    end
end

return shakes