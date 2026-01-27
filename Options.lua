local addonName, ns = ...
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Helper function to get SharedMedia list
local function GetLSMList(type)
    local list = {}
    if LSM then
        for k, v in pairs(LSM:HashTable(type)) do
            list[k] = k
        end
    end
    return list
end

local anchorValues = {
    ["CENTER"] = "Center",
    ["TOP"] = "Top",
    ["BOTTOM"] = "Bottom",
    ["LEFT"] = "Left",
    ["RIGHT"] = "Right",
    ["TOPLEFT"] = "Top Left",
    ["TOPRIGHT"] = "Top Right",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOMRIGHT"] = "Bottom Right",
}

local iconAnchorPoints = {
    ["TOPLEFT"] = "Top Left",
    ["TOP"] = "Top",
    ["TOPRIGHT"] = "Top Right",
    ["LEFT"] = "Left",
    ["CENTER"] = "Center",
    ["RIGHT"] = "Right",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOM"] = "Bottom",
    ["BOTTOMRIGHT"] = "Bottom Right",
}

local tagValues = {
    [""] = "None",
    ["[perhp]%"] = "Percent (100%)",
    ["[my:perhp]%"] = "Percent (100.0%)",
    ["[my:perhp_grad]"] = "Percent (Gradient)",
    ["[curhp]"] = "Current (1234)",
    ["[curhp] / [maxhp]"] = "Current / Max (1234 / 2000)",
    ["[missinghp]"] = "Deficit (-500)",
    ["[my:shortval]"] = "Short Value (10k)",
}

local nameTagValues = {
    ["[name]"] = "Name",
    ["[raidcolor][name]"] = "Colored Name",
    ["[level] [raidcolor][name]"] = "Level Name",
    ["[difficulty][level][shortclassification] [name]"] = "Full Level Name",
    ["[raidcolor][name] [dead][offline][my:afk]"] = "Name + Status",
    ["[name] [dead][offline]"] = "Name + Dead/Offline",
    ["[raidcolor][my:shortname]"] = "Short Name",
}

-- Function to create unit specific setting groups
local function CreateUnitGroup(key, name, order, hasCastbar, hasNameTag, xIndex, yIndex)
    local config = ns.Config.Units[key]
    xIndex = xIndex or 2
    yIndex = yIndex or 3

    local function CreateIconSettings(iconKey, iconName, order)
        -- Get a reference to the default config for this icon from the DEFAULTS table
        local unitDefaults = (ns.Defaults.Units[key] or ns.Defaults.Units.Default)
        local defaultIconConfig = (unitDefaults and unitDefaults.Icons and unitDefaults.Icons[iconKey]) or {}

        -- This function will be called by the get/set closures to ensure the path exists
        local function getIconConfig()
            if not config.Icons then config.Icons = {} end
            if not config.Icons[iconKey] then config.Icons[iconKey] = {} end
            return config.Icons[iconKey]
        end

        return {
            type = "group", name = iconName, order = order, inline = true,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 1,
                    get = function() return getIconConfig().Enable end,
                    set = function(_, val) getIconConfig().Enable = val; ns.UpdateFrames() end,
                },
                size = {
                    type = "range", name = "Size", min = 8, max = 64, step = 1, order = 2,
                    get = function() return getIconConfig().Size or defaultIconConfig.Size end,
                    set = function(_, val) getIconConfig().Size = val; ns.UpdateFrames() end,
                },
                point = {
                    type = "select", name = "Anchor Point", values = iconAnchorPoints, order = 3,
                    get = function() return getIconConfig().Point or defaultIconConfig.Point end,
                    set = function(_, val) getIconConfig().Point = val; ns.UpdateFrames() end,
                },
                x = {
                    type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 4,
                    get = function() return getIconConfig().X or defaultIconConfig.X end,
                    set = function(_, val) getIconConfig().X = val; ns.UpdateFrames() end,
                },
                y = {
                    type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 5,
                    get = function() return getIconConfig().Y or defaultIconConfig.Y end,
                    set = function(_, val) getIconConfig().Y = val; ns.UpdateFrames() end,
                },
            }
        }
    end

    local args = {
        general = {
            type = "group", name = "General", order = 10,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 0,
                    get = function() return config.Enable end,
                    set = function(_, val) config.Enable = val; ns.UpdateFrames() end,
                },
                width = {
                    type = "range", name = "Width", min = 10, max = 500, step = 1, order = 1,
                    get = function() return config.Width end,
                    set = function(_, val) config.Width = val; ns.UpdateFrames() end,
                },
                height = {
                    type = "range", name = "Height", min = 10, max = 500, step = 1, order = 2,
                    get = function() return config.Height end,
                    set = function(_, val) config.Height = val; ns.UpdateFrames() end,
                },
                x = {
                    type = "range", name = "X Position", min = -1000, max = 1000, step = 1, order = 3,
                    get = function() return config.Position[xIndex] end,
                    set = function(_, val) config.Position[xIndex] = val; ns.UpdateFrames() end,
                },
                y = {
                    type = "range", name = "Y Position", min = -1000, max = 1000, step = 1, order = 4,
                    get = function() return config.Position[yIndex] end,
                    set = function(_, val) config.Position[yIndex] = val; ns.UpdateFrames() end,
                },
                anchor = {
                    type = "select", name = "Anchor Point", values = anchorValues, order = 5,
                    get = function() return config.Position[1] end,
                    set = function(_, val) config.Position[1] = val; ns.UpdateFrames() end,
                },
            }
        },
        health = {
            type = "group", name = "Health Bar", order = 20,
            args = {
                height = {
                    type = "range", name = "Height", min = 5, max = 100, step = 1, order = 1,
                    get = function() return config.HealthHeight end,
                    set = function(_, val) config.HealthHeight = val; ns.UpdateFrames() end,
                },
                tag = {
                    type = "select", name = "Text Format", values = tagValues, order = 2,
                    get = function() return config.HealthTag end,
                    set = function(_, val) config.HealthTag = val; ns.UpdateFrames() end,
                },
                texture = {
                    type = "select",
                    name = "Texture",
                    values = function() return GetLSMList("statusbar") end,
                    get = function() return config.HealthBarTexture or ns.Config.Media.HealthBar end,
                    set = function(_, val) config.HealthBarTexture = val; ns.UpdateFrames() end,
                    order = 2,
                },
                text = {
                    type = "group", name = "Font Settings", inline = true, order = 3,
                    args = {
                        font = {
                            type = "select", name = "Font", order = 1,
                            values = function() return GetLSMList("font") end,
                            get = function() return config.HealthText.Font or ns.Config.Media.Font end,
                            set = function(_, val) config.HealthText.Font = val; ns.UpdateFrames() end,
                        },
                        size = {
                            type = "range", name = "Size", min = 8, max = 32, step = 1, order = 2,
                            get = function() return config.HealthText.Size end,
                            set = function(_, val) config.HealthText.Size = val; ns.UpdateFrames() end,
                        },
                        outline = {
                            type = "select", name = "Outline", order = 3,
                            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
                            get = function() return config.HealthText.Outline end,
                            set = function(_, val) config.HealthText.Outline = val; ns.UpdateFrames() end,
                        },
                        point = {
                            type = "select", name = "Anchor Point", values = iconAnchorPoints, order = 4,
                            get = function() return config.HealthText.Point or "RIGHT" end,
                            set = function(_, val) config.HealthText.Point = val; ns.UpdateFrames() end,
                        },
                        x = {
                            type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 5,
                            get = function() return config.HealthText.X or 0 end,
                            set = function(_, val) config.HealthText.X = val; ns.UpdateFrames() end,
                        },
                        y = {
                            type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 6,
                            get = function() return config.HealthText.Y or 0 end,
                            set = function(_, val) config.HealthText.Y = val; ns.UpdateFrames() end,
                        },
                    }
                }
            }
        },
        power = {
            type = "group", name = "Power Bar", order = 22,
            args = {
                height = {
                    type = "range", name = "Height", min = 5, max = 50, step = 1, order = 1,
                    get = function() return config.PowerHeight or 10 end,
                    set = function(_, val)
                        config.PowerHeight = val
                        ns.UpdateFrames()
                    end,
                },
                texture = {
                    type = "select",
                    name = "Texture",
                    values = function() return GetLSMList("statusbar") end,
                    get = function() return config.PowerBarTexture or ns.Config.Media.PowerBar end,
                    set = function(_, val) config.PowerBarTexture = val; ns.UpdateFrames() end,
                    order = 2,
                },
            }
        },
        portrait = {
            type = "group", name = "Portrait", order = 30,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 1,
                    get = function() return config.Portrait.Enable end,
                    set = function(_, val) config.Portrait.Enable = val; ns.UpdateFrames() end,
                },
                width = {
                    type = "range", name = "Width", min = 10, max = 300, step = 1, order = 2,
                    get = function() return config.Portrait.Width end,
                    set = function(_, val) config.Portrait.Width = val; ns.UpdateFrames() end,
                },
                height = {
                    type = "range", name = "Height", min = 10, max = 300, step = 1, order = 3,
                    get = function() return config.Portrait.Height end,
                    set = function(_, val) config.Portrait.Height = val; ns.UpdateFrames() end,
                },
                x = {
                    type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 4,
                    get = function() return config.Portrait.X end,
                    set = function(_, val) config.Portrait.X = val; ns.UpdateFrames() end,
                },
                y = {
                    type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 5,
                    get = function() return config.Portrait.Y end,
                    set = function(_, val) config.Portrait.Y = val; ns.UpdateFrames() end,
                },
            }
        },
        buffs = {
            type = "group", name = "Buffs", order = 40,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 1,
                    get = function() return config.Buffs.Enable end,
                    set = function(_, val) config.Buffs.Enable = val; ns.UpdateFrames() end,
                },
                size = {
                    type = "range", name = "Size", min = 10, max = 60, step = 1, order = 2,
                    get = function() return config.Buffs.Size end,
                    set = function(_, val) config.Buffs.Size = val; ns.UpdateFrames() end,
                },
                x = {
                    type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 3,
                    get = function() return config.Buffs.X end,
                    set = function(_, val) config.Buffs.X = val; ns.UpdateFrames() end,
                },
                y = {
                    type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 4,
                    get = function() return config.Buffs.Y end,
                    set = function(_, val) config.Buffs.Y = val; ns.UpdateFrames() end,
                },
                playerOnly = {
                    type = "toggle", name = "Player Cast Only", order = 5,
                    get = function() return config.Buffs.PlayerOnly end,
                    set = function(_, val) config.Buffs.PlayerOnly = val; ns.UpdateFrames() end,
                },
            }
        },
        debuffs = {
            type = "group", name = "Debuffs", order = 50,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 1,
                    get = function() return config.Debuffs.Enable end,
                    set = function(_, val) config.Debuffs.Enable = val; ns.UpdateFrames() end,
                },
                size = {
                    type = "range", name = "Size", min = 10, max = 60, step = 1, order = 2,
                    get = function() return config.Debuffs.Size end,
                    set = function(_, val) config.Debuffs.Size = val; ns.UpdateFrames() end,
                },
                x = {
                    type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 3,
                    get = function() return config.Debuffs.X end,
                    set = function(_, val) config.Debuffs.X = val; ns.UpdateFrames() end,
                },
                y = {
                    type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 4,
                    get = function() return config.Debuffs.Y end,
                    set = function(_, val) config.Debuffs.Y = val; ns.UpdateFrames() end,
                },
                playerOnly = {
                    type = "toggle", name = "Player Cast Only", order = 5,
                    get = function() return config.Debuffs.PlayerOnly end,
                    set = function(_, val) config.Debuffs.PlayerOnly = val; ns.UpdateFrames() end,
                },
            }
        },
        icons = {
            type = "group", name = "Icons", order = 60,
            args = {
                RaidTarget = CreateIconSettings("RaidTarget", "Raid Target", 1),
                GroupRole = CreateIconSettings("GroupRole", "Group Role", 2),
                ReadyCheck = CreateIconSettings("ReadyCheck", "Ready Check", 3),
                Leader = CreateIconSettings("Leader", "Leader", 4),
                Assistant = CreateIconSettings("Assistant", "Assistant", 5),
            }
        },
    }

    if hasNameTag or config.NameText then
        args.name = {
            type = "group", name = "Name Text", order = 15,
            args = {}
        }

        if hasNameTag then
            args.name.args.tag = {
                type = "select", name = "Name Format", values = nameTagValues, order = 1,
                get = function() return config.NameTag end,
                set = function(_, val) config.NameTag = val; ns.UpdateFrames() end,
            }
            args.name.args.shortNameLength = {
                type = "range", name = "Short Name Length", min = 1, max = 30, step = 1, order = 1.5,
                get = function() return config.ShortNameLength or 10 end,
                set = function(_, val) config.ShortNameLength = val; ns.UpdateFrames() end,
            }
        end

        if config.NameText then
            args.name.args.enable = {
                type = "toggle", name = "Enable", order = 0,
                get = function() return config.NameText.Enable ~= false end,
                set = function(_, val) config.NameText.Enable = val; ns.UpdateFrames() end,
            }
            args.name.args.font = {
                type = "select", name = "Font", order = 2,
                values = function() return GetLSMList("font") end,
                get = function() return config.NameText.Font or ns.Config.Media.Font end,
                set = function(_, val) config.NameText.Font = val; ns.UpdateFrames() end,
            }
            args.name.args.size = {
                type = "range", name = "Size", min = 8, max = 32, step = 1, order = 3,
                get = function() return config.NameText.Size end,
                set = function(_, val) config.NameText.Size = val; ns.UpdateFrames() end,
            }
            args.name.args.outline = {
                type = "select", name = "Outline", order = 4,
                values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
                get = function() return config.NameText.Outline end,
                set = function(_, val) config.NameText.Outline = val; ns.UpdateFrames() end,
            }
            args.name.args.point = {
                type = "select", name = "Anchor Point", values = iconAnchorPoints, order = 5,
                get = function() return config.NameText.Point end,
                set = function(_, val) config.NameText.Point = val; ns.UpdateFrames() end,
            }
            args.name.args.x = {
                type = "range", name = "X Offset", min = -100, max = 100, step = 1, order = 6,
                get = function() return config.NameText.X or 0 end,
                set = function(_, val) config.NameText.X = val; ns.UpdateFrames() end,
            }
            args.name.args.y = {
                type = "range", name = "Y Offset", min = -100, max = 100, step = 1, order = 7,
                get = function() return config.NameText.Y or 0 end,
                set = function(_, val) config.NameText.Y = val; ns.UpdateFrames() end,
            }
        end
    end

    if hasCastbar then
        local unitDefaults = (ns.Defaults.Units[key] or ns.Defaults.Units.Default)
        local defaultCbConfig = (unitDefaults and unitDefaults.Castbar) or {}

        local function getCbConfig()
            if not config.Castbar then config.Castbar = {} end
            return config.Castbar
        end

        args.castbar = {
            type = "group", name = "Cast Bar", order = 25,
            args = {
                enable = {
                    type = "toggle", name = "Enable", order = 0,
                    get = function() return getCbConfig().Enable end,
                    set = function(_, val) getCbConfig().Enable = val; ns.UpdateFrames() end,
                },
                height = {
                    type = "range", name = "Height", min = 5, max = 50, step = 1, order = 2,
                    get = function() return getCbConfig().Height or defaultCbConfig.Height end,
                    set = function(_, val) getCbConfig().Height = val; ns.UpdateFrames() end,
                },
                width = {
                    type = "range", name = "Width (0=auto)", min = 0, max = 500, step = 1, order = 3,
                    get = function() return getCbConfig().Width or defaultCbConfig.Width end,
                    set = function(_, val) getCbConfig().Width = val; ns.UpdateFrames() end,
                },
                position = {
                    type = "group", name = "Position", inline = true, order = 4,
                    args = {
                        point = {
                            type = "select", name = "Anchor Point", values = iconAnchorPoints, order = 1,
                            get = function() return getCbConfig().Point or defaultCbConfig.Point end,
                            set = function(_, val) getCbConfig().Point = val; ns.UpdateFrames() end,
                        },
                        relativeTo = {
                            type = "select", name = "Relative To", values = { FRAME = "Frame", HEALTH = "Health Bar", POWER = "Power Bar" }, order = 2,
                            get = function() return getCbConfig().RelativeTo or defaultCbConfig.RelativeTo end,
                            set = function(_, val) getCbConfig().RelativeTo = val; ns.UpdateFrames() end,
                        },
                        relativePoint = {
                            type = "select", name = "Relative Point", values = iconAnchorPoints, order = 3,
                            get = function() return getCbConfig().RelativePoint or defaultCbConfig.RelativePoint end,
                            set = function(_, val) getCbConfig().RelativePoint = val; ns.UpdateFrames() end,
                        },
                        x = {
                            type = "range", name = "X Offset", min = -200, max = 200, step = 1, order = 4,
                            get = function() return getCbConfig().X or defaultCbConfig.X end,
                            set = function(_, val) getCbConfig().X = val; ns.UpdateFrames() end,
                        },
                        y = {
                            type = "range", name = "Y Offset", min = -200, max = 200, step = 1, order = 5,
                            get = function() return getCbConfig().Y or defaultCbConfig.Y end,
                            set = function(_, val) getCbConfig().Y = val; ns.UpdateFrames() end,
                        },
                    }
                },
                text = {
                    type = "group", name = "Font Settings", inline = true, order = 5,
                    args = {
                        font = {
                            type = "select", name = "Font", order = 1,
                            values = function() return GetLSMList("font") end,
                            get = function() return config.CastbarText.Font or ns.Config.Media.Font end,
                            set = function(_, val) config.CastbarText.Font = val; ns.UpdateFrames() end,
                        },
                        size = {
                            type = "range", name = "Size", min = 8, max = 32, step = 1, order = 2,
                            get = function() return config.CastbarText.Size end,
                            set = function(_, val) config.CastbarText.Size = val; ns.UpdateFrames() end,
                        },
                        outline = {
                            type = "select", name = "Outline", order = 3,
                            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
                            get = function() return config.CastbarText.Outline end,
                            set = function(_, val) config.CastbarText.Outline = val; ns.UpdateFrames() end,
                        },
                    }
                }
            }
        }
    end

    if key == "Player" then
        args.icons.args.Resting = CreateIconSettings("Resting", "Resting", 10)
        args.icons.args.Combat = CreateIconSettings("Combat", "Combat", 11)
    end

    if xIndex == 4 then
        args.general.args.parentAnchor = {
            type = "select", name = "Parent Anchor", values = anchorValues, order = 6,
            get = function() return config.Position[3] end,
            set = function(_, val) config.Position[3] = val; ns.UpdateFrames() end,
        }
    end

    if key == "Raid" then
        args.general.args.showParty = {
            type = "toggle", name = "Show Party", order = 7,
            get = function() return config.ShowParty end,
            set = function(_, val) config.ShowParty = val; ns.UpdateFrames() end,
        }
        args.general.args.showSolo = {
            type = "toggle", name = "Show Solo", order = 8,
            get = function() return config.ShowSolo end,
            set = function(_, val) config.ShowSolo = val; ns.UpdateFrames() end,
        }
    end

    if key ~= "Pet" and key ~= "Raid" then
        args.health.args.hideAtFull = {
            type = "toggle",
            name = "Hide Full/Empty",
            order = 4,
            get = function() return config.HideHealthTextAtFull end,
            set = function(_, val) config.HideHealthTextAtFull = val; ns.UpdateFrames() end,
        }
        args.health.args.showStatus = {
            type = "toggle",
            name = "Show Status Text",
            order = 5,
            get = function() return config.ShowStatusText end,
            set = function(_, val) config.ShowStatusText = val; ns.UpdateFrames() end,
        }
    end

    return {
        type = "group",
        name = name,
        order = order,
        childGroups = "tab",
        args = args
    }
end

-- Define configuration table
ns.SetupOptions = function()
    local options = {
        type = "group",
        name = "oUF_MyLayout",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 10,
                args = {
                    disablePortraitsInRaid = {
                        type = "toggle", name = "Disable Portraits in Raid", order = 1, width = "full",
                        get = function() return ns.Config.General.DisablePortraitsInRaid end,
                        set = function(_, val) ns.Config.General.DisablePortraitsInRaid = val; ns.UpdateFrames() end,
                    },
                },
            },
            about = {
                type = "group",
                name = "About",
                order = 201, -- Because AceDBOptions Profiles defaults to order 200
                args = {
                    title = {
                        type = "description",
                        name = "oUF_MyLayout",
                        fontSize = "large",
                        order = 0,
                    },
                    version = {
                        type = "description",
                        name = function() return "Version: " .. (ns.Version or "N/A") end,
                        order = 1,
                    },
                    author = {
                        type = "description",
                        name = "Author: ktkr3d",
                        order = 2,
                    },
                    url = {
                        type = "input",
                        name = "URL",
                        get = function() return "https://github.com/ktkr3d/oUF_MyLayout" end,
                        width = "double",
                        order = 3,
                    },
                },
            },
            colors = {
                type = "group",
                name = "Colors",
                order = 15,
                args = {
                    health = {
                        type = "color",
                        name = "Health",
                        get = function() return unpack(ns.Config.Colors.Health) end,
                        set = function(_, r, g, b) ns.Config.Colors.Health = {r, g, b}; ns.UpdateFrames() end,
                        order = 1,
                    },
                    healthBg = {
                        type = "color",
                        name = "Health Background",
                        get = function() return unpack(ns.Config.Colors.HealthBg) end,
                        set = function(_, r, g, b) ns.Config.Colors.HealthBg = {r, g, b}; ns.UpdateFrames() end,
                        order = 2,
                    },
                    powerBg = {
                        type = "color",
                        name = "Power Background",
                        get = function() return unpack(ns.Config.Colors.PowerBg) end,
                        set = function(_, r, g, b) ns.Config.Colors.PowerBg = {r, g, b}; ns.UpdateFrames() end,
                        order = 3,
                    },
                    castbar = {
                        type = "color",
                        name = "Castbar",
                        get = function() return unpack(ns.Config.Colors.Castbar) end,
                        set = function(_, r, g, b) ns.Config.Colors.Castbar = {r, g, b}; ns.UpdateFrames() end,
                        order = 4,
                    },
                    castbarBg = {
                        type = "color",
                        name = "Castbar Background",
                        get = function() return unpack(ns.Config.Colors.CastbarBg) end,
                        set = function(_, r, g, b) ns.Config.Colors.CastbarBg = {r, g, b}; ns.UpdateFrames() end,
                        order = 5,
                    },
                },
            },
            player = CreateUnitGroup("Player", "Player Frame", 20, true, true),
            target = CreateUnitGroup("Target", "Target Frame", 21, true, true),
            targettarget = CreateUnitGroup("TargetTarget", "Target's Target", 22, false, true),
            focus = CreateUnitGroup("Focus", "Focus Frame", 23, true, true),
            pet = CreateUnitGroup("Pet", "Pet Frame", 24, true, true),
            party = CreateUnitGroup("Party", "Party Frame", 25, true, true),
            partytarget = CreateUnitGroup("PartyTarget", "Party Target Frame", 25.5, false, true),
            raid = CreateUnitGroup("Raid", "Raid Frame", 26, false, true, 4, 5),
            boss = CreateUnitGroup("Boss", "Boss Frame", 27, false, true, 4, 5),
            maintank = CreateUnitGroup("MainTank", "MainTank Frame", 28, false, true, 4, 5),
            maintanktarget = CreateUnitGroup("MainTankTarget", "MainTank Target Frame", 29, false, true, 4, 5),
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(ns.db),
        },
    }

    -- Register options table
    AC:RegisterOptionsTable("oUF_MyLayout", options)
    -- Add to Blizzard Interface Options
    ACD:AddToBlizOptions("oUF_MyLayout", "oUF_MyLayout")
end