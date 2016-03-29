-- deps

local event = require("event")

local countdown = require("countdown")
local eventbus = require("eventbus")
local digital = require("digital")
local signal = require("signal")

local chat = require("component").chat_box

local devices = require("devices").load("/mtcs/devices/01shabei")

local routes = require("routes")

print("Minecraft 计算机列控系统 2.0")
print("===========================================\n")

local STATION_CODE = "01"
local DURATION = 10

-- X0108B 进路

local X0108B = { state = 0, number = nil }

function X0108B.layout()
  -- 封锁 S0102
  digital.set(devices.LOCK_S0102, false)
  signal.set(devices.C_S0102, signal.aspects.red)

  -- 排列 X0108
  digital.set(devices.LOCK_S0106, true)
  digital.set(devices.LOCK_X0104, false)

  digital.set(devices.CONTROL_R, true)

  digital.set(devices.W0106, true)
  digital.set(devices.W0108, true)

  -- 排列完成
  signal.set(devices.C_X0108, signal.aspects.green)

  chat.say("下行进折返线进路排列完成")
end

function X0108B.open()
  digital.set(devices.LOCK_X0108, true)

  chat.say("下行进折返线进路开放")
end

function X0108B.reset()
  digital.set(devices.LOCK_X0108, false)

  signal.set(devices.C_X0108, signal.aspects.red)

  digital.set(devices.W0106, false)
  digital.set(devices.W0108, false)

  X0108B.state = 0
  X0108B.number = nil
end

-- S0106 进路

local S0106 = { state = 0, number = nil }

function S0106.layout()
  -- 封锁 S0102
  digital.set(devices.LOCK_S0102, false)
  signal.set(devices.C_S0102, signal.aspects.red)

  -- 排列 S0106
  digital.set(devices.W0110, true)
  digital.set(devices.W0112, true)

  -- 排列完成
  signal.set(devices.C_S0106, signal.aspects.green)

  chat.say("折返线进站进路排列完成")
end

function S0106.open()
  digital.set(devices.CONTROL_R, false)

  digital.set(devices.LOCK_X0104, true)
  digital.set(devices.LOCK_S0106, true)

  chat.say("折返线进站进路开放")
end

function S0106.reset()
  digital.set(devices.LOCK_S0106, false)

  signal.set(devices.C_S0106, signal.aspects.red)

  digital.set(devices.W0110, false)
  digital.set(devices.W0112, false)

  S0106.state = 0
  S0106.number = nil
end

----

digital.set(devices.W0102, false)
digital.set(devices.W0104, false)
digital.set(devices.W0106, false)
digital.set(devices.W0108, false)

if (signal.get(devices.S0102) == signal.aspects.green) then
  digital.set(devices.W0110, true)
  digital.set(devices.W0112, true)

  digital.set(devices.CONTROL_R, false)

  digital.set(devices.LOCK_X0104, true)
  digital.set(devices.LOCK_S0106, true)
end

----

-- 上行

digital.set(devices.LOCK_S0101, signal.get(devices.S0101) == signal.aspects.green)
digital.set(devices.LOCK_S0102, signal.get(devices.S0102) == signal.aspects.green)

digital.set(devices.DOOR_S, false)

eventbus.on(devices.S0102, "aspect_changed", function(receiver, aspect)
  -- TODO
end)

local countdown_s = countdown.bind(devices.COUNTDOWN_S, DURATION, function(delayed)
  digital.set(devices.DOOR_S, false)

  if (signal.get(devices.S0101) == signal.aspects.green) then
    digital.set(devices.LOCK_S0101, true)
  end
end)

eventbus.on(devices.DETECTOR_S, "minecart", function(detector, type, en, pc, sc, number, o)
  if (number == nil) then
    return
  end

  if (routes.stops(number, STATION_CODE .. "S")) then
    chat.say(number .. " 上行站内停车")

    digital.set(devices.LOCK_S0101, false)
    countdown_s:start()

    event.timer(2, function()
      digital.set(devices.DOOR_S, true)
    end)

    if (S0106.number == number) then
      S0106.reset()
    end
  end
end)

eventbus.on(devices.S0101, "aspect_changed", function(receiver, aspect)
  if (aspect == signal.aspects.green) then
    countdown_s:go()
  end
end)

-- 下行

digital.set(devices.LOCK_X0103, signal.get(devices.X0103) == signal.aspects.green)
digital.set(devices.LOCK_X0108, signal.get(devices.X0108) == signal.aspects.green)

digital.set(devices.DOOR_X, false)

eventbus.on(devices.X0103, "aspect_changed", function(receiver, aspect)
  digital.set(devices.LOCK_X0103, aspect == signal.aspects.green)
end)

local countdown_x = countdown.bind(devices.COUNTDOWN_X, DURATION, function(delayed)
  digital.set(devices.DOOR_X, false)

  if (X0108B.state == 1) then
    if (signal.get(devices.X0108) == signal.aspects.green) then
      digital.set(devices.LOCK_X0108, true)
    end
  else
    if (signal.get(devices.X0108B) == signal.aspects.green) then
      X0108B.open()
    end
  end
end)

eventbus.on(devices.DETECTOR_X, "minecart", function(detector, type, en, pc, sc, number, o)
  if (number == nil) then
    return
  end

  if (routes.stops(number, STATION_CODE .. "X")) then
    chat.say(number .. " 下行站内停车")

    digital.set(devices.LOCK_X0108, false)
    countdown_x:start()

    event.timer(2, function()
      digital.set(devices.DOOR_X, true)
    end)
  end

  if (routes.stops(number, STATION_CODE .. "R")) then
    X0108B.state = 1
    X0108B.number = number

    if (signal.get(devices.X0108B) == signal.aspects.green) then
      X0108B.layout()
    end
  else
    if (X0108B.state == 0) then
      digital.set(devices.W0106, false)
      digital.set(devices.W0108, false)

      signal.set(devices.C_X0108, signal.get(devices.X0108))
    end
  end

  if (routes.stops(number, STATION_CODE .. "S")) then
    S0106.state = 1
    S0106.number = number
  end
end)

eventbus.on(devices.X0108, "aspect_changed", function(receiver, aspect)
  if (X0108B.state == 0) then
    signal.set(devices.C_X0108, aspect)
    if (aspect == signal.aspects.green) then
      countdown_x:go()
    end
  end
end)

eventbus.on(devices.X0108B, "aspect_changed", function(receiver, aspect)
  if (X0108B.state == 1) then
    signal.set(devices.C_X0108, aspect)
    if (aspect == signal.aspects.green) then
      X0108B.layout()
      countdown_x:go()
    end
  end
end)

-- 折返线

eventbus.on(devices.DETECTOR_X0104, "minecart", function(detector, type, en, pc, sc, number, o)
  if (number == nil) then
    return
  end

  if (X0108B.state == 1) then
    X0108B.reset()
  end

  if (S0106.state == 1) then
    S0106.state = 2

    if (signal.get(devices.S0102) == signal.aspects.green) then
      S0106.layout()
      S0106.open()
      S0106.state = 3
    end
  end
end)

eventbus.on(devices.S0102, "aspect_changed", function(receiver, aspect)
  if (S0106.state == 2) then
    if (aspect == signal.aspects.green) then
      S0106.layout()
      S0106.open()
      S0106.state = 3
    end
  elseif (S0106.state == 3) then
    signal.set(devices.C_S0106, signal.get(devices.S0102))
  else
    -- signal.set(devices.C_S0106, aspect)
    -- digital.set(devices.LOCK_S0102, aspect == signal.aspects.green)
    -- TODO
  end
end)

eventbus.on(chat.address, "chat_message", function(c, user, message)
end)

chat.setName("沙贝")
chat.setDistance(100)
chat.say("系统初始化完毕")

while true do
  eventbus.handle(event.pull())
end
