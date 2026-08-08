local addonName, ns = ...

-- ------------------------------------------------------------------------
-- Test Mode Helpers
-- ------------------------------------------------------------------------
ns.TestMode = false
ns.TestModeFrameState = nil

local sampleNames = {
    player = "Test Player",
    target = "Test Target",
    targettarget = "Target of Target",
    focus = "Focus Unit",
    pet = "Test Pet",
    boss1 = "Boss 1",
    boss2 = "Boss 2",
    boss3 = "Boss 3",
    boss4 = "Boss 4",
    boss5 = "Boss 5",
}

local function GetTestName(obj)
    local frameName = obj:GetName() or ""
    if frameName:match("BossTest") then
        return "Boss " .. (frameName:match("(%d+)$") or "1")
    end
    if frameName:match("MainTankTargetTest") then return "Main Tank Target" end
    if frameName:match("MainTankTest") then return "Main Tank" end

    local unit = obj.unit or "target"
    return sampleNames[unit] or (unit:find("party") and "Party Member" or (unit:find("raid") and "Raid Member" or "Test Unit"))
end

function ns.ApplyTestModeData(obj)
    if not obj or not obj.style or obj.style ~= "MyLayout" then return end
    obj:Show()

    -- Set mock Health
    if obj.Health then
        obj.Health:SetMinMaxValues(0, 100)
        obj.Health:SetValue(75)
    end

    -- Set mock Power
    if obj.Power then
        obj.Power:SetMinMaxValues(0, 100)
        obj.Power:SetValue(60)
    end

    -- Set mock Name text (only if element is shown and font is set)
    if obj.Name and obj.Name:IsShown() and obj.Name:GetFont() then
        obj.Name:SetText(GetTestName(obj))
    end

    -- Set mock Health text (HpVal, only if shown and font is set)
    if obj.HpVal and obj.HpVal:IsShown() and obj.HpVal:GetFont() then
        obj.HpVal:SetText("75.0%")
    end

    -- Castbar preview
    if obj.Castbar then
        obj.Castbar:Show()
        obj.Castbar:SetMinMaxValues(0, 100)
        obj.Castbar:SetValue(50)
        if obj.Castbar.Text and obj.Castbar.Text:GetFont() then
            obj.Castbar.Text:SetText("Casting Test Spell...")
        end
        if obj.Castbar.Time and obj.Castbar.Time:GetFont() then
            obj.Castbar.Time:SetText("1.5s / 3.0s")
        end
        if obj.Castbar.Icon and not obj.Castbar.Icon:GetTexture() then
            obj.Castbar.Icon:SetTexture("Interface\\Icons\\Spell_Nature_HealingTouch")
        end
    end
end

function ns.ClearTestModeData(obj)
    if not obj or not obj.style or obj.style ~= "MyLayout" then return end

    if obj.isTestPreview then
        obj:Hide()
        return
    end

    if obj.Castbar then
        obj.Castbar:Hide()
        obj.Castbar.casting = nil
        obj.Castbar.channeling = nil
    end

    if obj.unit and UnitExists(obj.unit) then
        if obj.UpdateAllElements then
            obj:UpdateAllElements("TestModeDisabled")
        end
    else
        if not obj:GetParent() or obj:GetParent() == UIParent then
            if obj.unit and not UnitExists(obj.unit) then
                obj:Hide()
            end
        end
    end
end

local function HideTestPreviewFrames()
    if ns.testboss then
        for _, frame in ipairs(ns.testboss) do
            frame:Hide()
            if ns.testPreviewParent then frame:SetParent(ns.testPreviewParent) end
        end
    end

    if ns.testmaintank then
        ns.testmaintank:Hide()
        if ns.testPreviewParent then ns.testmaintank:SetParent(ns.testPreviewParent) end
    end
    if ns.testmaintanktarget then
        ns.testmaintanktarget:Hide()
        if ns.testPreviewParent then ns.testmaintanktarget:SetParent(ns.testPreviewParent) end
    end
end

local function GetTestModeFrames()
    local frames = {}

    if ns.boss then
        for _, frame in ipairs(ns.boss) do
            frames[#frames + 1] = frame
        end
    end

    frames[#frames + 1] = ns.maintank
    frames[#frames + 1] = ns.maintanktarget

    return frames
end

local function SaveTestModeFrameState()
    local state = {}

    for _, frame in ipairs(GetTestModeFrames()) do
        if frame then
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
            state[frame] = {
                shown = frame:IsShown(),
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
                width = frame:GetWidth(),
                height = frame:GetHeight(),
                alpha = frame:GetAlpha(),
            }
        end
    end

    ns.TestModeFrameState = state
end

local function RestoreTestModeFrameState()
    local state = ns.TestModeFrameState
    if not state then return end

    for frame, saved in pairs(state) do
        if saved.point and saved.relativeTo then
            frame:ClearAllPoints()
            frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.x, saved.y)
        end
        if saved.width and saved.height then
            frame:SetSize(saved.width, saved.height)
        end
        if saved.alpha then
            frame:SetAlpha(saved.alpha)
        end
        local isMainTankHeader = frame == ns.maintank or frame == ns.maintanktarget
        if not isMainTankHeader then
            local shouldShow = saved.shown
            if frame.unit and frame.unit:match("^boss%d+$") and not UnitExists(frame.unit) then
                shouldShow = false
            end
            if shouldShow then
                frame:Show()
            else
                frame:Hide()
            end
        end
    end

    ns.TestModeFrameState = nil
end

function ns.ToggleTestMode(enable)
    if InCombatLockdown() then
        print("|cff00ff00oUF_MyLayout:|r Cannot toggle Test Mode during combat.")
        return
    end

    local wasTestMode = ns.TestMode
    if enable == nil then
        ns.TestMode = not ns.TestMode
    else
        ns.TestMode = enable
    end

    if ns.TestMode and not wasTestMode then
        SaveTestModeFrameState()
    end

    if ns.TestMode then
        print("|cff00ff00oUF_MyLayout:|r Test Mode |cff00ff00ENABLED|r.")
    else
        print("|cff00ff00oUF_MyLayout:|r Test Mode |cffff0000DISABLED|r.")
        HideTestPreviewFrames()
    end

    if ns.UpdateFrames then
        ns.UpdateFrames()
    end

    if not ns.TestMode and wasTestMode then
        RestoreTestModeFrameState()
    end
end
