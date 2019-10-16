local table = table
local plantingTargetOffset = vector3(0,2,-3)
local rayFlagsLocation = 17
local rayFlagsObstruction = 273

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
        -- TODO "permanent message kvp" sort of thing?
    end,
    __index = function(instance,key)
        return instance._methods[key]
    end,
}

local debug = {
    active = true,
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

function flatEnough(surfaceNormal)
    local x = math.abs(surfaceNormal.x)
    local y = math.abs(surfaceNormal.y)
    local z = math.abs(surfaceNormal.z)
    return (
        x <= Config.MaxGroundAngle
        and
        y <= Config.MaxGroundAngle
        and
        z >= 1.0 - Config.MaxGroundAngle
    )
end

function getPlantingLocation(visible)
    local ped = PlayerPedId()
    local playerCoord = GetEntityCoords(ped)
    local target = GetOffsetFromEntityInWorldCoords(ped, plantingTargetOffset)
    local testRay = StartShapeTestRay(playerCoord, target, rayFlagsLocation, ped, 7) -- This 7 is entirely cargo cult. No idea what it does.
    local _, hit, hitLocation, surfaceNormal, material, _ = GetShapeTestResultEx(testRay)

    if hit == 1 then
        debug('Material:', material)
        debug('Hit location:', hitLocation)
        debug('Surface normal:', surfaceNormal)

        if Config.Soil[material] then
            if flatEnough(surfaceNormal) then
                local plantDistance = #(playerCoord - hitLocation)
                debug(plantDistance)
                if plantDistance <= Config.Distance.Interact then
                    if visible then
                        DebugSphere(hitLocation, 0.1, 0, 255, 0, 100)
                        DrawLine(playerCoord, hitLocation, 0, 255, 0, 100)
                        debug('~g~planting OK')
                    end
                    return true,'ok', hitLocation, surfaceNormal, material
                else
                    if visible then
                        DebugSphere(hitLocation, 0.1, 0, 128, 0, 100)
                        DrawLine(playerCoord, hitLocation, 0, 128, 0, 100)
                        debug('Target too far away')
                    end
                    return false, 'planting_too_far', hitLocation, surfaceNormal, material
                end
            else
                if visible then
                    DebugSphere(hitLocation, 0.1, 0, 0, 255, 100)
                    DrawLine(playerCoord, hitLocation, 0, 0, 255, 100)
                    debug('Location too steep')
                end
                return false, 'planting_too_steep', hitLocation, surfaceNormal, material
            end
        else
            if visible then
                debug('Not plantable soil')
                DebugSphere(hitLocation, 0.1, 255, 255, 0, 100)
                DrawLine(playerCoord, hitLocation, 255, 255, 0, 100)
            end
            return false, 'planting_not_suitable_soil', hitLocation, surfaceNormal, material
        end
    else
        if visible then
            debug('Ground not found')
            DrawLine(playerCoord, target, 255, 0, 0, 255)
        end
        return false, 'planting_too_steep', hitLocation, surfaceNormal, material
    end

end

Citizen.CreateThread(function()
    while true do
        if debug.active then
            local plantable, message, where, normal, material = getPlantingLocation(true)
            if not plantable and message then
                debug(_U(message))
            end
            debug:flush()
        end
        Citizen.Wait(0)
    end
end)

RegisterCommand('groundmat',function(source, args, raw)
    local plantable, message, where, normal, material = getPlantingLocation(true)
    TriggerEvent("chat:addMessage", {args={'Material', material}})
end, false)