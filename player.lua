local Player = {}
Player.__index = Player

function Player.new()
  return setmetatable({
    x = 50, y = 50, w = 32, h = 32, speed = 2,
    facing = "right", moving = false,
    anim_timer = 0, anim_frame = 1,
    animations = {
      idle  = {1},
      right = {1, 2, 3, 4},
      left  = {1, 2, 3, 4},
      up    = {33, 34, 35, 36},
      down  = {1, 2, 3, 4}
    }
  }, Player)
end

function Player:update(dt, map)
  self.moving = false

  if input.held(input.LEFT)  then self.x = self.x - self.speed; self.facing = "left";  self.moving = true end
  if input.held(input.RIGHT) then self.x = self.x + self.speed; self.facing = "right"; self.moving = true end
  if input.held(input.UP)    then self.y = self.y - self.speed; self.facing = "up";    self.moving = true end
  if input.held(input.DOWN)  then self.y = self.y + self.speed; self.facing = "down";  self.moving = true end

  if self.moving then
    self.anim_timer = self.anim_timer + dt
    if self.anim_timer > 0.12 then
      self.anim_timer = 0
      self.anim_frame = self.anim_frame + 1
      local frames = self.animations[self.facing]
      if self.anim_frame > #frames then self.anim_frame = 1 end
    end
  else
    self.anim_frame = 1
  end

  self.x = util.clamp(self.x, 0, map.w - self.w)
  self.y = util.clamp(self.y, 0, map.h - self.h)
end

function Player:draw(cam)
  local screen_x, screen_y = cam:to_screen(self.x, self.y)
  local frames = self.animations[self.facing]
  local sprite_index = frames[self.anim_frame]
  local flip_x = self.facing == "left"
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
end

return Player
