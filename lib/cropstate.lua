local onServer = IsDuplicityVersion()
local cropstateMethods = {
    plant = function(instance, location, soil, stage)
        if onServer then
            stage = stage or 1
            MySQL.Async.insert("INSERT INTO `uteknark` (`x`, `y`, `z`, `soil`, `stage`) VALUES (@x, @y, @z, @soil, @stage);",
            {
                ['@x'] = location.x,
                ['@y'] = location.y,
                ['@z'] = location.z,
                ['@soil'] = soil,
                ['@stage'] = stage,
            },
            function(id)
                instance:import(id, location, stage, os.time(), soil)
                TriggerClientEvent('esx_uteknark:planted',-1, id, location, stage)
                verbose('Plant',id,'was planted.')
            end)
        else
            Citizen.Trace("Attempt to cropstate:plant on client. Not going to work.\n")
        end
    end,
    load = function(instance, callback)
        if onServer then
            verbose('Loading...')
            MySQL.Async.fetchAll("SELECT `id`, `stage`, UNIX_TIMESTAMP(`time`) AS `time`, `x`, `y`, `z`, `soil` FROM `uteknark`;", 
            {},
            function(rows)
                Citizen.CreateThread(function()
                    for rownum,row in ipairs(rows) do
                        instance:import(row.id, vector3(row.x, row.y, row.z), row.stage, row.time, row.soil)
                        if rownum % 50 == 0 then
                            Citizen.Wait(0)
                        end
                    end
                    if callback then callback(#rows) end
                    instance.loaded = true
                    verbose('Load complete')
                end)
            end)
        else
            Citizen.Trace("Attempt to cropstate:load on client. Not going to work\n")
        end
    end,
    import = function(instance, id, location, stage, time, soil)
        local success, object = instance.octree:insert(location, 0.01, {id=id, stage=stage, time=time, soil=soil})
        if not success then
            Citizen.Trace(string.format("Uteknark failed to import plant with ID %i into octree\n", id))
        end
        instance.index[id] = object
    end,
    update = function(instance, id, stage)
        local plant = instance.index[id]
        plant.data.stage = stage
        if onServer then
            plant.data.time = os.time()
            MySQL.Async.execute("UPDATE `uteknark` SET `stage` = @stage WHERE `id` = @id LIMIT 1;",
            {
                ['@id'] = id,
                ['@stage'] = stage,
            }, function(_)
                TriggerClientEvent('esx_uteknark:update', -1, id, stage)
                verbose('Set plant',id,'to stage',stage)
            end)
        elseif plant.data.object then
            if DoesEntityExist(plant.data.object) then
                DeleteObject(plant.data.object)
            end
            plant.data.object = nil
        end
    end,
    remove = function(instance, id, withPyro)
        local object = instance.index[id]
        local location = object.bounds.location
        object.data.deleted = true
        if object.node then
            -- NOTE: In rare cases the node is being re-assigned while a remove is happening.
            -- This cases `node` to be nil here, crashing the script.
            -- Technically this is a memory leak because the object will then exist in the reflowed node.
            -- It's not a real problem, however, as it's exceedingly rare and not even a whole kilobyte.
            -- The object will still get deleted, and is not propagated to clients, so it's just a data ghost.
            object.node:remove(object.oindex)
        end
        instance.index[id] = nil
        if onServer then
            MySQL.Async.execute("DELETE FROM `uteknark` WHERE `id` = @id LIMIT 1;",
            { ['@id'] = id },
            function()
                TriggerClientEvent('esx_uteknark:removePlant', -1, id)
                if withPyro then
                    TriggerClientEvent('esx_uteknark:pyromaniac', -1, location)
                end
                verbose('Removed plant',id)
            end)
        else
            if object.data.object then
                if DoesEntityExist(object.data.object) then
                    DeleteObject(object.data.object)
                end
                object.data.object = nil
            end
        end
    end,
    bulkData = function(instance, target)
        if onServer then
            verbose('Preparing bulk plant data for player',target)
            target = target or -1
            while not instance.loaded do
                Citizen.Wait(1000)
            end
            local forest = {}
            for id, plant in pairs(instance.index) do
                if type(id) == 'number' then -- Because there is a key called `hashtable`!
                    table.insert(forest, {id=id, location=plant.bounds.location, stage=plant.data.stage})
                end
            end
            TriggerClientEvent('esx_uteknark:bulk_data', target, forest)
        else
            TriggerServerEvent('esx_uteknark:request_data')
        end
    end,
}

local cropstateMeta = {
    __newindex = function(instance, key, value)
        -- Do I even need this?
    end,
    __index = function(instance, key)
        return instance._methods[key]
    end,
}

cropstate = {
    index = {
        hashtable = true, -- To *force* lua to make it a hashtable rather than an array.
    },
    octree = pOctree(vector3(0,1500,0),vector3(12000,13000,2000)),
    loaded = false,
    _methods = cropstateMethods,
}

setmetatable(cropstate,cropstateMeta)

if onServer then
    RegisterNetEvent('esx_uteknark:request_data')
    AddEventHandler ('esx_uteknark:request_data', function()
        cropstate:bulkData(source)
    end)
    
    RegisterNetEvent('esx_uteknark:remove')
    AddEventHandler ('esx_uteknark:remove', function(plantID, nearLocation)
        local src = source
        local plant = cropstate.index[plantID]
        if plant then
            local plantLocation = plant.bounds.location
            local distance = #( nearLocation - plantLocation)
            if distance <= Config.Distance.Interact then
                cropstate:remove(plantID, true)
                makeToast(src, _U('interact_text'), _U('interact_destroyed'))
                doScenario(src, 'Destroy', plantLocation)
            else
                Citizen.Trace(GetPlayerName(src)..' ('..src..') is too far away from '..plantID..' to remove it ('..distance'm)\n')
            end
        else
            Citizen.Trace(GetPlayerName(src)..' ('..src..') tried to remove plant '..plantID..': That plant does not exist!\n')
            TriggerClientEvent('esx_uteknark:remove', src, plantID)
        end
    end)

    RegisterNetEvent('esx_uteknark:frob')
    AddEventHandler ('esx_uteknark:frob', function(plantID, nearLocation)
        local src = source
        local plant = cropstate.index[plantID]
        if plant then
            local plantLocation = plant.bounds.location
            local distance = #( nearLocation - plantLocation)
            if distance <= Config.Distance.Interact then
                local stageData = Growth[plant.data.stage]
                if stageData.interact then
                    if stageData.yield then
                        local yield = math.random(Config.Yield[1], Config.Yield[2])
                        local seeds = math.random(Config.YieldSeed[1], Config.YieldSeed[2])
                        if GiveItem(src, Config.Items.Product, yield) then
                            cropstate:remove(plantID)
                            doScenario(src, 'Frob', plantLocation)
                            if seeds > 0 and GiveItem(src, Config.Items.Seed, seeds) then
                                makeToast(src, _U('interact_text'), _U('interact_harvested', yield, seeds))
                            else
                                makeToast(src, _U('interact_text'), _U('interact_harvested', yield, 0))
                            end
                        else
                            makeToast(src, _U('interact_text'), _U('interact_full', yield))
                        end
                    else
                        if #Growth > plant.data.stage then
                            if not Config.Items.Tend or TakeItem(src, Config.Items.Tend) then
                                makeToast(src, _U('interact_text'), _U('interact_tended'))
                                cropstate:update(plantID, plant.data.stage + 1)
                                doScenario(src, 'Frob', plantLocation)
                            else
                                makeToast(src, _U('interact_text'), _U('interact_missing_item'))
                            end
                        end
                    end
                else
                    Citizen.Trace(GetPlayerName(src)..' ('..src..') tried to frob plant '..plantID..': That plant is in a non-frobbable stage!\n')
                end
            else
                Citizen.Trace(GetPlayerName(src)..' ('..src..') is too far away from '..plantID..' to frob it ('..distance'm)\n')
            end
        else
            Citizen.Trace(GetPlayerName(src)..' ('..src..') tried to frob plant '..plantID..': That plant does not exist!\n')
        end
    end)

else
    RegisterNetEvent('esx_uteknark:bulk_data')
    AddEventHandler ('esx_uteknark:bulk_data', function(forest)
        for i, plant in ipairs(forest) do
            cropstate:import(plant.id, plant.location, plant.stage)
        end
        cropstate.loaded = true
    end)

    RegisterNetEvent('esx_uteknark:planted')
    AddEventHandler ('esx_uteknark:planted', function(id, location, stage)
        cropstate:import(id, location, stage)
    end)
    
    RegisterNetEvent('esx_uteknark:update')
    AddEventHandler ('esx_uteknark:update', function(plantID, stage)
        cropstate:update(plantID, stage)
    end)

    RegisterNetEvent('esx_uteknark:removePlant')
    AddEventHandler ('esx_uteknark:removePlant', function(plantID)
        cropstate:remove(plantID)
    end)
end
