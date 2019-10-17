local table = table
local plantingTargetOffset = vector3(0,2,-3)
local rayFlagsLocation = 17
local rayFlagsObstruction = 273

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
            debug('Soil quality:',Config.Soil[material])
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
