Framework = {}
Framework.Type = nil -- "qbox" or "qbcore"
Framework.Object = nil

local isServer = IsDuplicityVersion()

-- Initialize Framework Detection
local function init()
    if Config.Framework == "qbox" or (Config.Framework == "auto" and GetResourceState("qbx_core") == "started") then
        Framework.Type = "qbox"
        -- In Qbox, core functions are accessed directly via exports
        Framework.Object = exports.qbx_core
    elseif Config.Framework == "qbcore" or (Config.Framework == "auto" and GetResourceState("qb-core") == "started") then
        Framework.Type = "qbcore"
        Framework.Object = exports['qb-core']:GetCoreObject()
    else
        -- Fallback detection
        local status, err = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if status and err then
            Framework.Type = "qbcore"
            Framework.Object = err
        else
            -- Check for Qbox
            local statusQbox, errQbox = pcall(function()
                return exports.qbx_core
            end)
            if statusQbox and errQbox then
                Framework.Type = "qbox"
                Framework.Object = errQbox
            else
                print("^1[gokart_racing] Warning: No active framework (Qbox or QBCore) detected in init. Falling back to default native methods.^7")
            end
        end
    end
end

init()

-- =========================================================================
-- SERVER FUNCTIONS
-- =========================================================================
if isServer then
    -- Get Player Object
    function Framework.GetPlayer(source)
        if Framework.Type == "qbox" then
            return exports.qbx_core:GetPlayer(source)
        elseif Framework.Type == "qbcore" then
            return Framework.Object.Functions.GetPlayer(source)
        end
        return nil
    end

    -- Get Player Citizen ID
    function Framework.GetPlayerCitizenId(source)
        local Player = Framework.GetPlayer(source)
        if not Player then return nil end
        return Player.PlayerData.citizenid
    end

    -- Get Player Character Name
    function Framework.GetPlayerName(source)
        local Player = Framework.GetPlayer(source)
        if not Player then return "Unknown Racer" end
        local charinfo = Player.PlayerData.charinfo
        if charinfo then
            return charinfo.firstname .. " " .. charinfo.lastname
        end
        return GetPlayerName(source) or "Unknown Racer"
    end

    -- Notify Player
    function Framework.Notify(source, text, type, length)
        type = type or "primary"
        length = length or 5000
        if Framework.Type == "qbox" then
            -- Qbox compatibility for QBCore:Notify triggers or ox_lib notify
            TriggerClientEvent('QBCore:Notify', source, text, type, length)
        elseif Framework.Type == "qbcore" then
            TriggerClientEvent('QBCore:Notify', source, text, type, length)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "SYSTEM", text } })
        end
    end

    -- Check if Player is Admin
    function Framework.IsAdmin(source)
        if not Config.AdminOnly then return true end
        if Framework.Type == "qbox" then
            return exports.qbx_core:HasPermission(source, "admin") or exports.qbx_core:HasPermission(source, "god") or IsPlayerAceAllowed(source, "command")
        elseif Framework.Type == "qbcore" then
            local Player = Framework.GetPlayer(source)
            if not Player then return false end
            return Framework.Object.Functions.HasPermission(source, "admin") or Framework.Object.Functions.HasPermission(source, "god") or Player.PlayerData.group == "admin" or Player.PlayerData.group == "god"
        end
        return IsPlayerAceAllowed(source, "command")
    end

    -- Remove Player Money
    function Framework.RemovePlayerMoney(source, amount, moneyType)
        moneyType = moneyType or "cash"
        local Player = Framework.GetPlayer(source)
        if Player and Player.Functions.RemoveMoney(moneyType, amount, "gokart-bet") then
            return true
        end
        return false
    end

    -- Add Player Money
    function Framework.AddPlayerMoney(source, amount, moneyType)
        moneyType = moneyType or "cash"
        local Player = Framework.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney(moneyType, amount, "gokart-winnings")
            return true
        end
        return false
    end


-- =========================================================================
-- CLIENT FUNCTIONS
-- =========================================================================
else
    -- Get Player Data
    function Framework.GetPlayerData()
        if Framework.Type == "qbox" then
            return exports.qbx_core:GetPlayerData()
        elseif Framework.Type == "qbcore" then
            return Framework.Object.Functions.GetPlayerData()
        end
        return nil
    end

    -- Client Notify
    function Framework.Notify(text, type, length)
        type = type or "primary"
        length = length or 5000
        if Framework.Type == "qbox" then
            exports.qbx_core:Notify(text, type, length)
        elseif Framework.Type == "qbcore" then
            Framework.Object.Functions.Notify(text, type, length)
        else
            TriggerEvent('chat:addMessage', { args = { "SYSTEM", text } })
        end
    end
end
