local addonName, ns = ...

-- Get oUF object (global or from namespace)
local oUF = ns.oUF or oUF

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local percentCurve = C_CurveUtil.CreateCurve()
percentCurve:SetType(Enum.LuaCurveType.Linear)
percentCurve:AddPoint(0, 0)
percentCurve:AddPoint(1, 100)

local alphaCurve = C_CurveUtil.CreateCurve()
alphaCurve:SetType(Enum.LuaCurveType.Linear)
alphaCurve:AddPoint(0.0, 255)
alphaCurve:AddPoint(0.99, 255)
alphaCurve:AddPoint(1.0, 0)

-- Custom Tag: AFK (displayed in red)
oUF.Tags.Methods["my:afk"] = function(unit)
    if UnitIsAFK(unit) then
        return "|cffff0000AFK|r"
    end
end
oUF.Tags.Events["my:afk"] = "PLAYER_FLAGS_CHANGED UNIT_FLAGS"

-- Custom Tag: HP Percent (1 decimal place)
oUF.Tags.Methods["my:perhp"] = function(unit)
    local per = UnitHealthPercent(unit, false, percentCurve)
    return string.format("%.1f", per)
end
oUF.Tags.Events["my:perhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- Custom Tag: HP Percent (Gradient Color)
oUF.Tags.Methods["my:perhp_grad"] = function(unit)
    local per = UnitHealthPercent(unit, false, percentCurve)
    local alpha = UnitHealthPercent(unit, false, alphaCurve)
    return string.format("|c%02xffffff%.1f%%|r", alpha, per)
end
oUF.Tags.Events["my:perhp_grad"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- Custom Tag: Short Value (Human Readable)
oUF.Tags.Methods["my:shortval"] = function(unit)
    local val = UnitHealth(unit)
    if type(val) ~= "number" then return val end
    return AbbreviateNumbers(val)
end
oUF.Tags.Events["my:shortval"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- Custom Tag: Short Name (adjusted by visual width)
oUF.Tags.Methods["my:shortname"] = function(unit)
    local name = UnitName(unit)
    if not name then return "" end
    if issecretvalue and issecretvalue(name) then return name end
    if type(name) ~= "string" then return name end
    
    -- Get settings according to unit
    local C = ns.Config
    local maxLen = 10 -- Default value

    if unit == "targettarget" then maxLen = C.Units.TargetTarget.ShortNameLength
    elseif unit == "focus" then maxLen = C.Units.Focus.ShortNameLength
    elseif unit:match("party%d?target") then maxLen = C.Units.PartyTarget.ShortNameLength
    elseif unit:match("party") then maxLen = C.Units.Party.ShortNameLength
    elseif unit:match("raid") then maxLen = C.Units.Raid.ShortNameLength
    elseif unit:match("boss") then maxLen = C.Units.Boss.ShortNameLength
    elseif unit:match("maintank") then maxLen = C.Units.MainTank.ShortNameLength -- maintanktarget etc. might be included here
    end
    maxLen = maxLen or 10

    local currentLen = 0
    local byteOffset = 1
    local len = #name

    while byteOffset <= len do
        local b = string.byte(name, byteOffset)
        local charLen = 1
        local charWidth = 1

        if b < 128 then
            charLen = 1
            charWidth = 1
        elseif b >= 192 and b < 224 then
            charLen = 2
            charWidth = 1
        elseif b >= 224 and b < 240 then
            charLen = 3
            charWidth = 2
        elseif b >= 240 then
            charLen = 4
            charWidth = 2
        end

        if currentLen + charWidth > maxLen then
            return string.sub(name, 1, byteOffset - 1) .. "..."
        end

        currentLen = currentLen + charWidth
        byteOffset = byteOffset + charLen
    end
    return name
end
oUF.Tags.Events["my:shortname"] = "UNIT_NAME_UPDATE"

-- ------------------------------------------------------------------------
-- SharedMedia Support
-- ------------------------------------------------------------------------
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local InternalMedia = {
    ["oUF_MyLayout Gradient"] = "Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga",
    ["oUF_MyLayout Minimalist"] = "Interface\\Addons\\oUF_MyLayout\\media\\textures\\Minimalist.tga",
    ["oUF_MyLayout Prototype"] = "Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf",
}

if LSM then
    for name, path in pairs(InternalMedia) do
        local mediaType = path:match("%.ttf$") and "font" or "statusbar"
        LSM:Register(mediaType, name, path)
    end
end

local function GetMedia(mediaType, key)
    if LSM then
        return LSM:Fetch(mediaType, key) or InternalMedia[key] or key
    end
    return InternalMedia[key] or key
end

-- ------------------------------------------------------------------------
-- Filter Functions
-- ------------------------------------------------------------------------
local function CustomFilter(element, unit, data)
    if element.onlyShowPlayer then
        return data.sourceUnit == "player" or data.sourceUnit == "vehicle" or data.sourceUnit == "pet"
    end
    return true
end

-- Helper function to update icons (Moved out to avoid closure creation)
local function UpdateIcon(self, icon, iconKey, iConfig, defaultIconsConfig)
    if not icon then return end

    local liveIconConfig = iConfig[iconKey] or {}
    local defaultIconConfig = defaultIconsConfig[iconKey] or {}

    local isEnabled = liveIconConfig.Enable
    if isEnabled == nil then isEnabled = defaultIconConfig.Enable end

    local size = liveIconConfig.Size or defaultIconConfig.Size
    local point = liveIconConfig.Point or defaultIconConfig.Point
    local x = liveIconConfig.X
    if x == nil then x = defaultIconConfig.X end
    local y = liveIconConfig.Y
    if y == nil then y = defaultIconConfig.Y end

    if isEnabled and size and point and x ~= nil and y ~= nil then
        icon:SetAlpha(1)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint(point, self.Health, point, x, y)
    else
        icon:SetAlpha(0)
    end
end

-- ------------------------------------------------------------------------
-- Frame Update Function (Live Update)
-- ------------------------------------------------------------------------
local function UpdateUnitFrame(self, isInit)
    local unit = self.unit
    local C = ns.Config
    local name = self:GetName()

    local uConfig = C.Units.Default
    if unit == "pet" then uConfig = C.Units.Pet
    elseif name and name:match("oUF_MyLayoutMainTankTarget") then uConfig = C.Units.MainTankTarget
    elseif name and name:match("oUF_MyLayoutMainTank") then uConfig = C.Units.MainTank
    elseif name and name:match("oUF_MyLayoutRaid") then uConfig = C.Units.Raid
    elseif name and name:match("oUF_MyLayoutPartyTarget") then uConfig = C.Units.PartyTarget
    elseif name and name:match("oUF_MyLayoutParty") then uConfig = C.Units.Party
    elseif name and name:match("oUF_MyLayoutBoss") then uConfig = C.Units.Boss
    elseif unit == "player" then uConfig = C.Units.Player
    elseif unit == "target" then uConfig = C.Units.Target
    elseif unit == "targettarget" then uConfig = C.Units.TargetTarget
    elseif unit == "focus" then uConfig = C.Units.Focus
    end

    local fontMain = GetMedia("font", C.Media.Font)

    if not InCombatLockdown() then
        self:SetSize(uConfig.Width, uConfig.Height)
    end

    if self.Health then
        self.Health:SetHeight(uConfig.HealthHeight)
        local textureBar = GetMedia("statusbar", uConfig.HealthBarTexture or C.Media.HealthBar)
        self.Health:SetStatusBarTexture(textureBar)
        self.Health:SetStatusBarColor(unpack(C.Colors.Health))
        if self.Health.bg then self.Health.bg:SetColorTexture(unpack(C.Colors.HealthBg)) end
    end

    if self.Power then
        self.Power:SetHeight(uConfig.PowerHeight or 10)
        local texturePower = GetMedia("statusbar", uConfig.PowerBarTexture or C.Media.PowerBar)
        self.Power:SetStatusBarTexture(texturePower)
        -- self.Power:SetStatusBarColor(unpack(C.Colors.Power))
        if self.Power.bg then self.Power.bg:SetColorTexture(unpack(C.Colors.PowerBg)) end
    end

    if self.Name then
        local nConfig = uConfig.NameText or {}
        if nConfig.Enable == false then
            self.Name:Hide()
        else
            self.Name:Show()
            local nFont = GetMedia("font", nConfig.Font or C.Media.Font)
            local nSize = nConfig.Size or 20
            local nOutline = nConfig.Outline or "OUTLINE"
            self.Name:SetFont(nFont, nSize, nOutline)

            -- Apply only if position settings exist (relative to Health bar)
            if nConfig.Point then
                self.Name:ClearAllPoints()
                self.Name:SetPoint(nConfig.Point, self.Health, nConfig.Point, nConfig.X or 0, nConfig.Y or 0)
            end

            -- NameTag update
            if uConfig.NameTag then
                self:Tag(self.Name, uConfig.NameTag)
                self.Name:UpdateTag()
            end
        end
    end

    if self.Level then
        -- Level text uses NameText settings for now or default
        local nConfig = uConfig.NameText or {}
        local nFont = GetMedia("font", nConfig.Font or C.Media.Font)
        self.Level:SetFont(nFont, 20, "OUTLINE")
    end

    if self.HpVal then
        local hConfig = uConfig.HealthText or {}
        local hFont = GetMedia("font", hConfig.Font or C.Media.Font)
        local hSize = hConfig.Size or 24
        local hOutline = hConfig.Outline or "OUTLINE"
        self.HpVal:SetFont(hFont, hSize, hOutline)
        self.HpVal:ClearAllPoints()
        local point, x, y = hConfig.Point or "RIGHT", hConfig.X or 0, hConfig.Y or 0
        self.HpVal:SetPoint(point, self.Health, point, x, y)
    end

    if self.CastbarRaw then
        local cbConfig = uConfig.Castbar or {}
        if cbConfig.Enable then
            self.Castbar = self.CastbarRaw
            self.Castbar:Show()
            if not isInit then
                if not self:IsElementEnabled("Castbar") then
                    self:EnableElement("Castbar")
                end
            end
        else
            if not isInit and self:IsElementEnabled("Castbar") then
                self:DisableElement("Castbar")
            end
            self.Castbar = nil
            self.CastbarRaw:Hide()
        end

        if self.Castbar then
            local defaultCbConfig = (ns.Defaults.Units[unitKey] and ns.Defaults.Units[unitKey].Castbar) or {}

            local height = cbConfig.Height or defaultCbConfig.Height or 20
            local width = cbConfig.Width or defaultCbConfig.Width or 0

            self.Castbar:SetHeight(height)
            self.Castbar:ClearAllPoints()

            local point = cbConfig.Point or defaultCbConfig.Point or "TOPLEFT"
            local relativeToKey = cbConfig.RelativeTo or defaultCbConfig.RelativeTo or "FRAME"
            local relativePoint = cbConfig.RelativePoint or defaultCbConfig.RelativePoint or "BOTTOMLEFT"
            local x = cbConfig.X
            if x == nil then x = defaultCbConfig.X or 0 end
            local y = cbConfig.Y
            if y == nil then y = defaultCbConfig.Y or -5 end

            local relativeFrame = self
            if relativeToKey == "HEALTH" then
                relativeFrame = self.Health
            elseif relativeToKey == "POWER" then
                relativeFrame = self.Power
            end

            self.Castbar:SetPoint(point, relativeFrame, relativePoint, x, y)

            if width > 0 then
                self.Castbar:SetWidth(width)
            else -- Auto width
                self.Castbar:SetWidth(self:GetWidth())
            end

            local textureBar = GetMedia("statusbar", uConfig.HealthBarTexture or C.Media.HealthBar)
            self.Castbar:SetStatusBarTexture(textureBar)
            self.Castbar:SetStatusBarColor(unpack(C.Colors.Castbar))
            if self.Castbar.bg then self.Castbar.bg:SetColorTexture(unpack(C.Colors.CastbarBg)) end

            local cbtConfig = uConfig.CastbarText or {}
            local cbFont = GetMedia("font", cbtConfig.Font or C.Media.Font)
            local cbSize = cbtConfig.Size or 12
            local cbOutline = cbtConfig.Outline or "OUTLINE"
            if self.Castbar.Text then self.Castbar.Text:SetFont(cbFont, cbSize, cbOutline) end
            if self.Castbar.Time then self.Castbar.Time:SetFont(cbFont, cbSize, cbOutline) end
        end
    end

    if self.PortraitModel then
        local pConfig = uConfig.Portrait or {}
        -- For compatibility, convert to table if boolean
        if type(pConfig) ~= "table" then
            pConfig = { Enable = pConfig }
        end

        local isPortraitEnabled = pConfig.Enable
        local _, instanceType = IsInInstance()
        if ns.Config.General then
            if ns.Config.General.DisablePortraitsInRaid and IsInRaid() then
                isPortraitEnabled = false
            elseif ns.Config.General.DisablePortraitsInDungeon and instanceType == "party" then
                isPortraitEnabled = false
            end
        end

        if isPortraitEnabled then
            self.Portrait = self.PortraitModel
            self.Portrait:Show()
            if self.PortraitBg then self.PortraitBg:Show() end

            self.Portrait:SetSize(pConfig.Width or 150, pConfig.Height or 43)
            self.Portrait:ClearAllPoints()
            self.Portrait:SetPoint("LEFT", self, "LEFT", pConfig.X or 2, pConfig.Y or 0)

            if not isInit then
                if not self:IsElementEnabled("Portrait") then
                    self:EnableElement("Portrait")
                end
                self.Portrait:ForceUpdate()
            end
        else
            if not isInit and self:IsElementEnabled("Portrait") then
                self:DisableElement("Portrait")
            end
            self.Portrait = nil -- Remove from oUF auto-detection
            self.PortraitModel:Hide()
            if self.PortraitBg then self.PortraitBg:Hide() end
        end
    end

    if self.Buffs then
        local bConfig = uConfig.Buffs or {}
        if bConfig.Enable then
            self.Buffs:Show()
            self.Buffs.size = bConfig.Size or 20
            self.Buffs.spacing = 4
            self.Buffs:SetWidth(uConfig.Width)
            self.Buffs:SetHeight((bConfig.Size or 20) * 2)
            self.Buffs:ClearAllPoints()
            self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", bConfig.X or 0, bConfig.Y or 5)
            self.Buffs.onlyShowPlayer = bConfig.PlayerOnly
            if not isInit then
                if not self:IsElementEnabled("Buffs") then self:EnableElement("Buffs") end
                if self.Buffs.ForceUpdate then self.Buffs:ForceUpdate() end
            end
        else
            self.Buffs:Hide()
            if not isInit and self:IsElementEnabled("Buffs") then
                self:DisableElement("Buffs")
            end
        end
    end

    if self.Debuffs then
        local dConfig = uConfig.Debuffs or {}
        if dConfig.Enable then
            self.Debuffs:Show()
            self.Debuffs.size = dConfig.Size or 20
            self.Debuffs.spacing = 4
            self.Debuffs:SetWidth(uConfig.Width)
            self.Debuffs:SetHeight((dConfig.Size or 20) * 2)
            self.Debuffs:ClearAllPoints()
            self.Debuffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", dConfig.X or 0, dConfig.Y or 35)
            self.Debuffs.onlyShowPlayer = dConfig.PlayerOnly
            if not isInit then
                if not self:IsElementEnabled("Debuffs") then self:EnableElement("Debuffs") end
                if self.Debuffs.ForceUpdate then self.Debuffs:ForceUpdate() end
            end
        else
            self.Debuffs:Hide()
            if not isInit and self:IsElementEnabled("Debuffs") then
                self:DisableElement("Debuffs")
            end
        end
    end

    -- Update Icons
    local iConfig = uConfig.Icons or {}
    local unitKey
    local name = self:GetName()
    if self.unit == "pet" then unitKey = "Pet"
    elseif name and name:match("oUF_MyLayoutMainTankTarget") then unitKey = "MainTankTarget"
    elseif name and name:match("oUF_MyLayoutMainTank") then unitKey = "MainTank"
    elseif name and name:match("oUF_MyLayoutRaid") then unitKey = "Raid"
    elseif name and name:match("oUF_MyLayoutPartyTarget") then unitKey = "PartyTarget"
    elseif name and name:match("oUF_MyLayoutParty") then unitKey = "Party"
    elseif name and name:match("oUF_MyLayoutBoss") then unitKey = "Boss"
    elseif self.unit == "player" then unitKey = "Player"
    elseif self.unit == "targettarget" then unitKey = "TargetTarget"
    elseif self.unit == "target" then unitKey = "Target"
    else unitKey = "Default" end
    local defaultIconsConfig = (ns.Defaults.Units[unitKey] and ns.Defaults.Units[unitKey].Icons) or {}

    UpdateIcon(self, self.RaidTargetIndicator, "RaidTarget", iConfig, defaultIconsConfig)
    UpdateIcon(self, self.GroupRoleIndicator, "GroupRole", iConfig, defaultIconsConfig)
    UpdateIcon(self, self.ReadyCheckIndicator, "ReadyCheck", iConfig, defaultIconsConfig)
    UpdateIcon(self, self.LeaderIndicator, "Leader", iConfig, defaultIconsConfig)

    UpdateIcon(self, self.AssistantIndicator, "Assistant", iConfig, defaultIconsConfig)
    if self.unit == "player" then
        UpdateIcon(self, self.RestingIndicator, "Resting", iConfig, defaultIconsConfig)
        UpdateIcon(self, self.CombatIndicator, "Combat", iConfig, defaultIconsConfig)
    end
end

function ns.UpdateFrames()
    local C = ns.Config
    if not InCombatLockdown() then
        -- Player
        if ns.player then
            if C.Units.Player.Enable then
                ns.player:Show()
                ns.player:ClearAllPoints()
                ns.player:SetPoint(unpack(C.Units.Player.Position))
            else
                ns.player:Hide()
            end
        end
        -- Target
        if ns.target then
            if C.Units.Target.Enable then
                ns.target:Show()
                ns.target:ClearAllPoints()
                ns.target:SetPoint(unpack(C.Units.Target.Position))
            else
                ns.target:Hide()
            end
        end
        -- TargetTarget
        if ns.targettarget then
            if C.Units.TargetTarget.Enable then
                ns.targettarget:Show()
                ns.targettarget:ClearAllPoints()
                ns.targettarget:SetPoint(unpack(C.Units.TargetTarget.Position))
            else
                ns.targettarget:Hide()
            end
        end
        -- Pet
        if ns.pet then
            if C.Units.Pet.Enable then
                ns.pet:Show()
                ns.pet:ClearAllPoints()
                ns.pet:SetPoint(unpack(C.Units.Pet.Position))
            else
                ns.pet:Hide()
            end
        end
        -- Focus
        if ns.focus then
            if C.Units.Focus.Enable then
                ns.focus:Show()
                ns.focus:ClearAllPoints()
                ns.focus:SetPoint(unpack(C.Units.Focus.Position))
            else
                ns.focus:Hide()
            end
        end
        -- Party
        if ns.party then
            if C.Units.Party.Enable then
                ns.party:SetAttribute("initial-width", C.Units.Party.Width)
                ns.party:SetAttribute("initial-height", C.Units.Party.Height)
                ns.party:ClearAllPoints()
                ns.party:SetPoint(unpack(C.Units.Party.Position))
                RegisterStateDriver(ns.party, "visibility", "[group:party,nogroup:raid] show; hide")
            else
                UnregisterStateDriver(ns.party, "visibility")
                ns.party:Hide()
            end
        end
        -- PartyTarget
        if ns.partytarget then
            if C.Units.PartyTarget.Enable then
                ns.partytarget:SetAttribute("initial-width", C.Units.PartyTarget.Width)
                ns.partytarget:SetAttribute("initial-height", C.Units.PartyTarget.Height)
                ns.partytarget:ClearAllPoints()
                ns.partytarget:SetPoint(unpack(C.Units.PartyTarget.Position))
                RegisterStateDriver(ns.partytarget, "visibility", "[group:party,nogroup:raid] show; hide")
            else
                UnregisterStateDriver(ns.partytarget, "visibility")
                ns.partytarget:Hide()
            end
        end
        -- Raid
        if ns.raid then
            if C.Units.Raid.Enable then
                ns.raid:Show()
                ns.raid:ClearAllPoints()
                ns.raid:SetPoint(unpack(C.Units.Raid.Position))
                
                -- Update holder size for Edit Mode
                local spacing = 5
                local totalWidth = (C.Units.Raid.Width * 8) + (spacing * 7)
                local totalHeight = (C.Units.Raid.Height * 5) + (spacing * 4)
                ns.raid:SetSize(totalWidth, totalHeight)

                for i = 1, 8 do
                    local header = ns.raidHeaders[i]
                    if header then
                        local visibility = "custom "
                        if C.Units.Raid.ShowParty then
                            visibility = visibility .. "[group:party] show; "
                            header:SetAttribute("showParty", true)
                        else
                            visibility = visibility .. "[group:raid] show; "
                            header:SetAttribute("showParty", false)
                        end

                        header:SetAttribute("initial-width", C.Units.Raid.Width)
                        header:SetAttribute("initial-height", C.Units.Raid.Height)
                        header:SetAttribute("xOffset", 0)
                        header:SetAttribute("yOffset", -spacing)

                        if C.Units.Raid.ShowSolo then
                            visibility = visibility .. "[nogroup] show; "
                            header:SetAttribute("showSolo", true)
                        else
                            header:SetAttribute("showSolo", false)
                        end
                        
                        visibility = visibility .. "hide"
                        RegisterStateDriver(header, "visibility", visibility)

                        header:ClearAllPoints()
                        -- Fixed position for each group column
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
        -- Boss
        if ns.boss then
            if C.Units.Boss.Enable then
                local prevBoss
                for i=1, 5 do
                    if ns.boss[i] then
                        ns.boss[i]:Show()
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
                for i=1, 5 do
                    if ns.boss[i] then ns.boss[i]:Hide() end
                end
            end
        end
        -- MainTank
        if ns.maintank then
            if C.Units.MainTank.Enable then
                ns.maintank:Show()
                ns.maintank:SetAttribute("initial-width", C.Units.MainTank.Width)
                ns.maintank:SetAttribute("initial-height", C.Units.MainTank.Height)
                ns.maintank:ClearAllPoints()
                ns.maintank:SetPoint(unpack(C.Units.MainTank.Position))
            else
                ns.maintank:Hide()
            end
        end
        -- MainTankTarget
        if ns.maintanktarget then
            if C.Units.MainTankTarget.Enable then
                ns.maintanktarget:Show()
                ns.maintanktarget:SetAttribute("initial-width", C.Units.MainTankTarget.Width)
                ns.maintanktarget:SetAttribute("initial-height", C.Units.MainTankTarget.Height)
                ns.maintanktarget:ClearAllPoints()
                ns.maintanktarget:SetPoint(unpack(C.Units.MainTankTarget.Position))
            else
                ns.maintanktarget:Hide()
            end
        end
        for _, obj in pairs(oUF.objects) do
            if obj.style == "MyLayout" then
                UpdateUnitFrame(obj)
                if obj.Health and obj.Health.ForceUpdate then
                    obj.Health:ForceUpdate()
                end
                if obj.Power and obj.Power.ForceUpdate then
                    obj.Power:ForceUpdate()
                end
                if obj.ClassPower and obj.ClassPower.ForceUpdate then
                    obj.ClassPower:ForceUpdate()
                end
            end
        end
    end
end

-- Monitor Raid State for Portrait Override
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
end

local Loader = CreateFrame("Frame")
Loader:RegisterEvent("ADDON_LOADED")
Loader:SetScript("OnEvent", function(self, event, addon)
    if addon ~= addonName then return end

    -- Get version info from TOC
    ns.Version = C_AddOns.GetAddOnMetadata(addonName, "Version")

    -- Check dependency libraries
    -- if not C_AddOns.IsAddOnLoaded("Ace3") or not C_AddOns.IsAddOnLoaded("LibSharedMedia-3.0") or not C_AddOns.IsAddOnLoaded("oUF") then
    if not C_AddOns.IsAddOnLoaded("Ace3") or not C_AddOns.IsAddOnLoaded("LibSharedMedia-3.0") then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Required libraries (Ace3, LibSharedMedia-3.0, oUF) are missing or not enabled.")
        return
    end

    -- Initialize AceDB
    -- Use ns.Config defined in Config.lua as default values
    ns.Defaults = ns.Config -- Save reference to the original defaults
    local defaults = {
        profile = ns.Defaults
    }
    ns.db = LibStub("AceDB-3.0"):New("oUF_MyLayoutDB", defaults, true)

    -- Register callbacks for profile changes
    ns.db.RegisterCallback(ns, "OnProfileChanged", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileCopied", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileReset", "OnProfileChanged")

    -- Set current profile to ns.Config
    ns.Config = ns.db.profile -- ns.Config now points to the live profile

    -- Update frames to apply saved settings
    ns.UpdateFrames()

    -- Initialize options screen
    if ns.SetupOptions then ns.SetupOptions() end

    -- Hide Blizzard Raid Frames
    HideBlizzardFrames()

    self:UnregisterEvent("ADDON_LOADED")
end)

-- Slash Commands (/mylayout reset)
SLASH_OUF_MYLAYOUT1 = "/mylayout"
SlashCmdList["OUF_MYLAYOUT"] = function(msg)
    if msg == "reset" then
        ns.db:ResetProfile()
        print("|cff00ff00oUF_MyLayout:|r Current profile settings have been reset.")
    elseif msg == "config" then
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    else
        print("|cff00ff00oUF_MyLayout:|r Commands: /mylayout config, /mylayout reset")
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    end
end

-- ------------------------------------------------------------------------
-- Style Definition Function (Shared Style Function)
-- ------------------------------------------------------------------------
-- Define the appearance of each unit frame (player, target, etc.) within this function.
local function Shared(self, unit)
    -- 1. Basic Frame Settings
    -- Avoid ADDON_ACTION_BLOCKED: Do not execute RegisterForClicks during combat
    if not InCombatLockdown() then
        self:RegisterForClicks("AnyUp")
    end
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)

    -- Set unit for initialization
    self.unit = unit

    local C = ns.Config
    local uConfig = C.Units.Default -- Required for initial construction

    -- Background settings (optional)
    local bg = self:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1) -- Semi-transparent black

    -- --------------------------------------------------------------------
    -- 2. Create Health Bar
    -- --------------------------------------------------------------------
    local Health = CreateFrame("StatusBar", nil, self)
    Health:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
    Health:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)

    -- Health Bar Background
    local HealthBg = Health:CreateTexture(nil, "BACKGROUND")
    HealthBg:SetAllPoints(true)

    -- Option: Enable class colors or reaction colors
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = false
    Health.colorReaction = false
    Health.bg = HealthBg

    Health.PostUpdate = function(health, unit, cur, max)
        local isTapped = health.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)
        local isDisconnected = health.colorDisconnected and not UnitIsConnected(unit)
        if not isTapped and not isDisconnected then
            health:SetStatusBarColor(unpack(C.Colors.Health))
        end

        local parent = health:GetParent()
        if not parent.HpVal then return end

        local uConfig = C.Units.Default
        local name = parent:GetName()
        if parent.unit == "pet" then uConfig = C.Units.Pet
        elseif name and name:match("oUF_MyLayoutMainTankTarget") then uConfig = C.Units.MainTankTarget
        elseif name and name:match("oUF_MyLayoutMainTank") then uConfig = C.Units.MainTank
        elseif name and name:match("oUF_MyLayoutRaid") then uConfig = C.Units.Raid
        elseif name and name:match("oUF_MyLayoutPartyTarget") then uConfig = C.Units.PartyTarget
        elseif name and name:match("oUF_MyLayoutParty") then uConfig = C.Units.Party
        elseif name and name:match("oUF_MyLayoutBoss") then uConfig = C.Units.Boss
        elseif parent.unit == "player" then uConfig = C.Units.Player
        elseif parent.unit == "target" then uConfig = C.Units.Target
        elseif parent.unit == "targettarget" then uConfig = C.Units.TargetTarget
        elseif parent.unit == "focus" then uConfig = C.Units.Focus
        end

        local shouldHideHealth = UnitIsDead(unit) or UnitIsGhost(unit) or UnitIsAFK(unit)

        local tag = uConfig.HealthTag or "[perhp]%"
        if shouldHideHealth then
            tag = ""
        end

        if uConfig.ShowStatusText then
            if tag ~= "" then
                tag = tag .. " [dead][offline][my:afk]"
            else
                tag = "[dead][offline][my:afk]"
            end
        end

        if parent.HpVal.__currentTag ~= tag then
            parent:Tag(parent.HpVal, tag)
            parent.HpVal.__currentTag = tag
            parent.HpVal:UpdateTag()
        end

        parent.HpVal:Show()
    end

    -- Register with oUF (oUF automatically updates by assigning to self.Health)
    self.Health = Health

    -- --------------------------------------------------------------------
    -- 3. Create Power Bar (Mana/Resource Bar)
    -- --------------------------------------------------------------------
    local Power = CreateFrame("StatusBar", nil, self)
    Power:SetPoint("TOPLEFT", Health, "BOTTOMLEFT", 0, -2)
    Power:SetPoint("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -2)

    local PowerBg = Power:CreateTexture(nil, "BACKGROUND")
    PowerBg:SetAllPoints(true)

    Power.colorClass = true -- Class Color
    Power.bg = PowerBg
    
    Power.PostUpdate = function(power, unit, min, max)
        local C = ns.Config
        if power.bg then power.bg:SetColorTexture(unpack(C.Colors.PowerBg)) end

        -- Apply power type color for non-players since class color is not applied
        -- If not done, the class color of the previously targeted player may remain
        if not UnitIsPlayer(unit) then
            local _, ptoken = UnitPowerType(unit)
            local color = oUF.colors.power[ptoken]
            if color then
                local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
                power:SetStatusBarColor(r, g, b)
            end
        end
    end
    
    -- Register with oUF
    self.Power = Power

    -- --------------------------------------------------------------------
    -- 4. Text Information (Name and HP Value)
    -- --------------------------------------------------------------------
    -- Name
    local Name = Health:CreateFontString(nil, "OVERLAY")
    self.Name = Name

    -- HP Value
    local HpVal = Health:CreateFontString(nil, "OVERLAY")
    self.HpVal = HpVal

    -- --------------------------------------------------------------------
    -- 5. Portrait (3D Model)
    -- --------------------------------------------------------------------
    local Portrait = CreateFrame("PlayerModel", nil, self)
    Portrait:SetSize(150, 43)
    Portrait:SetPoint("LEFT", self, "LEFT", 2, 0) -- Position on the left side of the frame

    -- Background (Optional)
    local PortraitBg = self:CreateTexture(nil, "BACKGROUND")
    PortraitBg:SetAllPoints(Portrait)
    PortraitBg:SetColorTexture(0, 0, 0, 0.5)

    self.Portrait = Portrait
    self.PortraitBg = PortraitBg
    self.PortraitModel = Portrait -- Keep reference

    -- --------------------------------------------------------------------
    -- 6. Raid Icon
    -- --------------------------------------------------------------------
    local RaidTargetIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.RaidTargetIndicator = RaidTargetIndicator

    -- --------------------------------------------------------------------
    -- 7. Castbar
    -- --------------------------------------------------------------------
    local name = self:GetName()
    if not (name and (name:match("oUF_MyLayoutRaid") or name:match("oUF_MyLayoutBoss"))) and unit ~= "targettarget" then
        local Castbar = CreateFrame("StatusBar", nil, self)

        local CastbarBg = Castbar:CreateTexture(nil, "BACKGROUND")
        CastbarBg:SetAllPoints(true)

        -- Spell Name
        local CastbarText = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarText:SetPoint("LEFT", Castbar, "LEFT", 2, 0)

        -- Icon
        local CastbarIcon = Castbar:CreateTexture(nil, "OVERLAY")
        CastbarIcon:SetSize(20, 20)
        CastbarIcon:SetPoint("RIGHT", Castbar, "LEFT", -5, 0)
        CastbarIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        -- Cast Time
        local CastbarTime = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarTime:SetPoint("RIGHT", Castbar, "RIGHT", -2, 0)

        Castbar.bg = CastbarBg
        Castbar.Text = CastbarText
        Castbar.Icon = CastbarIcon
        Castbar.Time = CastbarTime
        Castbar.timeToHold = 0.5 -- Keep visible for a bit after completion
        
        Castbar.PostCastStart = function(castbar, unit)
            local C = ns.Config
            if castbar.bg then castbar.bg:SetColorTexture(unpack(C.Colors.CastbarBg)) end
        end
        Castbar.PostCastInterruptible = Castbar.PostCastStart
        Castbar.PostCastNotInterruptible = Castbar.PostCastStart

        self.Castbar = Castbar
        self.CastbarRaw = Castbar
    end

    -- --------------------------------------------------------------------
    -- 8. Role Icon
    -- --------------------------------------------------------------------
    local GroupRoleIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.GroupRoleIndicator = GroupRoleIndicator

    -- --------------------------------------------------------------------
    -- 9. Ready Check Icon
    -- --------------------------------------------------------------------
    local ReadyCheckIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.ReadyCheckIndicator = ReadyCheckIndicator

    -- --------------------------------------------------------------------
    -- 10. Rest Icon
    -- --------------------------------------------------------------------
    if unit == "player" then
        local RestingIndicator = Health:CreateTexture(nil, "OVERLAY")
        RestingIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        RestingIndicator:SetTexCoord(0, 0.5, 0, 0.421875)
        self.RestingIndicator = RestingIndicator
    end

    -- --------------------------------------------------------------------
    -- 11. Combat Icon
    -- --------------------------------------------------------------------
    if unit == "player" then
        local CombatIndicator = Health:CreateTexture(nil, "OVERLAY")
        CombatIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        CombatIndicator:SetTexCoord(0.5, 1, 0, 0.5)
        self.CombatIndicator = CombatIndicator
    end

    -- --------------------------------------------------------------------
    -- 12. Class Power (Combo Points etc.)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local ClassPower = {}
        for i = 1, 10 do -- Max 10 points (Supports Rogue's 7 points etc.)
            local bar = CreateFrame("StatusBar", nil, self)
            bar:SetHeight(10)
            bar:SetWidth((254 - (5 * 2)) / 6) -- Initial width

            if i == 1 then
                bar:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 5)
            else
                bar:SetPoint("LEFT", ClassPower[i-1], "RIGHT", 2, 0)
            end

            local bg = bar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0.1, 0.1, 0.1)
            bar.bg = bg

            ClassPower[i] = bar
        end

        ClassPower.PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
            if hasMaxChanged then
                local spacing = 2
                local width = self:GetWidth()
                local maxPoints = max or 5
                if type(maxPoints) ~= "number" or issecretvalue(maxPoints) then maxPoints = 5 end
                
                local barWidth = (width - (spacing * (maxPoints - 1))) / maxPoints
                for i = 1, #element do
                    element[i]:SetWidth(barWidth)
                end
            end
        end

        self.ClassPower = ClassPower
    end

    -- --------------------------------------------------------------------
    -- 13. Runes (Death Knight Runes)
    -- --------------------------------------------------------------------
    if unit == "player" and select(2, UnitClass("player")) == "DEATHKNIGHT" then
        local Runes = {}
        for i = 1, 6 do
            local rune = CreateFrame("StatusBar", nil, self)
            rune:SetHeight(10)
            rune:SetWidth((254 - (5 * 2)) / 6) -- Calculate width same as ClassPower

            if i == 1 then
                rune:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 5)
            else
                rune:SetPoint("LEFT", Runes[i-1], "RIGHT", 2, 0)
            end

            local bg = rune:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0.1, 0.1, 0.1)
            rune.bg = bg

            Runes[i] = rune
        end
        self.Runes = Runes
    end

    -- --------------------------------------------------------------------
    -- 14. Additional Power (Druid Mana)
    -- --------------------------------------------------------------------
    if unit == "player" and select(2, UnitClass("player")) == "DRUID" then
        local AdditionalPower = CreateFrame("StatusBar", nil, self)
        AdditionalPower:SetHeight(5)
        AdditionalPower:SetPoint("TOPLEFT", self.Power, "BOTTOMLEFT", 0, 5)
        AdditionalPower:SetPoint("TOPRIGHT", self.Power, "BOTTOMRIGHT", 0, 5)
        AdditionalPower.colorPower = true

        local bg = AdditionalPower:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0.2, 0.2, 0.2)
        AdditionalPower.bg = bg

        self.AdditionalPower = AdditionalPower
    end

    -- --------------------------------------------------------------------
    -- 15. Leader Icon
    -- --------------------------------------------------------------------
    local LeaderIndicator = Health:CreateTexture(nil, "OVERLAY")
    LeaderIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    self.LeaderIndicator = LeaderIndicator

    -- --------------------------------------------------------------------
    -- 16. Assistant Icon
    -- --------------------------------------------------------------------
    local AssistantIndicator = Health:CreateTexture(nil, "OVERLAY")
    AssistantIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
    self.AssistantIndicator = AssistantIndicator

    -- --------------------------------------------------------------------
    -- 17. Buffs
    -- --------------------------------------------------------------------
    local Buffs = CreateFrame("Frame", nil, self)
    Buffs.gap = true
    Buffs.initialAnchor = "BOTTOMLEFT"
    Buffs["growth-x"] = "RIGHT"
    Buffs["growth-y"] = "UP"
    Buffs.showStealableBuffs = true
    Buffs.CustomFilter = CustomFilter
    self.Buffs = Buffs

    -- 18. Debuffs
    local Debuffs = CreateFrame("Frame", nil, self)
    Debuffs.gap = true
    Debuffs.initialAnchor = "BOTTOMLEFT"
    Debuffs["growth-x"] = "RIGHT"
    Debuffs["growth-y"] = "UP"
    Debuffs.showDebuffType = true
    Debuffs.CustomFilter = CustomFilter
    self.Debuffs = Debuffs

    -- 19. Range
    local Range = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    self.Range = Range

    -- Apply style (Initialization)
    UpdateUnitFrame(self, true)
end

-- ------------------------------------------------------------------------
-- Factory
-- ------------------------------------------------------------------------
-- Register style and spawn frames.

oUF:RegisterStyle("MyLayout", Shared)

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
        "yOffset", -60, -- Same spacing as Party frame
        "initial-width", C.Units.PartyTarget.Width,
        "initial-height", C.Units.PartyTarget.Height,
        "oUF-initialConfigFunction", [[
            self:SetAttribute('unitsuffix', 'target')
        ]]
    )

    -- Spawn Raid frame
    -- Create a holder frame for positioning and Edit Mode
    ns.raid = CreateFrame("Frame", "oUF_MyLayoutRaidHolder", UIParent)
    ns.raid:SetSize(100, 100) -- Size updated in UpdateFrames

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

    -- Update all frames once at initial load to finalize positions and visibility
    ns.UpdateFrames()
end)
