local addonName, ns = ...

-- Get oUF object (global or from namespace)
local oUF = ns.oUF or oUF

-- ------------------------------------------------------------------------
-- UpdateFrames helpers
-- ------------------------------------------------------------------------

-- Apply position/visibility to a simple single-unit frame.
local function UpdateSingleFrame(frame, cfg)
    if not frame then return end
    if cfg.Enable then
        frame:Show()
        frame:ClearAllPoints()
        frame:SetPoint(unpack(cfg.Position))
    else
        frame:Hide()
    end
end

-- Apply position/visibility to a SecureHeader that uses a party-style
-- visibility driver ("[group:party,nogroup:raid] show; hide").
-- testVisibility : state-driver string used in Test Mode (default "show")
-- liveVisibility : state-driver string used in live play
local function UpdatePartyHeader(frame, cfg, liveVisibility, showPlayer)
    if not frame then return end
    if cfg.Enable then
        frame:SetAttribute("initial-width",  cfg.Width)
        frame:SetAttribute("initial-height", cfg.Height)
        frame:ClearAllPoints()
        frame:SetPoint(unpack(cfg.Position))
        if ns.TestMode then
            frame:SetAttribute("showSolo",   true)
            frame:SetAttribute("showPlayer", true)
            RegisterStateDriver(frame, "visibility", "show")
        else
            frame:SetAttribute("showSolo", false)
            frame:SetAttribute("showPlayer", showPlayer ~= false)
            RegisterStateDriver(frame, "visibility", liveVisibility)
        end
    else
        UnregisterStateDriver(frame, "visibility")
        frame:Hide()
    end
end

local function UpdateMainTankTestFrame(frame, cfg)
    if not frame then return end
    if ns.TestMode and cfg.Enable then
        if frame:GetParent() ~= UIParent then frame:SetParent(UIParent) end
        frame:ClearAllPoints()
        frame:SetPoint(unpack(cfg.Position))
        frame:Show()
    else
        frame:Hide()
    end
end

local function UpdateBossTestFrames(frames, cfg)
    if not frames then return end
    if ns.TestMode and cfg.Enable then
        for i, frame in ipairs(frames) do
            if frame:GetParent() ~= UIParent then frame:SetParent(UIParent) end
            frame:ClearAllPoints()
            if i == 1 then
                frame:SetPoint(unpack(cfg.Position))
            else
                frame:SetPoint("TOP", frames[i - 1], "BOTTOM", 0, -10)
            end
            frame:Show()
        end
    else
        for _, frame in ipairs(frames) do
            frame:Hide()
        end
    end
end

-- ------------------------------------------------------------------------
-- Update All Frames (Layout and Position)
-- ------------------------------------------------------------------------
function ns.UpdateFrames()
    local C = ns.Config
    if not InCombatLockdown() then
        -- ----------------------------------------------------------------
        -- Single-unit frames (player / target / targettarget / pet / focus)
        -- ----------------------------------------------------------------
        local singleUnits = {
            { frame = ns.player,       cfg = C.Units.Player },
            { frame = ns.target,       cfg = C.Units.Target },
            { frame = ns.targettarget, cfg = C.Units.TargetTarget },
            { frame = ns.pet,          cfg = C.Units.Pet },
            { frame = ns.focus,        cfg = C.Units.Focus },
        }
        for _, u in ipairs(singleUnits) do
            UpdateSingleFrame(u.frame, u.cfg)
        end

        -- ----------------------------------------------------------------
        -- Party / PartyTarget headers
        -- ----------------------------------------------------------------
        UpdatePartyHeader(ns.party,       C.Units.Party,       "[group:party,nogroup:raid] show; hide", false)
        UpdatePartyHeader(ns.partytarget, C.Units.PartyTarget, "[group:party,nogroup:raid] show; hide", false)

        -- ----------------------------------------------------------------
        -- Raid headers
        -- ----------------------------------------------------------------
        if ns.raid then
            if C.Units.Raid.Enable then
                ns.raid:Show()
                ns.raid:ClearAllPoints()
                ns.raid:SetPoint(unpack(C.Units.Raid.Position))

                local spacing    = 5
                local totalWidth = (C.Units.Raid.Width * 8) + (spacing * 7)
                local totalHeight= (C.Units.Raid.Height * 5) + (spacing * 4)
                ns.raid:SetSize(totalWidth, totalHeight)

                for i = 1, 8 do
                    local header = ns.raidHeaders[i]
                    if header then
                        header:SetAttribute("initial-width",  C.Units.Raid.Width)
                        header:SetAttribute("initial-height", C.Units.Raid.Height)
                        header:SetAttribute("xOffset", 0)
                        header:SetAttribute("yOffset", -spacing)

                        if ns.TestMode then
                            header:SetAttribute("showParty",  true)
                            header:SetAttribute("showSolo",   true)
                            header:SetAttribute("showPlayer", true)
                            RegisterStateDriver(header, "visibility", "show")
                        else
                            local visibility = "custom "
                            if C.Units.Raid.ShowParty then
                                visibility = visibility .. "[group:party] show; "
                                header:SetAttribute("showParty", true)
                            else
                                visibility = visibility .. "[group:raid] show; "
                                header:SetAttribute("showParty", false)
                            end

                            if C.Units.Raid.ShowSolo then
                                visibility = visibility .. "[nogroup] show; "
                                header:SetAttribute("showSolo", true)
                            else
                                header:SetAttribute("showSolo", false)
                            end

                            visibility = visibility .. "hide"
                            RegisterStateDriver(header, "visibility", visibility)
                        end

                        header:ClearAllPoints()
                        local offsetX = (i - 1) * (C.Units.Raid.Width + spacing)
                        header:SetPoint("TOPLEFT", ns.raid, "TOPLEFT", offsetX, 0)
                    end
                end
            else
                ns.raid:Hide()
                for i = 1, 8 do
                    local header = ns.raidHeaders[i]
                    if header then
                        UnregisterStateDriver(header, "visibility")
                        header:Hide()
                    end
                end
            end
        end

        -- ----------------------------------------------------------------
        -- Boss frames (boss1-5, stacked vertically)
        -- ----------------------------------------------------------------
        if ns.boss then
            if C.Units.Boss.Enable then
                local prevBoss
                for i = 1, 5 do
                    if ns.boss[i] then
                        if ns.TestMode or not UnitExists("boss" .. i) then
                            ns.boss[i]:Hide()
                        else
                            ns.boss[i]:Show()
                        end
                        ns.boss[i]:ClearAllPoints()
                        if i == 1 then
                            ns.boss[i]:SetPoint(unpack(C.Units.Boss.Position))
                        else
                            ns.boss[i]:SetPoint("TOP", prevBoss, "BOTTOM", 0, -10)
                        end
                        prevBoss = ns.boss[i]
                    end
                end
            else
                for i = 1, 5 do
                    if ns.boss[i] then ns.boss[i]:Hide() end
                end
            end
        end
        UpdateBossTestFrames(ns.testboss, C.Units.Boss)

        -- ----------------------------------------------------------------
        -- MainTank / MainTankTarget headers (raid-only visibility)
        -- ----------------------------------------------------------------
        UpdatePartyHeader(ns.maintank,       C.Units.MainTank,       "[group:raid] show; hide")
        UpdatePartyHeader(ns.maintanktarget, C.Units.MainTankTarget, "[group:raid] show; hide")
        UpdateMainTankTestFrame(ns.testmaintank, C.Units.MainTank)
        UpdateMainTankTestFrame(ns.testmaintanktarget, C.Units.MainTankTarget)

        -- ----------------------------------------------------------------
        -- Refresh appearance of all spawned oUF frames
        -- ----------------------------------------------------------------
        for _, obj in pairs(oUF.objects) do
            if obj.style == "MyLayout" then
                if ns.UpdateUnitFrame then ns.UpdateUnitFrame(obj) end
                if ns.TestMode then
                    if ns.ApplyTestModeData  then ns.ApplyTestModeData(obj) end
                else
                    if obj.isTestPreview then
                        obj:Hide()
                    end
                    if ns.ClearTestModeData  then ns.ClearTestModeData(obj) end
                    if obj.unit and UnitExists(obj.unit) then
                        if obj.Health     and obj.Health.ForceUpdate     then obj.Health:ForceUpdate() end
                        if obj.Power      and obj.Power.ForceUpdate      then obj.Power:ForceUpdate() end
                        if obj.ClassPower and obj.ClassPower.ForceUpdate then obj.ClassPower:ForceUpdate() end
                    end
                end
            end
        end
    end
end


-- ------------------------------------------------------------------------
-- Monitor Raid State for Portrait Override
-- ------------------------------------------------------------------------
local wasInRaid = IsInRaid()
local RosterMonitor = CreateFrame("Frame")
RosterMonitor:RegisterEvent("GROUP_ROSTER_UPDATE")
RosterMonitor:RegisterEvent("PLAYER_ENTERING_WORLD")
RosterMonitor:RegisterEvent("PLAYER_REGEN_ENABLED")
RosterMonitor:SetScript("OnEvent", function(self, event)
    local isInRaid = IsInRaid()
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" or isInRaid ~= wasInRaid then
        wasInRaid = isInRaid
        ns.UpdateFrames()
    end
end)

-- ------------------------------------------------------------------------
-- Hide Blizzard Frames
-- ------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()
ns.testPreviewParent = hiddenParent

local function HideBlizzardFrames()
    if CompactRaidFrameManager then
        CompactRaidFrameManager:SetParent(hiddenParent)
        CompactRaidFrameManager:UnregisterAllEvents()
        CompactRaidFrameManager:Hide()
    end
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetParent(hiddenParent)
        CompactRaidFrameContainer:UnregisterAllEvents()
        CompactRaidFrameContainer:Hide()
    end
end

-- ------------------------------------------------------------------------
-- Configuration Initialization (SavedVariables)
-- ------------------------------------------------------------------------
function ns:OnProfileChanged(event, database, newProfileKey)
    -- Update ns.Config reference when profile changes
    ns.Config = database.profile
    -- Update frame appearance
    ns.UpdateFrames()
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end

local Loader = CreateFrame("Frame")
Loader:RegisterEvent("ADDON_LOADED")
Loader:SetScript("OnEvent", function(self, event, addon)
    if addon ~= addonName then return end

    -- Get version info from TOC
    ns.Version = C_AddOns.GetAddOnMetadata(addonName, "Version")

    -- Check dependency libraries
    if not C_AddOns.IsAddOnLoaded("Ace3") or not C_AddOns.IsAddOnLoaded("LibSharedMedia-3.0") then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Required libraries (Ace3, LibSharedMedia-3.0, oUF) are missing or not enabled.")
        return
    end

    -- Initialize AceDB
    ns.Defaults = ns.Config -- Save reference to original defaults
    local defaults = {
        profile = ns.Defaults
    }
    ns.db = LibStub("AceDB-3.0"):New("oUF_MyLayoutDB", defaults, true)

    -- Register callbacks for profile changes
    ns.db.RegisterCallback(ns, "OnProfileChanged", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileCopied", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileReset", "OnProfileChanged")

    -- Set current profile to ns.Config
    ns.Config = ns.db.profile -- ns.Config now points to live profile

    -- Update frames to apply saved settings
    ns.UpdateFrames()

    -- Initialize options screen
    if ns.SetupOptions then ns.SetupOptions() end

    -- Initialize Minimap Button
    if ns.SetupMinimapButton then ns.SetupMinimapButton() end

    -- Hide Blizzard Raid Frames
    HideBlizzardFrames()

    self:UnregisterEvent("ADDON_LOADED")
end)

-- ------------------------------------------------------------------------
-- Slash Commands (/mylayout reset, /mylayout test, /mylayout config)
-- ------------------------------------------------------------------------
SLASH_OUF_MYLAYOUT1 = "/mylayout"
SlashCmdList["OUF_MYLAYOUT"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if cmd == "reset" then
        ns.db:ResetProfile()
        print("|cff00ff00oUF_MyLayout:|r Current profile settings have been reset.")
    elseif cmd == "config" then
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    elseif cmd == "test" then
        if ns.ToggleTestMode then ns.ToggleTestMode() end
    else
        print("|cff00ff00oUF_MyLayout:|r Commands: /mylayout config, /mylayout test, /mylayout reset")
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    end
end

-- ------------------------------------------------------------------------
-- Factory (Register Style and Spawn Frames)
-- ------------------------------------------------------------------------
if ns.Shared then
    oUF:RegisterStyle("MyLayout", ns.Shared)
end

oUF:Factory(function(self)
    local C = ns.Config
    self:SetActiveStyle("MyLayout")

    -- Spawn and position Player frame
    ns.player = self:Spawn("player")

    -- Spawn and position Target frame
    ns.target = self:Spawn("target")

    -- Spawn Target's Target frame
    ns.targettarget = self:Spawn("targettarget")

    -- Spawn and position Pet frame
    ns.pet = self:Spawn("pet")

    -- Spawn Focus frame
    ns.focus = self:Spawn("focus")

    -- Spawn Party frame
    ns.party = self:SpawnHeader("oUF_MyLayoutParty", nil,
        "showParty", true,
        "yOffset", -60,
        "initial-width", C.Units.Party.Width,
        "initial-height", C.Units.Party.Height
    )

    -- Spawn Party Target frame
    ns.partytarget = self:SpawnHeader("oUF_MyLayoutPartyTarget", nil,
        "showParty", true,
        "yOffset", -60,
        "initial-width", C.Units.PartyTarget.Width,
        "initial-height", C.Units.PartyTarget.Height,
        "oUF-initialConfigFunction", [[
            self:SetAttribute('unitsuffix', 'target')
        ]]
    )

    -- Spawn Raid frame
    ns.raid = CreateFrame("Frame", "oUF_MyLayoutRaidHolder", UIParent)
    ns.raid:SetSize(100, 100)

    ns.raidHeaders = {}
    for i = 1, 8 do
        ns.raidHeaders[i] = self:SpawnHeader("oUF_MyLayoutRaid" .. i, nil,
            "showRaid", true,
            "xOffset", 0,
            "yOffset", -5,
            "point", "TOP",
            "groupFilter", tostring(i),
            "groupBy", "GROUP",
            "groupingOrder", tostring(i),
            "sortMethod", "INDEX",
            "initial-width", C.Units.Raid.Width,
            "initial-height", C.Units.Raid.Height
        )
    end

    -- Spawn Boss frames (Boss1 - Boss5)
    ns.boss = {}
    for i = 1, 5 do
        ns.boss[i] = self:Spawn("boss" .. i)
    end

    ns.testboss = {}
    for i = 1, 5 do
        ns.testboss[i] = self:Spawn("player", "oUF_MyLayoutBossTest" .. i)
        ns.testboss[i].isTestPreview = true
        ns.testboss[i].unit = nil
    end

    -- Spawn Main Tank frame
    ns.maintank = self:SpawnHeader("oUF_MyLayoutMainTank", nil,
        "showRaid", true,
        "groupFilter", "MAINTANK",
        "yOffset", -10,
        "initial-width", C.Units.MainTank.Width,
        "initial-height", C.Units.MainTank.Height
    )

    -- Spawn Main Tank Target frame
    ns.maintanktarget = self:SpawnHeader("oUF_MyLayoutMainTankTarget", nil,
        "showRaid", true,
        "groupFilter", "MAINTANK",
        "yOffset", -10,
        "initial-width", C.Units.MainTankTarget.Width,
        "initial-height", C.Units.MainTankTarget.Height,
        "oUF-initialConfigFunction", [[
            self:SetAttribute('unitsuffix', 'target')
        ]]
    )

    ns.testmaintank = self:Spawn("player", "oUF_MyLayoutMainTankTest")
    ns.testmaintank.isTestPreview = true
    ns.testmaintank.unit = nil
    ns.testmaintanktarget = self:Spawn("target", "oUF_MyLayoutMainTankTargetTest")
    ns.testmaintanktarget.isTestPreview = true
    ns.testmaintanktarget.unit = nil

    -- Update all frames once at initial load
    ns.UpdateFrames()
end)
