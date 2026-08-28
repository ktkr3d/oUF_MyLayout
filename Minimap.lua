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
    end

    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end
