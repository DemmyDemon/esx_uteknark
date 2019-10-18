local table = table
local plantingTargetOffset = vector3(0,2,-3)
local plantingSpaceAbove = vector3(0,0,Config.Distance.Above)
local rayFlagsLocation = 17
local rayFlagsObstruction = 273
local octree = pOctree(vector3(0,1500,0),vector3(12000,12000,2000)) -- Covers the whole damn map!
local activePlants = {}

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

    if IsPedInAnyVehicle(ped) then
        return false, 'planting_in_vehicle' -- The rest can all nil out
    end

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
                    local hits = octree:searchSphere(hitLocation, Config.Distance.Space)
                    if #hits > 0 then
                        debug('Found another plant too close')
                        if visible then
                            for i, hit in ipairs(hits) do
                                DrawLine(hitLocation, hit.bounds.location, 255, 0, 255, 100)
                            end
                            DebugSphere(hitLocation, 0.1, 255, 0, 255, 100)
                            DrawLine(playerCoord, hitLocation, 255, 0, 255, 100)
                        end
                        return false, 'planting_too_close', hitLocation, surfaceNormal, material
                    else
                        if visible then
                            DebugSphere(hitLocation, 0.1, 0, 255, 0, 100)
                            DrawLine(playerCoord, hitLocation, 0, 255, 0, 100)
                        end
                        local aboveTarget = hitLocation + plantingSpaceAbove
                        local aboveRay = StartShapeTestRay(hitLocation, aboveTarget, rayFlagsObstruction, ped, 7)
                        local _,hitAbove,hitAbovePoint = GetShapeTestResult(aboveRay)
                        if hitAbove == 1 then
                            if visible then
                                debug('Obstructed above')
                                DrawLine(hitLocation, hitAbovePoint, 255, 0, 0, 100)
                                DebugSphere(hitAbovePoint, 0.1, 255, 0, 0, 100)
                            end
                            return false, 'planting_obstructed', hitLocation, surfaceNormal, material
                        else
                            if visible then
                                DrawLine(hitLocation, aboveTarget, 0, 255, 0, 100)
                                DebugSphere(hitAbovePoint, 0.1, 255, 0, 0, 100)
                                debug('~g~planting OK')
                            end
                            return true,'planting_ok', hitLocation, surfaceNormal, material
                        end
                    end
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
            if message then
                debug('Planting message:',_U(message))
            end
            debug:flush()
        end
        Citizen.Wait(0)
    end
end)

function DrawIndicator(location, r, g, b, a)
    local range = Config.Distance.Interact * 0.5
    DrawMarker(
        23, -- type (23 is a fat horizontal ring)
        location + vector3(0,0,0.2),
        0.0, 0.0, 0.0, -- direction (?)
        0.0, 0.0, 0.0, -- rotation
        range, range, range, -- scale
        r, g, b, a, -- color
        false, -- bob
        false, -- face camera
        2, -- dunno, lol, 100% cargo cult
        false, -- rotates
        0, 0, -- texture
        false -- Projects/draws on entities
    )
end

Citizen.CreateThread(function()
    local drawDistance = Config.Distance.Draw
    drawDistance = drawDistance * 1.01 -- So they don't fight about it, culling is at a slightly longer range
    while true do
        if #activePlants > 0 then
            debug(#activePlants,'active plants')
            local myLocation = GetEntityCoords(PlayerPedId())
            local closestDistance
            local closestPlant
            for i,plant in ipairs(activePlants) do
                local distance = #(plant.at - myLocation)
                if distance > drawDistance then
                    DeleteObject(plant.object)
                    plant.node.data.object = nil
                    table.remove(activePlants, i)
                elseif not closestDistance or distance < closestDistance then
                    closestDistance = distance
                    closestPlant = plant
                end
            end
            if closestDistance then
                debug('Closest plant at',closestDistance,'meters')
                if closestDistance <= Config.Distance.Interact then
                    local stage = Growth[closestPlant.stage]
                    debug('Closest pant is stage', closestPlant.stage)
                    DrawIndicator(closestPlant.at + stage.marker.offset, 0, 255, 0, 128)
                    debug('Within intraction distance!')
                end
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    local drawDistance = Config.Distance.Draw
    while true do
        local here = GetEntityCoords(PlayerPedId())
        local hits = octree:searchSphere(here, drawDistance)
        for i,entry in ipairs(hits) do
            if not entry.data.object then
                local stage = entry.data.stage or 1
                local model = Growth[stage].model
                local weed = CreateObject(model, entry.bounds.location, false, false, false)
                local heading = math.random(0,359) * 1.0
                SetEntityHeading(weed, heading)
                FreezeEntityPosition(weed, true)
                SetEntityCollision(weed, false, true)
                SetEntityLodDist(weed, math.floor(drawDistance))
                table.insert(activePlants, {node=entry, object=weed, at=entry.bounds.location, stage=stage})
                entry.data.object = weed
            end
        end
        if #hits > 0 then
            debug(#hits,'octree hits')
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

RegisterCommand('groundmat',function(source, args, raw)
    local plantable, message, where, normal, material = getPlantingLocation(true)
    TriggerEvent("chat:addMessage", {args={'Material', material}})
end, false)

function deleteActivePlants()
    for i,plant in ipairs(activePlants) do
        if DoesEntityExist(plant.object) then
            DeleteObject(plant.object)
        end
    end
    activePlants = {}
end

RegisterCommand('testforest', function(source, args, raw)
    local origin = GetEntityCoords(PlayerPedId())
    local count = 25
    if args[1] and string.match(args[1],'^[0-9]+$') then
        count = tonumber(args[1])
    end
    TriggerEvent("chat:addMessage", {args={'Forest size', count}})
    local column = math.ceil(math.sqrt(count))
    TriggerEvent("chat:addMessage", {args={'Column', column}})
    TriggerEvent("chat:addMessage", {args={'Draw Distance',Config.Distance.Draw}})
    local offset = (column * Config.Distance.Space)/2
    offset = vector3(-offset, -offset, 5)
    local cursor = origin + offset
    local planted = 0
    while planted < count do
        local found, Z = GetGroundZFor_3dCoord(cursor.x, cursor.y, cursor.z, false)
        if found then
            local stage = math.random(1,#Growth)
            octree:insert(vector3(cursor.x, cursor.y, Z), 0.01, {stage=stage})
        end
        cursor = cursor + vector3(0, Config.Distance.Space, 0)
        planted = planted + 1
        if planted % column == 0 then
            Citizen.Wait(0)
            cursor = cursor + vector3(Config.Distance.Space, -(Config.Distance.Space * column), 0)
        end

    end
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        deleteActivePlants()
    end
end)