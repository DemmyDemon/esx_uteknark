local ENABLED = false
local table = table

local function drawDebugLine(instance,line)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(false)
    SetTextJustification(1)
    SetTextScale(instance.scale, instance.scale)
    SetTextFont(instance.font)
    SetTextOutline()
    AddTextComponentSubstringPlayerName(line)
    DrawText(instance.x,instance.y)
    instance.y = instance.y + instance.lineHeight
end

local debugMethods = {
    add = function (instance,...)
        local numElements = select('#',...)
        local elements = {...}
        local line = ''
        for i=1,numElements do
            local element = tostring(elements[i])
            if i ~= 1 then
                line = line .. ' '
            end
            line = line .. element
        end
        table.insert(instance.buffer,line)
        while #instance.buffer > 25 do
            table.remove(instance.buffer, 1)
        end
    end,
    flush = function(instance)
        if instance.active then
            drawDebugLine(instance, instance.header)
            for i,debugEntry in ipairs(instance.buffer) do
                drawDebugLine(instance,debugEntry)
            end

            instance.y = instance.reset
        end
        instance.buffer = {}
    end,
}

local debugMeta = {
    __call = function(instance,...)
        instance:add(...)
    end,
    __newindex = function(instance, key, value)
        -- Just drop. Ignore. Go away.
    end,
    __index = function(instance,key)
        return instance._methods[key]
    end,
}

debug = {
    active = ENABLED,
    header = '~y~[Debugging '..GetCurrentResourceName()..']',
    x = 0.02,
    y = 0.33,
    reset = 0.33,
    lineHeight = 0.015,
    font = 0,
    scale = 0.25,
    spacing = 0.2,
    buffer = {},
    _methods = debugMethods,
}
setmetatable(debug, debugMeta)

function DebugSphere(where, scale, r, g, b, a)
    scale = scale or 1.0
    r = r or 255
    b = b or 255
    g = g or 255
    a = a or 128
    DrawMarker(
        28, -- type
        where, -- location
        0.0, 0.0, 0.0, -- direction (?)
        0.0, 0.0, 0.0, -- rotation
        scale, scale, scale, -- scale
        r, g, b, a, -- color
        false, -- bob
        false, -- face camera
        2, -- dunno, lol, 100% cargo cult
        false, -- rotates
        0, 0, -- texture
        false -- Projects/draws on entities
    )
end