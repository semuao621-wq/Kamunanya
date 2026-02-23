local EventResolver = {}
EventResolver.__index = EventResolver

local KNOWN_REMOTE_EVENTS = {
    "FishCaught",
    "FishingMinigameChanged",
    "FishingStopped",
    "UpdateChargeState",
    "BaitSpawned",
    "SpawnTotem",
    "ReplicateTextEffect",
    "EquipToolFromHotbar",
    "FavoriteItem",
    "EquipItem",
    "ActivateEnchantingAltar",
    "ActivateSecondEnchantingAltar",
    "RollEnchant",
    "ClaimPirateChest",
    "ObtainedNewFishNotification",
    "PurchaseTotem",
}

local KNOWN_REMOTE_FUNCTIONS = {
    "ChargeFishingRod",
    "RequestFishingMinigameStarted",
    "CancelFishingInputs",
    "CatchFishCompleted",
    "UpdateAutoFishingState",
    "SellAllItems",
    "UpdateFishingRadar",
    "PurchaseWeatherEvent",
    "PurchaseCharm",
    "InitiateTrade",
}

local _initialized = false
local _netFolder = nil
local _netModule = nil
local _resolvedRE = {}
local _resolvedRF = {}
local _nameMap = {}

local function hasAPI(name)
    return typeof(_G[name]) == "function" or typeof(getfenv()[name]) == "function"
end

local function getNetFolder()
    if _netFolder then return _netFolder end
    
    local RS = game:GetService("ReplicatedStorage")
    
    local ok, folder = pcall(function()
        return RS:WaitForChild("Packages", 10)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)
    end)
    
    if ok and folder then
        _netFolder = folder
        return folder
    end
    
    local ok2, folder2 = pcall(function()
        local packages = RS:WaitForChild("Packages", 10)
        local index = packages:WaitForChild("_Index", 5)
        
        for _, child in pairs(index:GetChildren()) do
            if child.Name:find("sleitnick_net") or child.Name:find("net@") then
                local netChild = child:FindFirstChild("net")
                if netChild then
                    return netChild
                end
            end
        end
        return nil
    end)
    
    if ok2 and folder2 then
        _netFolder = folder2
        return folder2
    end
    
    return nil
end

local function getNetModule()
    if _netModule then return _netModule end
    
    local RS = game:GetService("ReplicatedStorage")
    local ok, mod = pcall(function()
        return require(RS.Packages.Net)
    end)
    
    if ok and mod then
        _netModule = mod
        return mod
    end
    
    return nil
end

local function method1_HookNetModule()
    local Net = getNetModule()
    if not Net then return 0 end
    
    local count = 0
    
    if Net.RemoteEvent then
        local originalRE = Net.RemoteEvent
        for _, name in ipairs(KNOWN_REMOTE_EVENTS) do
            if not _resolvedRE[name] then
                local ok, remote = pcall(function()
                    return originalRE(Net, name)
                end)
                if ok and remote then
                    _resolvedRE[name] = remote
                    _nameMap["RE/" .. name] = remote.Name
                    count = count + 1
                end
            end
        end
    end
    
    if Net.RemoteFunction then
        local originalRF = Net.RemoteFunction
        for _, name in ipairs(KNOWN_REMOTE_FUNCTIONS) do
            if not _resolvedRF[name] then
                local ok, remote = pcall(function()
                    return originalRF(Net, name)
                end)
                if ok and remote then
                    _resolvedRF[name] = remote
                    _nameMap["RF/" .. name] = remote.Name
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- Disabled: causes "cannot access Instance (lacking capability Plugin)" in many executors.
-- method1 + method3 are enough for sleitnick_net.
local function method2_GCScan()
    return 0
end

local function method3_ChildrenScan()
    local netFolder = getNetFolder()
    if not netFolder then return 0 end
    
    local count = 0
    local children = netFolder:GetChildren()
    
    for _, child in pairs(children) do
        local name = child.Name
        
        local reMatch = name:match("^RE/(.+)$")
        if reMatch then
            for _, knownName in ipairs(KNOWN_REMOTE_EVENTS) do
                if reMatch == knownName and not _resolvedRE[knownName] then
                    _resolvedRE[knownName] = child
                    _nameMap["RE/" .. knownName] = child.Name
                    count = count + 1
                end
            end
        end
        
        local rfMatch = name:match("^RF/(.+)$")
        if rfMatch then
            for _, knownName in ipairs(KNOWN_REMOTE_FUNCTIONS) do
                if rfMatch == knownName and not _resolvedRF[knownName] then
                    _resolvedRF[knownName] = child
                    _nameMap["RF/" .. knownName] = child.Name
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- Disabled: same Instance capability issue as method2 in many executors.
local function method4_UpvalueScan()
    return 0
end

function EventResolver:Init()
    if _initialized then return true end
    
    local totalExpected = #KNOWN_REMOTE_EVENTS + #KNOWN_REMOTE_FUNCTIONS
    local totalResolved = 0
    
    totalResolved = totalResolved + method1_HookNetModule()
    
    if totalResolved < totalExpected then
        totalResolved = totalResolved + method3_ChildrenScan()
    end
    
    -- method2/method4 can throw "cannot access Instance (lacking capability Plugin)" in some executors
    if totalResolved < totalExpected then
        local ok, n = pcall(method2_GCScan)
        if ok and n then totalResolved = totalResolved + n end
    end
    
    if totalResolved < totalExpected then
        local ok, n = pcall(method4_UpvalueScan)
        if ok and n then totalResolved = totalResolved + n end
    end
    
    _initialized = true
    
    _G.EventResolver = EventResolver
    _G.ResolvedNetEvents = {
        RE = _resolvedRE,
        RF = _resolvedRF,
        NameMap = _nameMap,
    }
    
    return totalResolved > 0
end

function EventResolver:GetRE(originalName)
    if _resolvedRE[originalName] then
        return _resolvedRE[originalName]
    end
    if not _initialized then self:Init() end
    return _resolvedRE[originalName]
end

function EventResolver:GetRF(originalName)
    if _resolvedRF[originalName] then
        return _resolvedRF[originalName]
    end
    if not _initialized then self:Init() end
    return _resolvedRF[originalName]
end

function EventResolver:Get(fullName)
    local prefix, name = fullName:match("^(R[EF])/(.+)$")
    if prefix == "RE" then
        return self:GetRE(name)
    elseif prefix == "RF" then
        return self:GetRF(name)
    end
    return nil
end

function EventResolver:GetAllMappings()
    return {
        RE = _resolvedRE,
        RF = _resolvedRF,
        NameMap = _nameMap,
    }
end

function EventResolver:GetNetFolder()
    return getNetFolder()
end

function EventResolver:IsInitialized()
    return _initialized
end

function EventResolver:GetResolvedCount()
    local reCount = 0
    local rfCount = 0
    for _ in pairs(_resolvedRE) do reCount = reCount + 1 end
    for _ in pairs(_resolvedRF) do rfCount = rfCount + 1 end
    return reCount + rfCount, reCount, rfCount
end

function EventResolver:Reset()
    _initialized = false
    _netFolder = nil
    _netModule = nil
    _resolvedRE = {}
    _resolvedRF = {}
    _nameMap = {}
end

function EventResolver:PrintReport()
end

return EventResolver
