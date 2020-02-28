local beats = include('lib/libbeats')
local BeatClock = require "beatclock"

local beat_clock

function init_beatclock(bpm)
  beat_clock = BeatClock.new()
  beat_clock.ticks_per_step = 6
  beat_clock.steps_per_beat = 2
  beat_clock.on_select_internal = function() beat_clock:start() end
  beat_clock.on_select_external = function() print("external") end
  beat_clock:start()
  beat_clock:bpm_change(bpm)
  beat_clock:add_clock_params()

  local clk_midi = midi.connect(1)
  clk_midi.event = beat_clock.process_mid

  beat_clock.on_step = function() 
    local beatstep = beat_clock.steps_per_beat * beat_clock.beat + beat_clock.step
    beats.advance_step(beatstep, beat_clock.bpm)
  end
end

function redraw()
  beats:redraw()
end

function init()
  audio.rev_off()
  audio.comp_off()

  local file = _path.dust .. "audio/breaks/BBB_120_BPM_PRO_BREAK_10.wav"
  local bpm = 120

  -- list of which beats contain kicks, so that a Crow trigger can fire every time they hit
  local kicks = { 0, 3, 5, 7 }

  beats.init(file, bpm, kicks)
  beats.add_params()

  init_beatclock(bpm)
end