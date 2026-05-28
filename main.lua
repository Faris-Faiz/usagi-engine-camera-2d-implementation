local Camera  = require("camera")
local Player  = require("player")
local Tilemap = require("tilemap")

local LevelData = usagi.read_json("levels.json")

function _config()
  return { name = "Keyboard Rectangle" }
end

function _init()
  local level = LevelData.levels[1]
  State = {
    player  = Player.new(),
    camera  = Camera.new(),
    tilemap = Tilemap.new(level)
  }
end

function _update(_dt)
  State.player:update(_dt, State.tilemap)
  State.camera:follow(State.player)
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)
  State.tilemap:draw(State.camera)
  State.player:draw(State.camera)
  gfx.text(
    "Current player position: (" .. State.player.x .. ", " .. State.player.y .. ")",
    10, 10, gfx.COLOR_WHITE
  )
end
