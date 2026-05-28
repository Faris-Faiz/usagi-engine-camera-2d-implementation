local Tilemap = {}
Tilemap.__index = Tilemap

function Tilemap.new(level)
  local rows = #level.tiles
  local cols = #level.tiles[1]
  return setmetatable({
    level     = level,
    tile_size = level.tile_size,
    w         = cols * level.tile_size,
    h         = rows * level.tile_size
  }, Tilemap)
end

function Tilemap:draw(cam)
  for row = 1, #self.level.tiles do
    local line = self.level.tiles[row]
    for col = 1, #line do
      local tile = string.sub(line, col, col)
      local sprite_index = self.level.palette[tile] or 130
      local world_x = (col - 1) * self.tile_size
      local world_y = (row - 1) * self.tile_size
      local screen_x, screen_y = cam:to_screen(world_x, world_y)
      gfx.spr(sprite_index, screen_x, screen_y)
    end
  end
end

return Tilemap
