Config = {
    Locale = 'en-US',
    Distance = { -- All distances in meters
        Draw = 150.0,   -- How close to a plant do you need to be to see it?
        Interact = 1.5, -- How close do you need to be to interact?
        Space = 1.2,    -- How far apart do the plants need to be planted?
        Above = 5.0,    -- How much clear space above the planting space do you need to plant?
    },
    ActionTime = 10000,   -- How many milliseconds does an action take (planting, destroying, harvesting, tending)
    ScenarioTime = 3000,  -- How long should the scenario/animations run?
    MaxGroundAngle = 0.6, -- How tilted can the ground be and still hold plants?
    Items = { -- What items are used?
        Seed = 'weed_seed',     -- Used to plant the weed
        Tend = nil,             -- Optional item to progress growth cycle
        Product = 'weed_pooch', -- What item is given when you harvest?
    },
    Scenario = {
        Plant = 'WORLD_HUMAN_GARDENER_PLANT',
        Frob = 'PROP_HUMAN_BUM_BIN',
        Destroy = 'WORLD_HUMAN_STAND_FIRE',
    },
    Yield = {5,10}, -- How many Items.Product does each plant yield? {5,10} means "from 5 to 10, inclusive"
    YieldSeed = {0,1}, -- Same as Yield, except for the amount of seeds you get back
    TimeMultiplier = 1.0, -- Multiplier for the growth/tend times
    Soil = {
        -- What soil types can you grow on, and what are their multiplers/divisors? Higher is better.
        -- 0.5 means growing takes twice the time and you have half as much time to tend or harvest
        [2409420175] = 1.0,
        -- [951832588] = 0.5,
        [3008270349] = 0.8,
        [3833216577] = 1.0,
        [223086562] = 1.1,
        [1333033863] = 0.9,
        [4170197704] = 1.0,
        [3594309083] = 0.8,
        [2461440131] = 0.8,
        [1109728704] = 1.5,
        [2352068586] = 1.1,
        [1144315879] = 0.9,
        [581794674] = 1.1,
        [2128369009] = 0.8,
        [-461750719] = 1.0,
        [-1286696947] = 1.0,
    },
}
