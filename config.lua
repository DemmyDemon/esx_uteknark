Config = {
    Locale = 'en',
    Distance = { -- All distances in meters
        Draw = 200,     -- How close to a plant do you need to be to see it?
        Interact = 2,   -- How close do you need to be to interact?
        Space = 2,      -- How far apart do the plants need to be planted?
        Above = 4,      -- How much clear space above the planting space do you need to plant?
    },
    MaxGroundAngle = 0.6, -- How tilted can the ground be and still hold plants?
    Items = { -- What items are used?
        Seed = 'cannabis_seed',     -- Used to plant the weed
        Feed = 'plantfood',         -- Used to progress growth
        Product = 'weed',           -- What item is given when you harvest?
    },
    Yield = {5,10}, -- How many Items.Product does each plant yield? {5,10} means "from 5 to 10, inclusive"
    YieldSeed = {0,1}, -- Same as Yield, except for the amount of seeds you get back
    Time = { -- Time in *minutes*
        Grow = 1,
        Wait = 60,
    },
    Soil = {
        -- What soil types can you grow on, and what are their multiplers/divisors? Higher is better.
        -- 1.5 means Grow/1.5 and Wait*1.5
        [2409420175] = 1.0,
        [951832588] = 1.0,
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
        [581794674] = 1.1, -- Used for some shrubberies!
        [2128369009] = 0.8,
        [-461750719] = 1.0,
    },
}
