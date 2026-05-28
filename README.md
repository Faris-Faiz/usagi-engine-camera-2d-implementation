# 2D Camera Implementation — Usagi Dev

A top-down 2D game demonstrating a camera that follows the player across a tile-based map. Built with the [Usagi Dev](https://usagi.gg) engine using Lua.

---

## Project Structure

```
camera-2d-implementation/
├── main.lua          -- entry point; wires modules into the game loop
├── camera.lua        -- reusable camera that follows any target
├── player.lua        -- player state, movement, animation, and drawing
├── tilemap.lua       -- loads and draws a tile-based level
├── sprites.png       -- sprite sheet (32 columns of 16×16 sprites)
├── data/
│   └── levels.json   -- tile map definition for "Garden"
└── meta/
    └── usagi.lua     -- type stubs for IDE autocompletion (not runtime code)
```

---

## How the Usagi Engine Works

Usagi calls four special functions that you define in `main.lua`. You never call them yourself — the engine drives them:

| Function | When it runs |
|---|---|
| `_config()` | Once at startup, before anything loads. Return a table of settings. |
| `_init()` | Once after config, when the game is ready. Set up your initial state here. |
| `_update(dt)` | Every frame. `dt` is delta time — seconds since the last frame. Move things here. |
| `_draw(dt)` | Every frame, after update. Draw everything here. Never mutate state here. |

`State` is a plain Lua global table used to hold everything alive between frames. Usagi doesn't impose any structure on it — it's just a convenient place to keep your game objects.

---

## `main.lua` — The Game Loop

```lua
local Camera  = require("camera")
local Player  = require("player")
local Tilemap = require("tilemap")

local LevelData = usagi.read_json("levels.json")
```

`require` loads a Lua module from a file in the project root. `usagi.read_json` reads the level file once at startup and returns it as a Lua table — not every frame, just once.

```lua
function _config()
  return { name = "Keyboard Rectangle" }
end
```

Sets the window title. This runs before anything else.

```lua
function _init()
  local level = LevelData.levels[1]
  State = {
    player  = Player.new(),
    camera  = Camera.new(),
    tilemap = Tilemap.new(level)
  }
end
```

Creates one instance of each module. `State` becomes the single source of truth for the whole game. Notice that `main.lua` doesn't know anything about _how_ these objects work — it just creates them and stores them.

```lua
function _update(_dt)
  State.player:update(_dt, State.tilemap)
  State.camera:follow(State.player)
end
```

Each frame: move the player first (which also clamps it to the map), then move the camera to catch up. Order matters — if you followed before updating, the camera would always be one frame behind.

```lua
function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)
  State.tilemap:draw(State.camera)
  State.player:draw(State.camera)
  gfx.text(
    "Current player position: (" .. State.player.x .. ", " .. State.player.y .. ")",
    10, 10, gfx.COLOR_WHITE
  )
end
```

Drawing order is back-to-front: clear the screen, draw the map, draw the player on top, then draw the HUD text last so it's never covered. The camera is passed into every draw call because both the map and the player need it to convert their world positions into screen positions.

---

## `camera.lua` — Following the Player

### The core idea: world space vs screen space

Every object in the game lives in **world space** — coordinates relative to the map origin (0, 0). The screen is only 320×180 pixels, but the map is 512×320 pixels, so you can't draw everything at its world position directly. The camera tracks which part of the world is currently visible and converts world positions to **screen positions** before drawing.

```lua
local Camera = {}
Camera.__index = Camera
```

This is the Lua pattern for creating objects. `Camera` is a plain table that acts as the "class". Setting `Camera.__index = Camera` means that when you do `cam:follow(...)`, Lua looks up `follow` on the `Camera` table automatically — this is Lua's way of doing method inheritance.

```lua
function Camera.new()
  return setmetatable({ x = 0, y = 0 }, Camera)
end
```

`Camera.new()` creates a new camera object starting at world position (0, 0). `setmetatable` links the new table to `Camera` so it inherits all the methods. The `.` (not `:`) means this is a constructor — it doesn't receive a `self`.

```lua
function Camera:follow(target)
  self.x = target.x + target.w / 2 - usagi.GAME_W / 2
  self.y = target.y + target.h / 2 - usagi.GAME_H / 2
end
```

This is the heart of the camera. It answers the question: "where in the world should the top-left corner of the screen be, so that `target` appears centered?"

Step by step:
- `target.x + target.w / 2` — the center of the target in world space (e.g. player's center X)
- `- usagi.GAME_W / 2` — subtract half the screen width to shift from "centered on target" to "top-left corner of what's visible"

So if the player's center is at world X=200 and the screen is 320px wide, `cam.x` becomes `200 - 160 = 40`. That means the left edge of the visible area starts at world X=40, putting the player in the middle of the screen.

```lua
function Camera:to_screen(world_x, world_y)
  return world_x - self.x, world_y - self.y
end
```

Converts any world position to a screen position by subtracting the camera offset. If the camera's top-left is at world X=40, then an object at world X=100 appears at screen X=60. Every object that gets drawn uses this.

---

## `player.lua` — State, Input, Animation, Drawing

### State

```lua
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
```

The player starts at world position (50, 50) with a 32×32 hitbox. `speed = 2` means it moves 2 pixels per frame — deliberately simple and frame-rate-dependent for a prototype.

The `animations` table maps a facing direction to a list of **sprite indices** into the sprite sheet. `facing = "right"` uses frames `{1, 2, 3, 4}` and `facing = "up"` uses `{33, 34, 35, 36}` (the third row of the sheet, since each row has 32 sprites). `facing = "left"` uses the same frames as `"right"` but will be drawn mirrored — see the draw section.

### Movement and animation

```lua
function Player:update(dt, map)
  self.moving = false

  if input.held(input.LEFT)  then self.x = self.x - self.speed; self.facing = "left";  self.moving = true end
  if input.held(input.RIGHT) then self.x = self.x + self.speed; self.facing = "right"; self.moving = true end
  if input.held(input.UP)    then self.y = self.y - self.speed; self.facing = "up";    self.moving = true end
  if input.held(input.DOWN)  then self.y = self.y + self.speed; self.facing = "down";  self.moving = true end
```

`self.moving` resets to `false` at the start of every frame, then gets set to `true` only if a key is currently held. `input.held` checks if a key is being held down right now (not just pressed this frame), which is what you want for continuous movement.

```lua
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
```

The animation timer accumulates real time (in seconds). When it exceeds 0.12 seconds (~8 fps), it resets and advances `anim_frame` by one. This makes the animation speed independent of the game's frame rate — it always ticks at the same real-world speed regardless of how fast the game is running. When the player stops, `anim_frame` snaps back to 1 (the idle/first frame).

```lua
  self.x = util.clamp(self.x, 0, map.w - self.w)
  self.y = util.clamp(self.y, 0, map.h - self.h)
end
```

After moving, clamp the player inside the map. `map.w - self.w` is the rightmost valid X position — the player's left edge can go no further right than one player-width from the map's right edge, so it never visually exits the map.

### Drawing from a sprite sheet

```lua
function Player:draw(cam)
  local screen_x, screen_y = cam:to_screen(self.x, self.y)
  local frames = self.animations[self.facing]
  local sprite_index = frames[self.anim_frame]
  local flip_x = self.facing == "left"
```

First, convert world position to screen position. Then look up which sprite index to use for the current facing direction and animation frame. `flip_x` is `true` when facing left — rather than drawing a separate set of left-facing sprites, the right-facing sprites are mirrored horizontally. This halves the number of sprites needed.

```lua
  local scale = 2
  local size = usagi.SPRITE_SIZE   -- 16 (pixels per sprite on the sheet)
  local sheet_cols = 32            -- the sheet is 32 sprites wide

  local sx = ((sprite_index - 1) % sheet_cols) * size
  local sy = math.floor((sprite_index - 1) / sheet_cols) * size
```

The sprite sheet is a grid. To find where sprite N lives on it:
- Subtract 1 because sprite indices start at 1 but grid math starts at 0
- `% sheet_cols` gives the column (wraps around every 32 sprites)
- `math.floor(/ sheet_cols)` gives the row
- Multiply by `size` (16) to get pixel coordinates on the sheet

So sprite index 1 is at (0, 0), index 32 is at (496, 0), index 33 is at (0, 16) — the start of the second row.

```lua
  gfx.sspr_ex(
    sx, sy, size, size,               -- source: where on the sheet, how big
    screen_x, screen_y, size * scale, size * scale,  -- dest: where on screen, drawn at 2×
    flip_x, false, 0, gfx.COLOR_WHITE, 1.0           -- flip, rotation, tint, opacity
  )
end
```

`gfx.sspr_ex` copies a region from the sprite sheet to the screen, scaling and optionally flipping it. The sprite is drawn at `32×32` pixels on screen (`16 * 2`) even though it's `16×16` on the sheet — the `scale = 2` makes it crisply doubled for a pixel-art look.

---

## `tilemap.lua` — Loading and Drawing the Level

### The level format

`data/levels.json` defines the map as an array of strings — one string per row, one character per tile:

```json
"tiles": [
  "11111111111111111111111111111111",
  "1..............................1",
  "1....2222..............444.....1",
  ...
]
```

Each character is a key into the `palette`, which maps it to a sprite index:

```json
"palette": { "1": 97, "2": 98, ".": 130, ... }
```

So `"1"` draws sprite 97 (a wall), `"."` draws sprite 130 (ground), and so on. This ASCII representation makes the map easy to read and edit by hand.

### Construction

```lua
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
```

`w` and `h` are pre-computed here so anything that needs the map's total pixel size (like the player's boundary clamping) can just read `map.w` and `map.h` without recalculating every frame. `#level.tiles` is the number of rows; `#level.tiles[1]` is the length of the first string, which gives the number of columns.

### Drawing

```lua
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
```

Iterates every tile in the grid. For each one:
1. `string.sub(line, col, col)` extracts the single character at that column
2. The palette lookup finds the sprite index (`or 130` is a fallback to the ground tile for any unmapped characters)
3. `(col - 1) * tile_size` converts the grid position to a world pixel position (subtract 1 because Lua arrays start at 1, not 0)
4. `cam:to_screen(...)` converts to screen space before drawing

All tiles are drawn every frame regardless of whether they're on screen. For a map this size (32×20 = 640 tiles) that's fine. Culling off-screen tiles would be an optimisation for much larger maps.

---

## How the Pieces Connect

```
_update each frame:
  player:update(dt, tilemap)   -- player moves, clamps against tilemap.w / tilemap.h
  camera:follow(player)        -- camera re-centers on player's new position

_draw each frame:
  tilemap:draw(camera)         -- each tile: world pos → camera:to_screen → gfx.spr
  player:draw(camera)          -- player: world pos → camera:to_screen → gfx.sspr_ex
```

The camera is the shared bridge. Neither the tilemap nor the player knows about each other — they both just accept a camera and ask it to translate their positions. This means any of these three modules can be dropped into a different project independently.
