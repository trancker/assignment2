--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
local TIMER = math.random(10, 30)
local multiplyball = 2
local KEY = false
local hasKEY = false

function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.level = params.level
    self.powerup = PowerUp(9)
    self.gotKey = params.gotKey

    k = PowerUp(10)

    self.recoverPoints = 5000
    self.balls = {}

    -- give ball random starting velocity
    params.ball.dx = math.random(-200, 200)
    params.ball.dy = math.random(-50, -60)
    self.balls[1] = params.ball

    if self.level % 5 == 0 then
        KEY = true
        if self.gotKey == true or self.gotKey == false then
            hasKEY = self.gotKey
        end
    end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    if not hasKEY then
        if KEY then
            k.timer = k.timer + dt
            if k.timer > TIMER * 1.5 then
                k:update(dt)
            end
        end
    end

    if k:collides(self.paddle) or hasKEY then
        k.y = 14
        k.x = VIRTUAL_WIDTH - 20
        k.dy = 0
        hasKEY = true
    end

    self.gotKey = hasKEY

    if k.y > VIRTUAL_HEIGHT then
        k.y = -20
        k.x = math.random(10, 400)
        k.timer = 0
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    self.powerup.timer = self.powerup.timer + dt
    if self.powerup.timer > TIMER then
        self.powerup:update(dt)
    end

    if self.powerup:collides(self.paddle) then
        self.powerup.y = -20
        self.powerup.timer = 0
        if multiplyball < 1 then
            self.powerup.dy = 0
        end
        local numofballs = #self.balls
        for i = numofballs + 1, math.min(50, numofballs + 2) do
            local ball = Ball()
            ball.skin = math.random(7)
            ball.x = self.paddle.x + (self.paddle.width / 2) - 4
            ball.y = self.paddle.y - 8
            ball.dx = math.random(-200, 200)
            ball.dy = math.random(-50, -60)
            self.balls[i] = ball
        end
        multiplyball = multiplyball - 1
    end

    if (self.powerup.y > VIRTUAL_HEIGHT or self.powerup:collides(self.paddle)) and multiplyball > 1 then
        self.powerup.y = -20
        self.powerup.x = math.random(10, 400)
        self.powerup.timer = 0
        multiplyball = multiplyball - 1
    end

    for i = #self.balls, 1, -1 do
        self.balls[i]:update(dt)
        if self.balls[i]:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            self.balls[i].y = self.paddle.y - 8
            self.balls[i].dy = -self.balls[i].dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if self.balls[i].x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                self.balls[i].dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.balls[i].x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif self.balls[i].x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                self.balls[i].dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.balls[i].x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            if brick.unbreakablebrick then
                if hasKEY then
                    brick.unbreakablebrick = false
                    brick.color = brick.color - 1
                    brick.tier = math.random(3)
                end
            end

            -- only check collision if we're in play
            if brick.inPlay and self.balls[i]:collides(brick) then

                if not brick.unbreakablebrick then

                    if brick.cantbreak then
                        self.score = self.score + (brick.tier * 200 + brick.color * 25) + 250
                    else
                        -- add to score
                        self.score = self.score + (brick.tier * 200 + brick.color * 25)
                    end

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    self.paddle:increase()

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.balls[i],
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if self.balls[i].x + 2 < brick.x and self.balls[i].dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.balls[i].dx = -self.balls[i].dx
                    self.balls[i].x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif self.balls[i].x + 6 > brick.x + brick.width and self.balls[i].dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.balls[i].dx = -self.balls[i].dx
                    self.balls[i].x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif self.balls[i].y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    self.balls[i].dy = -self.balls[i].dy
                    self.balls[i].y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    self.balls[i].dy = -self.balls[i].dy
                    self.balls[i].y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(self.balls[i].dy) < 150 then
                    self.balls[i].dy = self.balls[i].dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
        if self.balls[i].y >= VIRTUAL_HEIGHT then
            gSounds['hurt']:play()
            table.remove(self.balls, i)
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if #self.balls < 1 then
        self.health = self.health - 1

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            self.paddle:decrease()
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints,
                size = size,
                gotKey = self.gotKey
            })
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    if KEY then
        k:render()
    end
    -- render bricks
    if self.level >= 5 then
        self.powerup:render()
    end

    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, ball in pairs(self.balls) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end