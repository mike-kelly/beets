-- MoBeets
-- 0.1.0 @Lemmy
--
-- Forked from
-- Beets
-- 1.1.1 @mattbiddulph
--
-- Probabilistic performance
-- drum loop re-sequencer
--
-- Put one-bar or two-bar WAVs in folders
-- in dust/audio/beets
--
-- K2 : Quantized mute toggle
-- K3 : Instant mute while held
-- Enc2: Switch between Voice 1 and Voice 2
--
-- Use a Grid, or map
-- MIDI controller to params
--
-- thanks to @vcvcvc_val
-- for demo loops!

local ENABLE_CROW = false -- not finished, and may stomp over clock Crow controls if enabled

local Beets = include('lib/libbeets')
local beets_audio_dir = _path.audio .. 'beets'

local Passthrough = include('lib/passthrough')
local Arcify = include('lib/arcify')
local arcify = Arcify.new()

local current_voice = 1
local previous_voice = 1

local beets = Beets.new {softcut_voice_id = 1, current_voice = current_voice}
local beets2 = Beets.new {softcut_voice_id = 2, current_voice = current_voice}

local editing = false
local g = grid.connect()

-- handle grid inputs
g.key = function(x, y, z)
  if params:get('orientation') == 1 then -- horizontal
    if y == 1 then
      -- editing loop start and end in top row
      if current_voice == 1 then
        beets:grid_key(x, y, z)
      else
        beets2:grid_key(x, y, z)
      end
    elseif x < 9 then
      beets:grid_key(x, y, z)
    else
      beets2:grid_key(x - 8, y, z)
    end
  else -- vertical
    if beets.bars_per_loop > 1 or beets2.bars_per_loop > 1 then
      beets.status = 'Horizontal orientation required'
      return
    elseif y < 9 then
      beets:grid_key(x, y, z)
    else
      beets2:grid_key(x, y - 8, z)
    end
  end
end

local function init_crow()
  crow.output[2].action = 'pulse(0.001, 5, 1)'
  crow.output[3].action = 'pulse(0.001, 5, 1)'
  crow.output[4].action = 'pulse(0.001, 5, 1)'
end

local function multibar_loops_in_use()
  return (beets.bars_per_loop > 1 or beets2.bars_per_loop > 1)
end

local function beat()
  while true do
    clock.sync(1 / 2)
    local beatstep = math.floor(clock.get_beats() * 2) % beets.beat_count
    beets:advance_step(beatstep, clock.get_tempo())
    beets2:advance_step(beatstep, clock.get_tempo())
    redraw()
    if current_voice ~= previous_voice then
      g:all(0) -- clear the grid
      previous_voice = current_voice
    end
    if multibar_loops_in_use() == false then
      if params:get('orientation') == 1 then -- horizontal
        beets:drawGridUI(g, 1, 1, current_voice)
        beets2:drawGridUI(g, 9, 1, current_voice)
      else
        beets:drawGridUI(g, 1, 1, current_voice)
        beets2:drawGridUI(g, 1, 9, current_voice)
      end
    else
      beets:drawGridUI(g, 1, 1, current_voice)
      beets2:drawGridUI(g, 9, 1, current_voice)
    end
    g:refresh()
  end
end

function redraw()
  if current_voice == 1 then
    beets:drawUI(multibar_loops_in_use(), current_voice)
  else
    beets2:drawUI(multibar_loops_in_use(), current_voice)
  end
end

function enc(n, d)
  if editing then
    beets:enc(n, d)
  elseif n == 2 then
    current_voice = util.clamp(current_voice + d, 1, 2)
  end
end

function key(n, z)

  --  if n == 1 and z == 1 then
  --    editing = true
  --    beets:edit_mode_begin()
  --  end

  if editing then
    if n == 1 and z == 0 then
      editing = false
      beets:edit_mode_end()
    else
      beets:key(n, z)
    end
  else
    if n == 1 and z == 1 then
      editing = true
      beets:show_edit_screen()
    end
    if n == 2 and z == 0 then
      beets:toggle_mute()
    end
    if n == 3 then
      beets:instant_toggle_mute()
    end
  end
end

function init_beets_dir()
  if util.file_exists(beets_audio_dir) == false then
    util.make_dir(beets_audio_dir)
    local demodir = _path.code .. 'beets/demo-loops'
    if util.file_exists(demodir) then
      for _, dirname in ipairs(util.scandir(demodir)) do
        local from_dir = demodir .. '/' .. dirname
        local to_dir = beets_audio_dir .. '/' .. dirname
        util.make_dir(to_dir)
        util.os_capture('cp ' .. from_dir .. '* ' .. to_dir)
      end
    end
  end
end

function init()
  init_beets_dir()

  params:add_separator('BEETS')

  audio.level_cut_rev(0)

  beets.on_beat = function()
  end
  if ENABLE_CROW then
    beets.on_beat_one = function()
      crow.output[2]()
    end
    beets.on_kick = function()
      crow.output[3]()
    end
    beets.on_snare = function()
      crow.output[4]()
    end
  end

  params:add {
    type = 'option',
    id = 'orientation',
    name = 'Grid orientation',
    options = {'horizontal', 'vertical'},
    action = function(val)
      if val == 1 then
        g:rotation(0)
      else
        g:rotation(3)
      end
      g:all(0) -- clear the grid for a full redraw after orientation change
    end
  }

  beets:add_params(arcify)
  beets2:add_params(arcify)

  params:add_separator('UTILITIES')
  Passthrough.init()
  arcify:add_params()

  clock.run(beat)
  if ENABLE_CROW then
    init_crow()
  end

  beets:start()
  beets2:start()
end
