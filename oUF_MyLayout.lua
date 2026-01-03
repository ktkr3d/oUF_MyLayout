local addonName, ns = ...

-- oUFオブジェクトを取得（グローバルまたはネームスペースから）
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

-- カスタムタグ: AFK (赤色で表示)
oUF.Tags.Methods["my:afk"] = function(unit)
    if UnitIsAFK(unit) then
        return "|cffff0000AFK|r"
    end
end
oUF.Tags.Events["my:afk"] = "PLAYER_FLAGS_CHANGED UNIT_FLAGS"

-- カスタムタグ: HPパーセント (少数第一位)
oUF.Tags.Methods["my:perhp"] = function(unit)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if max == 0 then return 0 end
    return string.format("%.1f", cur / max * 100)
end
oUF.Tags.Events["my:perhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- カスタムタグ: 短縮名 (8文字)
oUF.Tags.Methods["my:shortname"] = function(unit)
    local name = UnitName(unit)
    if not name then return "" end
    
    local lenFunc = string.utf8len or string.len
    local subFunc = string.utf8sub or string.sub
    if lenFunc(name) > 8 then
        return subFunc(name, 1, 8) .. "..."
    end
    return name
end
oUF.Tags.Events["my:shortname"] = "UNIT_NAME_UPDATE"

-- ------------------------------------------------------------------------
-- SharedMediaのサポート
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
-- フィルタ関数
-- ------------------------------------------------------------------------
local function CustomFilter(element, unit, button, name, icon, count, debuffType, duration, expirationTime, source, ...)
    if element.onlyShowPlayer then
        return source == "player" or source == "vehicle" or source == "pet"
    end
    return true
end

-- ------------------------------------------------------------------------
-- フレーム更新関数 (Live Update)
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

    self:SetSize(uConfig.Width, uConfig.Height)

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

            -- 位置設定がある場合のみ適用 (Healthバーを基準とする)
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
        -- 互換性のため、もしbooleanならテーブルに変換
        if type(pConfig) ~= "table" then
            pConfig = { Enable = pConfig }
        end

        if pConfig.Enable then
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
            self.Portrait = nil -- oUFの自動検出対象から外す
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
            if self.Buffs.ForceUpdate then
                self.Buffs:ForceUpdate()
            end
        else
            self.Buffs:Hide()
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
            if self.Debuffs.ForceUpdate then
                self.Debuffs:ForceUpdate()
            end
        else
            self.Debuffs:Hide()
        end
    end

    -- アイコンの更新
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

    local function UpdateIcon(icon, iconKey)
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

    UpdateIcon(self.RaidTargetIndicator, "RaidTarget")
    UpdateIcon(self.GroupRoleIndicator, "GroupRole")
    UpdateIcon(self.ReadyCheckIndicator, "ReadyCheck")
    UpdateIcon(self.LeaderIndicator, "Leader")


    UpdateIcon(self.AssistantIndicator, "Assistant")
    if self.unit == "player" then
        UpdateIcon(self.RestingIndicator, "Resting")
        UpdateIcon(self.CombatIndicator, "Combat")
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
                ns.party:Show()
                ns.party:ClearAllPoints()
                ns.party:SetPoint(unpack(C.Units.Party.Position))
            else
                ns.party:Hide()
            end
        end
        -- PartyTarget
        if ns.partytarget then
            if C.Units.PartyTarget.Enable then
                ns.partytarget:Show()
                ns.partytarget:ClearAllPoints()
                ns.partytarget:SetPoint(unpack(C.Units.PartyTarget.Position))
            else
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
                local totalWidth = (C.Units.Raid.Width * 5) + (spacing * 4)
                local totalHeight = (C.Units.Raid.Height * 5) + (spacing * 4)
                ns.raid:SetSize(totalWidth, totalHeight)

                for i = 1, 5 do
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
                for i = 1, 5 do
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
                ns.maintanktarget:ClearAllPoints()
                ns.maintanktarget:SetPoint(unpack(C.Units.MainTankTarget.Position))
            else
                ns.maintanktarget:Hide()
            end
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
        end
    end
end

-- ------------------------------------------------------------------------
-- Edit Mode Integration
-- ------------------------------------------------------------------------
function ns.RegisterWithEditMode(unitKey, frame, displayName, category)
    if not EditModeManager then return end

    local layoutData = {
        name = displayName,
        movable = true,
        category = category,
        OnPositionChanged = function(self, x, y)
            -- The frame is moved, save its new position relative to the center.
            -- This will overwrite the original anchor point, which is fine.
            ns.Config.Units[unitKey].Position = {"CENTER", x, y}
        end,
        OnReset = function(self)
            -- Reset to the default position from Config.lua
            local defaultConfig = ns.Defaults.Units[unitKey]
            if defaultConfig and defaultConfig.Position then
                -- Use deepcopy to avoid modifying the defaults table
                ns.Config.Units[unitKey].Position = deepcopy(defaultConfig.Position)
                ns.UpdateFrames() -- This will re-apply positions for all frames
            end
        end,
        options = {
            {
                type = "toggle",
                name = "Enable",
                get = function() return ns.Config.Units[unitKey].Enable end,
                set = function(info, val)
                    ns.Config.Units[unitKey].Enable = val
                    ns.UpdateFrames()
                end
            }
        }
    }

    EditModeManager:RegisterFrame(frame, layoutData)
end

-- ------------------------------------------------------------------------
-- Blizzardフレームの非表示
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
-- 設定の初期化 (SavedVariables)
-- ------------------------------------------------------------------------
function ns:OnProfileChanged(event, database, newProfileKey)
    -- プロファイルが変更されたら、ns.Configの参照先を更新
    ns.Config = database.profile
    -- フレームの見た目を更新
    ns.UpdateFrames()
end

local Loader = CreateFrame("Frame")
Loader:RegisterEvent("ADDON_LOADED")
Loader:SetScript("OnEvent", function(self, event, addon)
    if addon ~= addonName then return end

    -- TOCからバージョン情報を取得
    ns.Version = C_AddOns.GetAddOnMetadata(addonName, "Version")

    -- 依存ライブラリのチェック
    if not C_AddOns.IsAddOnLoaded("Ace3") or not C_AddOns.IsAddOnLoaded("LibSharedMedia-3.0") or not C_AddOns.IsAddOnLoaded("oUF") then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Required libraries (Ace3, LibSharedMedia-3.0, oUF) are missing or not enabled.")
        return
    end

    -- AceDBの初期化
    -- Config.luaで定義した ns.Config をデフォルト値として使用
    ns.Defaults = ns.Config -- Save reference to the original defaults
    local defaults = {
        profile = ns.Defaults
    }
    ns.db = LibStub("AceDB-3.0"):New("oUF_MyLayoutDB", defaults, true)

    -- プロファイル変更時のコールバック登録
    ns.db.RegisterCallback(ns, "OnProfileChanged", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileCopied", "OnProfileChanged")
    ns.db.RegisterCallback(ns, "OnProfileReset", "OnProfileChanged")

    -- 現在のプロファイルを ns.Config にセット
    ns.Config = ns.db.profile -- ns.Config now points to the live profile

    -- 保存された設定を適用するためにフレームを更新
    ns.UpdateFrames()

    -- 設定画面の初期化
    if ns.SetupOptions then ns.SetupOptions() end

    -- BlizzardのRaidフレームを非表示にする
    HideBlizzardFrames()

    self:UnregisterEvent("ADDON_LOADED")
end)

-- スラッシュコマンド (/mylayout reset)
SLASH_OUF_MYLAYOUT1 = "/mylayout"
SlashCmdList["OUF_MYLAYOUT"] = function(msg)
    if msg == "reset" then
        ns.db:ResetProfile()
        print("|cff00ff00oUF_MyLayout:|r 現在のプロファイル設定をリセットしました。")
    elseif msg == "config" then
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    else
        print("|cff00ff00oUF_MyLayout:|r コマンド: /mylayout config, /mylayout reset")
        LibStub("AceConfigDialog-3.0"):Open("oUF_MyLayout")
    end
end

-- ------------------------------------------------------------------------
-- スタイル定義関数 (Shared Style Function)
-- ------------------------------------------------------------------------
-- この関数内で、各ユニットフレーム（プレイヤー、ターゲット等）の見た目を定義します。
local function Shared(self, unit)
    -- 1. フレームの基本設定
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)

    -- 初期化用にunitをセット
    self.unit = unit
    local C = ns.Config
    local uConfig = C.Units.Default -- 初期構築用に必要

    -- 背景の設定 (オプション)
    local bg = self:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1) -- 半透明の黒

    -- --------------------------------------------------------------------
    -- 2. Health Bar (HPバー) の作成
    -- --------------------------------------------------------------------
    local Health = CreateFrame("StatusBar", nil, self)
    Health:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
    Health:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)

    -- HPバーの背景
    local HealthBg = Health:CreateTexture(nil, "BACKGROUND")
    HealthBg:SetAllPoints(true)

    -- オプション: クラスカラーや敵対反応カラーを有効化
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = false
    Health.colorReaction = false
    Health.bg = HealthBg

    Health.PostUpdate = function(health, unit, min, max)
        local C = ns.Config
        if health.bg then health.bg:SetColorTexture(unpack(C.Colors.HealthBg)) end

        -- 前景色（HPバーの色）を適用
        -- Tapping(権利なし)やDisconnected(オフライン)の場合はoUFが色を設定しているので上書きしない
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

        local isFull = (min == max)
        local shouldHideHealth = uConfig.HideHealthTextAtFull and isFull

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

    -- oUFに登録 (self.Healthに代入することでoUFが自動更新を行う)
    self.Health = Health

    -- --------------------------------------------------------------------
    -- 3. Power Bar (マナ/リソースバー) の作成
    -- --------------------------------------------------------------------
    local Power = CreateFrame("StatusBar", nil, self)
    Power:SetPoint("TOPLEFT", Health, "BOTTOMLEFT", 0, -2)
    Power:SetPoint("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -2)

    local PowerBg = Power:CreateTexture(nil, "BACKGROUND")
    PowerBg:SetAllPoints(true)

    Power.colorClass = true -- クラスカラー
    Power.bg = PowerBg
    
    Power.PostUpdate = function(power, unit, min, max)
        local C = ns.Config
        if power.bg then power.bg:SetColorTexture(unpack(C.Colors.PowerBg)) end

        -- プレイヤー以外の場合、クラスカラーが適用されないため、パワータイプの色を適用する
        -- これを行わないと、直前にターゲットしていたプレイヤーのクラスカラーが残ってしまう場合がある
        if not UnitIsPlayer(unit) then
            local _, ptoken = UnitPowerType(unit)
            local color = oUF.colors.power[ptoken]
            if color then
                power:SetStatusBarColor(color[1], color[2], color[3])
            end
        end
    end
    
    -- oUFに登録
    self.Power = Power

    -- --------------------------------------------------------------------
    -- 4. テキスト情報 (名前とHP値)
    -- --------------------------------------------------------------------
    -- 名前
    local Name = Health:CreateFontString(nil, "OVERLAY")
    self.Name = Name

    -- HP数値
    local HpVal = Health:CreateFontString(nil, "OVERLAY")
    self.HpVal = HpVal

    -- --------------------------------------------------------------------
    -- 5. Portrait (3Dモデル)
    -- --------------------------------------------------------------------
    local Portrait = CreateFrame("PlayerModel", nil, self)
    Portrait:SetSize(150, 43)
    Portrait:SetPoint("LEFT", self, "LEFT", 2, 0) -- フレームの右側に配置

    -- 背景 (オプション)
    local PortraitBg = self:CreateTexture(nil, "BACKGROUND")
    PortraitBg:SetAllPoints(Portrait)
    PortraitBg:SetColorTexture(0, 0, 0, 0.5)

    self.Portrait = Portrait
    self.PortraitBg = PortraitBg
    self.PortraitModel = Portrait -- 参照を保持しておく

    -- --------------------------------------------------------------------
    -- 6. Raid Icon (レイドアイコン)
    -- --------------------------------------------------------------------
    local RaidTargetIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.RaidTargetIndicator = RaidTargetIndicator

    -- --------------------------------------------------------------------
    -- 7. Castbar (詠唱バー)
    -- --------------------------------------------------------------------
    local name = self:GetName()
    if not (name and (name:match("oUF_MyLayoutRaid") or name:match("oUF_MyLayoutBoss"))) and unit ~= "targettarget" then
        local Castbar = CreateFrame("StatusBar", nil, self)

        local CastbarBg = Castbar:CreateTexture(nil, "BACKGROUND")
        CastbarBg:SetAllPoints(true)

        -- 呪文名
        local CastbarText = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarText:SetPoint("LEFT", Castbar, "LEFT", 2, 0)

        -- アイコン
        local CastbarIcon = Castbar:CreateTexture(nil, "OVERLAY")
        CastbarIcon:SetSize(20, 20)
        CastbarIcon:SetPoint("RIGHT", Castbar, "LEFT", -5, 0)
        CastbarIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        -- 詠唱時間
        local CastbarTime = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarTime:SetPoint("RIGHT", Castbar, "RIGHT", -2, 0)

        Castbar.bg = CastbarBg
        Castbar.Text = CastbarText
        Castbar.Icon = CastbarIcon
        Castbar.Time = CastbarTime
        Castbar.timeToHold = 0.5 -- 完了後に少し表示を残す
        
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
    -- 8. Role Icon (ロールアイコン)
    -- --------------------------------------------------------------------
    local GroupRoleIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.GroupRoleIndicator = GroupRoleIndicator

    -- --------------------------------------------------------------------
    -- 9. Ready Check Icon (レディチェックアイコン)
    -- --------------------------------------------------------------------
    local ReadyCheckIndicator = Health:CreateTexture(nil, "OVERLAY")
    self.ReadyCheckIndicator = ReadyCheckIndicator

    -- --------------------------------------------------------------------
    -- 10. Rest Icon (休息アイコン)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local RestingIndicator = Health:CreateTexture(nil, "OVERLAY")
        RestingIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        RestingIndicator:SetTexCoord(0, 0.5, 0, 0.421875)
        self.RestingIndicator = RestingIndicator
    end

    -- --------------------------------------------------------------------
    -- 11. Combat Icon (戦闘アイコン)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local CombatIndicator = Health:CreateTexture(nil, "OVERLAY")
        CombatIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        CombatIndicator:SetTexCoord(0.5, 1, 0, 0.5)
        self.CombatIndicator = CombatIndicator
    end

    -- --------------------------------------------------------------------
    -- 12. Class Power (コンボポイント等)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local ClassPower = {}
        for i = 1, 6 do -- 最大6ポイント
            local bar = CreateFrame("StatusBar", nil, self)
            bar:SetHeight(10)
            bar:SetWidth((254 - (5 * 2)) / 6) -- フレーム幅に合わせて均等配置

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
        self.ClassPower = ClassPower
    end

    -- --------------------------------------------------------------------
    -- 13. Runes (デスナイトのルーン)
    -- --------------------------------------------------------------------
    if unit == "player" and select(2, UnitClass("player")) == "DEATHKNIGHT" then
        local Runes = {}
        for i = 1, 6 do
            local rune = CreateFrame("StatusBar", nil, self)
            rune:SetHeight(10)
            rune:SetWidth((254 - (5 * 2)) / 6) -- ClassPowerと同じ幅計算

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
        AdditionalPower:SetHeight(10)
        AdditionalPower:SetPoint("TOPLEFT", self.Power, "BOTTOMLEFT", 0, -2)
        AdditionalPower:SetPoint("TOPRIGHT", self.Power, "BOTTOMRIGHT", 0, -2)
        AdditionalPower.colorPower = true

        local bg = AdditionalPower:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0.2, 0.2, 0.2)
        AdditionalPower.bg = bg

        self.AdditionalPower = AdditionalPower
    end

    -- --------------------------------------------------------------------
    -- 15. Leader Icon (リーダーアイコン)
    -- --------------------------------------------------------------------
    local LeaderIndicator = Health:CreateTexture(nil, "OVERLAY")
    LeaderIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    self.LeaderIndicator = LeaderIndicator

    -- --------------------------------------------------------------------
    -- 16. Assistant Icon (アシスタントアイコン)
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

    -- スタイル適用 (初期化)
    UpdateUnitFrame(self, true)
end

-- ------------------------------------------------------------------------
-- ファクトリー (Factory)
-- ------------------------------------------------------------------------
-- スタイルを登録し、実際にフレームを生成(Spawn)します。

oUF:RegisterStyle("MyLayout", Shared)

oUF:Factory(function(self)
    local C = ns.Config
    self:SetActiveStyle("MyLayout")

    -- プレイヤーフレームの生成と配置
    ns.player = self:Spawn("player")
    ns.RegisterWithEditMode("Player", ns.player, "Player", "Unit Frames")

    -- ターゲットフレームの生成と配置
    ns.target = self:Spawn("target")
    ns.RegisterWithEditMode("Target", ns.target, "Target", "Unit Frames")

    -- ターゲットのターゲットフレームの生成
    ns.targettarget = self:Spawn("targettarget")
    ns.RegisterWithEditMode("TargetTarget", ns.targettarget, "Target's Target", "Unit Frames")

    -- ペットフレームの生成と配置
    ns.pet = self:Spawn("pet")
    ns.RegisterWithEditMode("Pet", ns.pet, "Pet", "Unit Frames")

    -- フォーカスフレームの生成
    ns.focus = self:Spawn("focus")
    ns.RegisterWithEditMode("Focus", ns.focus, "Focus", "Unit Frames")

    -- パーティフレームの生成
    ns.party = self:SpawnHeader("oUF_MyLayoutParty", nil, "custom [group:party, nogroup:raid] show; hide",
        "showParty", true,
        "yOffset", -60 -- 垂直方向に並べる
    )
    ns.RegisterWithEditMode("Party", ns.party, "Party Frames", "Party Frames")

    -- パーティターゲットフレームの生成
    ns.partytarget = self:SpawnHeader("oUF_MyLayoutPartyTarget", nil, "custom [group:party, nogroup:raid] show; hide",
        "showParty", true,
        "yOffset", -60, -- Partyフレームと同じ間隔
        "unitsuffix", "target"
    )
    ns.RegisterWithEditMode("PartyTarget", ns.partytarget, "Party Target Frames", "Party Frames")

    -- レイドフレームの生成
    -- Create a holder frame for positioning and Edit Mode
    ns.raid = CreateFrame("Frame", "oUF_MyLayoutRaidHolder", UIParent)
    ns.raid:SetSize(100, 100) -- Size updated in UpdateFrames
    ns.RegisterWithEditMode("Raid", ns.raid, "Raid Frames", "Raid Frames")

    ns.raidHeaders = {}
    for i = 1, 5 do
        ns.raidHeaders[i] = self:SpawnHeader("oUF_MyLayoutRaid" .. i, nil, "custom [group:raid] show; hide",
            "showRaid", true,
            "xOffset", 5,
            "yOffset", -5,
            "point", "TOP",
            "groupFilter", tostring(i),
            "groupBy", "GROUP",
            "groupingOrder", tostring(i),
            "sortMethod", "INDEX"
        )
    end

    -- ボスフレームの生成 (Boss1 - Boss5)
    ns.boss = {}
    for i = 1, 5 do
        ns.boss[i] = self:Spawn("boss" .. i)
    end
    ns.RegisterWithEditMode("Boss", ns.boss[1], "Boss Frames", "Boss Frames")

    -- メインタンクフレームの生成
    ns.maintank = self:SpawnHeader("oUF_MyLayoutMainTank", nil, "custom [group:raid] show; hide",
        "showRaid", true,
        "groupFilter", "MAINTANK",
        "yOffset", -10
    )
    ns.RegisterWithEditMode("MainTank", ns.maintank, "Main Tank Frames", "Raid Frames")

    -- メインタンクターゲットフレームの生成
    ns.maintanktarget = self:SpawnHeader("oUF_MyLayoutMainTankTarget", nil, "custom [group:raid] show; hide",
        "showRaid", true,
        "groupFilter", "MAINTANK",
        "unitsuffix", "target",
        "yOffset", -10
    )
    ns.RegisterWithEditMode("MainTankTarget", ns.maintanktarget, "Main Tank Target Frames", "Raid Frames")

    -- 初期ロード時に一度すべてのフレームを更新して位置と表示状態を確定
    ns.UpdateFrames()
end)
