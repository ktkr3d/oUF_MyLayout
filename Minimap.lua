local addonName, ns = ...

-- ------------------------------------------------------------------------
-- Minimap Icon Implementation (LibDBIcon / Custom Fallback)
-- ------------------------------------------------------------------------
function ns.SetupMinimapButton()
    if not ns.Config or not ns.Config.General then return end
    if not ns.Config.General.MinimapIcon then
        ns.Config.General.MinimapIcon = { hide = false, minimapPos = 220 }
    end

    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)

    if LDB and icon then
        local broker = LDB:GetDataObjectByName("oUF_MyLayout")
        if not broker then
            broker = LDB:NewDataObject("oUF_MyLayout", {
                type = "launcher",
                icon = "Interface\\Icons\\Achievement_Reputation_Kirintor",
                OnClick = function(self, button)
                    local ACD = LibStub("AceConfigDialog-3.0")
                    if button == "RightButton" then
                        if ns.ToggleTestMode then ns.ToggleTestMode() end
                    else
                        if ACD.OpenFrames and ACD.OpenFrames["oUF_MyLayout"] then
                            ACD:Close("oUF_MyLayout")
                        else
                            ACD:Open("oUF_MyLayout")
                        end
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine("oUF_MyLayout " .. (ns.Version or ""))
                    tooltip:AddLine("|cff00ff00Left-Click:|r Open Configuration", 1, 1, 1)
                    tooltip:AddLine("|cff00ff00Right-Click:|r Toggle Test Mode", 1, 1, 1)
                end,
            })
            icon:Register("oUF_MyLayout", broker, ns.Config.General.MinimapIcon)
        end

        function ns.UpdateMinimapButton()
            if ns.Config.General.MinimapIcon and ns.Config.General.MinimapIcon.hide then
                icon:Hide("oUF_MyLayout")
            else
                icon:Show("oUF_MyLayout")
            end
        end
    else
        -- Standalone Minimap Button Fallback
        if _G["oUF_MyLayoutMinimapButton"] then
            if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
            return
        end

        local button = CreateFrame("Button", "oUF_MyLayoutMinimapButton", Minimap)
        button:SetSize(31, 31)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local iconTexture = button:CreateTexture(nil, "BACKGROUND")
        iconTexture:SetTexture("Interface\\Icons\\Achievement_Reputation_Kirintor")
        iconTexture:SetSize(20, 20)
        iconTexture:SetPoint("CENTER", 0, 0)
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(53, 53)
        border:SetPoint("TOPLEFT", 0, 0)

        local function UpdatePos()
            local angle = math.rad((ns.Config.General.MinimapIcon and ns.Config.General.MinimapIcon.minimapPos) or 220)
            local x = math.cos(angle) * 80
            local y = math.sin(angle) * 80
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end

        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                cx, cy = cx / scale, cy / scale
                local angle = math.deg(math.atan2(cy - my, cx - mx))
                if not ns.Config.General.MinimapIcon then ns.Config.General.MinimapIcon = {} end
                ns.Config.General.MinimapIcon.minimapPos = angle
                UpdatePos()
            end)
        end)
        button:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(self, btn)
            local ACD = LibStub("AceConfigDialog-3.0")
            if btn == "RightButton" then
                if ns.ToggleTestMode then ns.ToggleTestMode() end
            else
                if ACD.OpenFrames and ACD.OpenFrames["oUF_MyLayout"] then
                    ACD:Close("oUF_MyLayout")
                else
                    ACD:Open("oUF_MyLayout")
                end
            end
        end)

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("oUF_MyLayout " .. (ns.Version or ""))
            GameTooltip:AddLine("|cff00ff00Left-Click:|r Open Configuration", 1, 1, 1)
            GameTooltip:AddLine("|cff00ff00Right-Click:|r Toggle Test Mode", 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        function ns.UpdateMinimapButton()
            if ns.Config.General.MinimapIcon and ns.Config.General.MinimapIcon.hide then
                button:Hide()
            else
                button:Show()
                UpdatePos()
            end
        end
    end

    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end
