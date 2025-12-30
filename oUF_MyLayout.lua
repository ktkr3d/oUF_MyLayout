local addonName, ns = ...
-- oUFオブジェクトを取得（グローバルまたはネームスペースから）
local oUF = ns.oUF or oUF

-- カスタムタグ: AFK (赤色で表示)
oUF.Tags.Methods["my:afk"] = function(unit)
    if UnitIsAFK(unit) then
        return "|cffff0000AFK|r"
    end
end
oUF.Tags.Events["my:afk"] = "PLAYER_FLAGS_CHANGED UNIT_FLAGS"

-- ------------------------------------------------------------------------
-- スタイル定義関数 (Shared Style Function)
-- ------------------------------------------------------------------------
-- この関数内で、各ユニットフレーム（プレイヤー、ターゲット等）の見た目を定義します。
local function Shared(self, unit)
    -- 1. フレームの基本設定
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
    
    -- フレームのサイズ設定 (幅230px, 高さ50px)
    if unit == "pet" then
        self:SetSize(134, 47)
    elseif self:GetName() and self:GetName():match("oUF_MyLayoutMainTank") then
        self:SetSize(120, 35)
    elseif unit and unit:match("raid") then
        self:SetSize(80, 35)
    elseif unit and unit:match("boss") then
        self:SetSize(160, 40)
    else
        self:SetSize(254, 47)
    end

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
    if self:GetName() and self:GetName():match("oUF_MyLayoutMainTank") then
        Health:SetHeight(26)
    elseif unit and unit:match("raid") then
        Health:SetHeight(22)
    elseif unit and unit:match("boss") then
        Health:SetHeight(26)
    else
        Health:SetHeight(30) -- HPバーの高さ
    end
    -- Health:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8") -- シンプルなテクスチャ
    Health:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga")
    Health:SetStatusBarColor(0.25, 0.25, 0.25) -- #404040

    -- HPバーの背景
    local HealthBg = Health:CreateTexture(nil, "BACKGROUND")
    HealthBg:SetAllPoints(true)
    HealthBg:SetColorTexture(0, 0, 0)

    -- オプション: クラスカラーや敵対反応カラーを有効化
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = false
    Health.colorReaction = false
    Health.bg = HealthBg

    -- oUFに登録 (self.Healthに代入することでoUFが自動更新を行う)
    self.Health = Health

    -- --------------------------------------------------------------------
    -- 3. Power Bar (マナ/リソースバー) の作成
    -- --------------------------------------------------------------------
    local Power = CreateFrame("StatusBar", nil, self)
    Power:SetPoint("TOPLEFT", Health, "BOTTOMLEFT", 0, -2)
    Power:SetPoint("TOPRIGHT", Health, "BOTTOMRIGHT", 0, -2)
    Power:SetPoint("BOTTOM", self, "BOTTOM", 0, 2)
    Power:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Minimalist.tga")

    local PowerBg = Power:CreateTexture(nil, "BACKGROUND")
    PowerBg:SetAllPoints(true)
    PowerBg:SetColorTexture(1, 1, 1)
    PowerBg.multiplier = 0.2

    Power.colorClass = true -- クラスカラー
    Power.bg = PowerBg

    -- oUFに登録
    self.Power = Power

    -- --------------------------------------------------------------------
    -- 4. テキスト情報 (名前とHP値)
    -- --------------------------------------------------------------------
    -- 名前
    if unit ~= "player" then
        local Name = Health:CreateFontString(nil, "OVERLAY")
        Name:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 20, "OUTLINE")
        if unit == "pet" then
            Name:SetPoint("BOTTOM", Health, "BOTTOM", 0, -25)
            Name:SetTextColor(1, 1, 1) -- 白色
            self:Tag(Name, "[name] [dead][offline]")
        elseif unit and unit:match("raid") then
            Name:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 12, "OUTLINE")
            Name:SetPoint("CENTER", Health, "CENTER", 0, 0)
            self:Tag(Name, "[raidcolor][name] [dead][offline][my:afk]")
        elseif unit and unit:match("boss") then
            Name:SetPoint("LEFT", Health, "LEFT", 5, 0)
            self:Tag(Name, "[raidcolor][name] [dead][offline]")
        else
            if unit == "target" then
                local Level = Health:CreateFontString(nil, "OVERLAY")
                Level:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 20, "OUTLINE")
                Level:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
                self:Tag(Level, "[difficulty][level][shortclassification]")
                Name:SetPoint("LEFT", Level, "RIGHT", 5, 0)
            else
                Name:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
            end

            self:Tag(Name, "[raidcolor][name] [dead][offline][my:afk]")
        end
        self.Name = Name
    end

    -- HP数値
    if unit ~= "pet" and not (unit and unit:match("raid")) then
        local HpVal = Health:CreateFontString(nil, "OVERLAY")
        if unit and unit:match("boss") then
            HpVal:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 20, "OUTLINE")
            HpVal:SetPoint("LEFT", self.Name, "RIGHT", 5, 0)
        else
            HpVal:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 24, "OUTLINE")
            HpVal:SetPoint("RIGHT", Health, "RIGHT", 0, 0)
        end
        if unit == "player" then
            self:Tag(HpVal, "[perhp]% [dead][offline][my:afk]")
        else
            self:Tag(HpVal, "[perhp]%") -- パーセント表示
        end
    end

    -- --------------------------------------------------------------------
    -- 5. Portrait (3Dモデル)
    -- --------------------------------------------------------------------
    if unit ~= "pet" and not (unit and unit:match("raid")) and not (unit and unit:match("boss")) then
        local Portrait = CreateFrame("PlayerModel", nil, self)
        Portrait:SetSize(150, 43)
        Portrait:SetPoint("LEFT", self, "LEFT", 2, 0) -- フレームの右側に配置

        -- 背景 (オプション)
        local PortraitBg = self:CreateTexture(nil, "BACKGROUND")
        PortraitBg:SetAllPoints(Portrait)
        PortraitBg:SetColorTexture(0, 0, 0, 0.5)

        self.Portrait = Portrait
    end

    -- --------------------------------------------------------------------
    -- 6. Raid Icon (レイドアイコン)
    -- --------------------------------------------------------------------
    local RaidTargetIndicator = Health:CreateTexture(nil, "OVERLAY")
    RaidTargetIndicator:SetSize(20, 20)
    RaidTargetIndicator:SetPoint("CENTER", Health, "TOP", 0, 0)
    self.RaidTargetIndicator = RaidTargetIndicator

    -- --------------------------------------------------------------------
    -- 7. Castbar (詠唱バー)
    -- --------------------------------------------------------------------
    if not (unit and (unit:match("raid") or unit:match("boss"))) then
        local Castbar = CreateFrame("StatusBar", nil, self)
        Castbar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
        Castbar:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -5)
        Castbar:SetHeight(20)
        Castbar:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga")
        Castbar:SetStatusBarColor(1, 0.7, 0) -- オレンジ色

        local CastbarBg = Castbar:CreateTexture(nil, "BACKGROUND")
        CastbarBg:SetAllPoints(true)
        CastbarBg:SetColorTexture(0.2, 0.2, 0.2)

        -- 呪文名
        local CastbarText = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarText:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 12, "OUTLINE")
        CastbarText:SetPoint("LEFT", Castbar, "LEFT", 2, 0)
        
        -- アイコン
        local CastbarIcon = Castbar:CreateTexture(nil, "OVERLAY")
        CastbarIcon:SetSize(20, 20)
        CastbarIcon:SetPoint("RIGHT", Castbar, "LEFT", -5, 0)
        CastbarIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        -- 詠唱時間
        local CastbarTime = Castbar:CreateFontString(nil, "OVERLAY")
        CastbarTime:SetFont("Interface\\Addons\\oUF_MyLayout\\media\\fonts\\Prototype.ttf", 12, "OUTLINE")
        CastbarTime:SetPoint("RIGHT", Castbar, "RIGHT", -2, 0)

        Castbar.bg = CastbarBg
        Castbar.Text = CastbarText
        Castbar.Icon = CastbarIcon
        Castbar.Time = CastbarTime
        Castbar.timeToHold = 0.5 -- 完了後に少し表示を残す

        self.Castbar = Castbar
    end

    -- --------------------------------------------------------------------
    -- 8. Role Icon (ロールアイコン)
    -- --------------------------------------------------------------------
    local GroupRoleIndicator = Health:CreateTexture(nil, "OVERLAY")
    if unit and unit:match("raid") then
        GroupRoleIndicator:SetSize(20, 20)
        GroupRoleIndicator:SetPoint("TOPRIGHT", Health, "TOPRIGHT", 5, 5)
    else
        GroupRoleIndicator:SetSize(32, 32)
        GroupRoleIndicator:SetPoint("TOPRIGHT", Health, "TOPRIGHT", 10, 10)
    end
    self.GroupRoleIndicator = GroupRoleIndicator

    -- --------------------------------------------------------------------
    -- 9. Ready Check Icon (レディチェックアイコン)
    -- --------------------------------------------------------------------
    local ReadyCheckIndicator = Health:CreateTexture(nil, "OVERLAY")
    ReadyCheckIndicator:SetSize(24, 24)
    ReadyCheckIndicator:SetPoint("CENTER", Health, "CENTER", 0, 0)
    self.ReadyCheckIndicator = ReadyCheckIndicator

    -- --------------------------------------------------------------------
    -- 10. Rest Icon (休息アイコン)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local RestingIndicator = Health:CreateTexture(nil, "OVERLAY")
        RestingIndicator:SetSize(32, 32)
        RestingIndicator:SetPoint("TOPLEFT", Health, "TOPLEFT", -10, 10)
        RestingIndicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        RestingIndicator:SetTexCoord(0, 0.5, 0, 0.421875)
        self.RestingIndicator = RestingIndicator
    end

    -- --------------------------------------------------------------------
    -- 11. Combat Icon (戦闘アイコン)
    -- --------------------------------------------------------------------
    if unit == "player" then
        local CombatIndicator = Health:CreateTexture(nil, "OVERLAY")
        CombatIndicator:SetSize(32, 32)
        CombatIndicator:SetPoint("BOTTOMLEFT", Health, "BOTTOMLEFT", -10, -10)
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
            bar:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga")
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
            rune:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga")
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
        AdditionalPower:SetStatusBarTexture("Interface\\Addons\\oUF_MyLayout\\media\\textures\\Gradient.tga")
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
    if unit and unit:match("raid") then
        LeaderIndicator:SetSize(20, 20)
        LeaderIndicator:SetPoint("TOPLEFT", Health, "TOPLEFT", -5, 5)
    else
        LeaderIndicator:SetSize(32, 32)
        LeaderIndicator:SetPoint("TOPLEFT", Health, "TOPLEFT", -10, 10)
    end
    self.LeaderIndicator = LeaderIndicator

    -- --------------------------------------------------------------------
    -- 16. Assistant Icon (アシスタントアイコン)
    -- --------------------------------------------------------------------
    local AssistantIndicator = Health:CreateTexture(nil, "OVERLAY")
    AssistantIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
    if unit and unit:match("raid") then
        AssistantIndicator:SetSize(12, 12)
        AssistantIndicator:SetPoint("TOPLEFT", Health, "TOPLEFT", 2, -2)
    else
        AssistantIndicator:SetSize(16, 16)
        AssistantIndicator:SetPoint("TOPLEFT", Health, "TOPLEFT", 2, -2)
    end
    self.AssistantIndicator = AssistantIndicator
end

-- ------------------------------------------------------------------------
-- ファクトリー (Factory)
-- ------------------------------------------------------------------------
-- スタイルを登録し、実際にフレームを生成(Spawn)します。

oUF:RegisterStyle("MyLayout", Shared)

oUF:Factory(function(self)
    self:SetActiveStyle("MyLayout")

    -- プレイヤーフレームの生成と配置
    local player = self:Spawn("player")
    player:SetPoint("CENTER", -200, -200)

    -- ターゲットフレームの生成と配置
    local target = self:Spawn("target")
    target:SetPoint("CENTER", 200, -200)
    
    -- ペットフレームの生成と配置
    local pet = self:Spawn("pet")
    pet:SetPoint("CENTER", 0, -200)

    -- フォーカスフレームなども同様に追加可能
    -- self:Spawn("focus"):SetPoint("CENTER", 0, -100)

    -- パーティフレームの生成
    local party = self:SpawnHeader(nil, nil, "custom [group:party, nogroup:raid] show; hide",
        "showParty", true,
        "yOffset", -60 -- 垂直方向に並べる
    )
    party:SetPoint("TOPLEFT", 150, -200)

    -- レイドフレームの生成
    local raid = self:SpawnHeader(nil, nil, "custom [group:raid] show; hide",
        "showRaid", true,
        "xOffset", 5,
        "yOffset", -5,
        "point", "TOP",
        "groupFilter", "1,2,3,4,5",
        "groupingOrder", "1,2,3,4,5",
        "groupBy", "GROUP",
        "maxColumns", 5,
        "unitsPerColumn", 5,
        "columnSpacing", 5,
        "columnAnchorPoint", "LEFT"
    )
    raid:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", -435, 225)

    -- ボスフレームの生成 (Boss1 - Boss5)
    local prevBoss
    for i = 1, 5 do
        local boss = self:Spawn("boss" .. i)
        if i == 1 then
            boss:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 5, -300)
        else
            boss:SetPoint("TOP", prevBoss, "BOTTOM", 0, -60)
        end
        prevBoss = boss
    end

    -- メインタンクフレームの生成
    local maintank = self:SpawnHeader("oUF_MyLayoutMainTank", nil, "custom [group:raid] show; hide",
        "showRaid", true,
        "groupFilter", "MAINTANK",
        "yOffset", -10
    )
    maintank:SetPoint("TOPLEFT", 50, -350)
end)
