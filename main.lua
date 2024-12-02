local ball = {}
function ball.new(x, y)
    local self = setmetatable({}, {__index = ball})
    self.x = x
    self.y = y
    self.radius = 10
    self.speed = 200
    self.gravity = 9.81*25
    self.weight = 1 + (self.radius / 10)
    self.velocity = {x = 0, y = 0}
    self.bounce = 0.9
    return self
end

local isHeld = false
local held = {}
local balls = {}
local physicsSteps = 5
local dragRadius = 100
local ringFade = 0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function fpsBasedLerp(a, b, t)
    -- use math.exp to make the lerp more smooth
    return lerp(a, b, 1 - math.exp(-t * love.timer.getDelta()))
end

function ball:checkCollisionWithWall()
    -- if ball is in held, don't check wall, instead check mouse bounds
    for i = 1, #held do
        if self == held[i] then
            self:checkCollisionWithDrag()
        end
    end
    if self.x - self.radius < 0 then
        self.x = self.radius
        self.velocity.x = -self.velocity.x * self.bounce
    end
    if self.x + self.radius > love.graphics.getWidth() then
        self.x = love.graphics.getWidth() - self.radius
        self.velocity.x = -self.velocity.x * self.bounce
    end
    if self.y - self.radius < 0 then
        self.y = self.radius
        self.velocity.y = -self.velocity.y * self.bounce
    end
    if self.y + self.radius > love.graphics.getHeight() then
        self.y = love.graphics.getHeight() - self.radius
        self.velocity.y = -self.velocity.y * self.bounce
    end

    -- now act as if the drag is a big ball
    if isHeld then
        local dx = self.x - love.mouse.getX()
        local dy = self.y - love.mouse.getY()
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.radius + dragRadius then
            local normalX = dx / distance
            local normalY = dy / distance
            local overlap = self.radius + dragRadius - distance
            self.x = self.x + overlap / 2 * normalX
            self.y = self.y + overlap / 2 * normalY
            local relativeVelocityX = self.velocity.x
            local relativeVelocityY = self.velocity.y
            local dotProduct = relativeVelocityX * normalX + relativeVelocityY * normalY 
            if dotProduct < 0 then
                local impulse = (2 * dotProduct) / (self.weight)
                self.velocity.x = self.velocity.x - impulse * self.weight * normalX
                self.velocity.y = self.velocity.y - impulse * self.weight * normalY
            end
        end
    end
end

function ball:checkCollisionWithBall(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < self.radius + other.radius then
        local normalX = dx / distance
        local normalY = dy / distance
        local overlap = self.radius + other.radius - distance
        self.x = self.x + overlap / 2 * normalX
        self.y = self.y + overlap / 2 * normalY
        other.x = other.x - overlap / 2 * normalX
        other.y = other.y - overlap / 2 * normalY
        local relativeVelocityX = self.velocity.x - other.velocity.x
        local relativeVelocityY = self.velocity.y - other.velocity.y
        local dotProduct = relativeVelocityX * normalX + relativeVelocityY * normalY 
        if dotProduct < 0 then
            local impulse = (2 * dotProduct) / (self.weight + other.weight)
            self.velocity.x = self.velocity.x - impulse * other.weight * normalX
            self.velocity.y = self.velocity.y - impulse * other.weight * normalY
            other.velocity.x = other.velocity.x + impulse * self.weight * normalX
            other.velocity.y = other.velocity.y + impulse * self.weight * normalY
        end
    end
end

function ball:checkCollisionWithDrag()
    -- treats the drag as a wall, causing it to bounce off
    if self.x - self.radius < love.mouse.getX() - dragRadius then
        self.x = love.mouse.getX() - dragRadius + self.radius
        self.velocity.x = -self.velocity.x * self.bounce
    end
    if self.x + self.radius > love.mouse.getX() + dragRadius then
        self.x = love.mouse.getX() + dragRadius - self.radius
        self.velocity.x = -self.velocity.x * self.bounce
    end
    if self.y - self.radius < love.mouse.getY() - dragRadius then
        self.y = love.mouse.getY() - dragRadius + self.radius
        self.velocity.y = -self.velocity.y * self.bounce
    end
    if self.y + self.radius > love.mouse.getY() + dragRadius then
        self.y = love.mouse.getY() + dragRadius - self.radius
        self.velocity.y = -self.velocity.y * self.bounce
    end
end

function ball:update(dt)
    self.velocity.y = self.velocity.y + self.gravity * self.weight * dt
    self.x = self.x + self.velocity.x * dt
    self.y = self.y + self.velocity.y * dt
    self:checkCollisionWithWall()
end

function ball:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("line", self.x, self.y, self.radius)
end

local function createBall(x, y)
    local x = (x or love.math.random(0, love.graphics.getWidth())) + love.math.random(-1, 1)
    local y = (y or love.math.random(0, love.graphics.getHeight())) + love.math.random(-1, 1)
    table.insert(balls, ball.new(x, y))
end

local function createBallGrid(x, y)
    local rows = 10
    local columns = 10
    -- each ball will be side by size
    local x, y = x or 0, y or 0
    local size = 10
    for i = 1, rows do
        for j = 1, columns do
            createBall(x + j * size, y + i * size)
        end
    end
end

function love.load()
    createBallGrid()
end

function love.update(dt)
    if isHeld then
        ringFade = fpsBasedLerp(ringFade, 1, 15)
    else
        ringFade = fpsBasedLerp(ringFade, 0, 15)
    end
    for i = 1, physicsSteps do
        for i = 1, #balls do
            for j = i + 1, #balls do
                balls[i]:checkCollisionWithBall(balls[j])
            end
        end
    end

    for i = 1, #balls do
        balls[i]:update(dt)

        for j = 1, #held do
            if balls[i] == held[j] then
                local dx = balls[i].x - love.mouse.getX()
                local dy = balls[i].y - love.mouse.getY()
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance > dragRadius then
                    local angle = math.atan2(dy, dx)
                    balls[i].x = love.mouse.getX() + dragRadius * math.cos(angle)
                    balls[i].y = love.mouse.getY() + dragRadius * math.sin(angle)
                end
            end
        end
    end
end

function love.draw()
    for i = 1, #balls do
        balls[i]:draw()
    end

    -- draw drag ring
    love.graphics.setColor(1, 0, 0, ringFade)
    love.graphics.circle("line", love.mouse.getX(), love.mouse.getY(), dragRadius)
    love.graphics.setColor(1, 1, 1, 1)

    -- print fps with border text
    love.graphics.setColor(0, 0, 0)
    for x = -1, 1 do
        for y = -1, 1 do
            love.graphics.print("FPS: " .. love.timer.getFPS() .. "\nPhysics Steps: " .. physicsSteps .. "\nBalls: " .. #balls, 10 + x, 10 + y)
        end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS() .. "\nPhysics Steps: " .. physicsSteps .. "\nBalls: " .. #balls, 10, 10)
end

function love.keypressed(key)
    if key == "space" then
        createBall(love.mouse.getX(), love.mouse.getY())
    elseif key == "c" then
        balls = {}
    elseif key == "g" then
        createBallGrid(love.mouse.getX(), love.mouse.getY())
    elseif key == "up" then
        physicsSteps = physicsSteps + 1
    elseif key == "down" then
        physicsSteps = math.max(1, physicsSteps - 1)
    end
end

function love.mousepressed(x, y, button)
    if button == 2 then
        createBall(x, y)
    elseif button == 1 then
        isHeld = true
        for i = #balls, 1, -1 do
            local ball = balls[i]
            if math.sqrt((ball.x - x)^2 + (ball.y - y)^2) < dragRadius then
                ball.ogX = ball.x
                ball.ogY = ball.y
                table.insert(held, ball)
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        held = {}
        isHeld = false
    end
end

function love.mousemoved(x, y, dx, dy)
    for i = 1, #held do
        held[i].x = held[i].x + dx
        held[i].y = held[i].y + dy
    end
end