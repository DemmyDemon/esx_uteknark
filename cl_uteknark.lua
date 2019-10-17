local table = table
local plantingTargetOffset = vector3(0,2,-3)
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
            --[[
            local plantable, message, where, normal, material = getPlantingLocation(true)
            if not plantable and message then
                debug(_U(message))
            end
            ]]
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
        true, -- bob
        false, -- face camera
        2, -- dunno, lol, 100% cargo cult
        false, -- rotates
        0, 0, -- texture
        false -- Projects/draws on entities
    )
end

Citizen.CreateThread(function()
    local drawDistance = Config.Distance.Draw
    -- drawDistance = 10 -- For testing purposes
    drawDistance = drawDistance * 1.1 -- So they don't fight about it, culling is at a slightly longer range
    while true do
        local waitAt = math.floor(math.sqrt(#activePlants))
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
        if #activePlants > 0 then
            debug(#activePlants,'active plants')
            debug('Closest plant at',closestDistance,'meters')
            if closestDistance <= Config.Distance.Interact then
                DrawIndicator(closestPlant.at, 0, 255, 0, 128)
                debug('Within intraction distance!')
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    local drawDistance = Config.Distance.Draw
    -- drawDistance = 10 -- For testing purposes
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
                SetEntityLodDist(weed, drawDistance)
                table.insert(activePlants, {node=entry, object=weed, at=entry.bounds.location})
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

local testWeedModel = `prop_weed_02`
function testWeed(location)
    if not HasModelLoaded(testWeedModel) then
        RequestModel(testWeedModel)
        while not HasModelLoaded(testWeedModel) do
            Citizen.Wait(0)
        end
    end
    local found, Z = GetGroundZFor_3dCoord(location.x, location.y, location.z, false)
    if found then
        local weed = CreateObject(testWeedModel, location.x, location.y, Z, false, false, false)
        FreezeEntityPosition(weed, true)
        SetEntityCollision(weed, false, true)
        return weed
    end
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
    local offset = (column * Config.Distance.Space)/2
    offset = vector3(-offset, -offset, 5)
    local cursor = origin + offset
    local planted = 0
    while planted < count do
        --[[
        local weed = testWeed(cursor)
        table.insert(activePlants,{object=weed,at=cursor})
        ]]
        local found, Z = GetGroundZFor_3dCoord(cursor.x, cursor.y, cursor.z, false)
        if found then
            octree:insert(vector3(cursor.x, cursor.y, Z), 0.2, {stage=1})
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