local themes = require "src.preferences.themes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local gameplay_countdown = {}
local PLAYER_POLARITY = "primary"
local SHIP_INVINCIBLE_DURATION = 2.5
local SCORE_COUNT_SPEED = 220
local SCORE_COUNT_SPEED_EXTRA = 6
local SURVIVOR_POP_INTERVAL_BASE = 0.55
local SURVIVOR_POP_INTERVAL_PER_MULT = 0.12
local SURVIVOR_POP_INTERVAL_MAX = 1.35
local MAX_WAVE_ORBITS = 5
local MAX_WAVES = 3
local PRE_WAVE_COUNTDOWN_SECONDS = 3

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

function gameplay_countdown:getArena()
	local shrinkAmount = 0.85
	local worldW, worldH = love.graphics.getWidth(),love.graphics.getHeight()
	local completedOrbits = self:getOrbitState()
	local shrinkScale = math.max(0.35, shrinkAmount ^ completedOrbits)
	local arenaSizeAdjustment = 10
	return worldW * 0.5, worldH * 0.5, (worldH * 0.5 - arenaSizeAdjustment) * shrinkScale
end

function gameplay_countdown:getOrbitState()
	local orbitPeriod = 6
	local elapsed = love.timer.getTime() - (self.orbitStartTime or love.timer.getTime())
	local completedOrbits = math.floor(elapsed / orbitPeriod)
	local orbitProgress = (elapsed % orbitPeriod) / orbitPeriod
	local orbitAngle = -math.pi * 0.5 + orbitProgress * math.pi * 2
	return completedOrbits, orbitAngle
end

function gameplay_countdown:getArenaPlayerColor()
	return self:getColorForPolarity(self:getPlayerPolarity())
end

function gameplay_countdown:getArenaPolarity()
	local completedOrbits = self:getOrbitState()
	if completedOrbits % 2 == 0 then
		return "secondary"
	end
	return "primary"
end

function gameplay_countdown:getArenaColor()
	return self:getColorForPolarity(self:getArenaPolarity())
end

function gameplay_countdown:getPlayerPolarity()
	return PLAYER_POLARITY
end

function gameplay_countdown:getAsteroidPolarity(asteroid)
	local completedOrbits = self:getOrbitState()
	local polarity = asteroid.polarity or "primary"
	if completedOrbits % 2 == 1 then
		if polarity == "primary" then
			return "secondary"
		end
		return "primary"
	end
	return polarity
end

function gameplay_countdown:getColorForPolarity(polarity)
	if polarity == "secondary" then
		return themes.current.secondary
	end
	return themes.current.primary
end

function gameplay_countdown:getAsteroidCountByPolarity(polarity)
	local count = 0
	for _, asteroid in ipairs(self.asteroids) do
		if self:getAsteroidPolarity(asteroid) == polarity then
			count = count + 1
		end
	end
	return count
end

function gameplay_countdown:spawnAsteroid(x, y, size, polarity)
	local radiusBySize = {
		large = 30,
		medium = 18,
		small = 10,
	}

	local speedBySize = {
		large = 40,
		medium = 65,
		small = 95,
	}

	local angle = love.math.random() * math.pi * 2
	local speed = speedBySize[size]

	table.insert(self.asteroids, {
		x = x,
		y = y,
		vx = math.cos(angle) * speed,
		vy = math.sin(angle) * speed,
		size = size,
		radius = radiusBySize[size],
		polarity = polarity or "primary",
	})
end

function gameplay_countdown:getSafeAsteroidSpawnPosition(shipX, shipY, minShipDistance)
	local centerX, centerY, arenaRadius = self:getArena()
	for _ = 1, 60 do
		local angle = love.math.random() * math.pi * 2
		local distance = math.sqrt(love.math.random())
		local x = centerX + math.cos(angle) * distance * (arenaRadius - 48)
		local y = centerY + math.sin(angle) * distance * (arenaRadius - 48)

		if length(x - shipX, y - shipY) >= minShipDistance then
			local overlap = false
			for _, asteroid in ipairs(self.asteroids) do
				if length(x - asteroid.x, y - asteroid.y) < (asteroid.radius + 30 + 8) then
					overlap = true
					break
				end
			end

			if not overlap then
				return x, y
			end
		end
	end

	local fallbackAngle = love.math.random() * math.pi * 2
	return centerX + math.cos(fallbackAngle) * (arenaRadius - 56), centerY + math.sin(fallbackAngle) * (arenaRadius - 56)
end

function gameplay_countdown:spawnWave(count)
	local centerX, centerY = self:getArena()
	local shipX = (self.ship and self.ship.x) or centerX
	local shipY = (self.ship and self.ship.y) or centerY
	local minShipDistance = (self.ship and self.ship.radius or 12) + 30 + 40
	local asteroidPolarities = {}
	local primaryCount = math.floor(count / 2)
	for _ = 1, primaryCount do
		table.insert(asteroidPolarities, "primary")
	end
	for _ = primaryCount + 1, count do
		table.insert(asteroidPolarities, "secondary")
	end
	for i = #asteroidPolarities, 2, -1 do
		local swapIndex = love.math.random(i)
		asteroidPolarities[i], asteroidPolarities[swapIndex] = asteroidPolarities[swapIndex], asteroidPolarities[i]
	end

	for _ = 1, count do
		local polarity = asteroidPolarities[_]
		local x, y = self:getSafeAsteroidSpawnPosition(shipX, shipY, minShipDistance)
		self:spawnAsteroid(x, y, "large", polarity)
	end
end

function gameplay_countdown:resetRun()
	local centerX, centerY = self:getArena()

	self.ship = {
		x = centerX,
		y = centerY,
		vx = 0,
		vy = 0,
		angle = 0,
		radius = 20,
	}

	self.bullets = {}
	self.asteroids = {}
	self.score = 0
	self.displayedScore = 0
	self.lives = 3
	self.wave = 1
	self.clearedWave = 0
	self.isGameOver = false
	self.mouseWasDown = false
	self.restartWasDown = false
	self.escapeWasDown = false
	self.continueWasDown = false
	self.fireCooldown = 0
	self.shipWallAccelLockTimer = 0
	self.shipInvincibleTimer = 0
	self.waitingForNextWaveStart = false
	self.shipHitEffects = {}
	self.waveClearMessage = ""
	self.waveClearChars = 0
	self.waveClearTypeTimer = 0
	self.waveClearScoreDelay = 0
	self.waveClearPromptDelay = 0
	self.waveClearCanContinue = false
	self.waveCompletionType = nil
	self.waveStartScore = 0
	self.wavePreResolutionScore = 0
	self.wavePendingAdjustment = 0
	self.waveClearPhase = ""
	self.wavePhaseTimer = 0
	self.wavePopDirection = 1
	self.wavePopInterval = 0.5
	self.wavePopTimer = 0
	self.waveAdjustmentApplied = false
	self.waveCountdownActive = false
	self.waveCountdownTimer = 0
	self.roundComplete = false
	self.scoreCountSoundPlaying = false
	sounds.get_points:setLooping(true)
	sounds.get_points:stop()
	self.orbitStartTime = nil

	self:spawnWave(5)
	self.waveStartScore = self.score
	self:startWaveCountdown()
end

function gameplay_countdown:startWaveCountdown()
	self.waveCountdownActive = true
	self.waveCountdownTimer = PRE_WAVE_COUNTDOWN_SECONDS
	self.orbitStartTime = nil
	self.bullets = {}
	self.ship.vx = 0
	self.ship.vy = 0
end

function gameplay_countdown:getCompletedOrbitsThisWave()
	local completedOrbits = self:getOrbitState()
	return completedOrbits
end

function gameplay_countdown:getOrbitsRemainingThisWave()
	return math.max(0, MAX_WAVE_ORBITS - self:getCompletedOrbitsThisWave())
end

function gameplay_countdown:addScore(points)
	self.score = self.score + points
end

function gameplay_countdown:getWaveScoreMultiplier()
	return math.max(1, self.wave or 1)
end

function gameplay_countdown:getSurvivorBonusMultiplier()
	return self:getWaveScoreMultiplier() * 2
end

function gameplay_countdown:addWaveScaledScore(basePoints)
	local multiplier = self:getWaveScoreMultiplier()
	self:addScore(basePoints * multiplier)
end

function gameplay_countdown:addSurvivorAsteroidScore(basePoints)
	local multiplier = self:getSurvivorBonusMultiplier()
	self:addScore(basePoints * multiplier)
end

function gameplay_countdown:updateDisplayedScore(dt)
	local displayed = self.displayedScore or 0
	local remaining = self.score - displayed
	local wasCounting = remaining ~= 0

	if remaining == 0 then
		self.displayedScore = self.score
	else
		local gain = SCORE_COUNT_SPEED + math.abs(remaining) * SCORE_COUNT_SPEED_EXTRA
		local step = math.max(1, math.floor(gain * dt))
		if remaining > 0 then
			self.displayedScore = math.min(self.score, displayed + step)
		else
			self.displayedScore = math.max(self.score, displayed - step)
		end
	end

	local isCounting = (self.displayedScore or 0) ~= self.score
	if isCounting and not self.scoreCountSoundPlaying then
		sounds.get_points:stop()
		sounds.get_points:play()
		self.scoreCountSoundPlaying = true
	elseif not isCounting and self.scoreCountSoundPlaying then
		sounds.get_points:stop()
		self.scoreCountSoundPlaying = false
	end

	if not wasCounting and not isCounting then
		self.displayedScore = self.score
	end
end

function gameplay_countdown:getRemainingAsteroidScoreValue()
	local remainingScore = 0
	for _, asteroid in ipairs(self.asteroids) do
		remainingScore = remainingScore + self:getPopScoreForAsteroid(asteroid)
	end
	return remainingScore
end

function gameplay_countdown:beginWaveClearSequence(completionType)
	if self.waitingForNextWaveStart then
		return
	end

	self.waitingForNextWaveStart = true
	self.continueWasDown = false
	self.clearedWave = self.wave
	self.waveCompletionType = completionType or "cleared"
	if self.waveCompletionType == "timeout" then
		self.waveClearMessage = "WAVE " .. tostring(self.clearedWave) .. " TIME UP"
	else
		self.waveClearMessage = "WAVE " .. tostring(self.clearedWave) .. " COMPLETE"
	end
	self.waveClearChars = 0
	self.waveClearTypeTimer = 0
	self.waveClearScoreDelay = 0
	self.waveClearPromptDelay = 0
	self.waveClearCanContinue = false
	self.wavePreResolutionScore = self.score
	self.waveAdjustmentApplied = false
	self.waveClearPhase = "start_hold"
	self.wavePhaseTimer = 2.5
	self.displayedScore = self.waveStartScore or 0

	local remainingScore = self:getRemainingAsteroidScoreValue()
	local survivorMultiplier = self:getSurvivorBonusMultiplier()
	if self.waveCompletionType == "timeout" then
		self.wavePendingAdjustment = -(remainingScore * survivorMultiplier)
		self.wavePopDirection = -1
	else
		self.wavePendingAdjustment = remainingScore * survivorMultiplier
		self.wavePopDirection = 1
	end

	local popMultiplier = self:getSurvivorBonusMultiplier()
	self.wavePopInterval = math.min(SURVIVOR_POP_INTERVAL_MAX, SURVIVOR_POP_INTERVAL_BASE + popMultiplier * SURVIVOR_POP_INTERVAL_PER_MULT)
	self.wavePopTimer = self.wavePopInterval

	self.bullets = {}
	self.ship.vx = 0
	self.ship.vy = 0
end

function gameplay_countdown:updateWaveClearSequence(dt)
	if self.waveClearChars < #self.waveClearMessage then
		self.waveClearTypeTimer = self.waveClearTypeTimer + dt
		local typeInterval = 0.045
		while self.waveClearTypeTimer >= typeInterval and self.waveClearChars < #self.waveClearMessage do
			self.waveClearTypeTimer = self.waveClearTypeTimer - typeInterval
			self.waveClearChars = self.waveClearChars + 1
		end
		return
	end

	if self.waveClearPhase == "start_hold" then
		self.wavePhaseTimer = math.max(0, (self.wavePhaseTimer or 0) - dt)
		if self.wavePhaseTimer > 0 then
			return
		end
		self.waveClearPhase = "count_to_pre"
		return
	end

	if self.waveClearPhase == "count_to_pre" then
		if (self.displayedScore or 0) ~= (self.wavePreResolutionScore or 0) then
			return
		end
		self.waveClearPhase = "pre_pop_wait"
		self.wavePhaseTimer = 2.0
		return
	end

	if self.waveClearPhase == "pre_pop_wait" then
		self.wavePhaseTimer = math.max(0, (self.wavePhaseTimer or 0) - dt)
		if self.wavePhaseTimer > 0 then
			return
		end
		self.waveClearPhase = "popping"
		self.waveAdjustmentApplied = true
		return
	end

	if self.waveClearPhase == "popping" then
		if #self.asteroids > 0 then
			self.wavePopTimer = self.wavePopTimer - dt
			if self.wavePopTimer <= 0 then
				self.wavePopTimer = self.wavePopInterval
				local popped = table.remove(self.asteroids)
				local popPoints = self:getPopScoreForAsteroid(popped) * self:getSurvivorBonusMultiplier() * self.wavePopDirection
				self:addScore(popPoints)
				sounds.hit_foe:play()
			end
			return
		end

		self.waveClearPhase = "final_hold"
		self.wavePhaseTimer = 1.0
		return
	end

	if self.waveClearPhase == "final_hold" then
		if (self.displayedScore or 0) ~= self.score then
			return
		end
		self.wavePhaseTimer = math.max(0, (self.wavePhaseTimer or 0) - dt)
		if self.wavePhaseTimer > 0 then
			return
		end
		self.waveClearPhase = "done"
	end

	if self.waveClearPhase ~= "done" then
		return
	end

	if (self.clearedWave or 0) >= MAX_WAVES then
		self.roundComplete = true
		self.waitingForNextWaveStart = false
		self.isGameOver = true
		self.waveClearCanContinue = false
		return
	end

	self.waveClearCanContinue = true
end

function gameplay_countdown:isShipInvincible()
	return debug.invn or (self.shipInvincibleTimer or 0) > 0
end

function gameplay_countdown:spawnShipHitEffect(x, y)
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

function gameplay_countdown:applyAsteroidHitRecoil(originX, originY)
	local recoilRadius = 600
	for _, asteroid in ipairs(self.asteroids) do
		local dx = asteroid.x - originX
		local dy = asteroid.y - originY
		local dist = length(dx, dy)
		local effectiveDist = math.max(0, dist - asteroid.radius)
		if effectiveDist <= recoilRadius then
			local nx, ny
			if dist <= 0.001 then
				local angle = love.math.random() * math.pi * 2
				nx = math.cos(angle)
				ny = math.sin(angle)
			else
				nx = dx / dist
				ny = dy / dist
			end

			local falloff = 1 - (effectiveDist / recoilRadius)
			local impulse = 500 * falloff + 40
			asteroid.vx = asteroid.vx + nx * impulse
			asteroid.vy = asteroid.vy + ny * impulse
		end
	end
end

function gameplay_countdown:updateShipHitEffects(dt)
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

function gameplay_countdown:enter()
	self:resetRun()
end

function gameplay_countdown:shoot()
	local ship = self.ship
	local bulletSpeed = 420
	table.insert(self.bullets, {
		x = ship.x + math.cos(ship.angle) * (ship.radius + 4),
		y = ship.y + math.sin(ship.angle) * (ship.radius + 4),
		vx = ship.vx + math.cos(ship.angle) * bulletSpeed,
		vy = ship.vy + math.sin(ship.angle) * bulletSpeed,
		ttl = 2.0,
		radius = 2,
		polarity = self:getPlayerPolarity(),
	})
	playShoot()
end

function gameplay_countdown:splitAsteroid(asteroid)
	if asteroid.size == "large" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium", asteroid.polarity)
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium", asteroid.polarity)
		self:addWaveScaledScore(20)
	elseif asteroid.size == "medium" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "small", asteroid.polarity)
		self:spawnAsteroid(asteroid.x, asteroid.y, "small", asteroid.polarity)
		self:addWaveScaledScore(40)
	else
		self:addWaveScaledScore(60)
	end
end

function gameplay_countdown:applyAsteroidPolarityForces(dt)
	local ship = self.ship
	local playerPolarity = self:getPlayerPolarity()

	for _, asteroid in ipairs(self.asteroids) do
		local asteroidPolarity = self:getAsteroidPolarity(asteroid)
		local dx = asteroid.x - ship.x
		local dy = asteroid.y - ship.y
		local dist = length(dx, dy)
		if dist > 0.001 then
			local nx = dx / dist
			local ny = dy / dist

			if asteroidPolarity == playerPolarity then
				local baseRepel = 300 / (1 + dist * 0.03)
				local approachSpeed = ship.vx * nx + ship.vy * ny
				local bonusRepel = math.max(0, approachSpeed) * 1.15
				local repelForce = baseRepel + bonusRepel
				asteroid.vx = asteroid.vx + nx * repelForce * dt
				asteroid.vy = asteroid.vy + ny * repelForce * dt
			else
				local attractForce = 300 / (1 + dist * 0.03)
				asteroid.vx = asteroid.vx - nx * attractForce * dt
				asteroid.vy = asteroid.vy - ny * attractForce * dt
			end
		end

		local asteroidSpeed = length(asteroid.vx, asteroid.vy)
		local maxAsteroidSpeed = 300
		if asteroidSpeed > maxAsteroidSpeed then
			local speedScale = maxAsteroidSpeed / asteroidSpeed
			asteroid.vx = asteroid.vx * speedScale
			asteroid.vy = asteroid.vy * speedScale
		end
	end
end

function gameplay_countdown:updateShip(dt)
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
		inputX, inputY = inputX / mag, inputY / mag
	end

	if self.shipWallAccelLockTimer <= 0 then
		local accel = 500
		ship.vx = ship.vx + inputX * accel * dt
		ship.vy = ship.vy + inputY * accel * dt
	end

	local drag = 1.0
	ship.vx = ship.vx * drag
	ship.vy = ship.vy * drag

	local maxSpeed = 220
	local speed = length(ship.vx, ship.vy)
	if speed > maxSpeed then
		local k = maxSpeed / speed
		ship.vx = ship.vx * k
		ship.vy = ship.vy * k
	end

	ship.x = ship.x + ship.vx * dt
	ship.y = ship.y + ship.vy * dt
	local bouncedOnWall = bounceInsideCircle(ship, centerX, centerY, arenaRadius, 1.18)
	if bouncedOnWall then
		self.shipWallAccelLockTimer = 0.22
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

function gameplay_countdown:updateBullets(dt)
	local centerX, centerY, arenaRadius = self:getArena()

	for i = #self.bullets, 1, -1 do
		local bullet = self.bullets[i]
		bullet.x = bullet.x + bullet.vx * dt
		bullet.y = bullet.y + bullet.vy * dt
        -- ttl means how long they last for
		bullet.ttl = bullet.ttl - dt

		if bullet.ttl <= 0 then
			table.remove(self.bullets, i)
		elseif isOutsideCircle(bullet.x, bullet.y, centerX, centerY, arenaRadius - bullet.radius) then
			bounceInsideCircle(bullet, centerX, centerY, arenaRadius, 0.98)
		end
	end
end

function gameplay_countdown:updateAsteroids(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	self:applyAsteroidPolarityForces(dt)

	for _, asteroid in ipairs(self.asteroids) do
		asteroid.x = asteroid.x + asteroid.vx * dt
		asteroid.y = asteroid.y + asteroid.vy * dt
		bounceInsideCircle(asteroid, centerX, centerY, arenaRadius, 1.0)
	end
end

function gameplay_countdown:handleAsteroidAsteroidCollisions()
	local splitSpeedThreshold = 190
	local toRemove = {}
	local toSplit = {}

	for i = 1, #self.asteroids - 1 do
		local a = self.asteroids[i]
		for j = i + 1, #self.asteroids do
			local b = self.asteroids[j]
			local dx = b.x - a.x
			local dy = b.y - a.y
			local dist = length(dx, dy)
			local minDist = a.radius + b.radius

			if dist <= minDist then
				local relVx = a.vx - b.vx
				local relVy = a.vy - b.vy
				local relSpeed = length(relVx, relVy)
				local aPolarity = self:getAsteroidPolarity(a)
				local bPolarity = self:getAsteroidPolarity(b)

				if aPolarity ~= bPolarity and relSpeed >= splitSpeedThreshold then
					local splitA = a.size ~= "small"
					local splitB = b.size ~= "small"

					-- Small asteroids should bounce even in high-speed opposite-color hits.
					if not splitA or not splitB then
						resolveBodyCollision(a, b, 0.9)
					end

					if splitA and not toRemove[i] then
						toRemove[i] = true
						toSplit[i] = a
					end
					if splitB and not toRemove[j] then
						toRemove[j] = true
						toSplit[j] = b
					end
				else
					resolveBodyCollision(a, b, 0.9)
				end
			end
		end
	end

	for i = #self.asteroids, 1, -1 do
		if toRemove[i] then
			table.remove(self.asteroids, i)
		end
	end

	for _, asteroid in pairs(toSplit) do
		self:splitAsteroid(asteroid)
	end
end

function gameplay_countdown:handleBulletAsteroidCollisions()
	for bi = #self.bullets, 1, -1 do
		local bullet = self.bullets[bi]
		local bulletHit = false

		for ai = #self.asteroids, 1, -1 do
			local asteroid = self.asteroids[ai]
			local asteroidPolarity = self:getAsteroidPolarity(asteroid)
			local dist = length(bullet.x - asteroid.x, bullet.y - asteroid.y)
			if dist <= bullet.radius + asteroid.radius then
				if bullet.polarity ~= asteroidPolarity then
					table.remove(self.bullets, bi)
					table.remove(self.asteroids, ai)
					self:splitAsteroid(asteroid)
					bulletHit = true
					sounds.hit_foe:play()
					break
				end

				local dx = bullet.x - asteroid.x
				local dy = bullet.y - asteroid.y
				if dx == 0 and dy == 0 then
					dx = 1
				end
				local normalLen = length(dx, dy)
				local nx = dx / normalLen
				local ny = dy / normalLen

				bullet.x = asteroid.x + nx * (asteroid.radius + bullet.radius + 0.5)
				bullet.y = asteroid.y + ny * (asteroid.radius + bullet.radius + 0.5)

				local impactSpeed = bullet.vx * nx + bullet.vy * ny
				if impactSpeed < 0 then
					bullet.vx = (bullet.vx - 2 * impactSpeed * nx) * 0.96
					bullet.vy = (bullet.vy - 2 * impactSpeed * ny) * 0.96
				end

				bulletHit = true
				break
			end
		end

		if bulletHit then
			goto continue
		end

		::continue::
	end
end

function gameplay_countdown:damagePlayer()
	if self:isShipInvincible() then
		return
	end

	local hitX = self.ship.x
	local hitY = self.ship.y
	self:spawnShipHitEffect(hitX, hitY)
	self:applyAsteroidHitRecoil(hitX, hitY)

	sounds.crash:stop()
	sounds.crash:play()
	self.lives = self.lives - 1
	local centerX, centerY = self:getArena()
	self.ship.x = centerX
	self.ship.y = centerY
	self.ship.vx = 0
	self.ship.vy = 0
	self.shipWallAccelLockTimer = 0.18
	self.shipInvincibleTimer = SHIP_INVINCIBLE_DURATION
	if self.lives <= 0 then
		self.isGameOver = true
		self.shipInvincibleTimer = 0
	end
end

function gameplay_countdown:handleShipBulletCollision()
	if self:isShipInvincible() then
		return
	end

	local ship = self.ship
	local playerPolarity = self:getPlayerPolarity()

	for bi = #self.bullets, 1, -1 do
		local bullet = self.bullets[bi]
		if bullet.polarity ~= playerPolarity then
			local dist = length(ship.x - bullet.x, ship.y - bullet.y)
			if dist <= ship.radius + bullet.radius then
				table.remove(self.bullets, bi)
				self:damagePlayer()
				return
			end
		end
	end
end

function gameplay_countdown:handleShipAsteroidCollision()
	local ship = self.ship
	for _, asteroid in ipairs(self.asteroids) do
		local dist = length(ship.x - asteroid.x, ship.y - asteroid.y)
		if dist <= ship.radius + asteroid.radius then
			resolveBodyCollision(ship, asteroid, 1.05)
		end
	end
end

function gameplay_countdown:getPopScoreForAsteroid(asteroid)
	if asteroid.size == "large" then
		return 20
	elseif asteroid.size == "medium" then
		return 40
	end
	return 60
end

function gameplay_countdown:startNextWave()
	self.wave = self.wave + 1
	self.waitingForNextWaveStart = false
	self.waveCompletionType = nil
	self.wavePreResolutionScore = 0
	self.wavePendingAdjustment = 0
	self.waveClearPhase = ""
	self.wavePhaseTimer = 0
	self.wavePopDirection = 1
	self.wavePopInterval = 0.5
	self.wavePopTimer = 0
	self.waveAdjustmentApplied = false
	self.orbitStartTime = nil
	self:spawnWave(math.min(5 + self.wave, 12))
	self.waveStartScore = self.score
	self:startWaveCountdown()
end

function gameplay_countdown:update(dt)
	local escapeDown = love.keyboard.isDown("escape")
	if escapeDown and not self.escapeWasDown then
		sounds.get_points:stop()
		self.scoreCountSoundPlaying = false
		local MenuState = require "src.states.menu"
		state.switch(MenuState)
		return
	end
	self.escapeWasDown = escapeDown
	self.shipInvincibleTimer = math.max(0, (self.shipInvincibleTimer or 0) - dt)
	self:updateDisplayedScore(dt)
	self:updateShipHitEffects(dt)

	if self.isGameOver then
		local restartDown = love.keyboard.isDown("r")
		if restartDown and not self.restartWasDown then
			self:resetRun()
		end
		self.restartWasDown = restartDown
		return
	end

	if self.waitingForNextWaveStart then
		self:updateWaveClearSequence(dt)
		local continueDown = love.keyboard.isDown("space")
		if self.waveClearCanContinue and (self.wave or 0) < MAX_WAVES and continueDown and not self.continueWasDown then
			self:startNextWave()
		end
		self.continueWasDown = continueDown
		return
	end
	self.continueWasDown = false

	if self.waveCountdownActive then
		self.waveCountdownTimer = math.max(0, (self.waveCountdownTimer or 0) - dt)
		if self.waveCountdownTimer <= 0 then
			self.waveCountdownActive = false
			self.orbitStartTime = love.timer.getTime()
		end
		return
	end

	self.fireCooldown = math.max(0, self.fireCooldown - dt)

	self:updateShip(dt)

	local mouseDown = love.mouse.isDown(1)
	if mouseDown and self.fireCooldown == 0 then
		self:shoot()
		self.fireCooldown = 0.27
	end


	self:updateBullets(dt)
	self:updateAsteroids(dt)
	self:handleAsteroidAsteroidCollisions()
	self:handleBulletAsteroidCollisions()
	self:handleShipBulletCollision()
	self:handleShipAsteroidCollision()

	if not self.isGameOver then
		local completedOrbits = self:getCompletedOrbitsThisWave()
		local yellowAsteroids = self:getAsteroidCountByPolarity("secondary")

		if yellowAsteroids == 0 and completedOrbits < MAX_WAVE_ORBITS then
			self:beginWaveClearSequence("cleared")
			return
		end

		if completedOrbits >= MAX_WAVE_ORBITS then
			self:beginWaveClearSequence("timeout")
			return
		end
	end

	if #self.asteroids == 0 then
		self:beginWaveClearSequence("cleared")
		return
	end
end

function gameplay_countdown:drawShipHitEffects()
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

function gameplay_countdown:drawShip()
	local isInvincible = (self.shipInvincibleTimer or 0) > 0
	if isInvincible then
		local blinkRate = 14
		if math.floor(self.shipInvincibleTimer * blinkRate) % 2 == 0 then
			return
		end
	end

	local ship = self.ship
	local r = ship.radius

	local noseX = ship.x + math.cos(ship.angle) * (r + 4)
	local noseY = ship.y + math.sin(ship.angle) * (r + 4)
	local leftX = ship.x + math.cos(ship.angle + 2.5) * r
	local leftY = ship.y + math.sin(ship.angle + 2.5) * r
	local rightX = ship.x + math.cos(ship.angle - 2.5) * r
	local rightY = ship.y + math.sin(ship.angle - 2.5) * r

	love.graphics.setColor(self:getArenaPlayerColor())
	love.graphics.polygon("fill", noseX, noseY, leftX, leftY, rightX, rightY)
end

function gameplay_countdown:drawBullets()
	for _, bullet in ipairs(self.bullets) do
		love.graphics.setColor(self:getColorForPolarity(bullet.polarity))
		love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
	end
end

function gameplay_countdown:drawAsteroids()
	for _, asteroid in ipairs(self.asteroids) do
		love.graphics.setColor(self:getColorForPolarity(self:getAsteroidPolarity(asteroid)))
		love.graphics.circle("fill", asteroid.x, asteroid.y, asteroid.radius)
	end
end

function gameplay_countdown:drawScoreWatermark()
	local centerX, centerY = self:getArena()
	local label
	local color
	local scale = 1.0
	local alpha = 0.14

	if self.waitingForNextWaveStart or self.isGameOver then
		label = tostring(self.displayedScore or 0)
		color = themes.current.secondary
		local isCounting = (self.displayedScore or 0) ~= self.score
		scale = isCounting and 1.5 or 1.0
		alpha = isCounting and 0.22 or 0.14
	else
		label = tostring(self:getOrbitsRemainingThisWave())
		color = themes.current.primary
		scale = 1.35
		alpha = 0.18
	end

	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	elseif scorefont then
		love.graphics.setFont(scorefont)
	end

	love.graphics.push()
	love.graphics.translate(centerX, centerY - 28)
	love.graphics.scale(scale, scale)
	love.graphics.setColor(color[1], color[2], color[3], alpha)
	love.graphics.printf(label, -centerX / scale, 0, (centerX * 2) / scale, "center")
	love.graphics.pop()
end

function gameplay_countdown:drawHud()
	if self.waveCountdownActive then
		return
	end

	love.graphics.setColor(themes.current.secondary)
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	if self.waitingForNextWaveStart or self.isGameOver then
		love.graphics.printf("SCORE: " .. tostring(self.displayedScore or 0), 0, 36, love.graphics.getWidth(), "center")
	else
		love.graphics.printf("ORBITS LEFT: " .. tostring(self:getOrbitsRemainingThisWave()), 0, 10,love.graphics.getWidth(),"center")
		love.graphics.printf("WAVE: " .. tostring(self.wave) .. "/" .. tostring(MAX_WAVES), 0, 36, love.graphics.getWidth(), "center")
	end
	--love.graphics.print("MOVE: WASD/ARROWS  AIM: MOUSE  FIRE: LEFT CLICK", 16, 460)
	if self.waitingForNextWaveStart then
		local worldW, worldH = love.graphics.getWidth(), love.graphics.getHeight()
		local typedText = string.sub(self.waveClearMessage or "", 1, self.waveClearChars or 0)
		love.graphics.setFont(gameoverfont)
		love.graphics.printf(typedText, 0, worldH * 0.38, worldW, "center")

		if (self.waveClearChars or 0) >= #(self.waveClearMessage or "") then
			if gameoverfont then
				love.graphics.setFont(gameoverfont)
			end
			love.graphics.printf("SCORE: " .. tostring(self.displayedScore or 0), 0, worldH * 0.50, worldW, "center")

			if self.waveClearCanContinue then
				local nextWaveModifier = math.max(1, (self.wave or 1) + 1)
				love.graphics.printf(tostring(nextWaveModifier) .. "X NEXT! ", 0, worldH * 0.62, worldW, "center")
				love.graphics.printf("PRESS SPACE ", 0, worldH * 0.67, worldW, "center")
			elseif (self.clearedWave or 0) >= MAX_WAVES then
				love.graphics.printf("ROUND COMPLETE", 0, worldH * 0.62, worldW, "center")
			end
		end
	end
end

function gameplay_countdown:drawWaveCountdown()
	if not self.waveCountdownActive then
		return
	end

	local worldW, worldH = love.graphics.getWidth(), love.graphics.getHeight()
	local value = math.max(1, math.ceil(self.waveCountdownTimer or 0))

	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	end
	love.graphics.setColor(themes.current.secondary)
	love.graphics.printf("CLEAR THE BALLS", 0, worldH * 0.23, worldW, "center")
	love.graphics.printf("BEFORE THE COUNTDOWN ENDS", 0, worldH * 0.33, worldW, "center")
	love.graphics.printf(tostring(value), 0, worldH * 0.43, worldW, "center")
end

function gameplay_countdown:drawArena()
	local centerX, centerY, arenaRadius = self:getArena()
	local _, orbitAngle = self:getOrbitState()
	local orbiterX = centerX + math.cos(orbitAngle) * arenaRadius
	local orbiterY = centerY + math.sin(orbitAngle) * arenaRadius
	local orbiterRadius = 8

	love.graphics.setColor(self:getArenaColor())
	love.graphics.setLineWidth(4)
	love.graphics.circle("line", centerX, centerY, arenaRadius)
	love.graphics.circle("fill", orbiterX, orbiterY, orbiterRadius)
end

function gameplay_countdown:drawCountdownArena()
	local centerX, centerY, arenaRadius = self:getArena()
	local firstOrbitColor = self:getColorForPolarity("secondary")
	arenaRadius = arenaRadius * 0.85
	love.graphics.setColor(firstOrbitColor)
	love.graphics.setLineWidth(4)
	love.graphics.circle("line", centerX, centerY, arenaRadius)
	-- Keep the countdown arena visually identical to orbit 1.
	love.graphics.circle("fill", centerX, centerY - arenaRadius, 8)
end

function gameplay_countdown:drawGameOver()
	if not self.isGameOver then
		return
	end

	local worldW, worldH = love.graphics.getWidth(),love.graphics.getHeight()
	love.graphics.setColor(themes.current.primary)
	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	end
	if self.roundComplete then
		love.graphics.printf("ROUND COMPLETE", 0, worldH * 0.36, worldW, "center")
	else
		love.graphics.printf("GAME OVER", 0, worldH * 0.36, worldW, "center")
	end
	love.graphics.setColor(themes.current.secondary)
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	love.graphics.printf("SCORE: " .. tostring(self.displayedScore or 0), 0, worldH * 0.46, worldW, "center")
	love.graphics.printf("PRESS R TO RESTART", 0, worldH * 0.52, worldW, "center")
end

function gameplay_countdown:draw()
	love.graphics.clear(themes.current.background)
	if self.waveCountdownActive then
		self:drawCountdownArena()
		self:drawWaveCountdown()
		love.graphics.setColor(1, 1, 1, 1)
		return
	end

	self:drawArena()
	self:drawScoreWatermark()
	self:drawAsteroids()
	self:drawBullets()
	self:drawShipHitEffects()
	self:drawShip()
	self:drawHud()
	self:drawGameOver()
	love.graphics.setColor(1, 1, 1, 1)
end

return gameplay_countdown