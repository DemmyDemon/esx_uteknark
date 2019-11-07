local table = table
local plantingTargetOffset = vector3(0,2,-3)
local plantingSpaceAbove = vector3(0,0,Config.Distance.Above)
local rayFlagsLocation = 17
local rayFlagsObstruction = 273
local activePlants = {}

local registerStrings = {
    'status_active',
    'status_passive',
}

for i,entry in ipairs(registerStrings) do
    AddTextEntry('uteknark_'..entry, _U(entry))
end

function interactHelp(stage,action)
    BeginTextCommandDisplayHelp('uteknark_status_active')
    AddTextComponentInteger(stage)
    AddTextComponentInteger(#Growth)
    AddTextComponentSubstringPlayerName(action)
    EndTextCommandDisplayHelp(0, false, false, 1)
end
function passiveHelp(stage,status)
    BeginTextCommandDisplayHelp('uteknark_status_passive')
    AddTextComponentInteger(stage)
    AddTextComponentInteger(#Growth)
    AddTextComponentSubstringPlayerName(status)
    EndTextCommandDisplayHelp(0, false, false, 1)
end

function makeToast(subject,message)
    local dict = 'bkr_prop_weed'
    local icon = 'prop_cannabis_leaf_dprop_cannabis_leaf_a'
    if not HasStreamedTextureDictLoaded(dict) then
        RequestStreamedTextureDict(dict)
        while not HasStreamedTextureDictLoaded(dict) do
            Citizen.Wait(0)
        end
    end

    -- BeginTextCommandThefeedPost("STRING")
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(message)
    --EndTextCommandThefeedPostMessagetext(
    SetNotificationMessage(
        dict, -- texture dict
        icon, -- texture name
        true, -- fade
        0, -- icon type
        'UteKnark', -- Sender
        subject
    )
    --EndTextCommandThefeedPostTicker(
    DrawNotification(
        false, -- important
        false -- has tokens
    )
    SetStreamedTextureDictAsNoLongerNeeded(icon)
end

function serverlog(...)
    TriggerServerEvent('esx_uteknark:log',...)
end

RegisterNetEvent('esx_uteknark:make_toast')
AddEventHandler ('esx_uteknark:make_toast', function(subject,message)
    makeToast(subject, message)
end)


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

    -- TODO: Refactor this *monster*, plx!
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
                    local hits = cropstate.octree:searchSphere(hitLocation, Config.Distance.Space)
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

function GetHeadingFromPoints(a, b)

    if not a or not b then
        return 0.0
    end
    if a.x == b.x and a.y == b.y then
        return 0.0
    end
    if #(a - b) < 1 then
        return 0.0
    end

    local theta = math.atan(b.x - a.x,a.y - b.y)
    if theta < 0.0 then
        theta = theta + (math.pi * 2)
    end
    return math.deg(theta) + 180 % 360
end

local inScenario = false
local WEAPON_UNARMED = `WEAPON_UNARMED`
local lastAction = 0
function RunScenario(name, facing)
    -- Citizen.Trace("Attempting to run scenario "..name.."\n")
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    SetCurrentPedWeapon(playerPed, WEAPON_UNARMED)
    if facing then
        local heading = GetHeadingFromPoints(GetEntityCoords(playerPed), facing)
        SetEntityHeading(playerPed, heading)
        Citizen.Wait(0) -- So it syncs before we start the scenario!
    end
    TaskStartScenarioInPlace(playerPed, name, 0, true)
    inScenario = true
end

RegisterNetEvent('esx_uteknark:attempt_plant')
AddEventHandler ('esx_uteknark:attempt_plant', function()
    -- false, 'planting_too_close', hitLocation, surfaceNormal, material
    local plantable, message, location, _, soil = getPlantingLocation()
    if plantable then
        TriggerServerEvent('esx_uteknark:success_plant', location, soil)
        RunScenario(Config.Scenario.Plant)
        lastAction = GetGameTimer()
    else
        makeToast(_U('planting_text'), _U(message))
    end
end)

function DrawIndicator(location, color)
    local range = 1.0
    DrawMarker(
        6, -- type (6 is a vertical and 3D ring)
        location,
        0.0, 0.0, 0.0, -- direction (?)
        -90.0, 0.0, 0.0, -- rotation (90 degrees because the right is really vertical)
        range, range, range, -- scale
        color[1], color[2], color[3], color[4],
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
        local now = GetGameTimer()
        local playerPed = PlayerPedId()
        
        if inScenario then
            debug('In scenario', inScenario)
            if now >= lastAction + Config.ScenarioTime then
                Citizen.Trace('Clearing scenario\n')
                ClearPedTasks(playerPed)
                inScenario = false
            end
        end
        
        if #activePlants > 0 then
            debug(#activePlants,'active plants')
            local myLocation = GetEntityCoords(playerPed)
            local closestDistance
            local closestPlant
            local closestIndex
            for i,plant in ipairs(activePlants) do
                local distance = #(plant.at - myLocation)
                if not DoesEntityExist(plant.object) then
                    table.remove(activePlants, i)
                elseif distance > drawDistance then
                    DeleteObject(plant.object)
                    plant.node.data.object = nil
                    table.remove(activePlants, i)
                elseif not closestDistance or distance < closestDistance then
                    closestDistance = distance
                    closestPlant = plant
                    closestIndex = i
                end
            end
            if closestDistance and not IsPedInAnyVehicle(playerPed) then
                debug('Closest plant at',closestDistance,'meters')
                if closestDistance <= Config.Distance.Interact then
                    local stage = Growth[closestPlant.stage]
                    debug('Closest plant has ID',closestPlant.id)
                    debug('Closest pant is stage', closestPlant.stage)
                    DrawIndicator(closestPlant.at + stage.marker.offset, stage.marker.color)
                    debug('Within intraction distance!')
                    DisableControlAction(0, 44, true) -- Disable INPUT_COVER, as it's used to destroy plants
                    if now >= lastAction + Config.ActionTime then
                        if IsDisabledControlJustPressed(0, 44) then
                            lastAction = now
                            table.remove(activePlants, closestIndex)
                            DeleteObject(closestPlant.object)
                            TriggerServerEvent('esx_uteknark:remove', closestPlant.id, myLocation)
                            RunScenario(Config.Scenario.Destroy, closestPlant.at)
                            -- FIXME: This causes people to run away!
                            -- AddExplosion(closestPlant.at,24,0.5,true,false,0.0,true)
                        else
                            if stage.interact then
                                interactHelp(closestPlant.stage, _U(stage.label))
                                if IsControlJustPressed(0, 38) then
                                    lastAction = now
                                    TriggerServerEvent('esx_uteknark:frob', closestPlant.id, myLocation)
                                    RunScenario(Config.Scenario.Frob, closestPlant.at)
                                end
                            else
                                passiveHelp(closestPlant.stage, _U(stage.label))
                            end
                        end
                    end
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
        cropstate.octree:searchSphereAsync(here, drawDistance, function(entry)
            if not entry.data.object and not entry.data.deleted then
                local stage = entry.data.stage or 1
                local model = Growth[stage].model
                if not model or not IsModelValid(model) then
                    Citizen.Trace(tostring(model).." is not a valid model!\n")
                    model = `prop_mp_cone_01`
                end
                if not HasModelLoaded(model) then
                    RequestModel(model)
                    local begin = GetGameTimer()
                    while not HasModelLoaded(model) and GetGameTimer() < begin + 2500 do
                        Citizen.Wait(0)
                    end
                end
                local offset = Growth[stage].offset or vector3(0,0,0)
                local weed = CreateObject(model, entry.bounds.location + offset, false, false, false)
                local heading = math.random(0,359) * 1.0
                SetEntityHeading(weed, heading)
                FreezeEntityPosition(weed, true)
                SetEntityCollision(weed, false, true)
                SetEntityLodDist(weed, math.floor(drawDistance))
                table.insert(activePlants, {node=entry, object=weed, at=entry.bounds.location, stage=stage, id=entry.data.id})
                entry.data.object = weed
                --SetModelAsNoLongerNeeded(model)
            end
        end, true)
        Citizen.Wait(1500)
    end
end)


function deleteActivePlants()
    for i,plant in ipairs(activePlants) do
        if DoesEntityExist(plant.object) then
            DeleteObject(plant.object)
        end
    end
    activePlants = {}
end


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        deleteActivePlants()
        if inScenario then
            ClearPedTasksImmediately(PlayerPedId())
        end
    end
end)

RegisterNetEvent('esx_uteknark:toggle_debug')
AddEventHandler ('esx_uteknark:toggle_debug', function()
    if not debug.active then
        serverlog('enabled debugging')
        debug.active = true
    else
        serverlog('disabled debugging')
        debug.active = false
    end
end)

Citizen.CreateThread(function()
    local ready = false
    while true do
        if ready then
            if debug.active then
                local plantable, message, where, normal, material = getPlantingLocation(true)
                if message then
                    debug('Planting message:',_U(message))
                end
                debug:flush()
            end
            Citizen.Wait(0)
        else
            if NetworkIsSessionStarted() then
                ready = true
                cropstate:bulkData()
            else
                Citizen.Wait(100)
            end
        end
    end
end)

-- TODO:  Below are debug/dev functions and shuld be disabled for release!

RegisterCommand('groundmat',function(source, args, raw)
    local plantable, message, where, normal, material = getPlantingLocation(true)
    TriggerEvent("chat:addMessage", {args={'Material', material}})
end, false)

RegisterCommand('toast', function(source, args, raw)
    if #args > 0 then
        makeToast(_U('planting_text'), table.concat(args, " "))
    end
end,false)

RegisterNetEvent('esx_uteknark:test_forest')
AddEventHandler ('esx_uteknark:test_forest',function(count, randomStage)
    local origin = GetEntityCoords(PlayerPedId())
    
    TriggerEvent("chat:addMessage", {args={'UteKnark','Target forest size: '..count}})
    local column = math.ceil(math.sqrt(count))
    TriggerEvent("chat:addMessage", {args={'UteKnark','Column size: '..column}})

    local offset = (column * Config.Distance.Space)/2
    offset = vector3(-offset, -offset, 5)
    local cursor = origin + offset
    local planted = 0
    local forest = {}
    while planted < count do
        local found, Z = GetGroundZFor_3dCoord(cursor.x, cursor.y, cursor.z, false)
        if found then
            local stage = (planted % #Growth) + 1
            if randomStage then
                stage = math.random(#Growth)
            end
            table.insert(forest, {location=vector3(cursor.x, cursor.y, Z), stage=stage})
        end
        cursor = cursor + vector3(0, Config.Distance.Space, 0)
        planted = planted + 1
        if planted % column == 0 then
            Citizen.Wait(0)
            cursor = cursor + vector3(Config.Distance.Space, -(Config.Distance.Space * column), 0)
        end
    end
    TriggerEvent("chat:addMessage", {args={'UteKnark', 'Actual viable locations: '..#forest}})
    TriggerServerEvent('esx_uteknark:test_forest', forest)
end)
