local Gamestate = require "lib.hump.gamestate"
local push = require "lib.push"
local themes = require "src.preferences.themes"

local gameplay = {}

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

local function wrap(value, maxValue)
	if value < 0 then
		return value + maxValue
	elseif value > maxValue then
		return value - maxValue
	end
	return value
end

function gameplay:getWorldSize()
	return push._WWIDTH or 640, push._WHEIGHT or 480
end

function gameplay:spawnAsteroid(x, y, size)
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
	})
end

function gameplay:spawnWave(count)
	local worldW, worldH = self:getWorldSize()
	for _ = 1, count do
		local side = love.math.random(1, 4)
		local x, y
		if side == 1 then
			x = love.math.random(0, worldW)
			y = -20
		elseif side == 2 then
			x = worldW + 20
			y = love.math.random(0, worldH)
		elseif side == 3 then
			x = love.math.random(0, worldW)
			y = worldH + 20
		else
			x = -20
			y = love.math.random(0, worldH)
		end
		self:spawnAsteroid(x, y, "large")
	end
end

function gameplay:resetRun()
	local worldW, worldH = self:getWorldSize()

	self.ship = {
		x = worldW * 0.5,
		y = worldH * 0.5,
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
	self.fireCooldown = 0

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
		ttl = 1.1,
		radius = 2,
	})
end

function gameplay:splitAsteroid(asteroid)
	if asteroid.size == "large" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium")
		self:spawnAsteroid(asteroid.x, asteroid.y, "medium")
		self.score = self.score + 20
	elseif asteroid.size == "medium" then
		self:spawnAsteroid(asteroid.x, asteroid.y, "small")
		self:spawnAsteroid(asteroid.x, asteroid.y, "small")
		self.score = self.score + 40
	else
		self.score = self.score + 60
	end
end

function gameplay:updateShip(dt)
	local worldW, worldH = self:getWorldSize()
	local ship = self.ship

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

	local accel = 280
	ship.vx = ship.vx + inputX * accel * dt
	ship.vy = ship.vy + inputY * accel * dt

	local drag = 0.985
	ship.vx = ship.vx * drag
	ship.vy = ship.vy * drag

	local maxSpeed = 220
	local speed = length(ship.vx, ship.vy)
	if speed > maxSpeed then
		local k = maxSpeed / speed
		ship.vx = ship.vx * k
		ship.vy = ship.vy * k
	end

	ship.x = wrap(ship.x + ship.vx * dt, worldW)
	ship.y = wrap(ship.y + ship.vy * dt, worldH)

	local mouseX, mouseY = love.mouse.getPosition()
	local gameX, gameY = push:toGame(mouseX, mouseY)
	if gameX and gameY then
		local dx = gameX - ship.x
		local dy = gameY - ship.y
		if dx ~= 0 or dy ~= 0 then
			ship.angle = angleTo(dx, dy)
		end
	end
end

function gameplay:updateBullets(dt)
	local worldW, worldH = self:getWorldSize()

	for i = #self.bullets, 1, -1 do
		local bullet = self.bullets[i]
		bullet.x = wrap(bullet.x + bullet.vx * dt, worldW)
		bullet.y = wrap(bullet.y + bullet.vy * dt, worldH)
		bullet.ttl = bullet.ttl - dt
		if bullet.ttl <= 0 then
			table.remove(self.bullets, i)
		end
	end
end

function gameplay:updateAsteroids(dt)
	local worldW, worldH = self:getWorldSize()

	for _, asteroid in ipairs(self.asteroids) do
		asteroid.x = wrap(asteroid.x + asteroid.vx * dt, worldW)
		asteroid.y = wrap(asteroid.y + asteroid.vy * dt, worldH)
	end
end

function gameplay:handleBulletAsteroidCollisions()
	for bi = #self.bullets, 1, -1 do
		local bullet = self.bullets[bi]
		local bulletHit = false

		for ai = #self.asteroids, 1, -1 do
			local asteroid = self.asteroids[ai]
			local dist = length(bullet.x - asteroid.x, bullet.y - asteroid.y)
			if dist <= bullet.radius + asteroid.radius then
				table.remove(self.bullets, bi)
				table.remove(self.asteroids, ai)
				self:splitAsteroid(asteroid)
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

function gameplay:handleShipAsteroidCollision()
	local ship = self.ship
	for _, asteroid in ipairs(self.asteroids) do
		local dist = length(ship.x - asteroid.x, ship.y - asteroid.y)
		if dist <= ship.radius + asteroid.radius then
			self.lives = self.lives - 1
			ship.x = (push._WWIDTH or 640) * 0.5
			ship.y = (push._WHEIGHT or 480) * 0.5
			ship.vx = 0
			ship.vy = 0
			if self.lives <= 0 then
				self.isGameOver = true
			end
			return
		end
	end
end

function gameplay:update(dt)
	local escapeDown = love.keyboard.isDown("escape")
	if escapeDown and not self.escapeWasDown then
		local MenuState = require "src.states.menu"
		Gamestate.switch(MenuState)
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

	self.fireCooldown = math.max(0, self.fireCooldown - dt)

	self:updateShip(dt)

	local mouseDown = love.mouse.isDown(1)
	if mouseDown and not self.mouseWasDown and self.fireCooldown == 0 then
		self:shoot()
		self.fireCooldown = 0.13
	end
	self.mouseWasDown = mouseDown

	self:updateBullets(dt)
	self:updateAsteroids(dt)
	self:handleBulletAsteroidCollisions()
	self:handleShipAsteroidCollision()

	if #self.asteroids == 0 then
		self.wave = self.wave + 1
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

	love.graphics.setColor(themes.current.primary)
	love.graphics.polygon("line", noseX, noseY, leftX, leftY, rightX, rightY)
end

function gameplay:drawBullets()
	love.graphics.setColor(themes.current.secondary)
	for _, bullet in ipairs(self.bullets) do
		love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
	end
end

function gameplay:drawAsteroids()
	love.graphics.setColor(themes.current.primary)
	for _, asteroid in ipairs(self.asteroids) do
		love.graphics.circle("line", asteroid.x, asteroid.y, asteroid.radius)
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
end

function gameplay:drawGameOver()
	if not self.isGameOver then
		return
	end

	local worldW, worldH = self:getWorldSize()
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
	self:drawAsteroids()
	self:drawBullets()
	self:drawShip()
	self:drawHud()
	self:drawGameOver()
	love.graphics.setColor(1, 1, 1, 1)
end

return gameplay