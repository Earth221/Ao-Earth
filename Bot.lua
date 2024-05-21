-- Define the bot's basic properties and state
Bot = {
    x = 0,        -- x position
    y = 0,        -- y position
    health = 100, -- initial health
    energy = 100, -- initial energy
    attack_power = 10, -- attack power
    defense_power = 5,  -- defense power
    flee_threshold = 20, -- energy threshold to start fleeing
    map_width = 100, -- example map width
    map_height = 100 -- example map height
}

-- Initialize the bot's position
function Bot:initialize(x, y)
    self.x = x
    self.y = y
end

-- Movement function
function Bot:move(dx, dy)
    self.x = math.max(0, math.min(self.x + dx, self.map_width - 1))
    self.y = math.max(0, math.min(self.y + dy, self.map_height - 1))
end

-- Attack function
function Bot:attack(target)
    if self.energy >= 10 then
        target:take_damage(self.attack_power)
        self.energy = self.energy - 10
    else
        print("Not enough energy to attack")
    end
end

-- Take damage function
function Bot:take_damage(damage)
    local actual_damage = damage - self.defense_power
    if actual_damage > 0 then
        self.health = self.health - actual_damage
    end
    if self.health <= 0 then
        self:die()
    end
end

-- Die function
function Bot:die()
    print("Bot has been eliminated")
end

-- Check if bot is alive
function Bot:is_alive()
    return self.health > 0
end

-- Scan for nearby enemies (stub function for now)
function Bot:scan_for_enemies()
    -- This function would interact with the arena's API to get the positions of other bots
    -- Here we return a list of dummy enemies for the example
    return {
        {x = self.x + 1, y = self.y, health = 50, take_damage = function(d) if type(d) == "number" then print("Dummy enemy took " .. d .. " damage") end end},
        {x = self.x - 1, y = self.y, health = 30, take_damage = function(d) if type(d) == "number" then print("Dummy enemy took " .. d .. " damage") end end},
        {x = self.x, y = self.y + 1, health = 70, take_damage = function(d) if type(d) == "number" then print("Dummy enemy took " .. d .. " damage") end end},
        {x = self.x, y = self.y - 1, health = 90, take_damage = function(d) if type(d) == "number" then print("Dummy enemy took " .. d .. " damage") end end}
    }
end

-- Main decision loop
function Bot:decide()
    while self:is_alive() do
        local enemies = self:scan_for_enemies()
        if #enemies > 0 then
            local target = self:select_weakest_enemy(enemies)
            if self:should_flee() then
                self:flee_from(target)
            else
                self:move_towards(target)
                if self:is_in_attack_range(target) then
                    self:attack(target)
                end
            end
        else
            self:patrol()
        end
    end
end

-- Select the weakest enemy based on health
function Bot:select_weakest_enemy(enemies)
    table.sort(enemies, function(a, b) return a.health < b.health end)
    return enemies[1]
end

-- Move towards the target
function Bot:move_towards(target)
    if self.x < target.x then
        self:move(1, 0)
    elseif self.x > target.x then
        self:move(-1, 0)
    end
    if self.y < target.y then
        self:move(0, 1)
    elseif self.y > target.y then
        self:move(0, -1)
    end
end

-- Check if the target is in attack range
function Bot:is_in_attack_range(target)
    return math.abs(self.x - target.x) <= 1 and math.abs(self.y - target.y) <= 1
end

-- Patrol function (dummy function for now)
function Bot:patrol()
    -- Move in a random direction
    local directions = {{1,0}, {-1,0}, {0,1}, {0,-1}}
    local dir = directions[math.random(1, #directions)]
    self:move(dir[1], dir[2])
end

-- Determine if the bot should flee
function Bot:should_flee()
    return self.energy < self.flee_threshold
end

-- Flee from the enemy
function Bot:flee_from(enemy)
    if self.x < enemy.x then
        self:move(-1, 0)
    elseif self.x > enemy.x then
        self:move(1, 0)
    end
    if self.y < enemy.y then
        self:move(0, -1)
    elseif self.y > enemy.y then
        self:move(0, 1)
    end
end

-- Create and run the bot
bot = Bot
bot:initialize(0, 0)
bot:decide()
