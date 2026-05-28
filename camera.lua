local Camera = {}
Camera.__index = Camera

function Camera.new()
  return setmetatable({ x = 0, y = 0 }, Camera)
end

function Camera:follow(target)
  self.x = target.x + target.w / 2 - usagi.GAME_W / 2
  self.y = target.y + target.h / 2 - usagi.GAME_H / 2
end

function Camera:to_screen(world_x, world_y)
  return world_x - self.x, world_y - self.y
end

return Camera
