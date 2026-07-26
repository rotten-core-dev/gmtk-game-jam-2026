local themes = require "src.preferences.themes"
local sounds = require "src.system.sounds"
local state = require "src.state"

local gameplay_billiards = {}

local PLAYER_OWNER = "player"
local ENEMY_OWNER = "enemy"
local BLACK_OWNER = "black"
local GROUP_A = "group_a"
local GROUP_B = "group_b"

local BALL_RADIUS = 12
local CUE_RADIUS = 12
local BALL_SPACING = BALL_RADIUS * 2.1
local ARENA_PADDING = 14
local WALL_BOUNCE = 0.94
local BALL_BOUNCE = 0.985
local BALL_DRAG = 0.984
local STOP_SPEED = 14
local MAX_BALL_SPEED = 720
local MAX_PULL_DISTANCE = 150
local MIN_PULL_DISTANCE = 10
local SHOT_POWER = 20
local AI_SHOT_DELAY = 0.9

local BLACK_HOLE_RADIUS = 22
local BLACK_HOLE_CAPTURE_RADIUS = 16
local BLACK_HOLE_GRAVITY = 125
local BLACK_HOLE_SWIRL = 95

local function length(x, y)
	return math.sqrt(x * x + y * y)
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
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

local function shuffle(list)
	for index = #list, 2, -1 do
		local swapIndex = love.math.random(index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
end

local function copyColor(color)
	return { color[1], color[2], color[3], color[4] or 1 }
end

function gameplay_billiards:getArena()
	local worldW = love.graphics.getWidth()
	local worldH = love.graphics.getHeight()
	local radius = math.min(worldW, worldH) * 0.5 - ARENA_PADDING
	return worldW * 0.5, worldH * 0.5, radius
end

function gameplay_billiards:getColorForOwner(owner)
	if owner == ENEMY_OWNER then
		return themes.current.secondary
	end
	return themes.current.primary
end

function gameplay_billiards:getColorForGroup(group)
	if group == GROUP_B then
		return themes.current.secondary
	end
	return themes.current.primary
end

function gameplay_billiards:getOwnerLabel(owner)
	if owner == ENEMY_OWNER then
		return "AI"
	end
	return "PLAYER"
end

function gameplay_billiards:getOtherOwner(owner)
	if owner == ENEMY_OWNER then
		return PLAYER_OWNER
	end
	return ENEMY_OWNER
end

function gameplay_billiards:getGroupForOwner(owner)
	if owner == ENEMY_OWNER then
		return self.enemyGroup
	end
	return self.playerGroup
end

function gameplay_billiards:getOwnerForGroup(group)
	if not group then
		return nil
	end
	if self.playerGroup == group then
		return PLAYER_OWNER
	end
	if self.enemyGroup == group then
		return ENEMY_OWNER
	end
	return nil
end

function gameplay_billiards:claimGroups(firstOwner, firstGroup)
	if self.playerGroup and self.enemyGroup then
		return false
	end

	if self.playerGroup or self.enemyGroup or not firstGroup then
		return false
	end

	local otherGroup = firstGroup == GROUP_A and GROUP_B or GROUP_A
	if firstOwner == ENEMY_OWNER then
		self.enemyGroup = firstGroup
		self.playerGroup = otherGroup
	else
		self.playerGroup = firstGroup
		self.enemyGroup = otherGroup
	end

	self.message = "COLORS ASSIGNED"
	self.subMessage = "PLAYER " .. self:getGroupName(self.playerGroup) .. "  |  AI " .. self:getGroupName(self.enemyGroup)
	self.messageColor = copyColor(self:getColorForGroup(firstGroup))
	self.subMessageColor = copyColor(self:getColorForGroup(firstGroup))
	return true
end

function gameplay_billiards:getGroupName(group)
	if group == GROUP_B then
		return themes.current.secondary_name
	end
	return themes.current.primary_name
end

function gameplay_billiards:createBall(ballType, owner, x, y)
	return {
		type = ballType,
		owner = owner,
		group = nil,
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		radius = ballType == "cue" and CUE_RADIUS or BALL_RADIUS,
		sunk = false,
	}
end

function gameplay_billiards:getCueBall()
	for _, ball in ipairs(self.balls) do
		if not ball.sunk and ball.type == "cue" then
			return ball
		end
	end
	return nil
end

function gameplay_billiards:getRemainingColorCount(owner)
	local group = self:getGroupForOwner(owner)
	if not group then
		return 7
	end

	local count = 0
	for _, ball in ipairs(self.balls) do
		if not ball.sunk and ball.type == "color" and ball.group == group then
			count = count + 1
		end
	end
	return count
end

function gameplay_billiards:getBlackHoles()
	local centerX, centerY, arenaRadius = self:getArena()
	local offset = (arenaRadius - BLACK_HOLE_RADIUS - 18) / math.sqrt(2)
	return {
		{ x = centerX + offset, y = centerY - offset },
		{ x = centerX + offset, y = centerY + offset },
		{ x = centerX - offset, y = centerY + offset },
		{ x = centerX - offset, y = centerY - offset },
	}
end

function gameplay_billiards:getCueStartPosition(owner)
	local centerX, centerY, arenaRadius = self:getArena()
	local direction = owner == ENEMY_OWNER and 1 or -1
	return centerX, centerY + direction * arenaRadius * 0.55
end

function gameplay_billiards:isPointClear(x, y, radius, ignoreBall)
	for _, ball in ipairs(self.balls) do
		if ball ~= ignoreBall and not ball.sunk then
			if length(ball.x - x, ball.y - y) < ball.radius + radius + 2 then
				return false
			end
		end
	end
	return true
end

function gameplay_billiards:respawnCueBallForOwner(owner)
	local cueBall = self:getCueBall()
	if not cueBall then
		local spawnX, spawnY = self:getCueStartPosition(owner)
		cueBall = self:createBall("cue", owner, spawnX, spawnY)
		table.insert(self.balls, cueBall)
	end

	local centerX, centerY, arenaRadius = self:getArena()
	local spawnX, spawnY = self:getCueStartPosition(owner)
	local fallbackY = centerY + (owner == ENEMY_OWNER and 1 or -1) * arenaRadius * 0.3
	local candidateX = spawnX
	local candidateY = spawnY
	local foundSpot = false

	for step = 0, 18 do
		local offsetX = step * (cueBall.radius * 1.8)
		for _, sign in ipairs({ 1, -1 }) do
			local testX = spawnX + offsetX * sign
			if testX > centerX - arenaRadius * 0.55 and testX < centerX + arenaRadius * 0.55 then
				if self:isPointClear(testX, spawnY, cueBall.radius, cueBall) then
					candidateX = testX
					candidateY = spawnY
					foundSpot = true
					break
				end
			end
		end
		if foundSpot then
			break
		end
	end

	if not foundSpot then
		for step = 0, 18 do
			local offsetX = step * (cueBall.radius * 1.8)
			for _, sign in ipairs({ 1, -1 }) do
				local testX = centerX + offsetX * sign
				if self:isPointClear(testX, fallbackY, cueBall.radius, cueBall) then
					candidateX = testX
					candidateY = fallbackY
					foundSpot = true
					break
				end
			end
			if foundSpot then
				break
			end
		end
	end

	cueBall.x = candidateX
	cueBall.y = candidateY
	cueBall.vx = 0
	cueBall.vy = 0
	cueBall.sunk = false
	cueBall.owner = owner

	local dx = cueBall.x - centerX
	local dy = cueBall.y - centerY
	local maxDist = arenaRadius - cueBall.radius - 2
	local dist = length(dx, dy)
	if dist > maxDist and dist > 0 then
		cueBall.x = centerX + dx / dist * maxDist
		cueBall.y = centerY + dy / dist * maxDist
	end
end

function gameplay_billiards:createRackBalls()
	local centerX, centerY = self:getArena()
	local rackX = centerX
	local rackY = centerY - BALL_SPACING * 4.1
	local positions = {}

	for row = 0, 4 do
		local startX = rackX - row * BALL_SPACING * 0.5
		for column = 0, row do
			table.insert(positions, {
				x = startX + column * BALL_SPACING,
				y = rackY + row * BALL_SPACING * 0.88,
			})
		end
	end

	local groups = {}
	for _ = 1, 7 do
		table.insert(groups, GROUP_A)
		table.insert(groups, GROUP_B)
	end
	shuffle(groups)

	local blackIndex = 5
	local groupIndex = 1
	for index, position in ipairs(positions) do
		if index == blackIndex then
			table.insert(self.balls, self:createBall("black", BLACK_OWNER, position.x, position.y))
		else
			local ball = self:createBall("color", nil, position.x, position.y)
			ball.group = groups[groupIndex]
			groupIndex = groupIndex + 1
			table.insert(self.balls, ball)
		end
	end

	local cueX, cueY = self:getCueStartPosition(PLAYER_OWNER)
	table.insert(self.balls, self:createBall("cue", PLAYER_OWNER, cueX, cueY))
end

function gameplay_billiards:resetMatch()
	self.balls = {}
	self.playerGroup = GROUP_A
	self.enemyGroup = GROUP_B
	self.currentTurn = PLAYER_OWNER
	self.turnsRemaining = 1
	self.waitingToStart = true
	self.breakShotPending = true
	self.shotActive = false
	self.aiming = false
	self.dragX = nil
	self.dragY = nil
	self.aiAimTimer = AI_SHOT_DELAY
	self.lastMouseDown = false
	self.winner = nil
	self.message = "DRAG BACK THE SHIP TO SHOOT"
	self.subMessage = "FIRST TO CLEAR THEIR COLOR WINS"
	self.messageColor = nil
	self.subMessageColor = nil
	self.escapeWasDown = false
	self.restartWasDown = false
	self.turnEvents = nil
	self.pendingCueRespawnOwner = nil
	self:createRackBalls()
end

function gameplay_billiards:enter()
	self:resetMatch()
end

function gameplay_billiards:startShot(owner)
	local cueBall = self:getCueBall()
	if not cueBall or self.shotActive or self.winner then
		return false
	end

	self.shotActive = true
	self.aiming = false
	self.dragX = nil
	self.dragY = nil
	self.aiAimTimer = AI_SHOT_DELAY
	self.turnEvents = {
		shooter = owner,
		firstContactOwner = nil,
		assignedGroup = nil,
		sankOpponentBall = false,
		sankOwnBall = false,
		sankCueBall = false,
		sankBlackBall = false,
	}
	return true
end

function gameplay_billiards:applyShotVelocity(owner, aimDX, aimDY, pullDistance)
	local cueBall = self:getCueBall()
	if not cueBall then
		return
	end

	local dist = length(aimDX, aimDY)
	if dist < 0.001 then
		return
	end

	local clampedPull = clamp(pullDistance or dist, 0, MAX_PULL_DISTANCE)
	if clampedPull < MIN_PULL_DISTANCE then
		return
	end

	if not self:startShot(owner) then
		return
	end

	local power = clampedPull * SHOT_POWER
	cueBall.vx = (aimDX / dist) * power
	cueBall.vy = (aimDY / dist) * power
	cueBall.owner = owner
	playSound("ball",0.9)
	self.message = self:getOwnerLabel(owner) .. " SHOT"
	self.subMessage = ""
	self.messageColor = nil
	self.subMessageColor = nil
end

function gameplay_billiards:getLegalTargetBalls(owner)
	local targets = {}
	local group = self:getGroupForOwner(owner)
	for _, ball in ipairs(self.balls) do
		if not ball.sunk then
			if ball.type == "color" and ball.group == group then
				table.insert(targets, ball)
			end
		end
	end
	return targets
end

function gameplay_billiards:removeBlackBallFromPlay()
	for _, ball in ipairs(self.balls) do
		if not ball.sunk and ball.type == "black" then
			ball.sunk = true
			ball.vx = 0
			ball.vy = 0
			return true
		end
	end
	return false
end

function gameplay_billiards:getWinnerByClearingColors()
	if self:getRemainingColorCount(PLAYER_OWNER) == 0 then
		return PLAYER_OWNER
	end
	if self:getRemainingColorCount(ENEMY_OWNER) == 0 then
		return ENEMY_OWNER
	end
	return nil
end

function gameplay_billiards:takeAIShot()
	local cueBall = self:getCueBall()
	if not cueBall or self.currentTurn ~= ENEMY_OWNER or self.winner then
		return
	end

	local targets = self:getLegalTargetBalls(ENEMY_OWNER)
	if #targets == 0 then
		for _, ball in ipairs(self.balls) do
			if not ball.sunk and ball.type == "color" then
				table.insert(targets, ball)
			end
		end
	end

	local target = nil
	local bestDistance = math.huge
	for _, candidate in ipairs(targets) do
		local dist = length(candidate.x - cueBall.x, candidate.y - cueBall.y)
		if dist < bestDistance then
			bestDistance = dist
			target = candidate
		end
	end

	if not target then
		return
	end

	local angle = angleTo(target.x - cueBall.x, target.y - cueBall.y)
	angle = angle + love.math.random(-18, 18) * math.pi / 180
	local aimDX = math.cos(angle)
	local aimDY = math.sin(angle)
	local pullDistance = clamp(bestDistance * 0.55 + 32, 56, MAX_PULL_DISTANCE)
	self:applyShotVelocity(ENEMY_OWNER, aimDX, aimDY, pullDistance)
end

function gameplay_billiards:applyBlackHoleForces(dt)
	for _, hole in ipairs(self:getBlackHoles()) do
		for _, ball in ipairs(self.balls) do
			if not ball.sunk then
				local dx = hole.x - ball.x
				local dy = hole.y - ball.y
				local dist = length(dx, dy)
				if dist > 0.001 then
					local nx = dx / dist
					local ny = dy / dist
					local tangentX = -ny
					local tangentY = nx
					local pullFactor = math.max(0, dist - BLACK_HOLE_RADIUS)
					local gravity = BLACK_HOLE_GRAVITY / (1 + pullFactor * 0.025)
					local swirl = BLACK_HOLE_SWIRL / (1 + pullFactor * 0.035)
					ball.vx = ball.vx + (nx * gravity + tangentX * swirl) * dt
					ball.vy = ball.vy + (ny * gravity + tangentY * swirl) * dt
				end
			end
		end
	end
end

function gameplay_billiards:updateBallMotion(dt)
	local centerX, centerY, arenaRadius = self:getArena()
	local dragScale = BALL_DRAG ^ (dt * 60)

	for _, ball in ipairs(self.balls) do
		if not ball.sunk then
			ball.x = ball.x + ball.vx * dt
			ball.y = ball.y + ball.vy * dt
			ball.vx = ball.vx * dragScale
			ball.vy = ball.vy * dragScale

			if length(ball.vx, ball.vy) < STOP_SPEED then
				ball.vx = 0
				ball.vy = 0
			end

			local speed = length(ball.vx, ball.vy)
			if speed > MAX_BALL_SPEED then
				local scale = MAX_BALL_SPEED / speed
				ball.vx = ball.vx * scale
				ball.vy = ball.vy * scale
			end

			bounceInsideCircle(ball, centerX, centerY, arenaRadius, WALL_BOUNCE)
		end
	end
end

function gameplay_billiards:recordCueContact(otherBall)
	if not self.turnEvents or self.turnEvents.firstContactOwner ~= nil then
		return
	end
	if otherBall.type == "color" then
		self.turnEvents.firstContactOwner = self:getOwnerForGroup(otherBall.group)
		return
	end
	if otherBall.type == "black" then
		self.turnEvents.firstContactOwner = BLACK_OWNER
	end
end

function gameplay_billiards:resolveBallCollisions()
	for index = 1, #self.balls - 1 do
		local a = self.balls[index]
		if not a.sunk then
			for otherIndex = index + 1, #self.balls do
				local b = self.balls[otherIndex]
				if not b.sunk then
					local dx = b.x - a.x
					local dy = b.y - a.y
					local dist = length(dx, dy)
					local minDist = a.radius + b.radius
					if dist == 0 then
						dx, dy, dist = 1, 0, 1
					end

					if dist < minDist then
						local nx = dx / dist
						local ny = dy / dist
						local overlap = minDist - dist
						a.x = a.x - nx * overlap * 0.5
						a.y = a.y - ny * overlap * 0.5
						b.x = b.x + nx * overlap * 0.5
						b.y = b.y + ny * overlap * 0.5

						local rvx = b.vx - a.vx
						local rvy = b.vy - a.vy
						local impactSpeed = rvx * nx + rvy * ny
						if impactSpeed < 0 then
							local impulse = -(1 + BALL_BOUNCE) * impactSpeed * 0.5
							a.vx = a.vx - impulse * nx
							a.vy = a.vy - impulse * ny
							b.vx = b.vx + impulse * nx
							b.vy = b.vy + impulse * ny
						end

						if self.shotActive then
							if a.type == "cue" and b.type ~= "cue" then
								self:recordCueContact(b)
							elseif b.type == "cue" and a.type ~= "cue" then
								self:recordCueContact(a)
							end
						end
					end
				end
			end
		end
	end
end

function gameplay_billiards:sinkBall(ball)
	if ball.sunk then
		return
	end

	ball.sunk = true
	ball.vx = 0
	ball.vy = 0

	if self.turnEvents then
		local shooter = self.turnEvents.shooter
		if ball.type == "cue" then
			self.turnEvents.sankCueBall = true
			self.pendingCueRespawnOwner = self:getOtherOwner(shooter)
		elseif ball.type == "black" then
			self.turnEvents.sankBlackBall = true
		elseif ball.type == "color" then
			local ballOwner = self:getOwnerForGroup(ball.group)
			if ballOwner == shooter then
				self.turnEvents.sankOwnBall = true
			elseif ballOwner ~= nil then
				self.turnEvents.sankOpponentBall = true
			end
		end
	end

	playSound("ball",0.9)
	playPointsSound()
	resetPointPitch()

end

function gameplay_billiards:handleBlackHoleCapture()
	for _, hole in ipairs(self:getBlackHoles()) do
		for _, ball in ipairs(self.balls) do
			if not ball.sunk then
				local dist = length(ball.x - hole.x, ball.y - hole.y)
				if dist <= BLACK_HOLE_RADIUS + BLACK_HOLE_CAPTURE_RADIUS then
					self:sinkBall(ball)
				end
			end
		end
	end
end

function gameplay_billiards:areBallsStill()
	for _, ball in ipairs(self.balls) do
		if not ball.sunk and (math.abs(ball.vx) > 0 or math.abs(ball.vy) > 0) then
			return false
		end
	end
	return true
end

function gameplay_billiards:finishShot()
	if not self.turnEvents then
		self.shotActive = false
		return
	end

	local shooter = self.turnEvents.shooter
	local opponentOwner = self:getOtherOwner(shooter)
	self.messageColor = nil
	self.subMessageColor = nil

	if self.breakShotPending then
		self.breakShotPending = false
		self:removeBlackBallFromPlay()
	end

	if self.pendingCueRespawnOwner then
		self:respawnCueBallForOwner(self.pendingCueRespawnOwner)
		self.pendingCueRespawnOwner = nil
	end

	local winner = self:getWinnerByClearingColors()
	if winner then
		self.winner = winner
		self.message = self:getOwnerLabel(winner) .. " WINS"
		self.subMessage = "CLEARED ALL " .. self:getGroupName(self:getGroupForOwner(winner)) .. " BALLS"
		self.shotActive = false
		self.turnEvents = nil
		return
	end

	self.currentTurn = opponentOwner
	self.turnsRemaining = 1
	self.message = self:getOwnerLabel(opponentOwner) .. " TO SHOOT"
	self.subMessage = ""

	self.aiAimTimer = AI_SHOT_DELAY
	self.shotActive = false
	self.turnEvents = nil
end

function gameplay_billiards:updatePlayerAim()
	if self.currentTurn ~= PLAYER_OWNER or self.shotActive or self.winner then
		self.aiming = false
		self.lastMouseDown = love.mouse.isDown(1)
		return
	end

	local cueBall = self:getCueBall()
	if not cueBall then
		self.lastMouseDown = love.mouse.isDown(1)
		return
	end

	local mouseX, mouseY = love.mouse.getPosition()
	local mouseDown = love.mouse.isDown(1)
	if mouseDown and not self.lastMouseDown then
		self.aiming = true
		self.dragX = mouseX
		self.dragY = mouseY
	end

	if mouseDown and self.aiming then
		self.dragX = mouseX
		self.dragY = mouseY
	elseif not mouseDown and self.lastMouseDown and self.aiming then
		local aimDX = cueBall.x - (self.dragX or mouseX)
		local aimDY = cueBall.y - (self.dragY or mouseY)
		self:applyShotVelocity(PLAYER_OWNER, aimDX, aimDY, length(aimDX, aimDY))
		self.aiming = false
	end

	self.lastMouseDown = mouseDown
end

function gameplay_billiards:updateAI(dt)
	if self.currentTurn ~= ENEMY_OWNER or self.shotActive or self.winner then
		return
	end

	self.aiAimTimer = math.max(0, (self.aiAimTimer or AI_SHOT_DELAY) - dt)
	if self.aiAimTimer == 0 then
		self:takeAIShot()
	end
end

function gameplay_billiards:update(dt)
	local escapeDown = love.keyboard.isDown("escape")
	if escapeDown and not self.escapeWasDown then
		local MenuState = require "src.states.menu"
		state.switch(MenuState)
		return
	end
	self.escapeWasDown = escapeDown

	local restartDown = love.keyboard.isDown("r")
	if restartDown and not self.restartWasDown then
		self:resetMatch()
		return
	end
	self.restartWasDown = restartDown

	if self.waitingToStart then
		if love.keyboard.isDown("space") then
			self.waitingToStart = false
			self.message = "PLAYER TO SHOOT"
			self.subMessage = "PLAYER " .. self:getGroupName(self.playerGroup) .. "  |  AI " .. self:getGroupName(self.enemyGroup)
			self.messageColor = nil
			self.subMessageColor = nil
		end
		return
	end

	if self.winner then
		return
	end

	if self.shotActive then
		self:applyBlackHoleForces(dt)
		self:updateBallMotion(dt)
		self:resolveBallCollisions()
		self:handleBlackHoleCapture()
		if self:areBallsStill() then
			self:finishShot()
		end
		return
	end

	self:updatePlayerAim()
	self:updateAI(dt)
end

function gameplay_billiards:drawBlackHoles()
	local pulse = love.timer.getTime() * 2.2
	for _, hole in ipairs(self:getBlackHoles()) do
		local outerRadius = BLACK_HOLE_RADIUS * 2
		love.graphics.setColor(0, 0, 0, 0.92)
		love.graphics.circle("fill", hole.x, hole.y, BLACK_HOLE_RADIUS)
		love.graphics.setColor(themes.current.secondary[1], themes.current.secondary[2], themes.current.secondary[3], 0.65)
		love.graphics.setLineWidth(4)
		love.graphics.circle("line", hole.x, hole.y, BLACK_HOLE_RADIUS + 4)
		love.graphics.arc("line", hole.x, hole.y, outerRadius, pulse, pulse + math.pi * 1.1, 24)
		love.graphics.arc("line", hole.x, hole.y, outerRadius + 8, pulse + 0.75, pulse + math.pi * 1.55, 24)
	end
end

function gameplay_billiards:drawArena()
	local centerX, centerY, arenaRadius = self:getArena()
	local shooterColor = self:getColorForOwner(self.currentTurn or PLAYER_OWNER)
	love.graphics.setColor(shooterColor)
	love.graphics.setLineWidth(4)
	love.graphics.circle("line", centerX, centerY, arenaRadius)
	self:drawBlackHoles()
end

function gameplay_billiards:drawBall(ball)
	if ball.sunk then
		return
	end

	if ball.type == "cue" then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.circle("fill", ball.x, ball.y, ball.radius)
		love.graphics.setColor(0.15, 0.15, 0.15, 0.55)
		love.graphics.circle("line", ball.x, ball.y, ball.radius)
		return
	end

	if ball.type == "black" then
		love.graphics.setColor(0.05, 0.05, 0.05, 1)
		love.graphics.setLineWidth(3)
		love.graphics.circle("line", ball.x, ball.y, ball.radius)
		love.graphics.setColor(1, 1, 1, 0.95)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", ball.x, ball.y, ball.radius + 2)
		return
	end

	local color = self:getColorForGroup(ball.group)
	love.graphics.setColor(color)
	love.graphics.circle("fill", ball.x, ball.y, ball.radius)
	love.graphics.setColor(1, 1, 1, 0.15)
	love.graphics.circle("line", ball.x, ball.y, ball.radius + 1)
end

function gameplay_billiards:drawBalls()
	for _, ball in ipairs(self.balls) do
		self:drawBall(ball)
	end
end

function gameplay_billiards:drawAimingShip()
	if self.currentTurn ~= PLAYER_OWNER or self.shotActive then
		return
	end

	local cueBall = self:getCueBall()
	if not cueBall then
		return
	end

	local dragX = self.dragX or cueBall.x
	local dragY = self.dragY or cueBall.y
	local aimDX = cueBall.x - dragX
	local aimDY = cueBall.y - dragY
	local aimDist = length(aimDX, aimDY)
	if aimDist < 0.001 then
		local mouseX, mouseY = love.mouse.getPosition()
		aimDX = cueBall.x - mouseX
		aimDY = cueBall.y - mouseY
		aimDist = length(aimDX, aimDY)
		dragX = mouseX
		dragY = mouseY
	end

	if aimDist < 0.001 then
		return
	end

	local clampedDist = clamp(aimDist, 16, MAX_PULL_DISTANCE)
	local nx = aimDX / aimDist
	local ny = aimDY / aimDist
	local guideDist = clampedDist * 0.5
	local guideEndX = cueBall.x + nx * guideDist
	local guideEndY = cueBall.y + ny * guideDist
	local shipX = cueBall.x - nx * clampedDist
	local shipY = cueBall.y - ny * clampedDist
	local angle = angleTo(cueBall.x - shipX, cueBall.y - shipY)
	local color = self:getColorForOwner(PLAYER_OWNER)

	love.graphics.setColor(color[1], color[2], color[3], 0.5)
	love.graphics.setLineWidth(2)
	love.graphics.line(cueBall.x, cueBall.y, shipX, shipY)
	love.graphics.line(cueBall.x, cueBall.y, guideEndX, guideEndY)

	local size = 14
	local noseX = shipX + math.cos(angle) * (size + 4)
	local noseY = shipY + math.sin(angle) * (size + 4)
	local leftX = shipX + math.cos(angle + 2.5) * size
	local leftY = shipY + math.sin(angle + 2.5) * size
	local rightX = shipX + math.cos(angle - 2.5) * size
	local rightY = shipY + math.sin(angle - 2.5) * size

	love.graphics.setColor(color)
	love.graphics.polygon("fill", noseX, noseY, leftX, leftY, rightX, rightY)
end

function gameplay_billiards:drawHud()
	local worldW = love.graphics.getWidth()
	if scorefont then
		love.graphics.setFont(scorefont)
	end

	-- love.graphics.setColor(themes.current.secondary)
	-- love.graphics.printf("PLAYER " .. tostring(self:getRemainingColorCount(PLAYER_OWNER)) .. "  -  " .. tostring(self:getRemainingColorCount(ENEMY_OWNER)) .. " AI", 0, 10, worldW, "center")
	-- love.graphics.printf(self:getOwnerLabel(self.currentTurn) .. " TO SHOOT", 0, 36, worldW, "center")
	-- local messageColor = self.messageColor or themes.current.secondary
	-- love.graphics.setColor(messageColor)
	-- love.graphics.printf(self.message or "", 0, 62, worldW, "center")
	-- if self.subMessage and self.subMessage ~= "" then
	-- 	local subMessageColor = self.subMessageColor or themes.current.secondary
	-- 	love.graphics.setColor(subMessageColor)
	-- 	love.graphics.printf(self.subMessage, 0, 86, worldW, "center")
	-- end
	-- love.graphics.setColor(themes.current.secondary)
	-- local playerColorName = self:getGroupName(self.playerGroup)
	-- local aiColorName = self:getGroupName(self.enemyGroup)
	-- local playerColorTint = self:getColorForGroup(self.playerGroup)
	-- local aiColorTint = self:getColorForGroup(self.enemyGroup)
	-- love.graphics.setColor(playerColorTint)
	-- love.graphics.printf("PLAYER COLOR: " .. playerColorName, 16, 110, worldW * 0.5 - 20, "right")
	-- love.graphics.setColor(aiColorTint)
	-- love.graphics.printf("AI COLOR: " .. aiColorName, worldW * 0.5 + 4, 110, worldW * 0.5 - 20, "left")
	-- love.graphics.setColor(themes.current.secondary)
	--love.graphics.printf("ESC MENU  |  R RESET", 0, love.graphics.getHeight() - 30, worldW, "center")

	if self.waitingToStart then
		local worldH = love.graphics.getHeight()
		if gameoverfont then
			love.graphics.setFont(gameoverfont)
		end
		love.graphics.setColor(themes.current.primary)
		love.graphics.printf("SINK THE " .. tostring(themes.current.primary_name) .. " INTO THE WORMHOLES", 0, worldH * 0.33, worldW, "center")
		love.graphics.setColor(themes.current.secondary)
		love.graphics.printf("PRESS SPACE TO BEGIN", 0, worldH * 0.43, worldW, "center")
		love.graphics.printf("DRAG BACK THE SHIP TO SHOOT", 0, worldH * 0.54, worldW, "center")
		return
	end

	if self.winner then
		local worldH = love.graphics.getHeight()
		if gameoverfont then
			love.graphics.setFont(gameoverfont)
		end
		love.graphics.printf(self.message, 0, worldH * 0.4, worldW, "center")
		if scorefont then
			love.graphics.setFont(scorefont)
		end
		love.graphics.printf("PRESS R TO RESTART", 0, worldH * 0.56, worldW, "center")
	end
end

function gameplay_billiards:draw()
	love.graphics.clear(themes.current.background)
	self:drawArena()
	if not self.waitingToStart then
		self:drawBalls()
		self:drawAimingShip()
	end
	self:drawHud()
	love.graphics.setColor(1, 1, 1, 1)
end

return gameplay_billiards