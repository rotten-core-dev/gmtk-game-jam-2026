local themes = require "src.preferences.themes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local gameplay = {}
local PLAYER_POLARITY = "primary"

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

local function isOutsideEllipse(x, y, centerX, centerY, radiusX, radiusY)
	local dx = x - centerX
	local dy = y - centerY
	return (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY) > 1
end

local function bounceInsideEllipse(body, centerX, centerY, radiusX, radiusY, bounce)
	local dx = body.x - centerX
	local dy = body.y - centerY
	local effectiveRadiusX = radiusX - body.radius
	local effectiveRadiusY = radiusY - body.radius
	local normalized = (dx * dx) / (effectiveRadiusX * effectiveRadiusX)
		+ (dy * dy) / (effectiveRadiusY * effectiveRadiusY)

	if normalized <= 1 then
		return false
	end

	local scale = 1 / math.sqrt(normalized)
	body.x = centerX + dx * scale
	body.y = centerY + dy * scale

	local nx = (body.x - centerX) / (effectiveRadiusX * effectiveRadiusX)
	local ny = (body.y - centerY) / (effectiveRadiusY * effectiveRadiusY)
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

function gameplay:getArena()
	local shrinkAmount = 0.98
	local worldW, worldH = love.graphics.getWidth(),love.graphics.getHeight()
	local completedOrbits = self:getOrbitState()
	local shrinkScale = math.max(0.35, shrinkAmount ^ completedOrbits)
	return worldW * 0.5, worldH * 0.5, worldH * 0.6 * shrinkScale, worldH * 0.6 * shrinkScale
end

function gameplay:getOrbitState()
	local orbitPeriod = 6
	local elapsed = love.timer.getTime() - (self.orbitStartTime or love.timer.getTime())
	local completedOrbits = math.floor(elapsed / orbitPeriod)
	local orbitProgress = (elapsed % orbitPeriod) / orbitPeriod
	local orbitAngle = -math.pi * 0.5 + orbitProgress * math.pi * 2
	return completedOrbits, orbitAngle
end

function gameplay:getArenaPlayerColor()
	return self:getColorForPolarity(self:getPlayerPolarity())
end

function gameplay:getArenaPolarity()
	local completedOrbits = self:getOrbitState()
	if completedOrbits % 2 == 0 then
		return "secondary"
	end
	return "primary"
end

function gameplay:getArenaColor()
	return self:getColorForPolarity(self:getArenaPolarity())
end

function gameplay:getPlayerPolarity()
	return PLAYER_POLARITY
end

function gameplay:getAsteroidPolarity(asteroid)
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

function gameplay:getColorForPolarity(polarity)
	if polarity == "secondary" then
		return themes.current.secondary
	end
	return themes.current.primary
end

function gameplay:getAsteroidCountByPolarity(polarity)
	local count = 0
	for _, asteroid in ipairs(self.asteroids) do
		if self:getAsteroidPolarity(asteroid) == polarity then
			count = count + 1
		end
	end
	return count
end

function gameplay:spawnAsteroid(x, y, size, polarity)
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

function gameplay:getSafeAsteroidSpawnPosition(shipX, shipY, minShipDistance)
	local centerX, centerY, arenaRadiusX, arenaRadiusY = self:getArena()
	for _ = 1, 60 do
		local angle = love.math.random() * math.pi * 2
		local distance = math.sqrt(love.math.random())
		local x = centerX + math.cos(angle) * distance * (arenaRadiusX - 48)
		local y = centerY + math.sin(angle) * distance * (arenaRadiusY - 48)

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
	return centerX + math.cos(fallbackAngle) * (arenaRadiusX - 56), centerY + math.sin(fallbackAngle) * (arenaRadiusY - 56)
end

function gameplay:spawnWave(count)
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

function gameplay:resetRun()
	local centerX, centerY = self:getArena()

	self.ship = {
		x = centerX,
		y = centerY,
		vx = 0,
		vy = 0,
		angle = 0,
		radius = 12,
	}

	self.bullets = {}
	self.asteroids = {}
	self.score = 0
	self.lives = 3
	self.wave = 1
	self.isGameOver = false
	self.mouseWasDown = false
	self.restartWasDown = false
	self.escapeWasDown = false
	self.continueWasDown = false
	self.fireCooldown = 0
	self.shipWallAccelLockTimer = 0
	self.isPoppingWave = false
	self.waitingForNextWaveStart = false
	self.popTimer = 0
	self.popInterval = 0.5
	self.orbitStartTime = love.timer.getTime()

	self:spawnWave(5)
end

function gameplay:enter()
	self:resetRun()
end

function gameplay:shoot()
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
end

function gameplay:splitAsteroid(asteroid)
	if asteroid.size == "large" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium", asteroid.polarity)
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium", asteroid.polarity)
		self.score = self.score + 20
	elseif asteroid.size == "medium" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "small", asteroid.polarity)
		self:spawnAsteroid(asteroid.x, asteroid.y, "small", asteroid.polarity)
		self.score = self.score + 40
	else
		self.score = self.score + 60
	end
end

function gameplay:applyAsteroidPolarityForces(dt)
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

function gameplay:updateShip(dt)
	local centerX, centerY, arenaRadiusX, arenaRadiusY = self:getArena()
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
	local bouncedOnWall = bounceInsideEllipse(ship, centerX, centerY, arenaRadiusX, arenaRadiusY, 1.18)
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

function gameplay:updateBullets(dt)
	local centerX, centerY, arenaRadiusX, arenaRadiusY = self:getArena()

	for i = #self.bullets, 1, -1 do
		local bullet = self.bullets[i]
		bullet.x = bullet.x + bullet.vx * dt
		bullet.y = bullet.y + bullet.vy * dt
        -- ttl means how long they last for
		bullet.ttl = bullet.ttl - dt

		if bullet.ttl <= 0 then
			table.remove(self.bullets, i)
		elseif isOutsideEllipse(bullet.x, bullet.y, centerX, centerY, arenaRadiusX - bullet.radius, arenaRadiusY - bullet.radius) then
			bounceInsideEllipse(bullet, centerX, centerY, arenaRadiusX, arenaRadiusY, 0.98)
		end
	end
end

function gameplay:updateAsteroids(dt)
	local centerX, centerY, arenaRadiusX, arenaRadiusY = self:getArena()
	self:applyAsteroidPolarityForces(dt)

	for _, asteroid in ipairs(self.asteroids) do
		asteroid.x = asteroid.x + asteroid.vx * dt
		asteroid.y = asteroid.y + asteroid.vy * dt
		bounceInsideEllipse(asteroid, centerX, centerY, arenaRadiusX, arenaRadiusY, 1.0)
	end
end

function gameplay:handleAsteroidAsteroidCollisions()
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

function gameplay:handleBulletAsteroidCollisions()
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

function gameplay:damagePlayer()
    sounds.crash:stop()
	sounds.crash:play()
	self.lives = self.lives - 1
	local centerX, centerY = self:getArena()
	self.ship.x = centerX
	self.ship.y = centerY
	self.ship.vx = 0
	self.ship.vy = 0
	if self.lives <= 0 then
		self.isGameOver = true
	end
end

function gameplay:handleShipBulletCollision()
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

function gameplay:handleShipAsteroidCollision()
	if debug.invn then return end
	local ship = self.ship
	local playerPolarity = self:getPlayerPolarity()
	for _, asteroid in ipairs(self.asteroids) do
		local dist = length(ship.x - asteroid.x, ship.y - asteroid.y)
		if dist <= ship.radius + asteroid.radius then
			local asteroidPolarity = self:getAsteroidPolarity(asteroid)
			if asteroidPolarity == playerPolarity then
				resolveBodyCollision(ship, asteroid, 1.05)
			else
				self:damagePlayer()
				return
			end
		end
	end
end

function gameplay:startPopSequence()
	self.isPoppingWave = true
	self.popTimer = 0
	self.shipWallAccelLockTimer = math.max(self.shipWallAccelLockTimer, 0.25)
end

function gameplay:getPopScoreForAsteroid(asteroid)
	if asteroid.size == "large" then
		return 20
	elseif asteroid.size == "medium" then
		return 40
	end
	return 60
end

function gameplay:updatePopSequence(dt)
	self.popTimer = self.popTimer - dt
	if self.popTimer > 0 then
		return
	end

	self.popTimer = self.popInterval
	if #self.asteroids > 0 then
		local popped = table.remove(self.asteroids)
		self.score = self.score + self:getPopScoreForAsteroid(popped)
		sounds.hit_foe:play()
	end

	if #self.asteroids == 0 then
		self.isPoppingWave = false
		self.waitingForNextWaveStart = true
		self.continueWasDown = false
	end
end

function gameplay:startNextWave()
	self.wave = self.wave + 1
	self.waitingForNextWaveStart = false
	self.orbitStartTime = love.timer.getTime()
	self:spawnWave(math.min(5 + self.wave, 12))
end

function gameplay:update(dt)
	local escapeDown = love.keyboard.isDown("escape")
	if escapeDown and not self.escapeWasDown then
		local MenuState = require "src.states.menu"
		state.switch(MenuState)
		return
	end
	self.escapeWasDown = escapeDown

	if self.isGameOver then
		local restartDown = love.keyboard.isDown("r")
		if restartDown and not self.restartWasDown then
			self:resetRun()
		end
		self.restartWasDown = restartDown
		return
	end

	if self.waitingForNextWaveStart then
		local continueDown = love.keyboard.isDown("return") or love.keyboard.isDown("space")
		if continueDown and not self.continueWasDown then
			self:startNextWave()
		end
		self.continueWasDown = continueDown
		return
	end
	self.continueWasDown = false

	if self.isPoppingWave then
		self:updatePopSequence(dt)
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
		local yellowAsteroids = self:getAsteroidCountByPolarity("secondary")
		if yellowAsteroids == 0 and #self.asteroids > 0 then
			self:startPopSequence()
			return
		end
	end

	if #self.asteroids == 0 then
		self.wave = self.wave + 1
		self.orbitStartTime = love.timer.getTime()
		self:spawnWave(math.min(5 + self.wave, 12))
	end
end

function gameplay:drawShip()
	local ship = self.ship
	local r = ship.radius

	local noseX = ship.x + math.cos(ship.angle) * (r + 4)
	local noseY = ship.y + math.sin(ship.angle) * (r + 4)
	local leftX = ship.x + math.cos(ship.angle + 2.5) * r
	local leftY = ship.y + math.sin(ship.angle + 2.5) * r
	local rightX = ship.x + math.cos(ship.angle - 2.5) * r
	local rightY = ship.y + math.sin(ship.angle - 2.5) * r

	love.graphics.setColor(self:getArenaPlayerColor())
	love.graphics.polygon("line", noseX, noseY, leftX, leftY, rightX, rightY)
end

function gameplay:drawBullets()
	for _, bullet in ipairs(self.bullets) do
		love.graphics.setColor(self:getColorForPolarity(bullet.polarity))
		love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
	end
end

function gameplay:drawAsteroids()
	for _, asteroid in ipairs(self.asteroids) do
		love.graphics.setColor(self:getColorForPolarity(self:getAsteroidPolarity(asteroid)))
		love.graphics.circle("fill", asteroid.x, asteroid.y, asteroid.radius)
	end
end

function gameplay:drawHud()
	love.graphics.setColor(themes.current.secondary)
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	love.graphics.print("SCORE: " .. tostring(self.score), 16, 12)
	love.graphics.print("LIVES: " .. tostring(self.lives), 16, 28)
	love.graphics.print("WAVE: " .. tostring(self.wave), 16, 44)
	love.graphics.print("MOVE: WASD/ARROWS  AIM: MOUSE  FIRE: LEFT CLICK", 16, 460)
	if self.waitingForNextWaveStart then
		love.graphics.printf("WAVE CLEAR - PRESS ENTER OR SPACE FOR NEXT", 0, 220, 640, "center")
	end
end

function gameplay:drawArena()
	local centerX, centerY, arenaRadiusX, arenaRadiusY = self:getArena()
	local _, orbitAngle = self:getOrbitState()
	local orbiterX = centerX + math.cos(orbitAngle) * arenaRadiusX
	local orbiterY = centerY + math.sin(orbitAngle) * arenaRadiusY
	local orbiterRadius = 6

	love.graphics.setColor(self:getArenaColor())
	love.graphics.setLineWidth(4)
	love.graphics.ellipse("line", centerX, centerY, arenaRadiusX, arenaRadiusY)
	love.graphics.circle("fill", orbiterX, orbiterY, orbiterRadius)
end

function gameplay:drawGameOver()
	if not self.isGameOver then
		return
	end

	local worldW, worldH = love.graphics.getWidth(),love.graphics.getHeight()
	love.graphics.setColor(themes.current.primary)
	if gameoverfont then
		love.graphics.setFont(gameoverfont)
	end
	love.graphics.printf("GAME OVER", 0, worldH * 0.36, worldW, "center")
	love.graphics.setColor(themes.current.secondary)
	if scorefont then
		love.graphics.setFont(scorefont)
	end
	love.graphics.printf("PRESS R TO RESTART", 0, worldH * 0.52, worldW, "center")
end

function gameplay:draw()
	love.graphics.clear(themes.current.background)
	self:drawArena()
	self:drawAsteroids()
	self:drawBullets()
	self:drawShip()
	self:drawHud()
	self:drawGameOver()
	love.graphics.setColor(1, 1, 1, 1)
end

return gameplay