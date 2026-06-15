local npcEntity = nil
local previewPed = nil
local isUIOpen = false

-- Racing Variables
local activeLobbyId = nil
local activeTrackId = nil
local playerKart = nil
local isRacing = false
local currentCheckpoint = 0
local currentLap = 1
local raceStartTime = 0
local lapStartTime = 0
local bestLapTime = 99999999
local countdownStartTime = 0
local leaderboardData = {}
local myCitizenId = ""
local myPlayerName = ""

-- Track Creator Variables
local isCreatingTrack = false
local creatorTrackId = ""
local creatorTrackName = ""
local creatorLaps = 3
local creatorCheckpoints = {}
local creatorStartPositions = {}
local CustomTracks = {}

-- Helper to load models
local function LoadModel(modelHash)
    if not IsModelInCdimage(modelHash) then return false end
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end
    return true
end

-- Helper to set vehicle fuel level
local function SetVehicleFuel(vehicle, amount)
    if GetResourceState("cdn-fuel") == "started" then
        exports['cdn-fuel']:SetFuel(vehicle, amount)
    elseif GetResourceState("qb-fuel") == "started" then
        exports['qb-fuel']:SetFuel(vehicle, amount)
    else
        SetVehicleFuelLevel(vehicle, amount)
    end
end

-- Helper to give vehicle keys to the player
local function GiveVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if GetResourceState("mm_carkeys") == "started" then
        exports.mm_carkeys:GiveTempKeys(plate)
    elseif GetResourceState("qb-vehiclekeys") == "started" then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    end
end


-- Setup Target Interaction (ox_target & qb-target support)
local function SetupTarget(entity)
    local options = {
        {
            num = 1,
            type = "client",
            event = "gokart_racing:client:openLobbyUI",
            icon = Config.NPC.targetIcon,
            label = Config.NPC.targetLabel,
        }
    }

    if Config.Target == "ox_target" or (Config.Target == "auto" and GetResourceState("ox_target") == "started") then
        exports.ox_target:addLocalEntity(entity, options)
    else
        exports['qb-target']:AddTargetEntity(entity, {
            options = options,
            distance = 2.5
        })
    end
end

-- Spawn NPC Coordinator
local function SpawnNPC(customCoords)
    -- Delete old ped if it exists
    if npcEntity and DoesEntityExist(npcEntity) then
        DeleteEntity(npcEntity)
        npcEntity = nil
    end

    local npcConfig = Config.NPC
    local coords = npcConfig.coords
    local heading = npcConfig.heading
    local model = npcConfig.model
    local scenario = npcConfig.scenario

    if customCoords then
        coords = vector4(customCoords.x, customCoords.y, customCoords.z, customCoords.heading)
        heading = customCoords.heading
        model = customCoords.model
        scenario = customCoords.scenario
    end

    local modelHash = type(model) == "string" and GetHashKey(model) or model

    if not LoadModel(modelHash) then
        print("^1[gokart_racing] Error: Failed to load NPC model " .. tostring(model) .. "^7")
        return
    end

    npcEntity = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, false)
    SetEntityHeading(npcEntity, heading)
    FreezeEntityPosition(npcEntity, true)
    SetEntityInvincible(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)

    if scenario and scenario ~= "" then
        TaskStartScenarioInPlace(npcEntity, scenario, 0, true)
    end

    SetupTarget(npcEntity)
    SetModelAsNoLongerNeeded(modelHash)
end

-- Clean up NPC on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if npcEntity and DoesEntityExist(npcEntity) then
        DeleteEntity(npcEntity)
    end
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    if playerKart and DoesEntityExist(playerKart) then
        DeleteVehicle(playerKart)
    end
end)

-- Spawn NPC and sync custom tracks on startup
CreateThread(function()
    SpawnNPC()
    Wait(1000)
    TriggerServerEvent("gokart_racing:server:requestLobbyList")
end)

-- Toggle UI State
local function ToggleUI(toggle, isAdmin)
    isUIOpen = toggle
    SetNuiFocus(toggle, toggle)
    if toggle then
        local tracksList = {}
        for trackId, trackData in pairs(Config.Tracks) do
            table.insert(tracksList, {
                id = trackId,
                name = trackData.name,
                laps = trackData.laps,
                maxSlots = #trackData.startPositions
            })
        end

        local playerData = Framework.GetPlayerData()
        local myName = "Racer"
        if playerData and playerData.charinfo then
            myName = playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
        end

        SendNUIMessage({
            action = "openUI",
            tracks = tracksList,
            isAdmin = isAdmin,
            karts = Config.Karts.models,
            playerName = myName
        })
        TriggerServerEvent("gokart_racing:server:requestLobbyList")
    else
        SendNUIMessage({
            action = "closeUI"
        })
    end
end

-- Event triggered by Target
RegisterNetEvent("gokart_racing:client:openLobbyUI", function()
    TriggerServerEvent("gokart_racing:server:checkAdminStatus")
end)

-- Event received from server after admin check
RegisterNetEvent("gokart_racing:client:openLobbyUIWithAdmin", function(isAdmin)
    ToggleUI(true, isAdmin)
end)

-- =========================================================================
-- NUI CALLBACKS
-- =========================================================================

RegisterNUICallback("close", function(data, cb)
    ToggleUI(false)
    cb("ok")
end)

RegisterNUICallback("createLobby", function(data, cb)
    if not data.name or data.name == "" then
        Framework.Notify("Please enter a lobby name!", "error")
        cb("error")
        return
    end
    TriggerServerEvent("gokart_racing:server:createLobby", data.name, data.maxPlayers, data.track, data.kartModel)
    cb("ok")
end)

RegisterNUICallback("joinLobby", function(data, cb)
    if not data.lobbyId then
        cb("error")
        return
    end
    TriggerServerEvent("gokart_racing:server:joinLobby", data.lobbyId)
    cb("ok")
end)

RegisterNUICallback("leaveLobby", function(data, cb)
    if not data.lobbyId then
        cb("error")
        return
    end
    TriggerServerEvent("gokart_racing:server:leaveLobby", data.lobbyId)
    cb("ok")
end)

-- NUI triggered start match
RegisterNUICallback("startRace", function(data, cb)
    if activeLobbyId then
        TriggerServerEvent("gokart_racing:server:startRace", activeLobbyId)
    end
    cb("ok")
end)

RegisterNUICallback("startTrackCreator", function(data, cb)
    if not data.name or data.name == "" then
        Framework.Notify("Please enter a track name!", "error")
        cb("error")
        return
    end
    TriggerServerEvent("gokart_racing:server:checkAdminStatusCreator", { data.name, data.laps })
    cb("ok")
end)

RegisterNUICallback("placeBet", function(data, cb)
    if activeLobbyId and data.amount and data.amount > 0 then
        TriggerServerEvent("gokart_racing:server:placeBet", activeLobbyId, data.amount)
    end
    cb("ok")
end)

RegisterNUICallback("notify", function(data, cb)
    Framework.Notify(data.text, data.type or "primary")
    cb("ok")
end)

RegisterNUICallback("dismissResults", function(data, cb)
    if activeLobbyId then
        TriggerServerEvent("gokart_racing:server:leaveLobby", activeLobbyId)
    end
    cb("ok")
end)

RegisterNUICallback("previewNPC", function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
    
    local modelHash = GetHashKey(data.model)
    if LoadModel(modelHash) then
        previewPed = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, false)
        SetEntityHeading(previewPed, heading)
        FreezeEntityPosition(previewPed, true)
        SetEntityInvincible(previewPed, true)
        SetBlockingOfNonTemporaryEvents(previewPed, true)
        
        if data.scenario and data.scenario ~= "" then
            TaskStartScenarioInPlace(previewPed, data.scenario, 0, true)
        end
        
        SetModelAsNoLongerNeeded(modelHash)
    end
    cb("ok")
end)

RegisterNUICallback("saveNPC", function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
    
    TriggerServerEvent("gokart_racing:server:saveNPCCoords", {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        model = data.model,
        scenario = data.scenario
    })
    
    isUIOpen = false
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("closeSetup", function(data, cb)
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
    isUIOpen = false
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("deleteLobby", function(data, cb)
    if activeLobbyId then
        TriggerServerEvent("gokart_racing:server:deleteLobby", activeLobbyId)
    end
    cb("ok")
end)

RegisterNUICallback("forceLeaveSession", function(data, cb)
    TriggerServerEvent("gokart_racing:server:forceLeaveAll")
    cb("ok")
end)

-- =========================================================================
-- SERVER TO CLIENT LOBBY EVENTS
-- =========================================================================

RegisterNetEvent("gokart_racing:client:updateLobbyList", function(lobbies)
    if isUIOpen then
        local lobbyList = {}
        for id, data in pairs(lobbies) do
            table.insert(lobbyList, {
                id = id,
                name = data.name,
                hostName = data.hostName,
                trackName = data.trackName,
                status = data.status,
                playerCount = #data.players,
                maxPlayers = data.maxPlayers
            })
        end
        SendNUIMessage({
            action = "updateLobbies",
            lobbies = lobbyList
        })
    end
end)

RegisterNetEvent("gokart_racing:client:onLobbyCreated", function(lobby)
    activeLobbyId = lobby.id
    if isUIOpen then
        local citizenid = Framework.GetPlayerData().citizenid
        local isHost = (lobby.host == citizenid)
        SendNUIMessage({
            action = "joinLobbyRoom",
            lobby = lobby,
            isHost = isHost
        })
    end
end)

RegisterNetEvent("gokart_racing:client:onLobbyUpdated", function(lobby)
    activeLobbyId = lobby.id
    if isUIOpen then
        local citizenid = Framework.GetPlayerData().citizenid
        local isHost = (lobby.host == citizenid)
        SendNUIMessage({
            action = "updateLobbyRoom",
            lobby = lobby,
            isHost = isHost
        })
    end
end)

RegisterNetEvent("gokart_racing:client:onLobbyLeft", function()
    activeLobbyId = nil
    activeTrackId = nil
    if isUIOpen then
        SendNUIMessage({
            action = "exitLobbyRoom"
        })
    end
end)

-- =========================================================================
-- PHASE 2: RACING LOOP & VISUALS
-- =========================================================================

-- Vector helpers for calculations
local function Normalize2D(x, y)
    local len = math.sqrt(x*x + y*y)
    if len == 0 then return 0, 0 end
    return x / len, y / len
end

-- Teleport player and prepare them on the grid
RegisterNetEvent("gokart_racing:client:setupRace", function(lobbyId, trackId, startPos, kartModel)
    activeLobbyId = lobbyId
    activeTrackId = trackId
    
    ToggleUI(false)
    DoScreenFadeOut(500)
    Wait(600)

    local playerPed = PlayerPedId()
    
    -- Teleport player to start grid
    SetEntityCoords(playerPed, startPos.x, startPos.y, startPos.z, false, false, false, true)
    SetEntityHeading(playerPed, startPos.w)
    
    -- Spawn Gokart Vehicle
    local modelHash = GetHashKey(kartModel)
    if not LoadModel(modelHash) then
        modelHash = GetHashKey("veto") -- Fallback
        LoadModel(modelHash)
    end

    playerKart = CreateVehicle(modelHash, startPos.x, startPos.y, startPos.z, startPos.w, true, false)
    SetPedIntoVehicle(playerPed, playerKart, -1)
    
    -- Setup fuel and give keys
    SetVehicleFuel(playerKart, 100.0)
    GiveVehicleKeys(playerKart)

    SetVehicleEngineOn(playerKart, false, true, true)
    FreezeEntityPosition(playerKart, true) -- Lock vehicle during countdown
    SetEntityInvincible(playerKart, true) -- Prevent kart from blowing up or popping tires
    SetVehicleHandbrake(playerKart, true)

    -- Reset state tracking variables
    currentCheckpoint = 0
    currentLap = 1
    bestLapTime = 99999999
    isRacing = true

    -- Cache player identity info
    local playerData = Framework.GetPlayerData()
    myCitizenId = playerData and playerData.citizenid or ""
    if playerData and playerData.charinfo then
        myPlayerName = playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
    else
        myPlayerName = "Racer"
    end

    SetModelAsNoLongerNeeded(modelHash)
    
    DoScreenFadeIn(500)
    Wait(500)

    TriggerServerEvent("gokart_racing:server:playerReady", lobbyId)
end)

-- Sync starting countdown
RegisterNetEvent("gokart_racing:client:startCountdown", function(duration, serverStartTime)
    SendNUIMessage({
        action = "startRaceCountdown",
        duration = duration
    })

    local timeRemaining = duration
    countdownStartTime = GetGameTimer() + (duration * 1000)

    -- Lock controls and freeze vehicle until countdown completes
    CreateThread(function()
        while isRacing and GetGameTimer() < countdownStartTime do
            DisableControlAction(0, 71, true) -- Accelerate
            DisableControlAction(0, 72, true) -- Brake/Reverse
            Wait(0)
        end

        -- Release lock and begin
        if playerKart and DoesEntityExist(playerKart) then
            FreezeEntityPosition(playerKart, false)
            SetVehicleEngineOn(playerKart, true, true, false)
            SetVehicleHandbrake(playerKart, false)
            PlaySoundFrontend(-1, "RACE_START_LIGHT", "HUD_AWARDS", 1)
        end

        raceStartTime = GetGameTimer()
        lapStartTime = GetGameTimer()
    end)
end)

-- Receive live sorted rankings
RegisterNetEvent("gokart_racing:client:syncLeaderboard", function(list)
    leaderboardData = list
end)

-- Player finished the race
RegisterNetEvent("gokart_racing:client:onRaceFinished", function(finalPosition, totalTime, bestLap)
    isRacing = false
    
    if playerKart and DoesEntityExist(playerKart) then
        FreezeEntityPosition(playerKart, true)
        SetVehicleEngineOn(playerKart, false, true, true)
    end

    -- Play finish sound
    PlaySoundFrontend(-1, "RACE_YOU_WIN", "HUD_AWARDS", 1)

    SendNUIMessage({
        action = "finishRace",
        position = finalPosition,
        totalTime = totalTime,
        bestLap = bestLap
    })
end)

-- Display final results overlays
RegisterNetEvent("gokart_racing:client:showResults", function(rankings)
    SendNUIMessage({
        action = "showRaceResults",
        rankings = rankings
    })
end)

-- Force clean up (deletes kart and teleports back to NPC)
RegisterNetEvent("gokart_racing:client:forceCleanUpRace", function()
    isRacing = false
    SendNUIMessage({
        action = "hideRaceHUD"
    })

    if playerKart and DoesEntityExist(playerKart) then
        DeleteVehicle(playerKart)
        playerKart = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)

    -- Teleport back to NPC coordinator
    SetEntityCoords(ped, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z, false, false, false, true)
    SetEntityHeading(ped, Config.NPC.coords.w)
end)

-- Main 3D Markers & Checkpoint Check Thread
CreateThread(function()
    while true do
        local sleep = 1000
        
        if isRacing and activeTrackId and Config.Tracks[activeTrackId] then
            sleep = 0
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Check if player exited the kart
            if playerKart and DoesEntityExist(playerKart) then
                if not IsPedInVehicle(playerPed, playerKart, false) then
                    Framework.Notify("You exited the kart! Exited the race.", "error")
                    TriggerServerEvent("gokart_racing:server:leaveLobby", activeLobbyId)
                    Wait(1000)
                end
            end

            local trackData = Config.Tracks[activeTrackId]
            local checkpoints = trackData.checkpoints
            local totalCheckpoints = #checkpoints

            -- Define which checkpoint to display (next expected index)
            local targetIdx = currentCheckpoint + 1
            if targetIdx > totalCheckpoints then
                targetIdx = 1 -- Finish line is checkpoint 1 on next lap
            end

            local targetCheckpoint = checkpoints[targetIdx]
            
            -- Render current checkpoint cylinder
            local markerColor = Config.CheckpointMarker.color
            if targetIdx == 1 then
                -- Red/Gold styling for the start/finish line
                markerColor = { r = 255, g = 215, b = 0, a = 150 }
            end

            DrawMarker(
                Config.CheckpointMarker.type,
                targetCheckpoint.coords.x, targetCheckpoint.coords.y, targetCheckpoint.coords.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                targetCheckpoint.radius * 2, targetCheckpoint.radius * 2, Config.CheckpointMarker.height,
                markerColor.r, markerColor.g, markerColor.b, markerColor.a,
                false, false, 2, false, nil, nil, false
            )

            -- Check distance to current checkpoint
            local dist = #(playerCoords - targetCheckpoint.coords)
            if dist < targetCheckpoint.radius then
                -- Check if passing start/finish line to start a new lap
                if targetIdx == 1 and currentCheckpoint == totalCheckpoints then
                    currentLap = currentLap + 1
                    lapStartTime = GetGameTimer()
                end

                currentCheckpoint = targetIdx
                PlaySoundFrontend(-1, "CHECKPOINT_BEAST", "HUD_MINI_GAME_SOUNDSET", 0)
                TriggerServerEvent("gokart_racing:server:passCheckpoint", activeLobbyId, targetIdx)
            end

            -- Directional Guidance System: Generate chevron floating 8m in front of player pointing at target
            local dx = targetCheckpoint.coords.x - playerCoords.x
            local dy = targetCheckpoint.coords.y - playerCoords.y
            
            local nx, ny = Normalize2D(dx, dy)
            local arrowPos = vector3(playerCoords.x + (nx * 8.0), playerCoords.y + (ny * 8.0), playerCoords.z + Config.ArrowMarker.offsetZ)

            -- Calculate heading for chevron marker pointing to target
            local heading = math.atan2(ny, nx) * 180.0 / math.pi - 90.0

            DrawMarker(
                Config.ArrowMarker.type,
                arrowPos.x, arrowPos.y, arrowPos.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, heading,
                Config.ArrowMarker.size.x, Config.ArrowMarker.size.y, Config.ArrowMarker.size.z,
                Config.ArrowMarker.color.r, Config.ArrowMarker.color.g, Config.ArrowMarker.color.b, Config.ArrowMarker.color.a,
                false, false, 2, false, nil, nil, false
            )
        end
        Wait(sleep)
    end
end)

-- Telemetry reporting thread (sends distance to next checkpoint)
CreateThread(function()
    while true do
        local sleep = 1000
        if isRacing and activeTrackId and Config.Tracks[activeTrackId] then
            sleep = 250 -- Telemetry tick rate

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            local trackData = Config.Tracks[activeTrackId]
            local checkpoints = trackData.checkpoints
            local totalCheckpoints = #checkpoints

            local targetIdx = currentCheckpoint + 1
            if targetIdx > totalCheckpoints then
                targetIdx = 1
            end

            local targetCheckpoint = checkpoints[targetIdx]
            local dist = #(playerCoords - targetCheckpoint.coords)

            TriggerServerEvent("gokart_racing:server:updateTelemetry", activeLobbyId, currentCheckpoint, dist)
        end
        Wait(sleep)
    end
end)

-- NUI HUD Sync Thread
CreateThread(function()
    while true do
        local sleep = 500
        if isRacing and activeTrackId and raceStartTime > 0 and GetGameTimer() >= countdownStartTime then
            sleep = 50 -- 20 FPS UI refresh rate

            local now = GetGameTimer()
            local totalElapsed = now - raceStartTime
            local lapElapsed = now - lapStartTime

            -- Find client's current position in leaderboard
            local clientPosition = 1
            for idx, racer in ipairs(leaderboardData) do
                if racer.citizenid == myCitizenId then
                    clientPosition = racer.position
                    break
                end
            end

            local totalLaps = 3
            if activeTrackId and Config.Tracks[activeTrackId] then
                totalLaps = Config.Tracks[activeTrackId].laps
            end

            SendNUIMessage({
                action = "updateRaceHUD",
                position = clientPosition,
                lap = currentLap,
                totalLaps = totalLaps,
                raceTime = totalElapsed,
                lapTime = lapElapsed,
                leaderboard = leaderboardData
            })
        end
        Wait(sleep)
    end
end)

-- Register command to leave race
RegisterCommand("leaverace", function()
    if isRacing and activeLobbyId then
        TriggerServerEvent("gokart_racing:server:leaveLobby", activeLobbyId)
    else
        Framework.Notify("You are not currently in a race!", "error")
    end
end, false)

-- Sync custom tracks from server
RegisterNetEvent("gokart_racing:client:syncCustomTracks", function(tracks)
    CustomTracks = tracks
    for trackId, trackData in pairs(tracks) do
        Config.Tracks[trackId] = trackData
    end
end)

-- Helper to update creator NUI HUD statistics
local function UpdateCreatorHUDStats()
    SendNUIMessage({
        action = "updateCreatorHUD",
        grids = #creatorStartPositions,
        checkpoints = #creatorCheckpoints
    })
end

-- Creator loop to handle inputs and markers drawing
local function StartCreatorLoop()
    -- Show creator HUD and sync initial stats
    SendNUIMessage({
        action = "showCreatorHUD",
        name = creatorTrackName
    })
    UpdateCreatorHUDStats()

    CreateThread(function()
        while isCreatingTrack do
            Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local heading = GetEntityHeading(playerPed)

            -- Disable default pause menu control action (ESC/P)
            DisableControlAction(0, 200, true)

            -- 1. Draw existing placed grids (green vectors/spheres)
            for idx, pos in ipairs(creatorStartPositions) do
                DrawMarker(23, pos.x, pos.y, pos.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, 0, 255, 127, 150, false, false, 2, false, nil, nil, false)
                DrawMarker(0, pos.x, pos.y, pos.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 127, 200, false, false, 2, false, nil, nil, false)
            end

            -- 2. Draw existing placed checkpoints (blue cylinder rings)
            for idx, cp in ipairs(creatorCheckpoints) do
                local coords = cp.coords
                local markerColor = { r = 0, g = 191, b = 255, a = 120 }
                if idx == 1 then
                    markerColor = { r = 255, g = 215, b = 0, a = 150 } -- Gold for start/finish line
                end
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cp.radius * 2, cp.radius * 2, 2.0, markerColor.r, markerColor.g, markerColor.b, markerColor.a, false, false, 2, false, nil, nil, false)
            end

            -- 3. Listen to key presses
            -- [E] - Add Checkpoint
            if IsControlJustReleased(0, 38) then
                table.insert(creatorCheckpoints, { coords = playerCoords, radius = 3.5 })
                PlaySoundFrontend(-1, "CHECKPOINT_BEAST", "HUD_MINI_GAME_SOUNDSET", 0)
                Framework.Notify("Added Checkpoint #" .. #creatorCheckpoints, "primary")
                UpdateCreatorHUDStats()
                Wait(200)
            end

            -- [G] - Add Grid Spawn Position
            if IsControlJustReleased(0, 47) then
                if #creatorStartPositions >= 8 then
                    Framework.Notify("Max 8 spawn grid positions reached!", "error")
                else
                    table.insert(creatorStartPositions, vector4(playerCoords.x, playerCoords.y, playerCoords.z, heading))
                    PlaySoundFrontend(-1, "CHECKPOINT_BEAST", "HUD_MINI_GAME_SOUNDSET", 0)
                    Framework.Notify("Added Grid Spawn Position #" .. #creatorStartPositions, "success")
                    UpdateCreatorHUDStats()
                    Wait(200)
                end
            end

            -- [BACKSPACE] - Undo Last action
            if IsControlJustReleased(0, 177) then
                if #creatorCheckpoints > 0 or #creatorStartPositions > 0 then
                    if #creatorCheckpoints > 0 then
                        table.remove(creatorCheckpoints)
                        Framework.Notify("Removed last checkpoint.", "primary")
                    elseif #creatorStartPositions > 0 then
                        table.remove(creatorStartPositions)
                        Framework.Notify("Removed last grid position.", "primary")
                    end
                    UpdateCreatorHUDStats()
                end
                Wait(200)
            end

            -- [ENTER] - Save Track
            if IsControlJustReleased(0, 191) then
                if #creatorStartPositions < 1 then
                    Framework.Notify("You need at least 1 grid spawn position!", "error")
                elseif #creatorCheckpoints < 2 then
                    Framework.Notify("You need at least 2 checkpoints!", "error")
                else
                    isCreatingTrack = false
                    SendNUIMessage({ action = "hideCreatorHUD" })
                    TriggerServerEvent("gokart_racing:server:saveCustomTrack", creatorTrackId, creatorTrackName, creatorLaps, creatorStartPositions, creatorCheckpoints)
                end
                Wait(200)
            end

            -- [ESC] - Cancel
            if IsControlJustReleased(0, 322) then
                isCreatingTrack = false
                SendNUIMessage({ action = "hideCreatorHUD" })
                Framework.Notify("Track Creator cancelled.", "error")
                Wait(200)
            end
        end
    end)
end

-- Start track creator
RegisterNetEvent("gokart_racing:client:startTrackCreator", function(args)
    if isCreatingTrack then
        Framework.Notify("You are already creating a track!", "error")
        return
    end

    local trackName = args[1] or "Custom Track"
    local laps = tonumber(args[2]) or 3
    local trackId = string.lower(string.gsub(trackName, "%s+", "_"))

    isCreatingTrack = true
    creatorTrackId = trackId
    creatorTrackName = trackName
    creatorLaps = laps
    creatorCheckpoints = {}
    creatorStartPositions = {}

    Framework.Notify("Track Creator started: " .. trackName, "success")
    StartCreatorLoop()
end)

-- Command to initiate track creator
RegisterCommand("createtrack", function(source, args)
    if #args < 1 then
        Framework.Notify("Usage: /createtrack [name] [laps]", "error")
        return
    end
    TriggerServerEvent("gokart_racing:server:checkAdminStatusCreator", args)
end, false)

-- Command to cancel
RegisterCommand("canceltrack", function()
    if isCreatingTrack then
        isCreatingTrack = false
        SendNUIMessage({ action = "hideCreatorHUD" })
        Framework.Notify("Track Creator cancelled.", "error")
    end
end, false)

-- =========================================================================
-- DYNAMIC NPC SETUP EVENTS
-- =========================================================================

RegisterNetEvent("gokart_racing:client:openSetupUI", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    isUIOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "openSetupUI",
        coords = {
            x = string.format("%.2f", coords.x),
            y = string.format("%.2f", coords.y),
            z = string.format("%.2f", coords.z),
            heading = string.format("%.2f", heading)
        }
    })
end)

RegisterNetEvent("gokart_racing:client:syncNPCCoords", function(data)
    SpawnNPC(data)
end)



