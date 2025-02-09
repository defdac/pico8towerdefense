pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Constants
local grid_size = 16 -- 128/8 = 16 cells across
local cell_size = 8
local max_waves = 30
local selected_tower = 1
local tower_menu_x = 128 - 32  -- 32 pixels wide menu on right

-- Game states
local game_state = {
    money = 100,
    lives = 20,
    wave = 1,
    enemies = {},
    towers = {},
    particles = {},
    spawn_timer = 0,
    wave_active = false
}

-- Tower Types
local tower_types = {
    {
        name = "wall",
        cost = 5,
        sprite = 1,
        damage = 0,
        range = 0,
        fire_rate = 0,
        description = "blocks enemy path"
    },
    {
        name = "basic",
        cost = 10,
        sprite = 2,
        damage = 1,
        range = 4,
        fire_rate = 30,
        description = "basic tower"
    },
    {
        name = "sniper",
        cost = 25,
        sprite = 3,
        damage = 3,
        range = 8,
        fire_rate = 60,
        description = "long range"
    },
    {
        name = "rapid",
        cost = 15,
        sprite = 4,
        damage = 0.5,
        range = 3,
        fire_rate = 15,
        description = "fast firing"
    },
    {
        name = "splash",
        cost = 30,
        sprite = 5,
        damage = 2,
        range = 3,
        splash = 2,
        fire_rate = 45,
        description = "area damage"
    },
    {
        name = "ice",
        cost = 20,
        sprite = 6,
        damage = 0.5,
        range = 3,
        slow = 0.5,
        fire_rate = 30,
        description = "slows enemies"
    },
    {
        name = "anti_air",
        cost = 35,
        sprite = 7,
        damage = 2,
        range = 5,
        air_only = true,
        fire_rate = 30,
        description = "targets flying"
    },
    {
        name = "poison",
        cost = 40,
        sprite = 8,
        damage = 1,
        range = 3,
        dot = 0.2,
        fire_rate = 45,
        description = "poison damage"
    },
    {
        name = "lightning",
        cost = 45,
        sprite = 9,
        damage = 1.5,
        range = 4,
        chain = 3,
        fire_rate = 40,
        description = "chains damage"
    },
    {
        name = "support",
        cost = 50,
        sprite = 10,
        damage = 0,
        range = 3,
        buff = 1.5,
        fire_rate = 0,
        description = "buffs nearby"
    }
}

-- Enemy types
local enemy_types = {
    -- Basic enemies
    {
        name = "crawler",
        hp = 3,
        speed = 0.5,
        reward = 1,
        sprite = 16,
        flying = false
    },
    {
        name = "runner",
        hp = 2,
        speed = 1,
        reward = 2,
        sprite = 17,
        flying = false
    },
    {
        name = "tank",
        hp = 10,
        speed = 0.3,
        reward = 3,
        sprite = 18,
        flying = false
    },
    -- Flying enemies
    {
        name = "scout",
        hp = 2,
        speed = 0.8,
        reward = 2,
        sprite = 19,
        flying = true
    },
    {
        name = "bomber",
        hp = 4,
        speed = 0.4,
        reward = 3,
        sprite = 20,
        flying = true
    }
    
}

-- Pathfinding functions
function get_neighbors(x, y)
    local neighbors = {}
    local dirs = {{0,1},{1,0},{0,-1},{-1,0}}
    
    for dir in all(dirs) do
        local nx, ny = x + dir[1], y + dir[2]
        if nx >= 1 and nx <= grid_size and
           ny >= 1 and ny <= grid_size and
           not is_blocked(nx, ny) then
            add(neighbors, {nx, ny})
        end
    end
    return neighbors
end

function find_path(start_x, start_y, end_x, end_y)
    local frontier = {}
    local came_from = {}
    local cost_so_far = {}
    
    add(frontier, {start_x, start_y})
    came_from[start_x..","..start_y] = nil
    cost_so_far[start_x..","..start_y] = 0
    
    while #frontier > 0 do
        local current = frontier[1]
        del(frontier, current)
        
        if current[1] == end_x and current[2] == end_y then
            break
        end
        
        for neighbor in all(get_neighbors(current[1], current[2])) do
            local new_cost = cost_so_far[current[1]..","..current[2]] + 1
            local key = neighbor[1]..","..neighbor[2]
            
            if not cost_so_far[key] or new_cost < cost_so_far[key] then
                cost_so_far[key] = new_cost
                add(frontier, neighbor)
                came_from[key] = current
            end
        end
    end
    
    return came_from
end

-- Core game functions
function _init()
    -- initialize game state
    game_state = {
        money = 100,
        lives = 20,
        wave = 1,
        enemies = {},
        towers = {},
        particles = {},
        spawn_timer = 0,
        wave_active = false
    }
end

function _update()
    -- handle tower selection
    if btnp(⬆️) then
        selected_tower = max(1, selected_tower - 1)
    elseif btnp(⬇️) then
        selected_tower = min(#tower_types, selected_tower + 1)
    end
    
    -- handle tower placement
    if btnp(❎) then
        local mouse_x = stat(32)
        local mouse_y = stat(33)
        
        -- check if click is in game area
        if mouse_x < tower_menu_x then
            local grid_x = flr(mouse_x / cell_size)
            local grid_y = flr(mouse_y / cell_size)
            place_tower(grid_x, grid_y, selected_tower)
        end
    end
    
    -- rest of update logic...
    update_towers()
    update_enemies()
    update_particles()
    check_wave_state()
end

function _draw()
    function _draw()
        cls()
        
        -- draw grid (same as before but limit to game area)
        for x=0,grid_size-1 do
            for y=0,grid_size-1 do
                rect(x*cell_size, y*cell_size, 
                     (x+1)*cell_size-1, (y+1)*cell_size-1, 1)
            end
        end
        
        -- draw towers and enemies (same as before)
        for t in all(game_state.towers) do
            spr(tower_types[t.type].sprite, 
                t.x*cell_size, t.y*cell_size)
        end
        
        for e in all(game_state.enemies) do
            spr(enemy_types[e.type].sprite,
                e.x*cell_size, e.y*cell_size)
        end
        
        -- draw tower menu
        rectfill(tower_menu_x, 0, 127, 127, 1)  -- menu background
        
        -- draw tower options
        for i=1,#tower_types do
            local y = (i-1) * 12
            local col = selected_tower == i and 7 or 6
            
            -- tower icon
            spr(tower_types[i].sprite, tower_menu_x + 2, y + 2)
            
            -- tower info
            print(tower_types[i].name, tower_menu_x + 12, y + 2, col)
            print("$"..tower_types[i].cost, tower_menu_x + 12, y + 8, can_afford(i) and col or 8)
            
            -- selection box
            if selected_tower == i then
                rect(tower_menu_x + 1, y + 1, tower_menu_x + 30, y + 11, 7)
            end
        end
        
        -- draw game stats
        print("wave: "..game_state.wave, 2, 2, 7)
        print("$"..game_state.money, 2, 10, 7)
        print("lives: "..game_state.lives, 2, 18, 7)
    end
end

-- tower placement and management
function place_tower(x, y, type)
    if can_afford(type) and not is_blocked(x, y) then
        local tower = {
            x = x,
            y = y,
            type = type,
            cooldown = 0
        }
        add(game_state.towers, tower)
        game_state.money -= tower_types[type].cost
    end
end

function update_towers()
    for t in all(game_state.towers) do
        t.cooldown = max(0, t.cooldown - 1)
        if t.cooldown == 0 then
            fire_tower(t)
        end
    end
end

function fire_tower(tower)
    local tower_data = tower_types[tower.type]
    if tower_data.damage == 0 then return end
    
    -- find target
    local target = find_target(tower)
    if target then
        -- apply damage and effects
        apply_damage(target, tower_data)
        tower.cooldown = tower_data.fire_rate
        
        -- create projectile particle
        add_particle(tower.x, tower.y, target.x, target.y)
    end
end

-- enemy spawning and management
function spawn_enemy(type)
    local enemy = {
        type = type,
        x = 0,
        y = 0,
        hp = enemy_types[type].hp,
        path = nil
    }
    add(game_state.enemies, enemy)
end

function update_enemies()
    for e in all(game_state.enemies) do
        -- update path if needed
        if not e.path then
            e.path = find_path(e.x, e.y, grid_size-1, grid_size-1)
        end
        
        -- move along path
        local next_pos = get_next_position(e)
        if next_pos then
            e.x = next_pos[1]
            e.y = next_pos[2]
        end
        
        -- check if reached end
        if e.x >= grid_size-1 and e.y >= grid_size-1 then
            del(game_state.enemies, e)
            game_state.lives -= 1
        end
    end
end

-- utility functions
function is_blocked(x, y)
    for t in all(game_state.towers) do
        if t.x == x and t.y == y then
            return true
        end
    end
    return false
end

function can_afford(tower_type)
    return game_state.money >= tower_types[tower_type].cost
end

function add_particle(x1, y1, x2, y2)
    add(game_state.particles, {
        x = x1 * cell_size + cell_size/2,
        y = y1 * cell_size + cell_size/2,
        dx = (x2 - x1) * cell_size / 10,
        dy = (y2 - y1) * cell_size / 10,
        life = 10,
        col = 8
    })
end

function update_particles()
    for p in all(game_state.particles) do
        p.x += p.dx
        p.y += p.dy
        p.life -= 1
        if p.life <= 0 then
            del(game_state.particles, p)
        end
    end
end
-->8
function check_wave_state()
    -- check if we need to start a new wave
    if not game_state.wave_active then
        if btnp(🅾️) then  -- press 🅾️ to start wave
            start_wave(game_state.wave)
            game_state.wave_active = true
        end
        return
    end
    
    -- handle enemy spawning during active wave
    if #game_state.enemies == 0 and game_state.spawn_timer <= 0 then
        -- wave completed
        game_state.wave_active = false
        game_state.wave += 1
        game_state.money += 25 + flr(game_state.wave * 1.5)  -- wave completion bonus
        return
    end
    
    -- handle enemy spawning
    if game_state.spawn_timer <= 0 then
        -- determine enemy type based on wave number
        local enemy_pool = {}
        
        -- add basic enemies
        add(enemy_pool, 1)  -- crawler
        if game_state.wave >= 3 then add(enemy_pool, 2) end  -- runner
        if game_state.wave >= 5 then add(enemy_pool, 3) end  -- tank
        
        -- add flying enemies
        if game_state.wave >= 7 then add(enemy_pool, 4) end  -- scout
        if game_state.wave >= 10 then add(enemy_pool, 5) end  -- bomber
        
        -- spawn random enemy from pool
        local enemy_type = enemy_pool[flr(rnd(#enemy_pool)) + 1]
        
        -- apply wave scaling
        local enemy = {
            type = enemy_type,
            x = 0,
            y = 0,
            hp = enemy_types[enemy_type].hp * (1 + game_state.wave * 0.1),
            speed = enemy_types[enemy_type].speed,
            flying = enemy_types[enemy_type].flying,
            reward = enemy_types[enemy_type].reward
        }
        
        add(game_state.enemies, enemy)
        
        -- set spawn timer for next enemy
        game_state.spawn_timer = 60 - min(30, game_state.wave * 2)  -- speeds up spawning in later waves
    else
        game_state.spawn_timer -= 1
    end
end

function start_wave(wave_number)
    -- initialize wave-specific variables
    game_state.spawn_timer = 30
    local num_enemies = 10 + flr(wave_number * 1.5)  -- more enemies in later waves
    
    -- store wave info
    game_state.enemies_remaining = num_enemies
    game_state.wave_active = true
end

-->8
function get_next_position(enemy)
    -- flying enemies move directly toward goal
    if enemy.flying then
        local goal_x, goal_y = grid_size-1, grid_size-1
        local dx = goal_x - enemy.x
        local dy = goal_y - enemy.y
        local dist = sqrt(dx*dx + dy*dy)
        
        if dist < enemy_types[enemy.type].speed then
            return {goal_x, goal_y}
        end
        
        -- normalize and scale by speed
        local speed = enemy_types[enemy.type].speed
        return {
            enemy.x + (dx/dist) * speed,
            enemy.y + (dy/dist) * speed
        }
    end
    
    -- ground enemies follow path from pathfinding
    local current_key = enemy.x..","..enemy.y
    local next_pos = enemy.path[current_key]
    
    if next_pos then
        -- calculate partial movement based on speed
        local dx = next_pos[1] - enemy.x
        local dy = next_pos[2] - enemy.y
        local speed = enemy_types[enemy.type].speed
        
        -- check if enemy has any slowdown effects
        if enemy.slow_factor then
            speed *= enemy.slow_factor
        end
        
        -- move partially toward next grid position
        return {
            enemy.x + dx * speed,
            enemy.y + dy * speed
        }
    end
    
    -- no valid next position found
    return nil
end
-->8
function find_target(tower)
    local tower_data = tower_types[tower.type]
    local best_target = nil
    local closest_dist = tower_data.range * cell_size
    
    for e in all(game_state.enemies) do
        -- check if tower can target this enemy type
        if (tower_data.air_only and not e.flying) or
           (not tower_data.air_only and e.flying) then
            goto continue
        end
        
        -- calculate distance
        local dx = (e.x * cell_size) - (tower.x * cell_size)
        local dy = (e.y * cell_size) - (tower.y * cell_size)
        local dist = sqrt(dx*dx + dy*dy)
        
        -- update closest target
        if dist <= closest_dist then
            -- targeting priority based on enemy progress and health
            local priority = (e.x + e.y) / (grid_size * 2)  -- progress toward goal
            priority += (enemy_types[e.type].hp - e.hp) / enemy_types[e.type].hp  -- damage taken
            
            if not best_target or priority > best_target.priority then
                best_target = {
                    enemy = e,
                    dist = dist,
                    priority = priority
                }
            end
        end
        
        ::continue::
    end
    
    return best_target and best_target.enemy
end
function apply_damage(enemy, tower_data)
    -- apply direct damage
    enemy.hp -= tower_data.damage
    
    -- apply effects
    if tower_data.slow then
        enemy.slow_factor = tower_data.slow
        enemy.slow_duration = 30  -- half second
    end
    
    if tower_data.dot then
        enemy.dot_damage = tower_data.dot
        enemy.dot_duration = 60  -- one second
    end
    
    -- handle splash damage
    if tower_data.splash then
        for e in all(game_state.enemies) do
            local dx = (e.x - enemy.x) * cell_size
            local dy = (e.y - enemy.y) * cell_size
            local dist = sqrt(dx*dx + dy*dy)
            
            if dist <= tower_data.splash * cell_size then
                e.hp -= tower_data.damage * (1 - dist/(tower_data.splash * cell_size))
            end
        end
    end
    
    -- handle chain lightning
    if tower_data.chain then
        local chains = tower_data.chain
        local last_target = enemy
        local hit_enemies = {[enemy]=true}
        
        while chains > 0 do
            local next_target = nil
            local closest_dist = 3 * cell_size -- chain range
            
            for e in all(game_state.enemies) do
                if not hit_enemies[e] then
                    local dx = (e.x - last_target.x) * cell_size
                    local dy = (e.y - last_target.y) * cell_size
                    local dist = sqrt(dx*dx + dy*dy)
                    
                    if dist < closest_dist then
                        next_target = e
                        closest_dist = dist
                    end
                end
            end
            
            if next_target then
                next_target.hp -= tower_data.damage * 0.7  -- reduced chain damage
                hit_enemies[next_target] = true
                last_target = next_target
                add_particle(last_target.x, last_target.y, next_target.x, next_target.y)
            end
            
            chains -= 1
        end
    end
    
    -- check for enemy death
    if enemy.hp <= 0 then
        del(game_state.enemies, enemy)
        game_state.money += enemy_types[enemy.type].reward
    end
end

__gfx__
00000000000600000000000000000000000000000000000000060000000000000000000000000000000600000000000000000000000000000000000000000000
00000000006600600000000000066000000060000066600000600000000000000600000000006600000660000000000000066000000000000000000000000000
00700700006606600000000000666000000060000666660006000660000000000606600000000600006060000060006006606600000000000000000000000000
00077000000060000000000006006000000060000000000006660066000000000666600000000600066066000060060060000060000000000000000000000000
00077000000066000600600006006000666666600066006000006600000000000600600000000600000006000006600060000006000000000000000000000000
00700700000006000556600000666000000060000660666600000000000000000666600000000660000000000006600000000006000000000000000000000000
00000000000000005505000000000000000000000000000000000000006666600000000006666660000000000006600000000006000000000000000000000000
00000000000000000555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000cc00000cc00000000000000800000000000000eee00000020000000000000000000000000000000000000000000000000000000000000000000000000000
00cccc00000000000000000000888080bbbbbb0000e00e0020002000000000000000000000000000000000000000000000000000000000000000000000000000
000c0c00000000000000000000808880b0000bb000eeee0022202000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000bbbb00b00000000000002000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000cc0cc00000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
