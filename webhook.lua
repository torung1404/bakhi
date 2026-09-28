-- webhook.lua - Discord webhook for ToRung HUB
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[ToRung/WH] Core chưa chạy") end

local HttpService = game:GetService("HttpService")
local log = S2.Core.log
local PATH = "ToRungHub/webhook.json"

local Webhook = {
    URL = "",
    Enabled = false,
    Events = {
        BossKilled = true,
        QuestAccepted = true,
        ItemDrop = false,
        Error = true,
        FishCaught = false,
        SoulGrabbed = false,
    },
}

local function ensureFolder()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
end

function Webhook:Load()
    ensureFolder()
    if not isfile(PATH) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
    if ok and type(data) == "table" then
        self.URL = data.URL or ""
        self.Enabled = data.Enabled or false
        if type(data.Events) == "table" then
            for k, v in pairs(data.Events) do self.Events[k] = v end
        end
    end
end

function Webhook:Save()
    ensureFolder()
    pcall(function()
        writefile(PATH, HttpService:JSONEncode({
            URL = self.URL,
            Enabled = self.Enabled,
            Events = self.Events,
        }))
    end)
end

function Webhook:Send(title, description, color, fields)
    if not self.Enabled or self.URL == "" then return end
    local payload = {
        username = "ToRung HUB",
        embeds = {{
            title = title or "Notification",
            description = description or "",
            color = color or 0x8A79E7,
            fields = fields or {},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "ToRung HUB" },
        }},
    }
    local json = HttpService:JSONEncode(payload)
    local url = self.URL

    task.spawn(function()
        local methods = {
            function() return request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json }) end,
            function() return http_request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json }) end,
            function() return syn and syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json }) end,
            function() return HttpService:PostAsync(url, json) end,
        }
        for _, fn in ipairs(methods) do
            local ok, res = pcall(fn)
            if ok and res then
                log("[WH] sent:", title)
                return
            end
        end
        warn("[ToRung/WH] all send methods failed")
    end)
end

function Webhook:Notify(event, title, description, color, fields)
    if not self.Enabled then return end
    if not self.Events[event] then return end
    self:Send(title, description, color, fields)
end

function Webhook:Test()
    local wasEnabled = self.Enabled
    self.Enabled = true
    self:Send("Test Webhook", "ToRung HUB webhook is working!", 0x38BA5B)
    self.Enabled = wasEnabled
end

Webhook:Load()
S2.Webhook = Webhook

print("[ToRung/WH] ready | enabled=" .. tostring(Webhook.Enabled))
