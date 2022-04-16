-----------------------
----   Variables   ----
-----------------------
local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}

-----------------------
----   Threads     ----
-----------------------
MySQL.ready(function ()
    local races = MySQL.Sync.fetchAll('SELECT * FROM race_tracks', {})
    if races[1] ~= nil then
        for _, v in pairs(races) do
            local Records = {}
            if v.records ~= nil then
                Records = json.decode(v.records)
            end
            Races[v.raceid] = {
                RaceName = v.name,
                Checkpoints = json.decode(v.checkpoints),
                Records = Records,
                Creator = v.creatorid,
                CreatorName = v.creatorname,
                RaceId = v.raceid,
                Started = false,
                Waiting = false,
                Distance = v.distance,
                LastLeaderboard = {},
                Racers = {}
            }
        end
    end
end)

-----------------------
---- Server Events ----
-----------------------
RegisterNetEvent('racing:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local xPlayer = ESX.GetPlayerFromId(src)
    local RacerName = xPlayer.getName()
    local PlayersFinished = 0
    local AmountOfRacers = 0

    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        if v.Finished then
            PlayersFinished = PlayersFinished + 1
        end
        AmountOfRacers = AmountOfRacers + 1
    end
    local BLap = 0
    if TotalLaps < 2 then
        BLap = TotalTime
    else
        BLap = BestLap
    end

    if LastRaces[RaceData.RaceId] ~= nil then
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] =  {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = RacerName
        }
    else
        LastRaces[RaceData.RaceId] = {}
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] =  {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = RacerName
        }
    end
    if Races[RaceData.RaceId].Records ~= nil and next(Races[RaceData.RaceId].Records) ~= nil then
        if BLap < Races[RaceData.RaceId].Records.Time then
            Races[RaceData.RaceId].Records = {
                Time = BLap,
                Holder = RacerName
            }
            MySQL.update('UPDATE race_tracks SET records = ? WHERE raceid = ?', {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
                TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = "inform", text = "Race leaderboard updated for : ".. RaceData.RaceName.. " with : " ..SecondsToClock(BLap), length = 10000})
        end
    else
        Races[RaceData.RaceId].Records = {
            Time = BLap,
            Holder = RacerName
        }
        MySQL.update('UPDATE race_tracks SET records = ? WHERE raceid = ?', {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
            TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = "inform", text = "Race leaderboard updated for : ".. RaceData.RaceName.. " with : " ..SecondsToClock(BLap), length = 10000})
    end
    AvailableRaces[AvailableKey].RaceData = Races[RaceData.RaceId]
    TriggerClientEvent('racing:client:PlayerFinish', -1, RaceData.RaceId, PlayersFinished, RacerName)
    if PlayersFinished == AmountOfRacers then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceData.RaceId] ~= nil and
            next(NotFinished[RaceData.RaceId]) ~= nil then
            for k, v in pairs(NotFinished[RaceData.RaceId]) do
                LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] = {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = v.Holder
                }
            end
        end
        Races[RaceData.RaceId].LastLeaderboard = LastRaces[RaceData.RaceId]
        Races[RaceData.RaceId].Racers = {}
        Races[RaceData.RaceId].Started = false
        Races[RaceData.RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceData.RaceId] = nil
        NotFinished[RaceData.RaceId] = nil
    end
end)

RegisterNetEvent('racing:server:CreateLapRace', function(RaceName, RacerName)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    if IsNameAvailable(RaceName) then
        TriggerClientEvent('racing:client:StartRaceEditor', source, RaceName, RacerName)
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', src, {type="inform", text="This race name already exists.",length=8000})
    end
end)

RegisterNetEvent('racing:server:JoinRace', function(RaceData)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local RaceName = RaceData.RaceData.RaceName
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local CurrentRace = GetCurrentRace(Player.getIdentifier())
    local RacerName = Player.getName()

    if CurrentRace ~= nil then
        local AmountOfRacers = 0
        PreviousRaceKey = GetOpenedRaceKey(CurrentRace)
        for _,_ in pairs(Races[CurrentRace].Racers) do
            AmountOfRacers = AmountOfRacers + 1
        end
        Races[CurrentRace].Racers[Player.getIdentifier()] = nil
        if (AmountOfRacers - 1) == 0 then
            Races[CurrentRace].Racers = {}
            Races[CurrentRace].Started = false
            Races[CurrentRace].Waiting = false
            table.remove(AvailableRaces, PreviousRaceKey)
            TriggerClientEvent('mythic_notify:client:SendAlert', creatorsource,{type="inform", text="You were the last person in that race so it was canceled.",length=8000})
            TriggerClientEvent('racing:client:LeaveRace', src, Races[CurrentRace])
        else
            AvailableRaces[PreviousRaceKey].RaceData = Races[CurrentRace]
            TriggerClientEvent('racing:client:LeaveRace', src, Races[CurrentRace])
        end
    else
        Races[RaceId].OrganizerCID = Player.getIdentifier()
    end

    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.getIdentifier()] = {
        Checkpoint = 0,
        Lap = 1,
        Finished = false,
        RacerName = RacerName,
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('racing:client:JoinRace', src, Races[RaceId], RaceData.Laps, RacerName)
    TriggerClientEvent('racing:client:UpdateRaceRacers', src, RaceId, Races[RaceId].Racers)
    local creatorsource = ESX.GetPlayerFromIdentifier(AvailableRaces[AvailableKey].SetupCitizenId)
    if creatorsource ~= Player.source then
        TriggerClientEvent('mythic_notify:client:SendAlert', creatorsource,{type="inform", text="Someone has joined the race.",length=8000})
    end
end)

RegisterNetEvent('racing:server:LeaveRace', function(RaceData)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local PlayerData = ESX.GetPlayerFromIdentifier(src)
    local RacerName = RaceData.RacerName
    local RaceName = RaceData.RaceName
    if RaceData.RaceData then
        RaceName = RaceData.RaceData.RaceName
    end

    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local creatorsource = ESX.GetPlayerFromIdentifier(AvailableRaces[AvailableKey].SetupCitizenId)
    -- local targetSource = ESX.GetPlayerFromId(creatorsource)
    -- print(targetSource)

    if creatorsource ~= Player.source then
        TriggerClientEvent('mythic_notify:client:SendAlert', creatorsource,{type="inform", text="Someone has left the race.",length=8000})
    end

    local AmountOfRacers = 0
    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        AmountOfRacers = AmountOfRacers + 1
    end
    if NotFinished[RaceData.RaceId] ~= nil then
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId]+1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = RacerName
        }
    else
        NotFinished[RaceData.RaceId] = {}
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId]+1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = RacerName
        }
    end
    Races[RaceId].Racers[Player.identifier] = nil
    if (AmountOfRacers - 1) == 0 then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceId] ~= nil and next(NotFinished[RaceId]) ~=
            nil then
            for k, v in pairs(NotFinished[RaceId]) do
                if LastRaces[RaceId] ~= nil then
                    LastRaces[RaceId][#LastRaces[RaceId]+1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                else
                    LastRaces[RaceId] = {}
                    LastRaces[RaceId][#LastRaces[RaceId]+1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                end
            end
        end
        Races[RaceId].LastLeaderboard = LastRaces[RaceId]
        Races[RaceId].Racers = {}
        Races[RaceId].Started = false
        Races[RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        TriggerClientEvent('mythic_notify:client:SendAlert', src, {type="inform", text="You were the last person in that race so it was canceled",length=8000})
        TriggerClientEvent('racing:client:LeaveRace', src, Races[RaceId])
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    else
        AvailableRaces[AvailableKey].RaceData = Races[RaceId]
        TriggerClientEvent('racing:client:LeaveRace', src, Races[RaceId])
    end
    TriggerClientEvent('racing:client:UpdateRaceRacers', src, RaceId, Races[RaceId].Racers)
end)

RegisterNetEvent('racing:server:SetupRace', function(RaceId, Laps, RacerName)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    if Races[RaceId] ~= nil then
        if not Races[RaceId].Waiting then
            if not Races[RaceId].Started then
                Races[RaceId].Waiting = true
                local allRaceData = {
                    RaceData = Races[RaceId],
                    Laps = Laps,
                    RaceId = RaceId,
                    SetupCitizenId = Player.getIdentifier(),
                    SetupRacerName = Player.getName()
                }
                AvailableRaces[#AvailableRaces+1] = allRaceData
                TriggerClientEvent('mythic_notify:client:SendAlert', src, {type="success", text ="Race Created", length = 5000})
                TriggerClientEvent('racing:server:ReadyJoinRace', src, allRaceData)

                CreateThread(function()
                    local count = 0
                    while Races[RaceId].Waiting do
                        Wait(1000)
                        if count < 5 * 60 then
                            count = count + 1
                        else
                            local AvailableKey = GetOpenedRaceKey(RaceId)
                            for cid, _ in pairs(Races[RaceId].Racers) do
                                local RacerData = ESX.GetPlayerFromIdentifier(cid)
                                if RacerData ~= nil then
                                    TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="error", text="Race timedout",length=8000})
                                    TriggerClientEvent('racing:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                                end
                            end
                            table.remove(AvailableRaces, AvailableKey)
                            Races[RaceId].LastLeaderboard = {}
                            Races[RaceId].Racers = {}
                            Races[RaceId].Started = false
                            Races[RaceId].Waiting = false
                            LastRaces[RaceId] = nil
                        end
                    end
                end)
            else
                TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="error", text="Race Timedout",length=8000})
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="error", text="Race already Started",length=8000})
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="error", text="This race doesn't exist?",length=8000})
    end
end)

RegisterNetEvent('racing:server:UpdateRaceState', function(RaceId, Started, Waiting)
    Races[RaceId].Waiting = Waiting
    Races[RaceId].Started = Started
end)

RegisterNetEvent('racing:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local CitizenId = Player.getIdentifier()

    Races[RaceId].Racers[CitizenId].Checkpoint = Checkpoint
    Races[RaceId].Racers[CitizenId].Lap = Lap
    Races[RaceId].Racers[CitizenId].Finished = Finished

    TriggerClientEvent('racing:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterNetEvent('racing:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = ESX.GetPlayerFromId(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)

    if not RaceId then
        TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="inform", text="You are not in a race.",length=8000})
        return
    end

    if AvailableRaces[AvailableKey].RaceData.Started then
        TriggerClientEvent('mythic_notify:client:SendAlert', RacerData.PlayerData.source,{type="inform", text="Race has already started.",length=8000})
        return
    end

    AvailableRaces[AvailableKey].RaceData.Started = true
    AvailableRaces[AvailableKey].RaceData.Waiting = false
    for CitizenId, _ in pairs(Races[RaceId].Racers) do
        local Player = ESX.GetPlayerFromIdentifier(CitizenId)
        if Player ~= nil then
            TriggerClientEvent('racing:client:RaceCountdown', Player.source)
        end
    end
end)

RegisterNetEvent('racing:server:SaveRace', function(RaceData)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local PlayerName = Player.getName()
    local PlayerId = Player.getIdentifier()
    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for k, v in pairs(RaceData.Checkpoints) do
        Checkpoints[k] = {
            offset = v.offset,
            coords = v.coords
        }
    end

    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.Identifier,
        CreatorName = Player.getName(),
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {}
    }
    MySQL.Async.insert('INSERT INTO race_tracks (name, checkpoints, creatorid, creatorname, distance, raceid) VALUES (?, ?, ?, ?, ?, ?)',
        {RaceData.RaceName, json.encode(Checkpoints), PlayerId, PlayerName, RaceData.RaceDistance, RaceId})
end)

-----------------------
----   Functions   ----
-----------------------

function SecondsToClock(seconds)
    local seconds = tonumber(seconds)
    local retval = 0
    if seconds <= 0 then
        retval = "00:00:00";
    else
        hours = string.format("%02.f", math.floor(seconds / 3600));
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60));
        retval = hours .. ":" .. mins .. ":" .. secs
    end
    return retval
end


function IsPermissioned(CitizenId, type)
    local Player = ESX.GetPlayerFromId(CitizenId)

    local HasMaster = xPlayer.getInventoryItem('fob_racing_master')
    if HasMaster > 0 then
        return true
    end

    local HasBasic = xPlayer.getInventoryItem('fob_racing_basic')
    if HasBasic > 0 then
        return true
    end
end

function IsNameAvailable(RaceName)
    local retval = true
    for RaceId, _ in pairs(Races) do
        if Races[RaceId].RaceName == RaceName then
            retval = false
            break
        end
    end
    return retval
end

function HasOpenedRace(CitizenId)
    local retval = false
    for k, v in pairs(AvailableRaces) do
        if v.SetupCitizenId == CitizenId then
            retval = true
        end
    end
    return retval
end

function GetOpenedRaceKey(RaceId)
    local retval = nil
    for k, v in pairs(AvailableRaces) do
        if v.RaceId == RaceId then
            retval = k
            break
        end
    end
    return retval
end

function GetCurrentRace(MyCitizenId)
    local retval = nil
    for RaceId, _ in pairs(Races) do
        for cid, _ in pairs(Races[RaceId].Racers) do
            if cid == MyCitizenId then
                retval = RaceId
                break
            end
        end
    end
    return retval
end

function GetRaceId(name)
    local retval = nil
    for k, v in pairs(Races) do
        if v.RaceName == name then
            retval = k
            break
        end
    end
    return retval
end

function GenerateRaceId()
    local RaceId = "LR-" .. math.random(1111, 9999)
    while Races[RaceId] ~= nil do
        RaceId = "LR-" .. math.random(1111, 9999)
    end
    return RaceId
end
--[[ This is just a testing command, but the idea therein from the original version was to gate the access to these races by validation of your possessed key, the Config permissions however, have been circumvented because i cannot be fucked to.]]
RegisterCommand('issueracekey', function(source,raw,args)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local name = Player.getName() -- Pick Relevent getter here, or gate through other means to check if you have the key.
    local type = name
    local itemalready = exports.ox_inventory:Search(source,'fob_racing_basic',{type=name, description="A basic Racing Fob."},true)
    if Player ~= nil then
        exports.ox_inventory:AddItem(source,"fob_racing_basic",1,{type=name, description="A basic Racing Fob."})
    end
end)

RegisterNetEvent('racing:server:onUseRaceKey', function(item)
    UseRacingFob(source,item)
end)

function UseRacingFob(source,item)
    local Player = ESX.GetPlayerFromId(source)
    local citizenid = Player.getName()
    if item.metadata.type == citizenid then -- more validation here, not your dongle, no race for u
        TriggerClientEvent('racing:Client:OpenMainMenu', source, { type = item.name, name = item.type})
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = "inform", text = "You do not own this dongle", length = 8000})
    end
end

ESX.RegisterServerCallback('racing:server:GetRacingLeaderboards', function(source, cb)
    local Leaderboard = {}
    for RaceId, RaceData in pairs(Races) do
        Leaderboard[RaceData.RaceName] = RaceData.Records
    end
    cb(Leaderboard)
end)

ESX.RegisterServerCallback('racing:server:GetRaces', function(source, cb)
    cb(AvailableRaces)
end)

ESX.RegisterServerCallback('racing:server:GetListedRaces', function(source, cb)
    cb(Races)
end)

ESX.RegisterServerCallback('racing:server:GetRacingData', function(source, cb, RaceId)
    cb(Races[RaceId])
end)

ESX.RegisterServerCallback('racing:server:HasCreatedRace', function(source, cb)
    cb(HasOpenedRace(xPlayer.GetPlayerFromId(source).PlayerData.Identifier))
end)

ESX.RegisterServerCallback('racing:server:IsAuthorizedToCreateRaces', function(source, cb, TrackName)
    cb(IsNameAvailable(TrackName))
end)

ESX.RegisterServerCallback('racing:server:GetTrackData', function(source, cb, RaceId)
    local result = MySQL.scalar.await('SELECT * FROM users WHERE identifier = ?', {Races[RaceId].Creator})
    if result[1] ~= nil then
        result[1].firstname = json.decode(result[1].firstname)
        cb(Races[RaceId], result[1])
    else
        cb(Races[RaceId], {
            charinfo = {
                firstname = "Unknown"
            }
        })
    end
end)