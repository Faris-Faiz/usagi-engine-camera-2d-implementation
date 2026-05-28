local Camera = require("camera")
local LevelData = usagi.read_json("levels.json")

function _config()
  return { name = "Keyboard Rectangle" }
end

function _init()
  local level = LevelData.levels[1]
  local tile_size = level.tile_size
  local rows = #level.tiles
  local cols = #level.tiles[1]

  State = {
    player = {
      x = 50,
      y = 50,
      w = 32,
      h = 32,
      speed = 2,

      facing = "right",
      moving = false,
      anim_timer = 0,
      anim_frame = 1,

      animations = {
        idle = {1},
        right = {1, 2, 3, 4},
        left = {1, 2, 3, 4},
        up = {33, 34, 35, 36},
        down = {1, 2, 3, 4}
      }
      --color = gfx.COLOR_LIGHT_GRAY
    },

    camera = Camera.new(),

    map = {
      w = cols * tile_size,
      h = rows * tile_size
    },

    level = level
  }
end

function _update(_dt)
  local p = State.player
  p.moving = false

  local cam = State.camera
  local map = State.map

  if input.held(input.LEFT) then
    p.x = p.x - p.speed
    p.facing = "left"
    p.moving = true
  end

  if input.held(input.RIGHT) then
    p.x = p.x + p.speed
    p.facing = "right"
    p.moving = true
  end

  if input.held(input.UP) then
    p.y = p.y - p.speed
    p.facing = "up"
    p.moving = true
  end

  if input.held(input.DOWN) then
    p.y = p.y + p.speed
    p.facing = "down"
    p.moving = true
  end

  if p.moving then
    p.anim_timer = p.anim_timer + _dt

    if p.anim_timer > 0.12 then
      p.anim_timer = 0
      p.anim_frame = p.anim_frame + 1

      local frames = p.animations[p.facing]
      if p.anim_frame > #frames then
        p.anim_frame = 1
      end
    end
  else -- show idle frame
    p.anim_frame = 1
  end

  -- clamp player within map boundaries
  p.x = util.clamp(p.x, 0, map.w - p.w)
  p.y = util.clamp(p.y, 0, map.h - p.h)

  cam:follow(p)
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)

  local p = State.player
  local cam = State.camera
  local level = State.level
  local tile_size = level.tile_size

  for row = 1, #level.tiles do
    local line = level.tiles[row]

    for col = 1, #line do
      local tile = string.sub(line, col, col)

      local sprite_index = level.palette[tile] or 130

      local world_x = (col - 1) * tile_size
      local world_y = (row - 1) * tile_size

      local screen_x, screen_y = cam:to_screen(world_x, world_y)

      gfx.spr(sprite_index, screen_x, screen_y)
    end
  end
  local screen_x, screen_y = cam:to_screen(p.x, p.y)

  -- reposition camera based on parsed player and camera positions from _update function
  ---gfx.rect_fill(screen_x, screen_y, p.w, p.h, p.color)
  local frames = p.animations[p.facing]
  local sprite_index = frames[p.anim_frame]
  local flip_x = p.facing == "left"

  local scale = 2
  local size = usagi.SPRITE_SIZE
  local sheet_cols = 32
  local sx = ((sprite_index - 1) % sheet_cols) * size
  local sy = math.floor((sprite_index - 1) / sheet_cols) * size
  gfx.sspr_ex(
    sx, sy, size, size,
    screen_x, screen_y, size * scale, size * scale,
    flip_x, false, 0, gfx.COLOR_WHITE, 1.0
  )
  gfx.text("Current player position: (" .. p.x .. ", " .. p.y .. ")", 10, 10, gfx.COLOR_WHITE)
end
