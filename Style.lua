local addonName, ns = ...

-- Get oUF object (global or from namespace)
local oUF = ns.oUF or oUF

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

ns.GetMedia = GetMedia

-- ------------------------------------------------------------------------
-- Filter Functions
-- ------------------------------------------------------------------------
local function CustomFilter(element, unit, data)
    if element and element.onlyShowPlayer then
        if not data or not data.sourceUnit then
            return true
        end
        local source = data.sourceUnit
        return source == "player" or source == "vehicle" or source == "pet"
    end
    return true
end

-- Helper function to update icons
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
function ns.UpdateUnitFrame(self, isInit)
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
        if self.Power.bg then self.Power.bg:SetColorTexture(unpack(C.Colors.PowerBg)) end
    end

    if self.Name then
        local nConfig = uConfig.NameText or {}
        local nFont = GetMedia("font", nConfig.Font or C.Media.Font)
        local nSize = nConfig.Size or 20
        local nOutline = nConfig.Outline or "OUTLINE"
        local isTestPreview = self.isTestPreview or (name and (name:match("BossTest") or name:match("MainTankTargetTest") or name:match("MainTankTest")))
        self.Name:SetFont(nFont, nSize, nOutline)

        if nConfig.Enable == false then
            self.Name:Hide()
        else
            self.Name:Show()

            -- Apply only if position settings exist (relative to Health bar)
            if nConfig.Point then
                self.Name:ClearAllPoints()
                self.Name:SetPoint(nConfig.Point, self.Health, nConfig.Point, nConfig.X or 0, nConfig.Y or 0)
            end

            -- NameTag update
            if isTestPreview then
                if self.Untag then self:Untag(self.Name) end
            elseif uConfig.NameTag then
                self:Tag(self.Name, uConfig.NameTag)
                self.Name:UpdateTag()
            end
        end
    end

    if self.Level then
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
            else
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
            self.Portrait = nil
            self.PortraitModel:Hide()
            if self.PortraitBg then self.PortraitBg:Hide() end
        end
    end

    if self.CreateAuras then
        local aConfig = uConfig.Buffs or {}
        local dConfig = uConfig.Debuffs or {}
        local isAuraSupported = unit and not (unit:match("target") and unit ~= "target") and not (unit:match("pet") and unit ~= "pet")

        if aConfig.Enable and isAuraSupported then
            local buffSize = aConfig.Size or 20
            local buffX = aConfig.X or 0
            local buffY = aConfig.Y or 10

            if not self.BuffAuras or self.BuffAuras._size ~= buffSize or self.BuffAuras._x ~= buffX or self.BuffAuras._y ~= buffY then
                if self.BuffAuras then
                    self.BuffAuras:Hide()
                    self.BuffAuras = nil
                end

                self.BuffAuras = self:CreateAuras()
                self.BuffAuras._size = buffSize
                self.BuffAuras._x = buffX
                self.BuffAuras._y = buffY
                self.BuffAuras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", buffX, buffY)
                self.BuffAuras:SetSize(uConfig.Width, 60)
                self.BuffAuras:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
                self.BuffAuras:SetFlowLayoutGrowthDirection(1, 1)
                self.BuffAuras:SetFlowLayoutPadding(0, 0, 0, 0)
                self.BuffAuras:AddGroup("HELPFUL", {
                    maxFrameCount = 20,
                    size = buffSize,
                    layout = { elementSpacing = 4, lineSpacing = 4 },
                })
            end

            self.BuffAuras:Show()
            self.BuffAuras:SetWidth(uConfig.Width)
            self.BuffAuras:SetHeight(60)
            self.BuffAuras:ClearAllPoints()
            self.BuffAuras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", buffX, buffY)
            if self.BuffAuras.ForceUpdate then
                self.BuffAuras:ForceUpdate()
            end
        elseif self.BuffAuras then
            self.BuffAuras:Hide()
        end

        if dConfig.Enable and isAuraSupported then
            local debuffSize = dConfig.Size or 20
            local debuffX = dConfig.X or 0
            local debuffY = dConfig.Y or 35

            if not self.DebuffAuras or self.DebuffAuras._size ~= debuffSize or self.DebuffAuras._x ~= debuffX or self.DebuffAuras._y ~= debuffY then
                if self.DebuffAuras then
                    self.DebuffAuras:Hide()
                    self.DebuffAuras = nil
                end

                self.DebuffAuras = self:CreateAuras()
                self.DebuffAuras._size = debuffSize
                self.DebuffAuras._x = debuffX
                self.DebuffAuras._y = debuffY
                self.DebuffAuras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", debuffX, debuffY)
                self.DebuffAuras:SetSize(uConfig.Width, 60)
                self.DebuffAuras:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
                self.DebuffAuras:SetFlowLayoutGrowthDirection(1, 1)
                self.DebuffAuras:SetFlowLayoutPadding(0, 0, 0, 0)
                self.DebuffAuras:AddGroup("HARMFUL", {
                    maxFrameCount = 20,
                    size = debuffSize,
                    layout = { elementSpacing = 4, lineSpacing = 4 },
                })
            end

            self.DebuffAuras:Show()
            self.DebuffAuras:SetWidth(uConfig.Width)
            self.DebuffAuras:SetHeight(60)
            self.DebuffAuras:ClearAllPoints()
            self.DebuffAuras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", debuffX, debuffY)
            if self.DebuffAuras.ForceUpdate then
                self.DebuffAuras:ForceUpdate()
            end
        elseif self.DebuffAuras then
            self.DebuffAuras:Hide()
        end
    elseif self.Buffs then
        local bConfig = uConfig.Buffs or {}
        local isAuraSupported = unit and not (unit:match("target") and unit ~= "target") and not (unit:match("pet") and unit ~= "pet")

        if bConfig.Enable and isAuraSupported then
            self.Buffs:Show()
            self.Buffs.size = bConfig.Size or 20
            self.Buffs.spacing = 4
            self.Buffs:SetWidth(uConfig.Width)
            self.Buffs:SetHeight((bConfig.Size or 20) * 2)
            self.Buffs:ClearAllPoints()
            self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", bConfig.X or 0, bConfig.Y or 5)
            self.Buffs.onlyShowPlayer = bConfig.PlayerOnly
            if not self:IsElementEnabled("Buffs") then
                self:EnableElement("Buffs")
            end
            if self.Buffs.ForceUpdate then
                self.Buffs:ForceUpdate()
            end
        else
            self.Buffs:Hide()
            if self:IsElementEnabled("Buffs") then
                self:DisableElement("Buffs")
            end
        end
    end

    if not self.CreateAuras and self.Debuffs then
        local dConfig = uConfig.Debuffs or {}
        local isAuraSupported = unit and not (unit:match("target") and unit ~= "target") and not (unit:match("pet") and unit ~= "pet")

        if dConfig.Enable and isAuraSupported then
            self.Debuffs:Show()
            self.Debuffs.size = dConfig.Size or 20
            self.Debuffs.spacing = 4
            self.Debuffs:SetWidth(uConfig.Width)
            self.Debuffs:SetHeight((dConfig.Size or 20) * 2)
            self.Debuffs:ClearAllPoints()
            self.Debuffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", dConfig.X or 0, dConfig.Y or 35)
            self.Debuffs.onlyShowPlayer = dConfig.PlayerOnly
            if not self:IsElementEnabled("Debuffs") then
                self:EnableElement("Debuffs")
            end
            if self.Debuffs.ForceUpdate then
                self.Debuffs:ForceUpdate()
            end
        else
            self.Debuffs:Hide()
            if self:IsElementEnabled("Debuffs") then
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
    local defaultIconsConfig = (ns.Defaults and ns.Defaults.Units and ns.Defaults.Units[unitKey] and ns.Defaults.Units[unitKey].Icons) or {}

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

-- ------------------------------------------------------------------------
-- Style Definition Function (Shared Style Function)
-- ------------------------------------------------------------------------
function ns.Shared(self, unit)
    -- 1. Basic Frame Settings
    if not InCombatLockdown() then
        self:RegisterForClicks("AnyUp")
    end

    -- Workaround for oUF library error: Prevent GROUP_ROSTER_UPDATE from firing when unit is nil
    local oldOnEvent = self:GetScript("OnEvent")
    if oldOnEvent then
        self:SetScript("OnEvent", function(self, event, ...)
            if event == "GROUP_ROSTER_UPDATE" and not self.unit then
                return
            end
            return oldOnEvent(self, event, ...)
        end)
    end

    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)

    -- Set unit for initialization
    self.unit = unit

    local C = ns.Config
    local uConfig = C.Units.Default

    -- Background settings
    local bg = self:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    -- 2. Create Health Bar
    local Health = CreateFrame("StatusBar", nil, self)
    Health:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
    Health:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)

    local HealthBg = Health:CreateTexture(nil, "BACKGROUND")
    HealthBg:SetAllPoints(true)

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

        local isDead = UnitIsDead(unit)
        local isGhost = UnitIsGhost(unit)
        local isAFK = UnitIsAFK(unit)

        if issecretvalue then
            if issecretvalue(isDead) then isDead = false end
            if issecretvalue(isGhost) then isGhost = false end
            if issecretvalue(isAFK) then isAFK = false end
        end

        local shouldHideHealth = isDead or isGhost or isAFK

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

    self.Health = Health

    -- 3. Create Power Bar
    local Power = CreateFrame("StatusBar", nil, self)
    Power:SetPoint("TOPLEFT", Health, "BOTTOMLEFT", 0, -2)
    Power:SetPoint("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -2)

    local PowerBg = Power:CreateTexture(nil, "BACKGROUND")
    PowerBg:SetAllPoints(true)

    Power.colorClass = true
    Power.bg = PowerBg
    
    Power.PostUpdate = function(power, unit, min, max)
        local C = ns.Config
        if power.bg then power.bg:SetColorTexture(unpack(C.Colors.PowerBg)) end

        if not UnitIsPlayer(unit) then
            local _, ptoken = UnitPowerType(unit)
            local color = oUF.colors.power[ptoken]
            if color then
                local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
                power:SetStatusBarColor(r, g, b)
            end
        end
    end
    
    self.Power = Power

    -- 4. Text Information
    local Name = Health:CreateFontString(nil, "OVERLAY")
    self.Name = Name

    local HpVal = Health:CreateFontString(nil, "OVERLAY")
    self.HpVal = HpVal

    -- 5. Portrait
    local Portrait = CreateFrame("PlayerModel", nil, self)
    Portrait:SetSize(150, 43)
    Portrait:SetPoint("LEFT", self, "LEFT", 2, 0)

    local PortraitBg = self:CreateTexture(nil, "BACKGROUND")
    PortraitBg:SetAllPoints(Portrait)
    PortraitBg:SetColorTexture(0, 0, 0, 0.5)

    self.Portrait = Portrait
    self.PortraitBg = PortraitBg
    self.PortraitModel = Portrait

    -- 6. Raid Icon
    local RaidTargetIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.RaidTargetIndicator = RaidTargetIndicator

    -- 7. Castbar
    local name = self:GetName()
    if not (name and (name:match("oUF_MyLayoutRaid") or name:match("oUF_MyLayoutBoss"))) and unit ~= "targettarget" then
        local Castbar = CreateFrame("StatusBar", nil, self)

        local CastbarBg = Castbar:CreateTexture(nil, "BACKGROUND")
        CastbarBg:SetAllPoints(true)

        local CastbarText = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarText:SetPoint("LEFT", Castbar, "LEFT", 2, 0)

        local CastbarIcon = Castbar:CreateTexture(nil, "OVERLAY")
        CastbarIcon:SetSize(20, 20)
        CastbarIcon:SetPoint("RIGHT", Castbar, "LEFT", -5, 0)
        CastbarIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        local CastbarTime = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarTime:SetPoint("RIGHT", Castbar, "RIGHT", -2, 0)

        Castbar.bg = CastbarBg
        Castbar.Text = CastbarText
        Castbar.Icon = CastbarIcon
        Castbar.Time = CastbarTime
        Castbar.timeToHold = 0.5
        
        Castbar.PostCastStart = function(castbar, unit)
            local C = ns.Config
            if castbar.bg then castbar.bg:SetColorTexture(unpack(C.Colors.CastbarBg)) end
        end
        Castbar.PostCastInterruptible = Castbar.PostCastStart
        Castbar.PostCastNotInterruptible = Castbar.PostCastStart

        self.Castbar = Castbar
        self.CastbarRaw = Castbar
    end

    -- 8. Role Icon
    local GroupRoleIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.GroupRoleIndicator = GroupRoleIndicator

    -- 9. Ready Check Icon
    local ReadyCheckIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.ReadyCheckIndicator = ReadyCheckIndicator

    -- 10. Rest Icon
    if unit == "player" then
        local RestingIndicator = Health:CreateTexture(nil, "OVERLAY")
        RestingIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        RestingIndicator:SetTexCoord(0, 0.5, 0, 0.421875)
        self.RestingIndicator = RestingIndicator
    end

    -- 11. Combat Icon
    if unit == "player" then
        local CombatIndicator = Health:CreateTexture(nil, "OVERLAY")
        CombatIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        CombatIndicator:SetTexCoord(0.5, 1, 0, 0.5)
        self.CombatIndicator = CombatIndicator
    end

    -- 12. Class Power
    if unit == "player" then
        local ClassPower = {}
        for i = 1, 10 do
            local bar = CreateFrame("StatusBar", nil, self)
            bar:SetHeight(10)
            bar:SetWidth((254 - (5 * 2)) / 6)

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

    -- 13. Runes
    if unit == "player" and select(2, UnitClass("player")) == "DEATHKNIGHT" then
        local Runes = {}
        for i = 1, 6 do
            local rune = CreateFrame("StatusBar", nil, self)
            rune:SetHeight(10)
            rune:SetWidth((254 - (5 * 2)) / 6)

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

    -- 14. Additional Power
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

    -- 15. Leader Icon
    local LeaderIndicator = Health:CreateTexture(nil, "OVERLAY")
    LeaderIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    self.LeaderIndicator = LeaderIndicator

    -- 16. Assistant Icon
    local AssistantIndicator = Health:CreateTexture(nil, "OVERLAY")
    AssistantIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
    self.AssistantIndicator = AssistantIndicator

    -- 17. Buffs / Debuffs (oUF 14 uses Auras, older oUF uses Buffs/Debuffs)
    local isAuraSupported = unit and not (unit:match("target") and unit ~= "target") and not (unit:match("pet") and unit ~= "pet")

    if isAuraSupported then
        if self.CreateAuras then
            self.BuffAuras = self:CreateAuras()
            self.BuffAuras:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            self.BuffAuras:SetFlowLayoutGrowthDirection(1, 1)
            self.BuffAuras:SetFlowLayoutPadding(0, 0, 0, 0)
            self.BuffAuras:AddGroup("HELPFUL", { maxFrameCount = 20, layout = { elementSpacing = 4, lineSpacing = 4 } })
            self.BuffAuras:Hide()

            self.DebuffAuras = self:CreateAuras()
            self.DebuffAuras:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            self.DebuffAuras:SetFlowLayoutGrowthDirection(1, 1)
            self.DebuffAuras:SetFlowLayoutPadding(0, 0, 0, 0)
            self.DebuffAuras:AddGroup("HARMFUL", { maxFrameCount = 20, layout = { elementSpacing = 4, lineSpacing = 4 } })
            self.DebuffAuras:Hide()
        else
            local Buffs = CreateFrame("Frame", nil, self)
            Buffs.gap = true
            Buffs.initialAnchor = "BOTTOMLEFT"
            Buffs["growth-x"] = "RIGHT"
            Buffs["growth-y"] = "UP"
            Buffs.showStealableBuffs = true
            Buffs.CustomFilter = CustomFilter
            self.Buffs = Buffs

            local Debuffs = CreateFrame("Frame", nil, self)
            Debuffs.gap = true
            Debuffs.initialAnchor = "BOTTOMLEFT"
            Debuffs["growth-x"] = "RIGHT"
            Debuffs["growth-y"] = "UP"
            Debuffs.showDebuffType = true
            Debuffs.CustomFilter = CustomFilter
            self.Debuffs = Debuffs
        end
    end

    -- 18. Range
    local Range = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    self.Range = Range

    -- Apply style
    ns.UpdateUnitFrame(self, true)
end
