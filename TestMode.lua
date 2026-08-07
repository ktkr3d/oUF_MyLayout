local addonName, ns = ...

-- ------------------------------------------------------------------------
-- Test Mode Helpers
-- ------------------------------------------------------------------------
ns.TestMode = false

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
        local u = obj.unit or "target"
        local nameText = sampleNames[u] or (u:find("party") and "Party Member" or (u:find("raid") and "Raid Member" or "Test Unit"))
        obj.Name:SetText(nameText)
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

function ns.ToggleTestMode(enable)
    if InCombatLockdown() then
        print("|cff00ff00oUF_MyLayout:|r Cannot toggle Test Mode during combat.")
        return
    end

    if enable == nil then
        ns.TestMode = not ns.TestMode
    else
        ns.TestMode = enable
    end

    if ns.TestMode then
        print("|cff00ff00oUF_MyLayout:|r Test Mode |cff00ff00ENABLED|r.")
    else
        print("|cff00ff00oUF_MyLayout:|r Test Mode |cffff0000DISABLED|r.")
    end

    if ns.UpdateFrames then
        ns.UpdateFrames()
    end
end
