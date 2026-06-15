Config = {}

-- Framework Settings
-- "auto" will auto-detect "qbox" or "qbcore". Can also be forced to "qbox" or "qbcore".
Config.Framework = "auto"

-- Target Settings
-- "auto" will auto-detect "ox_target" or "qb-target". Can also be forced to "ox_target" or "qb-target".
Config.Target = "auto"

-- Racing NPC Coordinator (Where players walk up to register/browse)
Config.NPC = {
    model = `a_m_y_motox_02`, -- Ped model hash
    coords = vector4(-151.52, -2142.69, 16.7, 223.51), -- New coordinates for testing
    heading = 223.51,
    scenario = "WORLD_HUMAN_STAND_IMPATIENT", -- Idle scenario
    targetLabel = "Register for Gokart Racing",
    targetIcon = "fas fa-flag-checkered"
}

-- Gokart Settings
Config.Karts = {
    default = "kart", -- Default kart spawn model
    models = {
        "kart", -- Custom/server specific model
        "veto", -- GTA V Cayo Perico kart
        "veto2", -- GTA V Cayo Perico kart (Modern style)
        "lambokart" -- Tiny custom bumper car
    }
}

-- Permission Settings
Config.AdminOnly = false -- Set to true to restrict lobby creation to admins. Set to false to allow everyone to create/test lobbies.

-- General Race Settings
Config.Race = {
    minPlayers = 1,
    maxPlayers = 8,
    countdownSeconds = 5,
    dnfTimeout = 20, -- seconds remaining to finish after first player crosses
}

-- Tracks configuration (Highly extensible structure)
Config.Tracks = {
    lsia_gp = {
        name = "LSIA GP",
        laps = 3,
        startPositions = {
            vector4(-1150.0, -2700.0, 12.94, 330.0),
            vector4(-1152.0, -2701.0, 12.94, 330.0),
            vector4(-1154.0, -2702.0, 12.94, 330.0),
            vector4(-1156.0, -2703.0, 12.94, 330.0),
            vector4(-1158.0, -2704.0, 12.94, 330.0),
            vector4(-1160.0, -2705.0, 12.94, 330.0),
            vector4(-1162.0, -2706.0, 12.94, 330.0),
            vector4(-1164.0, -2707.0, 12.94, 330.0),
        },
        checkpoints = {
            { coords = vector3(-1145.0, -2690.0, 12.94), radius = 3.5 },
            { coords = vector3(-1130.0, -2650.0, 12.94), radius = 3.5 },
            { coords = vector3(-1100.0, -2620.0, 12.94), radius = 3.5 },
            { coords = vector3(-1080.0, -2640.0, 12.94), radius = 3.5 },
            { coords = vector3(-1100.0, -2680.0, 12.94), radius = 3.5 },
            { coords = vector3(-1135.0, -2705.0, 12.94), radius = 3.5 }, -- Finish Line
        }
    },
    redwood_lights = {
        name = "Redwood Lights Track",
        laps = 2,
        startPositions = {
            vector4(1280.0, 780.0, 103.0, 90.0),
            vector4(1278.0, 778.0, 103.0, 90.0),
            vector4(1276.0, 776.0, 103.0, 90.0),
            vector4(1274.0, 774.0, 103.0, 90.0),
        },
        checkpoints = {
            { coords = vector3(1290.0, 790.0, 103.0), radius = 3.5 },
            { coords = vector3(1310.0, 810.0, 103.0), radius = 3.5 },
            { coords = vector3(1340.0, 800.0, 103.0), radius = 3.5 },
            { coords = vector3(1320.0, 770.0, 103.0), radius = 3.5 }, -- Finish Line
        }
    }
}

-- Checkpoint Visual Settings
Config.CheckpointMarker = {
    type = 1, -- Cylinder
    color = { r = 0, g = 191, b = 255, a = 80 }, -- Neon cyan (more transparent)
    height = 1.5 -- Shorter cylinder
}

Config.ArrowMarker = {
    type = 24, -- Chevron pointing down/forward
    color = { r = 0, g = 255, b = 127, a = 200 }, -- Neon green
    size = { x = 1.5, y = 1.5, z = 1.5 },
    offsetZ = 2.5 -- Height above ground for floating arrow
}

