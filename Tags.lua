local addonName, ns = ...

-- Get oUF object (global or from namespace)
local oUF = ns.oUF or oUF

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
    local isAFK = UnitIsAFK(unit)
    if issecretvalue and issecretvalue(isAFK) then isAFK = false end
    if isAFK then
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
    elseif unit:match("maintank") then maxLen = C.Units.MainTank.ShortNameLength
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
