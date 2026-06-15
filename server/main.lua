local Lobbies = {}
local CustomTracks = {}

-- Load custom tracks from database
local function LoadCustomTracksFromDb()
    CustomTracks = {}
    exports.oxmysql:query('SELECT * FROM gokart_racing_tracks', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                local startPositions = json.decode(row.start_positions)
                local checkpoints = json.decode(row.checkpoints)
                
                local parsedStarts = {}
                for _, pos in ipairs(startPositions) do
                    table.insert(parsedStarts, vector4(pos.x, pos.y, pos.z, pos.w or pos.h or 0.0))
                end
                
                local parsedCheckpoints = {}
                for _, cp in ipairs(checkpoints) do
                    table.insert(parsedCheckpoints, {
                        coords = vector3(cp.x, cp.y, cp.z),
                        radius = cp.radius or 3.5
                    })
                end
                
                local trackData = {
                    name = row.name,
                    laps = row.laps,
                    startPositions = parsedStarts,
                    checkpoints = parsedCheckpoints,
                    isCustom = true
                }
                CustomTracks[row.track_id] = trackData
                Config.Tracks[row.track_id] = trackData
            end
            print("^2[gokart_racing] Loaded " .. tostring(#results) .. " custom tracks from database.^7")
            TriggerClientEvent("gokart_racing:client:syncCustomTracks", -1, CustomTracks)
        end
    end)
end

-- Initialize database loading
-- Load custom NPC coords if they exist
local function LoadCustomNPCCoords()
    local configFile = LoadResourceFile(GetCurrentResourceName(), "npc_coords.json")
    if configFile then
        local data = json.decode(configFile)
        if data then
            Config.NPC.coords = vector4(data.x, data.y, data.z, data.heading)
            Config.NPC.heading = data.heading
            Config.NPC.model = GetHashKey(data.model)
            Config.NPC.scenario = data.scenario
            print("^2[gokart_racing] Loaded custom NPC coordinator coordinates from npc_coords.json.^7")
        end
    end
end

-- Initialize database loading
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1000)
        LoadCustomNPCCoords()
        LoadCustomTracksFromDb()
        
        -- Auto-refresh and start the vehicle/map resources if they are not active
        print("^3[gokart_racing] Checking lambokart and mappingcarbumpers resources...^7")
        ExecuteCommand("refresh")
        Wait(500)
        if GetResourceState("lambokart") ~= "started" then
            ExecuteCommand("ensure lambokart")
        end
        if GetResourceState("mappingcarbumpers") ~= "started" then
            ExecuteCommand("ensure mappingcarbumpers")
        end
    end)
end)

-- Helper to generate unique lobby IDs
local function GenerateLobbyId()
    local id = tostring(math.random(1000, 9999))
    while Lobbies[id] ~= nil do
        id = tostring(math.random(1000, 9999))
    end
    return id
end

-- Broadcast updated lobby list to all players
local function SyncLobbiesToAll()
    TriggerClientEvent("gokart_racing:client:updateLobbyList", -1, Lobbies)
end

-- Server callback/event to get initial lobby data on NUI open
RegisterNetEvent("gokart_racing:server:requestLobbyList", function()
    local src = source
    TriggerClientEvent("gokart_racing:client:syncCustomTracks", src, CustomTracks)
    TriggerClientEvent("gokart_racing:client:updateLobbyList", src, Lobbies)
    
    -- Sync coordinator NPC details to client
    TriggerClientEvent("gokart_racing:client:syncNPCCoords", src, {
        x = Config.NPC.coords.x,
        y = Config.NPC.coords.y,
        z = Config.NPC.coords.z,
        heading = Config.NPC.heading,
        model = Config.NPC.model,
        scenario = Config.NPC.scenario
    })
end)

-- Server event to check player admin status
RegisterNetEvent("gokart_racing:server:checkAdminStatus", function()
    local src = source
    local isAdmin = Framework.IsAdmin(src)
    TriggerClientEvent("gokart_racing:client:openLobbyUIWithAdmin", src, isAdmin)
end)

-- Server event to check player admin status specifically for track creator
RegisterNetEvent("gokart_racing:server:checkAdminStatusCreator", function(args)
    local src = source
    if Framework.IsAdmin(src) then
        TriggerClientEvent("gokart_racing:client:startTrackCreator", src, args)
    else
        Framework.Notify(src, "Only admins can create tracks!", "error")
    end
end)

-- Create a new lobby
RegisterNetEvent("gokart_racing:server:createLobby", function(lobbyName, maxPlayers, trackId, kartModel)
    local src = source
    
    if not Framework.IsAdmin(src) then
        Framework.Notify(src, "Only admins can create race lobbies!", "error")
        return
    end

    local citizenid = Framework.GetPlayerCitizenId(src)
    local name = Framework.GetPlayerName(src)

    if not citizenid then return end

    -- Check if player is already in any active lobby
    for _, lobby in pairs(Lobbies) do
        for _, player in ipairs(lobby.players) do
            if player.citizenid == citizenid then
                Framework.Notify(src, "You are already in a lobby!", "error")
                return
            end
        end
    end

    -- Validate track selection
    if not Config.Tracks[trackId] then
        Framework.Notify(src, "Invalid track selection!", "error")
        return
    end

    -- Validate and set gokart model selection
    local selectedKart = kartModel or Config.Karts.default
    local isValidKart = false
    for _, model in ipairs(Config.Karts.models) do
        if model == selectedKart then
            isValidKart = true
            break
        end
    end
    if not isValidKart then
        selectedKart = Config.Karts.default
    end

    local lobbyId = GenerateLobbyId()
    Lobbies[lobbyId] = {
        id = lobbyId,
        name = lobbyName,
        host = citizenid,
        hostName = name,
        hostSource = src,
        maxPlayers = tonumber(maxPlayers) or Config.Race.maxPlayers,
        track = trackId,
        trackName = Config.Tracks[trackId].name,
        kartModel = selectedKart,
        status = "waiting",
        players = {
            { source = src, citizenid = citizenid, name = name }
        },
        progress = {},
        finishedPlayers = {},
        readyCount = 0,
        betPool = 0,
        playerBets = {}
    }

    Framework.Notify(src, "Lobby created successfully!", "success")
    SyncLobbiesToAll()

    -- Notify the creator to open their lobby details view
    TriggerClientEvent("gokart_racing:client:onLobbyCreated", src, Lobbies[lobbyId])
end)

-- Join an existing lobby
RegisterNetEvent("gokart_racing:server:joinLobby", function(lobbyId)
    local src = source
    local citizenid = Framework.GetPlayerCitizenId(src)
    local name = Framework.GetPlayerName(src)

    if not citizenid then return end

    local lobby = Lobbies[lobbyId]
    if not lobby then
        Framework.Notify(src, "Lobby does not exist!", "error")
        return
    end

    if lobby.status ~= "waiting" then
        Framework.Notify(src, "Race has already started!", "error")
        return
    end

    if #lobby.players >= lobby.maxPlayers then
        Framework.Notify(src, "Lobby is full!", "error")
        return
    end

    -- Check if player is already in a lobby
    for _, l in pairs(Lobbies) do
        for _, player in ipairs(l.players) do
            if player.citizenid == citizenid then
                Framework.Notify(src, "You are already in a lobby!", "error")
                return
            end
        end
    end

    -- Add player to the list
    table.insert(lobby.players, { source = src, citizenid = citizenid, name = name })
    
    Framework.Notify(src, "Joined lobby " .. lobby.name, "success")
    SyncLobbiesToAll()

    -- Sync this lobby's details to all players inside it
    for _, player in ipairs(lobby.players) do
        TriggerClientEvent("gokart_racing:client:onLobbyUpdated", player.source, lobby)
    end
end)

-- Core function to handle leaving a lobby
local function LeaveLobby(src, lobbyId)
    local lobby = Lobbies[lobbyId]
    if not lobby then return end

    local playerIdx = nil
    local citizenid = nil
    for idx, player in ipairs(lobby.players) do
        if player.source == src then
            playerIdx = idx
            citizenid = player.citizenid
            break
        end
    end

    if not playerIdx then return end

    table.remove(lobby.players, playerIdx)

    -- If the race is active and players leave, clean up their vehicle on their client
    TriggerClientEvent("gokart_racing:client:forceCleanUpRace", src)

    -- If the player leaving was the host, re-assign or close lobby
    if lobby.host == citizenid then
        if #lobby.players > 0 then
            local newHost = lobby.players[1]
            lobby.host = newHost.citizenid
            lobby.hostName = newHost.name
            lobby.hostSource = newHost.source
            Framework.Notify(newHost.source, "You are now the lobby host!", "primary")
        else
            -- Delete empty lobby
            Lobbies[lobbyId] = nil
        end
    end

    -- Sync the update to remaining players
    if Lobbies[lobbyId] and #lobby.players > 0 then
        for _, player in ipairs(lobby.players) do
            TriggerClientEvent("gokart_racing:client:onLobbyUpdated", player.source, lobby)
        end
    end

    -- If the race is active and players leave, check if all remaining players have finished
    if lobby.status == "racing" and #lobby.players > 0 then
        local allFinished = true
        for _, player in ipairs(lobby.players) do
            local prog = lobby.progress[player.citizenid]
            if prog and not prog.finished then
                allFinished = false
                break
            end
        end

        if allFinished then
            EndRace(lobby)
        end
    end

    -- Update the player who left
    TriggerClientEvent("gokart_racing:client:onLobbyLeft", src)
    Framework.Notify(src, "Left the lobby", "primary")
    SyncLobbiesToAll()
end

RegisterNetEvent("gokart_racing:server:leaveLobby", function(lobbyId)
    local src = source
    LeaveLobby(src, lobbyId)
end)

RegisterNetEvent("gokart_racing:server:placeBet", function(lobbyId, amount)
    local src = source
    local lobby = Lobbies[lobbyId]
    if not lobby then return end

    if lobby.status ~= "waiting" then
        Framework.Notify(src, "Cannot place bets after the race has started!", "error")
        return
    end

    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid then return end

    -- Deduct money from the player using the framework wrapper
    local hasMoney = Framework.RemovePlayerMoney(src, amount, "cash")
    if not hasMoney then
        Framework.Notify(src, "You do not have enough money!", "error")
        return
    end

    lobby.playerBets[citizenid] = (lobby.playerBets[citizenid] or 0) + amount
    lobby.betPool = lobby.betPool + amount

    -- Store the bet amount in the player's roster record for easy NUI rendering
    for _, player in ipairs(lobby.players) do
        if player.citizenid == citizenid then
            player.bet = (player.bet or 0) + amount
            break
        end
    end

    Framework.Notify(src, "Placed a bet of $" .. tostring(amount) .. "!", "success")

    -- Sync lobby updates to all players
    for _, player in ipairs(lobby.players) do
        TriggerClientEvent("gokart_racing:client:onLobbyUpdated", player.source, lobby)
    end
end)

-- Handle Player Disconnection
AddEventHandler("playerDropped", function()
    local src = source
    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid then return end

    for lobbyId, lobby in pairs(Lobbies) do
        for _, player in ipairs(lobby.players) do
            if player.citizenid == citizenid then
                LeaveLobby(src, lobbyId)
                return
            end
        end
    end
end)

-- =========================================================================
-- PHASE 2: RACE MANAGEMENT & LIFECYCLE
-- =========================================================================

-- Sorting algorithm to calculate leaderboard positions
local function GetSortedLeaderboard(lobby)
    local leaderboard = {}
    for _, player in ipairs(lobby.players) do
        local prog = lobby.progress[player.citizenid]
        if prog then
            table.insert(leaderboard, {
                source = player.source,
                citizenid = player.citizenid,
                name = player.name,
                lap = prog.currentLap,
                checkpoint = prog.currentCheckpoint,
                distanceToNext = prog.distanceToNext or 9999.0,
                finished = prog.finished,
                finishTime = prog.finishTime or 99999999,
                bestLapTime = prog.bestLapTime or 0,
                totalTime = prog.totalTime or 0
            })
        end
    end

    table.sort(leaderboard, function(a, b)
        if a.finished and b.finished then
            return a.finishTime < b.finishTime
        elseif a.finished then
            return true
        elseif b.finished then
            return false
        end

        if a.lap ~= b.lap then
            return a.lap > b.lap
        end

        if a.checkpoint ~= b.checkpoint then
            return a.checkpoint > b.checkpoint
        end

        return a.distanceToNext < b.distanceToNext
    end)

    return leaderboard
end

-- Save race records to the MySQL Database (oxmysql integration)
local function SaveRaceResults(lobby, leaderboard)
    local trackId = lobby.track
    for pos, racer in ipairs(leaderboard) do
        if racer.finished then
            -- 1. Insert historical match rankings
            exports.oxmysql:insert('INSERT INTO gokart_racing_results (lobby_id, track_id, citizenid, player_name, position, total_time, best_lap_time) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                lobby.id, trackId, racer.citizenid, racer.name, pos, racer.totalTime, racer.bestLapTime
            })

            -- 2. Store or update personal best records
            exports.oxmysql:single('SELECT best_time FROM gokart_racing_records WHERE citizenid = ? AND track_id = ?', {
                racer.citizenid, trackId
            }, function(result)
                if not result then
                    exports.oxmysql:insert('INSERT INTO gokart_racing_records (citizenid, player_name, track_id, best_time) VALUES (?, ?, ?, ?)', {
                        racer.citizenid, racer.name, trackId, racer.totalTime
                    })
                elseif racer.totalTime < result.best_time then
                    exports.oxmysql:update('UPDATE gokart_racing_records SET best_time = ?, player_name = ? WHERE citizenid = ? AND track_id = ?', {
                        racer.totalTime, racer.name, racer.citizenid, trackId
                    })
                end
            end)

            -- 3. Check and store global track record
            exports.oxmysql:single('SELECT best_time FROM gokart_racing_track_records WHERE track_id = ?', {
                trackId
            }, function(result)
                if not result or racer.totalTime < result.best_time then
                    exports.oxmysql:execute('INSERT INTO gokart_racing_track_records (track_id, citizenid, player_name, best_time) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = ?, player_name = ?, best_time = ?', {
                        trackId, racer.citizenid, racer.name, racer.totalTime, racer.citizenid, racer.name, racer.totalTime
                    })
                end
            end)
        end
    end
end

-- Broadcast updated leaderboard to racers
local function BroadcastLeaderboard(lobby)
    local sorted = GetSortedLeaderboard(lobby)
    
    -- Format readable ranking list for NUI
    local list = {}
    for pos, racer in ipairs(sorted) do
        table.insert(list, {
            position = pos,
            name = racer.name,
            citizenid = racer.citizenid,
            lap = racer.lap,
            finished = racer.finished,
            time = racer.finished and racer.totalTime or nil
        })
    end

    for _, player in ipairs(lobby.players) do
        TriggerClientEvent("gokart_racing:client:syncLeaderboard", player.source, list)
    end
end

-- Helper to process race end sequence and betting payouts
local function EndRace(lobby)
    lobby.status = "finished"
    SyncLobbiesToAll()

    local sortedLeaderboard = GetSortedLeaderboard(lobby)
    
    -- Save to database
    SaveRaceResults(lobby, sortedLeaderboard)

    -- Betting Payout to Winner
    local winner = sortedLeaderboard[1]
    if winner and lobby.betPool and lobby.betPool > 0 then
        Framework.AddPlayerMoney(winner.source, lobby.betPool, "cash")
        for _, player in ipairs(lobby.players) do
            Framework.Notify(player.source, winner.name .. " won the race and takes the betting pool of $" .. tostring(lobby.betPool) .. "!", "success")
        end
    end

    -- Format results payload for NUI
    local resultsPayload = {}
    for pos, racer in ipairs(sortedLeaderboard) do
        table.insert(resultsPayload, {
            position = pos,
            name = racer.name,
            totalTime = racer.totalTime,
            bestLap = racer.bestLapTime
        })
    end

    -- Send results panel to all racers and clear lobby after 3 seconds
    for _, player in ipairs(lobby.players) do
        TriggerClientEvent("gokart_racing:client:showResults", player.source, resultsPayload)
    end

    -- Auto destroy lobby after completion (3 seconds as requested)
    SetTimeout(3000, function()
        for _, player in ipairs(lobby.players) do
            TriggerClientEvent("gokart_racing:client:forceCleanUpRace", player.source)
            TriggerClientEvent("gokart_racing:client:onLobbyLeft", player.source)
            Framework.Notify(player.source, "Lobby expired. Returning to lobby list.", "primary")
        end
        Lobbies[lobby.id] = nil
        SyncLobbiesToAll()
    end)
end

-- Host triggers start of the match
RegisterNetEvent("gokart_racing:server:startRace", function(lobbyId)
    local src = source
    local lobby = Lobbies[lobbyId]

    if not lobby then return end
    if lobby.host ~= Framework.GetPlayerCitizenId(src) then
        Framework.Notify(src, "Only the lobby host can start the race!", "error")
        return
    end

    if lobby.status ~= "waiting" then
        Framework.Notify(src, "Race has already started!", "error")
        return
    end

    if #lobby.players < Config.Race.minPlayers then
        Framework.Notify(src, "Not enough players to start!", "error")
        return
    end

    lobby.status = "starting"
    lobby.readyCount = 0
    lobby.finishedPlayers = {}
    SyncLobbiesToAll()

    local trackData = Config.Tracks[lobby.track]
    
    -- Teleport players to starting grid positions
    for idx, player in ipairs(lobby.players) do
        local startPos = trackData.startPositions[idx]
        -- Handle overflow grid positions if there are more players than grid positions
        if not startPos then
            startPos = trackData.startPositions[1]
        end

        -- Initialize server progress tracking
        lobby.progress[player.citizenid] = {
            currentLap = 1,
            currentCheckpoint = 0,
            lapStartTime = 0,
            bestLapTime = 99999999,
            totalTime = 0,
            finished = false
        }

        TriggerClientEvent("gokart_racing:client:setupRace", player.source, lobby.id, lobby.track, startPos, lobby.kartModel or Config.Karts.default)
    end
end)

-- Client triggers that their kart is spawned and ready
RegisterNetEvent("gokart_racing:server:playerReady", function(lobbyId)
    local src = source
    local lobby = Lobbies[lobbyId]
    if not lobby then return end

    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid or not lobby.progress[citizenid] then return end

    lobby.readyCount = lobby.readyCount + 1

    -- If all players are ready, start countdown
    if lobby.readyCount == #lobby.players then
        lobby.status = "racing"
        SyncLobbiesToAll()

        -- Set starting timestamp slightly offset by the countdown duration
        local startTime = GetGameTimer() + (Config.Race.countdownSeconds * 1000)
        lobby.raceStartTime = startTime

        -- Broadcast the initial leaderboard immediately so clients have it before driving
        BroadcastLeaderboard(lobby)

        for _, player in ipairs(lobby.players) do
            local prog = lobby.progress[player.citizenid]
            prog.lapStartTime = startTime
            TriggerClientEvent("gokart_racing:client:startCountdown", player.source, Config.Race.countdownSeconds, startTime)
        end
    end
end)

-- Telemetry sync sent from client
RegisterNetEvent("gokart_racing:server:updateTelemetry", function(lobbyId, checkpointIdx, distanceToNext)
    local src = source
    local lobby = Lobbies[lobbyId]
    if not lobby or lobby.status ~= "racing" then return end

    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid or not lobby.progress[citizenid] then return end

    local prog = lobby.progress[citizenid]
    if prog.finished then return end

    -- Update telemetry data in memory
    prog.currentCheckpoint = checkpointIdx
    prog.distanceToNext = distanceToNext

    BroadcastLeaderboard(lobby)
end)

-- Checkpoint pass validation
RegisterNetEvent("gokart_racing:server:passCheckpoint", function(lobbyId, checkpointIdx)
    local src = source
    local lobby = Lobbies[lobbyId]
    if not lobby or lobby.status ~= "racing" then return end

    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid or not lobby.progress[citizenid] then return end

    local prog = lobby.progress[citizenid]
    if prog.finished then return end

    local trackData = Config.Tracks[lobby.track]
    local totalCheckpoints = #trackData.checkpoints

    -- Validate checkpoint sequence (anti-teleport cheat check)
    local expectedCheckpoint = prog.currentCheckpoint + 1
    
    -- Check if completing a lap (passed last checkpoint and returning to checkpoint 1)
    if checkpointIdx == 1 and prog.currentCheckpoint == totalCheckpoints then
        local now = GetGameTimer()
        local lapTime = now - prog.lapStartTime
        
        -- Update personal best lap
        if lapTime < prog.bestLapTime then
            prog.bestLapTime = lapTime
            Framework.Notify(src, "New Personal Best Lap: " .. string.format("%.2f", lapTime / 1000) .. "s", "success")
        else
            Framework.Notify(src, "Lap Completed: " .. string.format("%.2f", lapTime / 1000) .. "s", "primary")
        end

        prog.currentCheckpoint = 1
        prog.lapStartTime = now
        prog.currentLap = prog.currentLap + 1

        -- Check if finished race
        if prog.currentLap > trackData.laps then
            prog.finished = true
            prog.finishTime = now - lobby.raceStartTime
            prog.totalTime = prog.finishTime
            prog.currentLap = trackData.laps -- lock lap display to max

            local winnerName = Framework.GetPlayerName(src)
            table.insert(lobby.finishedPlayers, {
                source = src,
                citizenid = citizenid,
                name = winnerName,
                totalTime = prog.totalTime,
                bestLap = prog.bestLapTime
            })

            Framework.Notify(src, "Finished! Total Time: " .. string.format("%.2f", prog.totalTime / 1000) .. "s", "success")
            TriggerClientEvent("gokart_racing:client:onRaceFinished", src, #lobby.finishedPlayers, prog.totalTime, prog.bestLapTime)

            -- If all players finished the race
            if #lobby.finishedPlayers == #lobby.players then
                EndRace(lobby)
            else
                -- If this is the FIRST player to finish, start a DNF timeout
                if #lobby.finishedPlayers == 1 then
                    local dnfSeconds = Config.Race.dnfTimeout or 20
                    for _, player in ipairs(lobby.players) do
                        Framework.Notify(player.source, winnerName .. " finished first! " .. tostring(dnfSeconds) .. "s remaining to finish.", "primary")
                    end
                    
                    SetTimeout(dnfSeconds * 1000, function()
                        if Lobbies[lobby.id] and Lobbies[lobby.id].status == "racing" then
                            EndRace(Lobbies[lobby.id])
                        end
                    end)
                end
            end
        end
    elseif checkpointIdx == expectedCheckpoint then
        prog.currentCheckpoint = checkpointIdx
    else
        -- Anti-cheat or skipped checkpoint notification
        Framework.Notify(src, "You skipped a checkpoint! Go back.", "error")
    end

    BroadcastLeaderboard(lobby)
end)

-- Save Custom Track from Creator
RegisterNetEvent("gokart_racing:server:saveCustomTrack", function(trackId, trackName, laps, startPositions, checkpoints)
    local src = source
    if not Framework.IsAdmin(src) then
        Framework.Notify(src, "Only admins can save custom tracks!", "error")
        return
    end

    -- Format start positions for JSON storage
    local startPosData = {}
    for _, pos in ipairs(startPositions) do
        table.insert(startPosData, { x = pos.x, y = pos.y, z = pos.z, w = pos.w or pos.h or 0.0 })
    end

    -- Format checkpoints for JSON storage
    local checkpointData = {}
    for _, cp in ipairs(checkpoints) do
        table.insert(checkpointData, { x = cp.coords.x, y = cp.coords.y, z = cp.coords.z, radius = cp.radius })
    end

    local citizenid = Framework.GetPlayerCitizenId(src) or "admin"

    exports.oxmysql:execute('INSERT INTO gokart_racing_tracks (track_id, name, laps, start_positions, checkpoints, created_by) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = ?, laps = ?, start_positions = ?, checkpoints = ?, created_by = ?', {
        trackId, trackName, laps, json.encode(startPosData), json.encode(checkpointData), citizenid,
        trackName, laps, json.encode(startPosData), json.encode(checkpointData), citizenid
    }, function(affectedRows)
        if affectedRows then
            -- Re-reconstruct vector4 and vector3 in server memory
            local parsedStarts = {}
            for _, pos in ipairs(startPositions) do
                table.insert(parsedStarts, vector4(pos.x, pos.y, pos.z, pos.w or pos.h or 0.0))
            end

            local parsedCheckpoints = {}
            for _, cp in ipairs(checkpoints) do
                table.insert(parsedCheckpoints, {
                    coords = vector3(cp.coords.x, cp.coords.y, cp.coords.z),
                    radius = cp.radius or 3.5
                })
            end

            local trackData = {
                name = trackName,
                laps = laps,
                startPositions = parsedStarts,
                checkpoints = parsedCheckpoints,
                isCustom = true
            }
            CustomTracks[trackId] = trackData
            Config.Tracks[trackId] = trackData -- Merge into server Config.Tracks!

            -- Broadcast updated custom tracks to all clients
            TriggerClientEvent("gokart_racing:client:syncCustomTracks", -1, CustomTracks)
            Framework.Notify(src, "Track '" .. trackName .. "' saved successfully!", "success")
        else
            Framework.Notify(src, "Failed to save track to database.", "error")
        end
    end)
end)

-- =========================================================================
-- DYNAMIC NPC SETUP & LOBBY MANAGEMENT
-- =========================================================================

RegisterNetEvent("gokart_racing:server:saveNPCCoords", function(data)
    local src = source
    if not Framework.IsAdmin(src) then
        Framework.Notify(src, "Only admins can save the NPC position!", "error")
        return
    end

    local fileData = {
        x = data.x,
        y = data.y,
        z = data.z,
        heading = data.heading,
        model = data.model,
        scenario = data.scenario
    }

    local success = SaveResourceFile(GetCurrentResourceName(), "npc_coords.json", json.encode(fileData, {indent = true}), -1)
    if success then
        Config.NPC.coords = vector4(data.x, data.y, data.z, data.heading)
        Config.NPC.heading = data.heading
        Config.NPC.model = GetHashKey(data.model)
        Config.NPC.scenario = data.scenario

        Framework.Notify(src, "NPC Coordinator location saved successfully!", "success")

        -- Sync coords globally to all clients
        TriggerClientEvent("gokart_racing:client:syncNPCCoords", -1, {
            x = data.x,
            y = data.y,
            z = data.z,
            heading = data.heading,
            model = Config.NPC.model,
            scenario = data.scenario
        })
    else
        Framework.Notify(src, "Failed to save npc_coords.json!", "error")
    end
end)

RegisterCommand("setupgokart", function(source, args)
    local src = source
    if src == 0 then
        print("This command can only be executed by a player in-game.")
        return
    end

    if Framework.IsAdmin(src) then
        TriggerClientEvent("gokart_racing:client:openSetupUI", src)
    else
        Framework.Notify(src, "Only admins can use the setup commands!", "error")
    end
end, false)

RegisterCommand("setup", function(source, args)
    local src = source
    if src == 0 then return end
    
    if args[1] == "gokart" then
        if Framework.IsAdmin(src) then
            TriggerClientEvent("gokart_racing:client:openSetupUI", src)
        else
            Framework.Notify(src, "Only admins can use the setup commands!", "error")
        end
    end
end, false)

RegisterNetEvent("gokart_racing:server:deleteLobby", function(lobbyId)
    local src = source
    local lobby = Lobbies[lobbyId]
    if not lobby then return end

    local citizenid = Framework.GetPlayerCitizenId(src)
    if lobby.host ~= citizenid then
        Framework.Notify(src, "Only the lobby host can delete the lobby!", "error")
        return
    end

    for _, player in ipairs(lobby.players) do
        TriggerClientEvent("gokart_racing:client:onLobbyLeft", player.source)
        Framework.Notify(player.source, "The host has closed and deleted the lobby.", "error")
    end

    Lobbies[lobbyId] = nil
    SyncLobbiesToAll()
end)

RegisterNetEvent("gokart_racing:server:forceLeaveAll", function()
    local src = source
    local citizenid = Framework.GetPlayerCitizenId(src)
    if not citizenid then return end

    local leftAny = false

    for lobbyId, lobby in pairs(Lobbies) do
        local playerIdx = nil
        for idx, player in ipairs(lobby.players) do
            if player.citizenid == citizenid then
                playerIdx = idx
                break
            end
        end

        if playerIdx then
            leftAny = true
            table.remove(lobby.players, playerIdx)

            if lobby.host == citizenid then
                if #lobby.players > 0 then
                    local newHost = lobby.players[1]
                    lobby.host = newHost.citizenid
                    lobby.hostName = newHost.name
                    lobby.hostSource = newHost.source
                    Framework.Notify(newHost.source, "You are now the lobby host!", "primary")
                    
                    for _, player in ipairs(lobby.players) do
                        TriggerClientEvent("gokart_racing:client:onLobbyUpdated", player.source, lobby)
                    end
                else
                    Lobbies[lobbyId] = nil
                end
            else
                for _, player in ipairs(lobby.players) do
                    TriggerClientEvent("gokart_racing:client:onLobbyUpdated", player.source, lobby)
                end
            end
        end
    end

    TriggerClientEvent("gokart_racing:client:forceCleanUpRace", src)
    TriggerClientEvent("gokart_racing:client:onLobbyLeft", src)
    
    if leftAny then
        Framework.Notify(src, "Successfully left all active gokart sessions.", "success")
        SyncLobbiesToAll()
    else
        Framework.Notify(src, "You were not in any active gokart session.", "primary")
    end
end)


