--[[ PLANT GROWTH STAGES

Each plant starts out at stage 1 and starting consumes
one Config.Items.Seed immediately, and the first timer starts running.
Interacting with the plant at this time destroys it.

When the time is up, it progresses to the next stage, which is
a mode='tend' stage. Interaction at this stage consumes one
Config.Items.Tend, or is free if the Tend Object is not specified.
Interaction is possible at any time. Failure to interact before the
time runs out causes the plant to die.

This continuses for all grow/tend cycles until a mode='yield' cycle
is arrived at. Interacting with the plant at this time will yield
between Config.Yield[1] and Config.Yield[2] of Config.Items.Product
and between Config.YieldSeed[1] and Config.YieldSeed[2] seeds.
By default this means between 5 and 10 weed_pooch, and between 0
and 1 weed_seed

--]]

Growth = {
    { -- 1
        label = 'growth_seedling',
        model = `prop_weed_01`,
        mode = 'growth',
        time = 1, -- One minute
        marker = {
            offset = vector3(0,0,0.2)
        },
    },
    { -- 2
        label = 'growth_tend',
        model = `prop_weed_01`,
        mode = 'tend',
        time = 20, -- Twenty minutes
        marker = {
            offset = vector3(0,0,0.3)
        },
    },
    { -- 3
        label = 'growth_growing',
        model = `prop_weed_01`,
        mode = 'grow',
        time = 480, -- 480 minutes is 12 hours
        marker = {
            offset = vector3(0,0,0.5)
        },
    },
    { -- 4
        label = 'growth_tend',
        model = `prop_weed_01`,
        mode = 'tend',
        time = 480,
        marker = {
            offset = vector3(0,0,0.75)
        },
    },
    { -- 5
        label = 'growth_growing',
        model = `prop_weed_01`,
        mode = 'grow',
        time = 480,
        marker = {
            offset = vector3(0,0,0.90)
        },
    },
    { -- 6
        label = 'growth_tend',
        model = `prop_weed_01`,
        mode = 'tend',
        time = 480,
        marker = {
            offset = vector3(0,0,1)
        },
    },
    { -- 7
        label = 'growth_growing',
        model = `prop_weed_01`,
        mode = 'grow',
        time = 480,
        marker = {
            offset = vector3(0,0,1.2)
        },
    },
    { -- 8
        label = 'growth_yield',
        model = `prop_weed_01`,
        mode = 'yield',
        time = 960,  -- 960 minutes is 24 hours
        marker = {
            offset = vector3(0,0,1.5)
        },
    },
}