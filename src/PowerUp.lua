PowerUp = Class{}

x = math.random(10, 400)
function PowerUp:init(powerup)
	self.powerup = powerup

	self.x = x
	self.y = -20
	self.width = 16
	self.height = 16
	self.timer = 0
	self.dy = math.random(50, 60)

end

function PowerUp:update(dt)
	self.y = self.y + self.dy * dt
end

function PowerUp:collides(target)
	if self.x > target.x + target.width or target.x > self.x + self.width then
		return false
	end

	if self.y > target.y + target.height or target.y > self.y + self.height then
		return false
	end

	return true
end

function PowerUp:render()
	love.graphics.draw(gTextures['main'], gFrames['powerups'][self.powerup], self.x, self.y)
end