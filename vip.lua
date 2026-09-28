-- vip.lua - VIP server management for ToRung HUB
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[VIP] core missing") end

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local log = S2.Core.log

local PATH = "ToRungHub/vip.json"

local VIP = {
    Enabled = false,
    Mode = "MyPS",  -- "MyPS" | "ServerID" | "Link"
    PlaceId = 0,
    ServerId = "",
    OwnerId = 0,
    LinkCode = "",
    AutoJoinOnStart = false,
    AutoRejoinOnKick = false,
    _rejoinTask = nil,
}

local function ensure()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
end

function VIP:Save()
    ensure()
    pcall(function()
        writefile(PATH, HttpService:JSONEncode({
            Enabled = self.Enabled, Mode = self.Mode,
            PlaceId = self.PlaceId, ServerId = self.ServerId,
            OwnerId = self.OwnerId, LinkCode = self.LinkCode,
            AutoJoinOnStart = self.AutoJoinOnStart,
            AutoRejoinOnKick = self.AutoRejoinOnKick,
        }))
    end)
end

function VIP:Load()
    ensure()
    if not isfile(PATH) then return end
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
    if ok and type(d) == "table" then
        for k, v in pairs(d) do if self[k] ~= nil then self[k] = v end end
    end
end

function VIP:CaptureCurrent()
    local ok, err = pcall(function()
        self.PlaceId = game.PlaceId
        self.ServerId = game.PrivateServerId or game.JobId or ""
        self.OwnerId = game.PrivateServerOwnerId or 0
    end)
    if ok then
        self:Save()
        log("[VIP] captured: PlaceId=" .. tostring(self.PlaceId)
            .. " ServerId=" .. tostring(self.ServerId):sub(1, 20) .. "...")
        return true
    end
    return false, err
end

function VIP:ParseLink(url)
    if type(url) ~= "string" or url == "" then return nil end
    local placeId = url:match("/games/(%d+)")
    local linkCode = url:match("privateServerLinkCode=([%w%-_]+)")
    if not placeId then return nil, "no PlaceId in URL" end
    if not linkCode then return nil, "no linkCode in URL" end
    return tonumber(placeId), linkCode
end

function VIP:Join()
    if not self.Enabled then return false, "VIP disabled" end
    if self.PlaceId == 0 or self.ServerId == "" then
        return false, "no server configured"
    end

    local ok, err = pcall(function()
        if self.Mode == "MyPS" or self.Mode == "ServerID" then
            TeleportService:TeleportToPrivateServer(
                self.PlaceId, self.ServerId, {LP}
            )
        elseif self.Mode == "Link" then
            TeleportService:TeleportToPrivateServer(
                self.PlaceId, self.LinkCode, {LP}
            )
        end
    end)
    if ok then
        log("[VIP] joining...")
        return true
    end
    return false, tostring(err)
end

function VIP:StartAutoRejoin()
    if self._rejoinTask then return end
    self._rejoinTask = task.spawn(function()
        while self.AutoRejoinOnKick and self.Enabled do
            task.wait(2)
            if not Players.LocalPlayer or not LP.Parent then
                task.wait(1)
                if self.AutoRejoinOnKick and self.Enabled then
                    self:Join()
                end
                break
            end
        end
        self._rejoinTask = nil
    end)
end

function VIP:StopAutoRejoin()
    self.AutoRejoinOnKick = false
    if self._rejoinTask then
        pcall(task.cancel, self._rejoinTask)
        self._rejoinTask = nil
    end
end

VIP:Load()
S2.VIP = VIP
print("[ToRung/VIP] ready | enabled=" .. tostring(VIP.Enabled) .. " mode=" .. VIP.Mode)
