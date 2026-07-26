local themes = require "src.preferences.themes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local gameplay_battle = {}

local PLAYER_OWNER = "player"
local ENEMY_OWNER = "enemy"
local ROUND_WIN_TARGET = 2
local ORBIT_ASTEROIDS_PER_SHIP = 3
local ORBIT_RADIUS = 72
local ORBIT_SPEED = 1.45
local PLAYER_FIRE_COOLDOWN = 0.75
local AI_FIRE_COOLDOWN = 0.75
local AI_STRAFE_SPEED = 1.4
local AI_BULLET_AVOID_RADIUS = 170
local PRE_ROUND_COUNTDOWN_SECONDS = 3

local function length(x, y)
	return math.sqrt(x * x + y * y)
end

local function angleTo(dx, dy)
	if dx == 0 then
		if dy > 0 then
			return math.pi * 0.5
		elseif dy < 0 then
			return -math.pi * 0.5
		end
		return 0
	end

	local a = math.atan(dy / dx)
	if dx < 0 then
		a = a + math.pi
	elseif dy < 0 then
		a = a + math.pi * 2
	end
	return a
end

local function isOutsideCircle(x, y, centerX, centerY, radius)
	local dx = x - centerX
	local dy = y - centerY
	return dx * dx + dy * dy > radius * radius
end

local function bounceInsideCircle(body, centerX, centerY, radius, bounce)
	local dx = body.x - centerX
	local dy = body.y - centerY
	local dist = length(dx, dy)
	local effectiveRadius = radius - body.radius
	if effectiveRadius <= 0 or dist <= effectiveRadius then
		return false
	end

	if dist == 0 then
		dx, dy, dist = 1, 0, 1
	end

	local scale = effectiveRadius / dist
	body.x = centerX + dx * scale
	body.y = centerY + dy * scale

	local nx = body.x - centerX
	local ny = body.y - centerY
	local normalLength = length(nx, ny)
	if normalLength == 0 then
		return false
	end
	nx = nx / normalLength
	ny = ny / normalLength

	local dot = body.vx * nx + body.vy * ny
	if dot > 0 then
		body.vx = body.vx - (1 + bounce) * dot * nx
		body.vy = body.vy - (1 + bounce) * dot * ny
	end

	return true
end

local function resolveBodyCollision(a, b, bounce)
	local dx = b.x - a.x
	local dy = b.y - a.y
	local dist = length(dx, dy)
	if dist == 0 then
		dx, dy, dist = 1, 0, 1
	end

	local nx = dx / dist
	local ny = dy / dist
	local minDist = a.radius + b.radius
	if dist < minDist then
		local overlap = minDist - dist
		a.x = a.x - nx * overlap * 0.5
		a.y = a.y - ny * overlap * 0.5
		b.x = b.x + nx * overlap * 0.5
		b.y = b.y + ny * overlap * 0.5
	end

	local rvx = b.vx - a.vx
	local rvy = b.vy - a.vy
	local closingSpeed = rvx * nx + rvy * ny
	if closingSpeed < 0 then
		local impulse = -(1 + bounce) * closingSpeed * 0.5
		a.vx = a.vx - impulse * nx
		a.vy = a.vy - impulse * ny
		b.vx = b.vx + impulse * nx
		b.vy = b.vy + impulse * ny
	end
end

local function getAsteroidRadius(size)
	if size == "large" then
		return 30
	elseif size == "medium" then
		return 18
	end
	return 10
end

local function getAsteroidSpeed(size)
	if size == "large" then
		return 70
	elseif size == "medium" then
		return 95
	end
	return 125
end

local function getNextAsteroidSize(size)
	if size == "large" then
		return "medium"
	elseif size == "medium" then
		return "small"
	end
	return nil
end

function gameplay_battle:getArena()
	local shrinkAmount = 0.98
	local worldW, worldH = love.graphics.getWidth(), love.graphics.getHeight()
	local completedOrbits = self:getArenaCompletedOrbits()
	local shrinkScale = math.max(0.35, shrinkAmount ^ completedOrbits)
	local arenaLineWidth = 4
	return worldW * 0.5, worldH * 0.5, (worldH * 0.45 - arenaLineWidth) * shrinkScale
end

function gameplay_battle:getOrbitState()
	local orbitPeriod = 3
	local elapsed = love.timer.getTime() - (self.orbitStartTime or love.timer.getTime())
	local completedOrbits = math.floor(elapsed / orbitPeriod)
	local orbitProgress = (elapsed % orbitPeriod) / orbitPeriod
	local orbitAngle = -math.pi * 0.5 + orbitProgress * math.pi * 2
	return completedOrbits, orbitAngle
end

function gameplay_battle:getArenaCompletedOrbits()
	if self.freezeRoundOrbitCount ~= nil then
		return self.freezeRoundOrbitCount
	end
	local completedOrbits = self:getOrbitState()
	return completedOrbits
end

function gameplay_battle:getArenaPolarity()
	local completedOrbits = self:getArenaCompletedOrbits()
	if completedOrbits % 2 == 0 then
		return "secondary"
	end
	return "primary"
end

function gameplay_battle:getArenaColor()
	if self:getArenaPolarity() == "secondary" then
		return themes.current.secondary
	end
	return themes.current.primary
end


function gameplay_battle:getColorForOwner(owner)
	if owner == ENEMY_OWNER then
		return themes.current.secondary
	end
	return themes.current.primary
end

function gameplay_battle:getColorForEnemy(owner)
	if owner == ENEMY_OWNER then
		return themes.current.primary
	end
	return themes.current.secondary
end

function gameplay_battle:getShipByOwner(owner)
	if owner == ENEMY_OWNER then
		return self.enemyShip
	end
	return self.ship
end

function gameplay_battle:getEnemyOwner(owner)
	if owner == ENEMY_OWNER then
		return PLAYER_OWNER
	end
	return ENEMY_OWNER
end

function gameplay_battle:getOrbitAsteroidCount(owner)
	local count = 0
	for _, asteroid in ipairs(self.asteroids) do
		if asteroid.owner == owner and asteroid.inOrbit then
			count = count + 1
		end
	end
	return count
end

function gameplay_battle:getCombatTargetForOwner(owner)
	local enemyOwner = self:getEnemyOwner(owner)
	local sourceShip = self:getShipByOwner(owner)
	local bestTarget = self:getShipByOwner(enemyOwner)
	local bestDist = math.huge

	for _, asteroid in ipairs(self.asteroids) do
		if asteroid.owner == enemyOwner and asteroid.inOrbit then
			local dist = length(asteroid.x - sourceShip.x, asteroid.y - sourceShip.y)
			if dist < bestDist then
				bestDist = dist
				bestTarget = asteroid
			end
		end
	end

	return bestTarget
end

function gameplay_battle:updateOrbitLayout(owner)
	local orbiting = {}
	for _, asteroid in ipairs(self.asteroids) do
		if asteroid.owner == owner and asteroid.inOrbit then
			table.insert(orbiting, asteroid)
		end
	end

	local count = #orbiting
	for index, asteroid in ipairs(orbiting) do
		asteroid.orbitPhase = ((index - 1) / math.max(1, count)) * math.pi * 2
	end
end

function gameplay_battle:spawnFloatingAsteroid(owner, x, y, size, dirX, dirY)
	local dist = length(dirX or 0, dirY or 0)
	local angle = love.math.random() * math.pi * 2
	local nx = dist > 0.001 and (dirX / dist) or math.cos(angle)
	local ny = dist > 0.001 and (dirY / dist) or math.sin(angle)
	local speed = getAsteroidSpeed(size)

	table.insert(self.asteroids, {
		x = x,
		y = y,
		vx = nx * speed,
		vy = ny * speed,
		size = size,
		radius = getAsteroidRadius(size),
		owner = owner,
		inOrbit = false,
	})
end

function gameplay_battle:spawnFloatingSplit(owner, x, y, size, normalX, normalY)
	local nextSize = getNextAsteroidSize(size)
	if not nextSize then
		return
	end

	local nx = normalX or 1
	local ny = normalY or 0
	local tx = -ny
	local ty = nx
	self:spawnFloatingAsteroid(owner, x, y, nextSize, nx + tx * 0.4, ny + ty * 0.4)
	self:spawnFloatingAsteroid(owner, x, y, nextSize, nx - tx * 0.4, ny - ty * 0.4)
end

function gameplay_battle:removeAsteroid(asteroid)
	for index = #self.asteroids, 1, -1 do
		if self.asteroids[index] == asteroid then
			table.remove(self.asteroids, index)
			return
		end
	end
end

function gameplay_battle:damageOrbitAsteroid(asteroid, normalX, normalY)
	local nextSize = getNextAsteroidSize(asteroid.size)
	local owner = asteroid.owner

	if not nextSize then
		self:removeAsteroid(asteroid)
		self:updateOrbitLayout(owner)
		return
	end

	asteroid.size = nextSize
	asteroid.radius = getAsteroidRadius(nextSize)
	self:spawnFloatingAsteroid(owner, asteroid.x, asteroid.y, nextSize, normalX, normalY)
	self:updateOrbitLayout(owner)
end

function gameplay_battle:damageFloatingAsteroid(asteroid, normalX, normalY)
	self:spawnParticles(asteroid.x,asteroid.y)
	if asteroid.size == "small" then
		self:removeAsteroid(asteroid)
		return
	end

	local owner = asteroid.owner
	local x = asteroid.x
	local y = asteroid.y
	local size = asteroid.size
	self:removeAsteroid(asteroid)
	self:spawnFloatingSplit(owner, x, y, size, normalX, normalY)
end

function gameplay_battle:createShip(owner, x, y)
	return {
		owner = owner,
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		angle = owner == ENEMY_OWNER and math.pi or 0,
		radius = 20,
		alive = true,
	}
end

function gameplay_battle:spawnOrbitAsteroids(owner)
	local ship = self:getShipByOwner(owner)
	for index = 1, ORBIT_ASTEROIDS_PER_SHIP do
		table.insert(self.asteroids, {
			x = ship.x,
			y = ship.y,
			vx = 0,
			vy = 0,
			size = "large",
			radius = getAsteroidRadius("large"),
			owner = owner,
			inOrbit = true,
			orbitPhase = ((index - 1) / ORBIT_ASTEROIDS_PER_SHIP) * math.pi * 2,
		})
	end
	self:updateOrbitLayout(owner)
end

function gameplay_battle:startRound()
	local centerX, centerY, arenaRadius = self:getArena()
	self.ship = self:createShip(PLAYER_OWNER, centerX - arenaRadius * 0.45, centerY)
	self.enemyShip = self:createShip(ENEMY_OWNER, centerX + arenaRadius * 0.45, centerY)
	self.asteroids = {}
	self.bullets = {}
	self.shipHitEffects = {}
	self.playerFireCooldown = 0
	self.enemyFireCooldown = AI_FIRE_COOLDOWN * 0.5
	self.shipWallAccelLockTimer = 0
	self.enemyWallAccelLockTimer = 0
	self.orbitClock = 0
	self.roundResolved = false
	self.waitingForNextRound = false
	self.freezeRoundOrbitCount = nil
	self.roundMessage = ""
	self.orbitStartTime = love.timer.getTime()
	self:spawnOrbitAsteroids(PLAYER_OWNER)
	self:spawnOrbitAsteroids(ENEMY_OWNER)
end

function gameplay_battle:resetRun()
	self.score = 0
	self.displayedScore = 0
	self.round = 1
	self.playerRoundsWon = 0
	self.enemyRoundsWon = 0
	self.isGameOver = false
	self.restartWasDown = false
	self.escapeWasDown = false
	self.continueWasDown = false
	self.waitingForInitialStart = true
	self.initialStartWasDown = love.keyboard.isDown("space")
	self.preRoundCountdownActive = false
	self.preRoundCountdownTimer = 0
	self.freezeRoundOrbitCount = nil
	self.scoreCountSoundPlaying = false
	sounds.get_points:setLooping(true)
	sounds.get_points:stop()
	self:startRound()
end

function gameplay_battle:enter()
	self:resetRun()
end

function gameplay_battle:updateDisplayedScore(dt)
	local displayed = self.displayedScore or 0
	local remaining = self.score - displayed
	if remaining == 0 then
		self.displayedScore = self.score
		return
	end

	local gain = 220 + math.abs(remaining) * 6
	local step = math.max(1, math.floor(gain * dt))
	if remaining > 0 then
		self.displayedScore = math.min(self.score, displayed + step)
	else
		self.displayedScore = math.max(self.score, displayed - step)
	end
end

function gameplay_battle:spawnShipHitEffect(x, y)
	local effect = {
		x = x,
		y = y,
		ttl = 0.42,
		duration = 0.42,
		ringRadius = 10,
		ringGrowth = 220,
		particles = {},
	}

	for _ = 1, 18 do
		local angle = love.math.random() * math.pi * 2
		local speed = love.math.random(120, 260)
		table.insert(effect.particles, {
			x = x,
			y = y,
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			ttl = 0.18 + love.math.random() * 0.24,
			radius = love.math.random(1, 3),
		})
	end

	table.insert(self.shipHitEffects, effect)
end

function gameplay_battle:updateShipHitEffects(dt)
	for i = #self.shipHitEffects, 1, -1 do
		local effect = self.shipHitEffects[i]
		effect.ttl = effect.ttl - dt
		effect.ringRadius = effect.ringRadius + effect.ringGrowth * dt

		for pi = #effect.particles, 1, -1 do
			local particle = effect.particles[pi]
			particle.ttl = particle.ttl - dt
			particle.x = particle.x + particle.vx * dt
			particle.y = particle.y + particle.vy * dt
			particle.vx = particle.vx * 0.94
			particle.vy = particle.vy * 0.94
			if particle.ttl <= 0 then
				table.remove(effect.particles, pi)
			end
		end

		if effect.ttl <= 0 and #effect.particles == 0 then
			table.remove(self.shipHitEffects, i)
		end
	end
end

function gameplay_battle:shoot(owner)
	local ship = self:getShipByOwner(owner)
	if not ship or not ship.alive then
		return
	end

	local bulletSpeed = 420
	table.insert(self.bullets, {
		x = ship.x + math.cos(ship.angle) * (ship.radius + 4),
		y = ship.y + math.sin(ship.angle) * (ship.radius + 4),
		vx = ship.vx + math.cos(ship.angle) * bulletSpeed,
		vy = ship.vy + math.sin(ship.angle) * bulletSpeed,
		ttl = 2.0,
		radius = 10,
		owner = owner,
	})
	if playShoot then
		playShoot()
	end
end


function gameplay_battle:spawnParticles(x, y, time, quant)
    local x = x or WINDOW_WIDTH/2
    local y = y or WINDOW_HEIGHT/2
    local quant = quant or 10
	local speed = 12
	local time = time or 10 --0.5
	local t = time + love.math.random(-0.1,0.1)
    for i = 1, quant do
        local velX = love.math.random(-speed, speed)
        local velY = love.math.random(-speed, speed)
        table.insert(particles, {
            x = x,
            y = y,
            velX = velX,  
            velY = velY, 
            time = time,  
        })
    end
end

function gameplay_battle:spawnShipParticles(x, y, velX,velY)
    local x = x or WINDOW_WIDTH/2
    local y = y or WINDOW_HEIGHT/2
    local quant = 3
	local rng = 3
	local velX = velX * 10
	local velY = velY * 10
    for i = 1, quant do
        vX = velX + love.math.random(-rng, rng)
        vY = velY + love.math.random(-rng, rng)
        table.insert(particles, {
            x = x,
            y = y,
            velX = vX,  
            velY = vY, 
            time = 0.07,  
        })
    end
end

function gameplay_battle:updateParticals(dt)
    if #particles < 1 then return end

    for i = #particles, 1, -1 do
        local cp = particles[i]
		local rng = love.math.random(0.97, 0.99)
        if cp.time > 0 then
            cp.time = cp.time - dt
            cp.x = cp.x + cp.velX
            cp.y = cp.y + cp.velY

			cp.velX = cp.velX * rng
			cp.velY = cp.velY * rng
        else
            table.remove(particles, i)
        end
    end
end

function gameplay_battle:drawParticals()
	love.graphics.setLineWidth(20)
	if #particles < 1 then return end

	for i = 1,#particles do
		local cp = particles[i]
		love.graphics.line(cp.x,cp.y,cp.x +cp.velX,cp.y +cp.velY)
	end
end

function gameplay_battle:updatePlayerShip(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	local ship = self.ship
	self.shipWallAccelLockTimer = math.max(0, (self.shipWallAccelLockTimer or 0) - dt)

	local inputX, inputY = 0, 0
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		inputX = inputX - 1
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		inputX = inputX + 1
	end
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
		inputY = inputY - 1
	end
	if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
		inputY = inputY + 1
	end

	if inputX ~= 0 or inputY ~= 0 then
		local mag = length(inputX, inputY)
		inputX = inputX / mag
		inputY = inputY / mag
		self:spawnShipParticles(ship.x, ship.y, -inputX,-inputY)
		playJetsSound()
	end

	if self.shipWallAccelLockTimer <= 0 then
		local accel = 500
		ship.vx = ship.vx + inputX * accel * dt
		ship.vy = ship.vy + inputY * accel * dt
	end

	ship.vx = ship.vx * 0.995
	ship.vy = ship.vy * 0.995

	local speed = length(ship.vx, ship.vy)
	if speed > 220 then
		local scale = 220 / speed
		ship.vx = ship.vx * scale
		ship.vy = ship.vy * scale
	end

	ship.x = ship.x + ship.vx * dt
	ship.y = ship.y + ship.vy * dt
	if bounceInsideCircle(ship, centerX, centerY, arenaRadius, 1.12) then
		self.shipWallAccelLockTimer = 0.18
	end

	local mouseX, mouseY = love.mouse.getPosition()
	if mouseX and mouseY then
		local dx = mouseX - ship.x
		local dy = mouseY - ship.y
		if dx ~= 0 or dy ~= 0 then
			ship.angle = angleTo(dx, dy)
		end
	end
end

function gameplay_battle:updateEnemyShip(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	local ship = self.enemyShip
	self.enemyWallAccelLockTimer = math.max(0, (self.enemyWallAccelLockTimer or 0) - dt)

	local target = self:getCombatTargetForOwner(ENEMY_OWNER)
	ship.angle = angleTo(target.x - ship.x, target.y - ship.y)

	local playerOrbitCount = self:getOrbitAsteroidCount(PLAYER_OWNER)
	local enemyOrbitCount = self:getOrbitAsteroidCount(ENEMY_OWNER)
	local lateralBias = enemyOrbitCount > playerOrbitCount and 0.52 or 0.34
	local desiredX = centerX + arenaRadius * lateralBias
	local desiredY = target.y + math.sin(self.orbitClock * AI_STRAFE_SPEED) * arenaRadius * 0.18
	local inputX = 0
	local inputY = 0

	local dx = desiredX - ship.x
	local dy = desiredY - ship.y
	local dist = length(dx, dy)
	if dist > 8 then
		inputX = inputX + dx / dist
		inputY = inputY + dy / dist
	end

	local targetDx = target.x - ship.x
	local targetDy = target.y - ship.y
	local targetDist = length(targetDx, targetDy)
	if targetDist > 0.001 then
		local orbitPressure = playerOrbitCount == 0 and 0.55 or 0.3
		inputX = inputX + (targetDx / targetDist) * orbitPressure
		inputY = inputY + (targetDy / targetDist) * orbitPressure
	end

	for _, bullet in ipairs(self.bullets) do
		if bullet.owner == PLAYER_OWNER then
			local avoidDx = ship.x - bullet.x
			local avoidDy = ship.y - bullet.y
			local bulletDist = length(avoidDx, avoidDy)
			if bulletDist > 0.001 and bulletDist < AI_BULLET_AVOID_RADIUS then
				local threat = 1 - (bulletDist / AI_BULLET_AVOID_RADIUS)
				inputX = inputX + (avoidDx / bulletDist) * threat * 2.2
				inputY = inputY + (avoidDy / bulletDist) * threat * 2.2
			end
		end
	end

	local inputMag = length(inputX, inputY)
	if inputMag > 0.001 then
		inputX = inputX / inputMag
		inputY = inputY / inputMag
		self:spawnShipParticles(ship.x, ship.y, -inputX,-inputY)
		playJetsSound()
	else
		inputX = 0
		inputY = 0
	end

	if self.enemyWallAccelLockTimer <= 0 then
		local accel = 360
		ship.vx = ship.vx + inputX * accel * dt
		ship.vy = ship.vy + inputY * accel * dt
	end

	ship.vx = ship.vx * 0.992
	ship.vy = ship.vy * 0.992

	local speed = length(ship.vx, ship.vy)
	if speed > 180 then
		local scale = 180 / speed
		ship.vx = ship.vx * scale
		ship.vy = ship.vy * scale
	end

	ship.x = ship.x + ship.vx * dt
	ship.y = ship.y + ship.vy * dt
	if bounceInsideCircle(ship, centerX, centerY, arenaRadius, 1.08) then
		self.enemyWallAccelLockTimer = 0.18
	end

	self.enemyFireCooldown = math.max(0, (self.enemyFireCooldown or 0) - dt)
	if self.enemyFireCooldown == 0 then
		self:shoot(ENEMY_OWNER)
		self.enemyFireCooldown = AI_FIRE_COOLDOWN
	end
end

function gameplay_battle:updateOrbitingAsteroids(dt)
	self.orbitClock = (self.orbitClock or 0) + dt
	for _, asteroid in ipairs(self.asteroids) do
		if asteroid.inOrbit then
			local ship = self:getShipByOwner(asteroid.owner)
			local direction = asteroid.owner == ENEMY_OWNER and -1 or 1
			local angle = self.orbitClock * ORBIT_SPEED * direction + (asteroid.orbitPhase or 0)
			local orbitRadius = ORBIT_RADIUS + asteroid.radius * 0.25
			asteroid.x = ship.x + math.cos(angle) * orbitRadius
			asteroid.y = ship.y + math.sin(angle) * orbitRadius
			asteroid.vx = -math.sin(angle) * orbitRadius * ORBIT_SPEED * direction
			asteroid.vy = math.cos(angle) * orbitRadius * ORBIT_SPEED * direction
		end
	end
end

function gameplay_battle:updateBullets(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	for index = #self.bullets, 1, -1 do
		local bullet = self.bullets[index]
		bullet.x = bullet.x + bullet.vx * dt
		bullet.y = bullet.y + bullet.vy * dt
		bullet.ttl = bullet.ttl - dt

		if bullet.ttl <= 0 then
			table.remove(self.bullets, index)
		elseif isOutsideCircle(bullet.x, bullet.y, centerX, centerY, arenaRadius - bullet.radius) then
			bounceInsideCircle(bullet, centerX, centerY, arenaRadius, 0.98)
		end
	end
end

function gameplay_battle:updateFloatingAsteroids(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	for _, asteroid in ipairs(self.asteroids) do
		if not asteroid.inOrbit then
			asteroid.x = asteroid.x + asteroid.vx * dt
			asteroid.y = asteroid.y + asteroid.vy * dt
			bounceInsideCircle(asteroid, centerX, centerY, arenaRadius, 0.96)
		end
	end
end

function gameplay_battle:destroyShip(owner)
	playSound("crash")
	playSound("crash2")
	playSound("crash3")
	self:spawnParticles(owner.x, owner.y,50,100)
	if self.roundResolved then
		return
	end

	local ship = self:getShipByOwner(owner)
	ship.alive = false
	self:spawnShipHitEffect(ship.x, ship.y)
	sounds.crash:stop()
	sounds.crash:play()
	self.bullets = {}
	self.roundResolved = true

	local winner = self:getEnemyOwner(owner)
	if winner == PLAYER_OWNER then
		self.playerRoundsWon = self.playerRoundsWon + 1
		self.score = self.score + 250
		if self.playerRoundsWon >= ROUND_WIN_TARGET then
			self.roundMessage = "YOU WIN"
			self.isGameOver = true
			return
		end
		self.roundMessage = "ROUND " .. tostring(self.round) .. " WON"
	else
		self.enemyRoundsWon = self.enemyRoundsWon + 1
		if self.enemyRoundsWon >= ROUND_WIN_TARGET then
			self.roundMessage = "AI WINS"
			self.isGameOver = true
			return
		end
		self.roundMessage = "ROUND " .. tostring(self.round) .. " LOST"
	end

	self.waitingForNextRound = true
	self.continueWasDown = false
	local completedOrbits = self:getOrbitState()
	self.freezeRoundOrbitCount = completedOrbits
	self.round = self.round + 1
end

function gameplay_battle:handleBulletCollisions()
	for bi = #self.bullets, 1, -1 do
		local bullet = self.bullets[bi]
		if not bullet then
			return
		end
		local bulletRemoved = false

		for _, asteroid in ipairs(self.asteroids) do
			if asteroid.inOrbit and asteroid.owner ~= bullet.owner then
				local dist = length(bullet.x - asteroid.x, bullet.y - asteroid.y)
				if dist <= bullet.radius + asteroid.radius then
					local nx = asteroid.x - bullet.x
					local ny = asteroid.y - bullet.y
					local normalLength = length(nx, ny)
					if normalLength == 0 then
						nx, ny, normalLength = 1, 0, 1
					end
					self:damageOrbitAsteroid(asteroid, nx / normalLength, ny / normalLength)
					table.remove(self.bullets, bi)
					sounds.hit_foe:play()
					bulletRemoved = true
					self:spawnParticles(asteroid.x,asteroid.y)
					break
				end
			end
		end

		if not bulletRemoved then
			local targetShip = self:getShipByOwner(self:getEnemyOwner(bullet.owner))
			if targetShip.alive then
				local dist = length(bullet.x - targetShip.x, bullet.y - targetShip.y)
				if dist <= bullet.radius + targetShip.radius then
					table.remove(self.bullets, bi)
					bulletRemoved = true
					if self:getOrbitAsteroidCount(targetShip.owner) == 0 then
						self:destroyShip(targetShip.owner)
						return
					end
				end
			end
		end

		::continue::
	end
end

function gameplay_battle:handleFloatingAsteroidInteractions()
	for i = #self.asteroids, 1, -1 do
		local floating = self.asteroids[i]
		if floating and not floating.inOrbit then
			local handled = false

			for _, orbiting in ipairs(self.asteroids) do
				if orbiting.inOrbit and orbiting.owner ~= floating.owner then
					local dx = orbiting.x - floating.x
					local dy = orbiting.y - floating.y
					local dist = length(dx, dy)
					if dist <= orbiting.radius + floating.radius then
						local normalLength = dist > 0.001 and dist or 1
						local nx = dx / normalLength
						local ny = dy / normalLength
						self:damageOrbitAsteroid(orbiting, nx, ny)
						self:damageFloatingAsteroid(floating, -nx, -ny)
						sounds.hit_foe:play()
						-- self:spawnParticles(asteroid.x,asteroid.y)
						handled = true
						break
					end
				end
			end

			if not handled then
				for _, ship in ipairs({ self.ship, self.enemyShip }) do
					if ship.alive and ship.owner ~= floating.owner then
						local dist = length(ship.x - floating.x, ship.y - floating.y)
						if dist <= ship.radius + floating.radius then
							if self:getOrbitAsteroidCount(ship.owner) == 0 then
								self:removeAsteroid(floating)
								self:destroyShip(ship.owner)
							else
								resolveBodyCollision(ship, floating, 0.8)
							end
							break
						end
					end
				end
			end
		end
	end
end

function gameplay_battle:handleShipAsteroidCollisions()
	for _, ship in ipairs({ self.ship, self.enemyShip }) do
		if ship.alive then
			for _, asteroid in ipairs(self.asteroids) do
				local dist = length(ship.x - asteroid.x, ship.y - asteroid.y)
				if dist <= ship.radius + asteroid.radius then
					if asteroid.inOrbit and asteroid.owner == ship.owner then
						resolveBodyCollision(ship, asteroid, 0.65)
					elseif not asteroid.inOrbit then
						if asteroid.owner ~= ship.owner and self:getOrbitAsteroidCount(ship.owner) == 0 then
							self:removeAsteroid(asteroid)
							self:destroyShip(ship.owner)
							return
						else
							resolveBodyCollision(ship, asteroid, 0.8)
						end
					end
				end
			end
		end
	end
end

function gameplay_battle:update(dt)
	local escapeDown = love.keyboard.isDown("escape")
	self:updateParticals(dt)
	if escapeDown and not self.escapeWasDown then
		sounds.get_points:stop()
		local MenuState = require "src.states.menu"
		state.switch(MenuState)
		return
	end
	self.escapeWasDown = escapeDown
	self:updateDisplayedScore(dt)
	self:updateShipHitEffects(dt)

	if self.waitingForInitialStart then
		local startDown = love.keyboard.isDown("space")
		if startDown and not self.initialStartWasDown then
			self.waitingForInitialStart = false
			self.preRoundCountdownActive = true
			self.preRoundCountdownTimer = PRE_ROUND_COUNTDOWN_SECONDS
			self.orbitStartTime = nil
		end
		self.initialStartWasDown = startDown
		return
	end

	if self.preRoundCountdownActive then
		self.preRoundCountdownTimer = math.max(0, (self.preRoundCountdownTimer or 0) - dt)
		if self.preRoundCountdownTimer <= 0 then
			self.preRoundCountdownActive = false
			self.orbitStartTime = love.timer.getTime()
		end
		return
	end

	if self.isGameOver then
		local restartDown = love.keyboard.isDown("r")
		if restartDown and not self.restartWasDown then
			self:resetRun()
		end
		self.restartWasDown = restartDown
		return
	end

	if self.waitingForNextRound then
		local continueDown = love.keyboard.isDown("space")
		if continueDown and not self.continueWasDown then
			self:startRound()
		end
		self.continueWasDown = continueDown
		return
	end
	self.continueWasDown = false

	self.playerFireCooldown = math.max(0, (self.playerFireCooldown or 0) - dt)
	self:updatePlayerShip(dt)
	self:updateEnemyShip(dt)

	local mouseDown = love.mouse.isDown(1)
	if mouseDown and self.playerFireCooldown == 0 then
		self:shoot(PLAYER_OWNER)
		self.playerFireCooldown = PLAYER_FIRE_COOLDOWN
	end

	self:updateOrbitingAsteroids(dt)
	self:updateBullets(dt)
	self:updateFloatingAsteroids(dt)
	self:handleBulletCollisions()
	self:handleFloatingAsteroidInteractions()
	self:handleShipAsteroidCollisions()
end

function gameplay_battle:drawShipHitEffects()
	for _, effect in ipairs(self.shipHitEffects) do
		local t = math.max(0, effect.ttl / effect.duration)
		local ringAlpha = 0.75 * t
		love.graphics.setColor(themes.current.secondary[1], themes.current.secondary[2], themes.current.secondary[3], ringAlpha)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", effect.x, effect.y, effect.ringRadius)

		for _, particle in ipairs(effect.particles) do
			local p = math.max(0, particle.ttl / 0.42)
			local alpha = 0.9 * p
			love.graphics.setColor(themes.current.primary[1], themes.current.primary[2], themes.current.primary[3], alpha)
			love.graphics.circle("fill", particle.x, particle.y, particle.radius)
		end
	end
end

function gameplay_battle:drawShipBody(ship)
	if not ship.alive then
		return
	end

	local r = ship.radius
	local noseX = ship.x + math.cos(ship.angle) * (r + 4)
	local noseY = ship.y + math.sin(ship.angle) * (r + 4)
	local leftX = ship.x + math.cos(ship.angle + 2.5) * r
	local leftY = ship.y + math.sin(ship.angle + 2.5) * r
	local rightX = ship.x + math.cos(ship.angle - 2.5) * r
	local rightY = ship.y + math.sin(ship.angle - 2.5) * r

	love.graphics.setColor(self:getColorForOwner(ship.owner))
	love.graphics.polygon("fill", noseX, noseY, leftX, leftY, rightX, rightY)
end

function gameplay_battle:drawBullets()
	for _, bullet in ipairs(self.bullets) do
		love.graphics.setColor(self:getColorForOwner(bullet.owner))
		love.graphics.setLineWidth(6)
		love.graphics.line(bullet.x,bullet.y,bullet.x + (bullet.vx*0.1), bullet.y + (bullet.vy*0.1))
	end
end

function gameplay_battle:drawAsteroids()
	
	for _, asteroid in ipairs(self.asteroids) do
		love.graphics.setLineWidth(3)
		if asteroid.inOrbit then
			love.graphics.setColor(self:getColorForOwner(asteroid.owner))
			love.graphics.circle("fill", asteroid.x, asteroid.y, asteroid.radius)
			love.graphics.setColor(self:getColorForEnemy(asteroid.owner))
			love.graphics.circle("line", asteroid.x, asteroid.y, asteroid.radius + 2)
		else 
			love.graphics.setColor(self:getColorForOwner(asteroid.owner))
			love.graphics.circle("line", asteroid.x, asteroid.y, asteroid.radius)
		end
	end
end

function gameplay_battle:drawHud()
	if self.waitingForInitialStart or self.preRoundCountdownActive then
		return
	end

	local worldW = love.graphics.getWidth()
	love.graphics.setColor(themes.current.secondary)
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	
	if self.waitingForNextRound then
		local worldH = love.graphics.getHeight()
		if gameoverfont then
			love.graphics.setFont(gameoverfont)
		end
		love.graphics.printf(self.roundMessage or "ROUND OVER", 0, worldH * 0.4, worldW, "center")
		if scorefont then
			love.graphics.setFont(scorefont)
		end
		love.graphics.printf("PRESS SPACE", 0, worldH * 0.55, worldW, "center")
	elseif self.isGameOver then
		local worldH = love.graphics.getHeight()
		if gameoverfont then
			love.graphics.setFont(gameoverfontbig)
		end
		love.graphics.printf(self.roundMessage or "GAME OVER", 0, worldH * 0.36 + 20, worldW, "center")
		love.graphics.setColor(themes.current.primary)
		love.graphics.printf(self.roundMessage or "GAME OVER", 0, worldH * 0.36, worldW, "center")
		if scorefont then
			love.graphics.setFont(scorefont)
		end
		love.graphics.printf("PRESS R TO RESTART", 0, worldH * 0.55 + 40, worldW, "center")
	end
end

function gameplay_battle:drawPreRoundIntro()
	if not self.waitingForInitialStart then
		return
	end

	local worldW, worldH = love.graphics.getWidth(), love.graphics.getHeight()
	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	end
	love.graphics.setColor(themes.current.secondary)
	love.graphics.printf("POP THE ENEMY'S BALLOONS", 0, worldH * 0.33, worldW, "center")
	love.graphics.printf("BEST OF THREE", 0, worldH * 0.43, worldW, "center")
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	love.graphics.printf("PRESS SPACE TO START", 0, worldH * 0.56, worldW, "center")
end

function gameplay_battle:drawPreRoundCountdown()
	if not self.preRoundCountdownActive then
		return
	end

	local worldW, worldH = love.graphics.getWidth(), love.graphics.getHeight()
	local value = math.max(1, math.ceil(self.preRoundCountdownTimer or 0))
	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	end
	love.graphics.setColor(themes.current.secondary)
	love.graphics.printf(tostring(value), 0, worldH * 0.45, worldW, "center")
end

function gameplay_battle:drawArena()
	local centerX, centerY, arenaRadius = self:getArena()
	local _, orbitAngle = self:getOrbitState()
	local orbiterX = centerX + math.cos(orbitAngle) * arenaRadius
	local orbiterY = centerY + math.sin(orbitAngle) * arenaRadius
	local orbiterRadius = 25

	love.graphics.setColor(self:getArenaColor())
	love.graphics.setLineWidth(20)
	love.graphics.circle("line", centerX, centerY, arenaRadius)
	love.graphics.circle("fill", orbiterX, orbiterY, orbiterRadius)
end

function gameplay_battle:draw()
	love.graphics.clear(themes.current.background)
	self:drawArena()
	if self.waitingForInitialStart then
		self:drawPreRoundIntro()
		love.graphics.setColor(1, 1, 1, 1)
		return
	end
	if self.preRoundCountdownActive then
		self:drawPreRoundCountdown()
		love.graphics.setColor(1, 1, 1, 1)
		return
	end
	self:drawAsteroids()
	self:drawParticals()
	self:drawBullets()
	self:drawShipHitEffects()
	self:drawShipBody(self.ship)
	self:drawShipBody(self.enemyShip)
	self:drawHud()
	love.graphics.setColor(1, 1, 1, 1)
end

return gameplay_battle