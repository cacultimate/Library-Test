--[[
    CAC ULTIMATE FRAMEWORK
    Version: 4.0 (Architect Edition)
    Description: Premium modular UI framework (black-first style) with global config.
    Language: English Only
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local isfile = isfile or function() return false end
local readfile = readfile or function() return "{}" end
local writefile = writefile or function() end
local delfile = delfile or function() end

-- ==============================================================================
-- 1) UTILITY + THEME
-- ==============================================================================

local Utility = {}

local ThemeManager = {
    Themes = {
        Default = {
            Background = Color3.fromRGB(5, 5, 5),
            Panel = Color3.fromRGB(12, 12, 12),
            PanelHover = Color3.fromRGB(18, 18, 18),
            Border = Color3.fromRGB(24, 24, 24),
            BorderHighlight = Color3.fromRGB(40, 40, 40),
            Text = Color3.fromRGB(255, 255, 255),
            TextDark = Color3.fromRGB(140, 140, 140),
            TextMuted = Color3.fromRGB(80, 80, 80),
            Accent = Color3.fromRGB(255, 255, 255),
            Success = Color3.fromRGB(120, 255, 120),
            Error = Color3.fromRGB(255, 90, 90),
            Warning = Color3.fromRGB(255, 200, 80),
            Shadow = Color3.fromRGB(0, 0, 0),
            AccentGlow = Color3.fromRGB(255, 255, 255)
        },
        Purple = {
            Background = Color3.fromRGB(7, 7, 10),
            Panel = Color3.fromRGB(17, 16, 24),
            PanelHover = Color3.fromRGB(23, 22, 32),
            Border = Color3.fromRGB(38, 34, 52),
            BorderHighlight = Color3.fromRGB(58, 49, 81),
            Text = Color3.fromRGB(240, 240, 255),
            TextDark = Color3.fromRGB(172, 165, 206),
            TextMuted = Color3.fromRGB(107, 99, 138),
            Accent = Color3.fromRGB(165, 121, 255),
            Success = Color3.fromRGB(140, 255, 180),
            Error = Color3.fromRGB(255, 110, 130),
            Warning = Color3.fromRGB(255, 200, 120),
            Shadow = Color3.fromRGB(0, 0, 0),
            AccentGlow = Color3.fromRGB(195, 167, 255)
        },
        Sapphire = {
            Background = Color3.fromRGB(5, 9, 14),
            Panel = Color3.fromRGB(11, 18, 27),
            PanelHover = Color3.fromRGB(16, 25, 38),
            Border = Color3.fromRGB(25, 42, 61),
            BorderHighlight = Color3.fromRGB(41, 66, 93),
            Text = Color3.fromRGB(232, 246, 255),
            TextDark = Color3.fromRGB(151, 186, 211),
            TextMuted = Color3.fromRGB(102, 130, 151),
            Accent = Color3.fromRGB(92, 186, 255),
            Success = Color3.fromRGB(120, 255, 195),
            Error = Color3.fromRGB(255, 105, 105),
            Warning = Color3.fromRGB(255, 204, 117),
            Shadow = Color3.fromRGB(0, 0, 0),
            AccentGlow = Color3.fromRGB(143, 212, 255)
        },
        Emerald = {
            Background = Color3.fromRGB(6, 10, 8),
            Panel = Color3.fromRGB(13, 22, 18),
            PanelHover = Color3.fromRGB(18, 30, 24),
            Border = Color3.fromRGB(26, 45, 36),
            BorderHighlight = Color3.fromRGB(38, 67, 52),
            Text = Color3.fromRGB(238, 252, 245),
            TextDark = Color3.fromRGB(160, 204, 184),
            TextMuted = Color3.fromRGB(104, 140, 123),
            Accent = Color3.fromRGB(94, 230, 167),
            Success = Color3.fromRGB(132, 255, 186),
            Error = Color3.fromRGB(255, 115, 115),
            Warning = Color3.fromRGB(255, 204, 112),
            Shadow = Color3.fromRGB(0, 0, 0),
            AccentGlow = Color3.fromRGB(138, 255, 200)
        },
        Crimson = {
            Background = Color3.fromRGB(11, 6, 7),
            Panel = Color3.fromRGB(22, 11, 13),
            PanelHover = Color3.fromRGB(31, 16, 18),
            Border = Color3.fromRGB(52, 24, 29),
            BorderHighlight = Color3.fromRGB(78, 34, 42),
            Text = Color3.fromRGB(255, 238, 240),
            TextDark = Color3.fromRGB(214, 161, 170),
            TextMuted = Color3.fromRGB(151, 102, 112),
            Accent = Color3.fromRGB(255, 107, 136),
            Success = Color3.fromRGB(130, 255, 190),
            Error = Color3.fromRGB(255, 120, 120),
            Warning = Color3.fromRGB(255, 198, 115),
            Shadow = Color3.fromRGB(0, 0, 0),
            AccentGlow = Color3.fromRGB(255, 149, 169)
        }
    },
    ThemeOrder = { "Default", "Purple", "Sapphire", "Emerald", "Crimson" },
    Current = "Default",
    Registry = {}
}

function ThemeManager:Get(key)
    local selected = self.Themes[self.Current] or self.Themes.Default
    return selected[key] or self.Themes.Default[key]
end

function ThemeManager:Register(instance, property, colorKey)
    if not instance then
        return
    end
    if not self.Registry[instance] then
        self.Registry[instance] = {}
    end
    self.Registry[instance][property] = colorKey
    pcall(function()
        instance[property] = self:Get(colorKey)
    end)
end

function ThemeManager:UpdateAll()
    for instance, properties in pairs(self.Registry) do
        if instance and instance.Parent then
            for prop, key in pairs(properties) do
                pcall(function()
                    TweenService:Create(instance, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        [prop] = self:Get(key)
                    }):Play()
                end)
            end
        else
            self.Registry[instance] = nil
        end
    end
end

function ThemeManager:SetTheme(themeName)
    if self.Themes[themeName] then
        self.Current = themeName
        self:UpdateAll()
        return true
    end
    return false
end

function ThemeManager:SetAccent(color)
    if typeof(color) == "Color3" then
        self.Themes[self.Current].Accent = color
        self.Themes[self.Current].AccentGlow = color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
        self:UpdateAll()
        return true
    end
    return false
end

function Utility:Tween(obj, props, time, style, direction)
    if not obj then
        return nil
    end
    local tween = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
        props or {}
    )
    tween:Play()
    return tween
end

function Utility:Create(className, properties, children)
    local inst = Instance.new(className)
    for key, value in pairs(properties or {}) do
        if key == "Theme" then
            for prop, colorKey in pairs(value) do
                ThemeManager:Register(inst, prop, colorKey)
            end
        else
            inst[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

function Utility:ApplyCorner(parent, radius)
    return self:Create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent
    })
end

function Utility:ApplyStroke(parent, colorKey, thickness)
    return self:Create("UIStroke", {
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = colorKey or "Border" },
        Parent = parent
    })
end

function Utility:AddShadow(parent, intensity)
    return self:Create("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = ThemeManager:Get("Shadow"),
        ImageTransparency = intensity or 0.58,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.new(0, -10, 0, -10),
        ZIndex = (parent.ZIndex or 1) - 1,
        Parent = parent
    })
end

function Utility:MakeDraggable(dragArea, target)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragInput = nil

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            Utility:Tween(target, {
                Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            }, 0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        end
    end)
end

function Utility:GetTextBounds(text, font, size, vector)
    return TextService:GetTextSize(tostring(text or ""), size or 12, font or Enum.Font.Gotham, vector or Vector2.new(10000, 10000))
end

local function ColorToHex(c)
    if typeof(c) ~= "Color3" then
        return "#FFFFFF"
    end
    return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function ClampNumber(value, min, max)
    local n = tonumber(value)
    if not n then
        return min
    end
    return math.clamp(n, min, max)
end

local function NormalizeKeyCode(value, fallback)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end
    if type(value) == "string" then
        local upper = value:gsub("%s+", ""):upper()
        if upper ~= "" then
            return Enum.KeyCode[upper] or fallback
        end
    end
    return fallback
end

-- ==============================================================================
-- 2) SAVE MANAGER
-- ==============================================================================

local SaveManager = {
    Folder = "CAC_Ultimate",
    Flags = {},
    Options = {},
    Ignore = {}
}

function SaveManager:Init(folderName)
    self.Folder = folderName or self.Folder
    if not isfolder(self.Folder) then
        makefolder(self.Folder)
    end
    if not isfolder(self.Folder .. "/configs") then
        makefolder(self.Folder .. "/configs")
    end
end

function SaveManager:Save(name)
    local filePath = self.Folder .. "/configs/" .. tostring(name) .. ".json"
    local data = {}
    for flag, optionObj in pairs(self.Options) do
        if not self.Ignore[flag] and optionObj then
            data[flag] = self.Flags[flag]
        end
    end
    writefile(filePath, HttpService:JSONEncode(data))
end

function SaveManager:Load(name)
    local filePath = self.Folder .. "/configs/" .. tostring(name) .. ".json"
    if not isfile(filePath) then
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(filePath))
    end)
    if not ok or type(data) ~= "table" then
        return false
    end
    for flag, val in pairs(data) do
        local option = self.Options[flag]
        if option and option.SetValue then
            pcall(function()
                option:SetValue(val)
            end)
        end
    end
    return true
end

-- ==============================================================================
-- 3) CORE LIBRARY
-- ==============================================================================

local Library = {
    Windows = {},
    ActiveWindow = nil,
    Keybind = Enum.KeyCode.K
}

function Library:SetGlobalKeybind(keycode)
    self.Keybind = NormalizeKeyCode(keycode, self.Keybind)
end

function Library:CreateWindow(Settings)
    Settings = Settings or {}

    local Name = Settings.Name or "CAC Ultimate"
    local LoadingTitle = Settings.LoadingTitle or "INITIALIZING FRAMEWORK..."
    local defaultW = ClampNumber(Settings.Width or 800, 520, 1400)
    local defaultH = ClampNumber(Settings.Height or 500, 360, 920)
    local defaultSidebar = ClampNumber(Settings.SidebarWidth or 200, 160, 360)
    local defaultScale = ClampNumber(Settings.UIScale or 1, 0.7, 1.5)
    local defaultKey = NormalizeKeyCode(Settings.ToggleKey, Enum.KeyCode.K)

    SaveManager:Init(Settings.Folder)

    local Window = {
        Tabs = {},
        Elements = {},
        IsLoaded = false,
        IsToggled = true,
        IsDestroyed = false,
        NotificationsEnabled = true,
        ToggleKey = defaultKey,
        SavedOpenSize = UDim2.fromOffset(defaultW, defaultH),
        ThemeName = ThemeManager.Current,
        Accent = ThemeManager:Get("Accent")
    }

    local GUI = Utility:Create("ScreenGui", {
        Name = "CAC_Ultimate_Core_" .. tostring(math.random(1000, 9999)),
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    })
    ProtectGui(GUI)
    GUI.Parent = CoreGui

    local MainFrame = Utility:Create("Frame", {
        Name = "MainFrame",
        Size = Window.SavedOpenSize,
        Position = UDim2.new(0.5, -defaultW / 2, 0.5, -defaultH / 2),
        ClipsDescendants = true,
        Theme = { BackgroundColor3 = "Background" },
        Parent = GUI
    })
    Utility:ApplyCorner(MainFrame, 8)
    Utility:ApplyStroke(MainFrame, "Border", 1)
    Utility:AddShadow(MainFrame, 0.52)

    local UIScale = Utility:Create("UIScale", {
        Scale = defaultScale,
        Parent = MainFrame
    })

    local LoadingFrame = Utility:Create("Frame", {
        Name = "LoadingOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2000,
        Theme = { BackgroundColor3 = "Background" },
        Parent = MainFrame
    })
    Utility:ApplyCorner(LoadingFrame, 8)

    local Spinner = Utility:Create("ImageLabel", {
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0.5, -20, 0.42, -20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://13778704232",
        Theme = { ImageColor3 = "Accent" },
        ZIndex = 2001,
        Parent = LoadingFrame
    })

    local LoadTitleObj = Utility:Create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 30),
        Position = UDim2.new(0, 20, 0.55, 0),
        BackgroundTransparency = 1,
        Text = LoadingTitle,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Theme = { TextColor3 = "Text" },
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2001,
        Parent = LoadingFrame
    })

    local spinning = true
    local spinConn = RunService.RenderStepped:Connect(function()
        if spinning and Spinner.Parent then
            Spinner.Rotation = (Spinner.Rotation + 4) % 360
        end
    end)

    local DragBar = Utility:Create("Frame", {
        Name = "DragBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 60,
        Parent = MainFrame
    })
    Utility:MakeDraggable(DragBar, MainFrame)

    local TopRightButtons = Utility:Create("Frame", {
        Name = "TopButtons",
        Size = UDim2.new(0, 90, 0, 34),
        Position = UDim2.new(1, -98, 0, 8),
        BackgroundTransparency = 1,
        ZIndex = 61,
        Parent = MainFrame
    })
    Utility:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = TopRightButtons
    })

    local MinButton = Utility:Create("TextButton", {
        Size = UDim2.new(0, 34, 0, 26),
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Theme = { TextColor3 = "TextDark", BackgroundColor3 = "Panel" },
        AutoButtonColor = false,
        ZIndex = 62,
        Parent = TopRightButtons
    })
    Utility:ApplyCorner(MinButton, 6)
    Utility:ApplyStroke(MinButton, "Border", 1)

    local CloseButton = Utility:Create("TextButton", {
        Size = UDim2.new(0, 34, 0, 26),
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Theme = { TextColor3 = "Text", BackgroundColor3 = "Panel" },
        AutoButtonColor = false,
        ZIndex = 62,
        Parent = TopRightButtons
    })
    Utility:ApplyCorner(CloseButton, 6)
    Utility:ApplyStroke(CloseButton, "Border", 1)

    local Sidebar = Utility:Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, defaultSidebar, 1, 0),
        Theme = { BackgroundColor3 = "Panel" },
        Parent = MainFrame
    })
    Utility:ApplyCorner(Sidebar, 8)
    Utility:ApplyStroke(Sidebar, "Border", 1)
    Utility:Create("Frame", {
        Size = UDim2.new(0, 12, 1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Panel" },
        Parent = Sidebar
    })

    local TitleArea = Utility:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundTransparency = 1,
        Parent = Sidebar
    })

    Utility:Create("TextLabel", {
        Size = UDim2.new(1, -30, 0, 30),
        Position = UDim2.new(0, 16, 0, 25),
        BackgroundTransparency = 1,
        Text = string.upper(Name),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Theme = { TextColor3 = "Text" },
        Parent = TitleArea
    })

    local TabContainer = Utility:Create("ScrollingFrame", {
        Name = "TabContainer",
        Size = UDim2.new(1, 0, 1, -120),
        Position = UDim2.new(0, 0, 0, 78),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = Sidebar
    })
    local TabLayout = Utility:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabContainer
    })
    TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 6)
    end)

    local ProfileCard = Utility:Create("Frame", {
        Name = "ProfileCard",
        Size = UDim2.new(1, -20, 0, 45),
        Position = UDim2.new(0, 10, 1, -55),
        Theme = { BackgroundColor3 = "Background" },
        Parent = Sidebar
    })
    Utility:ApplyCorner(ProfileCard, 6)
    Utility:ApplyStroke(ProfileCard, "Border", 1)

    local AvatarImg = Utility:Create("ImageLabel", {
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(0, 10, 0.5, -12.5),
        Theme = { BackgroundColor3 = "Border" },
        Parent = ProfileCard
    })
    Utility:ApplyCorner(AvatarImg, 100)
    task.spawn(function()
        local thumb, ready = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if ready and AvatarImg and AvatarImg.Parent then
            AvatarImg.Image = thumb
        end
    end)

    Utility:Create("TextLabel", {
        Size = UDim2.new(1, -50, 0, 15),
        Position = UDim2.new(0, 45, 0, 8),
        BackgroundTransparency = 1,
        Text = LocalPlayer.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Theme = { TextColor3 = "Text" },
        Parent = ProfileCard
    })

    Utility:Create("TextLabel", {
        Size = UDim2.new(1, -50, 0, 15),
        Position = UDim2.new(0, 45, 0, 22),
        BackgroundTransparency = 1,
        Text = "UID: " .. tostring(LocalPlayer.UserId),
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Theme = { TextColor3 = "TextMuted" },
        Parent = ProfileCard
    })

    local ContentArea = Utility:Create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -defaultSidebar, 1, 0),
        Position = UDim2.new(0, defaultSidebar, 0, 0),
        BackgroundTransparency = 1,
        Parent = MainFrame
    })

    local VersionLabel = Utility:Create("TextLabel", {
        Size = UDim2.new(0, 220, 0, 20),
        Position = UDim2.new(1, -230, 1, -25),
        BackgroundTransparency = 1,
        Text = "CAC Ultimate | v4.4",
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        Theme = { TextColor3 = "TextMuted" },
        Parent = ContentArea
    })

    local NotifContainer = Utility:Create("Frame", {
        Name = "Notifications",
        Size = UDim2.new(0, 280, 1, -20),
        Position = UDim2.new(1, -290, 0, 10),
        BackgroundTransparency = 1,
        ZIndex = 500,
        Parent = GUI
    })
    Utility:Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = NotifContainer
    })

    Window.UI = {
        GUI = GUI,
        MainFrame = MainFrame,
        Sidebar = Sidebar,
        ContentArea = ContentArea,
        DragBar = DragBar,
        TabContainer = TabContainer,
        UIScale = UIScale,
        VersionLabel = VersionLabel
    }

    local connections = {}

    local function track(conn)
        table.insert(connections, conn)
        return conn
    end

    local function keyToText(keycode)
        local name = tostring(keycode and keycode.Name or "K")
        return name
    end

    function Window:Notify(config)
        if self.IsDestroyed then
            return
        end
        if not self.NotificationsEnabled then
            return
        end
        local title = tostring((config and config.Title) or "Notification")
        local content = tostring((config and config.Content) or "...")
        local duration = tonumber((config and config.Duration) or 4) or 4

        local notif = Utility:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Parent = NotifContainer
        })

        local card = Utility:Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(1, 28, 0, 0),
            Theme = { BackgroundColor3 = "Panel" },
            Parent = notif
        })
        Utility:ApplyCorner(card, 6)
        Utility:ApplyStroke(card, "Border", 1)
        Utility:AddShadow(card, 0.42)

        local line = Utility:Create("Frame", {
            Size = UDim2.new(0, 3, 1, -16),
            Position = UDim2.new(0, 8, 0, 8),
            Theme = { BackgroundColor3 = "Accent" },
            Parent = card
        })
        Utility:ApplyCorner(line, 2)

        Utility:Create("TextLabel", {
            Size = UDim2.new(1, -35, 0, 16),
            Position = UDim2.new(0, 20, 0, 8),
            BackgroundTransparency = 1,
            Text = title,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Theme = { TextColor3 = "Text" },
            Parent = card
        })

        local desc = Utility:Create("TextLabel", {
            Size = UDim2.new(1, -35, 0, 0),
            Position = UDim2.new(0, 20, 0, 25),
            BackgroundTransparency = 1,
            Text = content,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Theme = { TextColor3 = "TextDark" },
            Parent = card
        })

        local bounds = Utility:GetTextBounds(content, Enum.Font.GothamMedium, 11, Vector2.new(230, 1000))
        local targetHeight = math.max(48, bounds.Y + 35)

        Utility:Tween(notif, { Size = UDim2.new(1, 0, 0, targetHeight) }, 0.26)
        Utility:Tween(desc, { Size = UDim2.new(1, -35, 0, bounds.Y) }, 0.26)
        task.wait(0.08)
        Utility:Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.delay(duration, function()
            if not notif or not notif.Parent then
                return
            end
            Utility:Tween(card, { Position = UDim2.new(1, 20, 0, 0) }, 0.24)
            task.wait(0.24)
            Utility:Tween(notif, { Size = UDim2.new(1, 0, 0, 0) }, 0.24)
            task.wait(0.24)
            if notif then
                notif:Destroy()
            end
        end)
    end

    local MiniBar = Utility:Create("Frame", {
        Name = "MiniBar",
        Size = UDim2.fromOffset(320, 34),
        Position = UDim2.new(0.5, -160, 0.5, -120),
        Visible = false,
        Theme = { BackgroundColor3 = "Background" },
        ZIndex = 700,
        Parent = GUI
    })
    Utility:ApplyCorner(MiniBar, 6)
    Utility:ApplyStroke(MiniBar, "Border", 1)
    Utility:AddShadow(MiniBar, 0.48)
    Utility:MakeDraggable(MiniBar, MiniBar)

    local MiniTitle = Utility:Create("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = string.upper(Name),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Theme = { TextColor3 = "Text" },
        ZIndex = 701,
        Parent = MiniBar
    })

    local MiniButtons = Utility:Create("Frame", {
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -84, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 701,
        Parent = MiniBar
    })
    Utility:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = MiniButtons
    })

    local MiniMaxButton = Utility:Create("TextButton", {
        Size = UDim2.new(0, 34, 0, 24),
        Text = "+",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Theme = { TextColor3 = "Text", BackgroundColor3 = "Panel" },
        AutoButtonColor = false,
        ZIndex = 702,
        Parent = MiniButtons
    })
    Utility:ApplyCorner(MiniMaxButton, 5)
    Utility:ApplyStroke(MiniMaxButton, "Border", 1)

    local MiniCloseButton = Utility:Create("TextButton", {
        Size = UDim2.new(0, 34, 0, 24),
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Theme = { TextColor3 = "Text", BackgroundColor3 = "Panel" },
        AutoButtonColor = false,
        ZIndex = 702,
        Parent = MiniButtons
    })
    Utility:ApplyCorner(MiniCloseButton, 5)
    Utility:ApplyStroke(MiniCloseButton, "Border", 1)

    function Window:Confirm(config)
        config = config or {}
        if self.IsDestroyed then
            return false
        end

        local timeout = ClampNumber(config.Timeout or 10, 3, 60)
        local title = tostring(config.Title or "Confirmation")
        local content = tostring(config.Content or "Continue?")
        local confirmText = tostring(config.ConfirmText or "Yes")
        local cancelText = tostring(config.CancelText or "No")

        if self.IsMinimized or self.IsHidden then
            self:Restore(true)
        end
        MainFrame.Visible = true

        local overlay = Utility:Create("Frame", {
            Name = "CenterConfirmOverlay",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 2600,
            Parent = MainFrame
        })
        Utility:ApplyCorner(overlay, 8)

        local card = Utility:Create("Frame", {
            Size = UDim2.fromOffset(390, 180),
            Position = UDim2.new(0.5, -195, 0.5, -90),
            Theme = { BackgroundColor3 = "Panel" },
            BackgroundTransparency = 1,
            ZIndex = 2601,
            Parent = overlay
        })
        Utility:ApplyCorner(card, 8)
        Utility:ApplyStroke(card, "Border", 1)
        Utility:AddShadow(card, 0.5)

        Utility:Create("TextLabel", {
            Size = UDim2.new(1, -36, 0, 22),
            Position = UDim2.new(0, 18, 0, 18),
            BackgroundTransparency = 1,
            Text = title,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Theme = { TextColor3 = "Text" },
            ZIndex = 2602,
            Parent = card
        })

        Utility:Create("TextLabel", {
            Size = UDim2.new(1, -36, 0, 48),
            Position = UDim2.new(0, 18, 0, 48),
            BackgroundTransparency = 1,
            Text = content,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Theme = { TextColor3 = "TextDark" },
            ZIndex = 2602,
            Parent = card
        })

        local barBack = Utility:Create("Frame", {
            Size = UDim2.new(1, -36, 0, 5),
            Position = UDim2.new(0, 18, 1, -62),
            Theme = { BackgroundColor3 = "Background" },
            ZIndex = 2602,
            Parent = card
        })
        Utility:ApplyCorner(barBack, 4)

        local barFill = Utility:Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            Theme = { BackgroundColor3 = "Accent" },
            ZIndex = 2603,
            Parent = barBack
        })
        Utility:ApplyCorner(barFill, 4)

        local buttonRow = Utility:Create("Frame", {
            Size = UDim2.new(1, -36, 0, 34),
            Position = UDim2.new(0, 18, 1, -46),
            BackgroundTransparency = 1,
            ZIndex = 2602,
            Parent = card
        })
        Utility:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            Parent = buttonRow
        })

        local noButton = Utility:Create("TextButton", {
            Size = UDim2.fromOffset(100, 30),
            Text = cancelText,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            AutoButtonColor = false,
            Theme = { BackgroundColor3 = "Background", TextColor3 = "TextDark" },
            ZIndex = 2603,
            Parent = buttonRow
        })
        Utility:ApplyCorner(noButton, 6)
        Utility:ApplyStroke(noButton, "Border", 1)

        local yesButton = Utility:Create("TextButton", {
            Size = UDim2.fromOffset(118, 30),
            Text = confirmText,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            AutoButtonColor = false,
            Theme = { BackgroundColor3 = "Accent", TextColor3 = "Text" },
            ZIndex = 2603,
            Parent = buttonRow
        })
        Utility:ApplyCorner(yesButton, 6)
        Utility:ApplyStroke(yesButton, "Accent", 1)

        local decided = false
        local result = false
        local function choose(value)
            if decided then
                return
            end
            decided = true
            result = value == true
        end

        yesButton.MouseButton1Click:Connect(function()
            choose(true)
        end)
        noButton.MouseButton1Click:Connect(function()
            choose(false)
        end)

        Utility:Tween(overlay, { BackgroundTransparency = 0.28 }, 0.16)
        Utility:Tween(card, { BackgroundTransparency = 0 }, 0.18)
        Utility:Tween(barFill, { Size = UDim2.new(0, 0, 1, 0) }, timeout, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

        local started = os.clock()
        while not decided and (os.clock() - started) < timeout do
            task.wait(0.05)
        end
        if not decided then
            choose(false)
        end

        Utility:Tween(card, { BackgroundTransparency = 1 }, 0.12)
        Utility:Tween(overlay, { BackgroundTransparency = 1 }, 0.12)
        task.wait(0.12)
        if overlay then
            overlay:Destroy()
        end

        return result
    end

    Window.IsMinimized = false
    Window.IsHidden = false

    function Window:Minimize(silent)
        if self.IsDestroyed or self.IsMinimized then
            return
        end
        self.SavedOpenSize = MainFrame.Size
        self.SavedOpenPosition = MainFrame.Position
        self.IsMinimized = true
        self.IsHidden = false
        self.IsToggled = false

        local miniWidth = math.clamp(math.floor(MainFrame.Size.X.Offset * 0.45), 260, 420)
        MiniBar.Size = UDim2.fromOffset(miniWidth, 34)
        MiniBar.Position = UDim2.new(
            MainFrame.Position.X.Scale,
            MainFrame.Position.X.Offset,
            MainFrame.Position.Y.Scale,
            MainFrame.Position.Y.Offset
        )
        if MainFrame and MainFrame.Parent then
            MainFrame.Visible = false
            MainFrame.BackgroundTransparency = 0
        end
        MiniBar.Visible = true
        MiniBar.BackgroundTransparency = 0.18
        Utility:Tween(MiniBar, { BackgroundTransparency = 0 }, 0.16)

        if not silent then
            self:Notify({
                Title = "Script Hidden",
                Content = "To open the script again, press " .. keyToText(self.ToggleKey) .. ".",
                Duration = 3.2
            })
        end
    end

    function Window:Restore(silent)
        if self.IsDestroyed then
            return
        end
        if not self.IsMinimized and not self.IsHidden then
            return
        end
        self.IsMinimized = false
        self.IsHidden = false
        self.IsToggled = true

        MainFrame.Visible = true
        MainFrame.Position = self.SavedOpenPosition or MainFrame.Position
        MainFrame.Size = UDim2.fromOffset(
            math.max(420, math.floor((self.SavedOpenSize and self.SavedOpenSize.X.Offset or defaultW) * 0.86)),
            56
        )
        MainFrame.BackgroundTransparency = 0.18
        Utility:Tween(MainFrame, {
            Size = self.SavedOpenSize or UDim2.fromOffset(defaultW, defaultH),
            BackgroundTransparency = 0
        }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        Utility:Tween(MiniBar, { BackgroundTransparency = 1 }, 0.14)
        task.delay(0.14, function()
            if MiniBar and MiniBar.Parent then
                MiniBar.Visible = false
                MiniBar.BackgroundTransparency = 0
            end
        end)

        if not silent then
            self:Notify({
                Title = "Window Opened",
                Content = "UI restored. Press " .. keyToText(self.ToggleKey) .. " to hide again.",
                Duration = 2.5
            })
        end
    end

    function Window:HideAll(silent)
        if self.IsDestroyed then
            return
        end
        self.SavedOpenSize = MainFrame.Size
        self.SavedOpenPosition = MainFrame.Position
        self.IsMinimized = false
        self.IsHidden = true
        self.IsToggled = false

        if MainFrame and MainFrame.Parent then
            MainFrame.Visible = false
            MainFrame.BackgroundTransparency = 0
        end
        if MiniBar and MiniBar.Parent then
            MiniBar.Visible = false
            MiniBar.BackgroundTransparency = 0
        end

        if not silent then
            self:Notify({
                Title = "Script Hidden",
                Content = "To open the script again, press " .. keyToText(self.ToggleKey) .. ".",
                Duration = 3.2
            })
        end
    end

    function Window:SetToggleKey(newKey)
        local resolved = NormalizeKeyCode(newKey, self.ToggleKey)
        if resolved then
            self.ToggleKey = resolved
            Library.Keybind = resolved
            return true
        end
        return false
    end

    function Window:SetSize(width, height)
        local w = ClampNumber(width, 520, 1400)
        local h = ClampNumber(height, 360, 920)
        self.SavedOpenSize = UDim2.fromOffset(w, h)
        if self.IsToggled then
            Utility:Tween(MainFrame, { Size = self.SavedOpenSize }, 0.25)
        end
    end

    function Window:SetSidebarWidth(value)
        local sidebarW = ClampNumber(value, 160, 360)
        Utility:Tween(Sidebar, { Size = UDim2.new(0, sidebarW, 1, 0) }, 0.24)
        Utility:Tween(ContentArea, {
            Size = UDim2.new(1, -sidebarW, 1, 0),
            Position = UDim2.new(0, sidebarW, 0, 0)
        }, 0.24)
    end

    function Window:SetUIScale(scale)
        UIScale.Scale = ClampNumber(scale, 0.7, 1.5)
    end

    function Window:SetTheme(themeName)
        if ThemeManager:SetTheme(themeName) then
            self.ThemeName = themeName
            self.Accent = ThemeManager:Get("Accent")
            return true
        end
        return false
    end

    function Window:SetAccent(color)
        if ThemeManager:SetAccent(color) then
            self.Accent = color
            return true
        end
        return false
    end

    function Window:ToggleVisible(forceState, silent)
        if self.IsDestroyed then
            return
        end
        local target = forceState
        if target == nil then
            target = not self.IsToggled
        end
        if target == self.IsToggled and ((target and not self.IsMinimized and not self.IsHidden) or (not target and (self.IsMinimized or self.IsHidden))) then
            return
        end

        if target then
            self:Restore(silent)
        else
            self:HideAll(silent)
        end
    end

    function Window:HideWithPrompt()
        self:HideAll(false)
    end

    function Window:Destroy()
        if self.IsDestroyed then
            return
        end
        self.IsDestroyed = true
        self.IsToggled = false
        spinning = false
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        if spinConn then
            pcall(function()
                spinConn:Disconnect()
            end)
        end
        if GUI then
            GUI:Destroy()
        end
    end

    track(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or Window.IsDestroyed then
            return
        end
        if input.KeyCode == Window.ToggleKey then
            Window:ToggleVisible(nil, false)
        end
    end))

    track(MinButton.MouseButton1Click:Connect(function()
        Window:Minimize(false)
    end))
    track(CloseButton.MouseButton1Click:Connect(function()
        Window:HideAll(false)
    end))
    track(MiniMaxButton.MouseButton1Click:Connect(function()
        Window:Restore(false)
    end))
    track(MiniCloseButton.MouseButton1Click:Connect(function()
        Window:HideAll(false)
    end))

    function Window:FinishLoading()
        if self.IsLoaded or self.IsDestroyed then
            return
        end
        self.IsLoaded = true
        spinning = false
        if spinConn then
            pcall(function() spinConn:Disconnect() end)
        end
        Utility:Tween(Spinner, { ImageTransparency = 1 }, 0.24)
        Utility:Tween(LoadTitleObj, { TextTransparency = 1 }, 0.24)
        task.wait(0.15)
        Utility:Tween(LoadingFrame, { BackgroundTransparency = 1 }, 0.34)
        task.wait(0.35)
        if LoadingFrame and LoadingFrame.Parent then
            LoadingFrame:Destroy()
        end
    end

    task.delay(12, function()
        if Window and not Window.IsDestroyed then
            Window:FinishLoading()
        end
    end)

    -- ==========================================================================
    -- TAB SYSTEM
    -- ==========================================================================

    function Window:CreateTab(name, iconId)
        local Tab = { Elements = {}, Name = tostring(name or "Tab") }

        local Btn = Utility:Create("TextButton", {
            Size = UDim2.new(1, -20, 0, 35),
            BackgroundTransparency = 1,
            Text = "",
            Parent = TabContainer
        })

        local BtnBg = Utility:Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Theme = { BackgroundColor3 = "Background" },
            Parent = Btn
        })
        Utility:ApplyCorner(BtnBg, 6)

        local Icon = Utility:Create("ImageLabel", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 15, 0.5, -8),
            BackgroundTransparency = 1,
            Image = iconId or "rbxassetid://10888331510",
            Theme = { ImageColor3 = "TextDark" },
            Parent = BtnBg
        })

        local Label = Utility:Create("TextLabel", {
            Size = UDim2.new(1, -45, 1, 0),
            Position = UDim2.new(0, 40, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(name or "Tab"),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Theme = { TextColor3 = "TextDark" },
            Parent = BtnBg
        })

        local Indicator = Utility:Create("Frame", {
            Size = UDim2.new(0, 3, 0, 0),
            Position = UDim2.new(0, 5, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Theme = { BackgroundColor3 = "Accent" },
            Parent = BtnBg
        })
        Utility:ApplyCorner(Indicator, 2)

        local Page = Utility:Create("ScrollingFrame", {
            Name = tostring(name or "Tab") .. "_Page",
            Size = UDim2.new(1, -40, 1, -50),
            Position = UDim2.new(0, 20, 0, 20),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            Theme = { ScrollBarImageColor3 = "BorderHighlight" },
            Visible = false,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Parent = ContentArea
        })

        local PageLayout = Utility:Create("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Page
        })
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 20)
        end)

        Btn.MouseEnter:Connect(function()
            if Window.CurrentTab ~= Tab then
                Utility:Tween(BtnBg, { BackgroundTransparency = 0 }, 0.16)
                Utility:Tween(Label, { TextColor3 = ThemeManager:Get("Text") }, 0.16)
            end
        end)
        Btn.MouseLeave:Connect(function()
            if Window.CurrentTab ~= Tab then
                Utility:Tween(BtnBg, { BackgroundTransparency = 1 }, 0.16)
                Utility:Tween(Label, { TextColor3 = ThemeManager:Get("TextDark") }, 0.16)
            end
        end)

        function Tab:Show()
            if Window.CurrentTab then
                local old = Window.CurrentTab
                old.Page.Visible = false
                Utility:Tween(old.BtnBg, { BackgroundTransparency = 1 }, 0.16)
                Utility:Tween(old.Label, { TextColor3 = ThemeManager:Get("TextDark") }, 0.16)
                Utility:Tween(old.Icon, { ImageColor3 = ThemeManager:Get("TextDark") }, 0.16)
                Utility:Tween(old.Indicator, { Size = UDim2.new(0, 3, 0, 0) }, 0.16)
            end
            Window.CurrentTab = self
            Page.Visible = true
            Utility:Tween(BtnBg, { BackgroundTransparency = 0 }, 0.16)
            Utility:Tween(Label, { TextColor3 = ThemeManager:Get("Text") }, 0.16)
            Utility:Tween(Icon, { ImageColor3 = ThemeManager:Get("Accent") }, 0.16)
            Utility:Tween(Indicator, { Size = UDim2.new(0, 3, 0, 16) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end

        Btn.MouseButton1Click:Connect(function()
            Tab:Show()
        end)

        if not Window.CurrentTab then
            Tab:Show()
        end

        Tab.BtnBg = BtnBg
        Tab.Label = Label
        Tab.Icon = Icon
        Tab.Indicator = Indicator
        Tab.Page = Page

        table.insert(Window.Tabs, Tab)

        -- ----------------------------------------------------------------------
        -- ELEMENT FACTORY
        -- ----------------------------------------------------------------------

        function Tab:CreateSection(title)
            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 25),
                BackgroundTransparency = 1,
                Parent = Page
            })

            Utility:Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = string.upper(tostring(title or "Section")),
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Accent" },
                Parent = frame
            })

            Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, 0),
                BorderSizePixel = 0,
                Theme = { BackgroundColor3 = "Border" },
                Parent = frame
            })
        end

        function Tab:CreateButton(cfg)
            cfg = cfg or {}
            local btnFrame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 45),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(btnFrame, 6)
            local stroke = Utility:ApplyStroke(btnFrame, "Border", 1)

            local btn = Utility:Create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = btnFrame
            })

            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Button"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = btnFrame
            })

            local icon = Utility:Create("ImageLabel", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -30, 0.5, -8),
                BackgroundTransparency = 1,
                Image = "rbxassetid://10888331510",
                Theme = { ImageColor3 = "TextDark" },
                Parent = btnFrame
            })

            btn.MouseEnter:Connect(function()
                Utility:Tween(btnFrame, { BackgroundColor3 = ThemeManager:Get("PanelHover") }, 0.16)
                Utility:Tween(stroke, { Color = ThemeManager:Get("Accent") }, 0.16)
                Utility:Tween(icon, {
                    Position = UDim2.new(1, -25, 0.5, -8),
                    ImageColor3 = ThemeManager:Get("Accent")
                }, 0.16)
            end)
            btn.MouseLeave:Connect(function()
                Utility:Tween(btnFrame, { BackgroundColor3 = ThemeManager:Get("Panel") }, 0.16)
                Utility:Tween(stroke, { Color = ThemeManager:Get("Border") }, 0.16)
                Utility:Tween(icon, {
                    Position = UDim2.new(1, -30, 0.5, -8),
                    ImageColor3 = ThemeManager:Get("TextDark")
                }, 0.16)
            end)
            btn.MouseButton1Click:Connect(function()
                Utility:Tween(btnFrame, { Size = UDim2.new(0.985, 0, 0, 43) }, 0.08)
                task.wait(0.08)
                Utility:Tween(btnFrame, { Size = UDim2.new(1, 0, 0, 45) }, 0.08)
                if cfg.Callback then
                    cfg.Callback()
                end
            end)
        end

        function Tab:CreateToggle(cfg)
            cfg = cfg or {}
            local flag = cfg.Flag or cfg.Name or ("Toggle_" .. tostring(#Tab.Elements + 1))
            local default = cfg.Default == true
            SaveManager.Flags[flag] = default

            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 45),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(frame, 6)
            Utility:ApplyStroke(frame, "Border", 1)

            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Toggle"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = frame
            })

            local pill = Utility:Create("Frame", {
                Size = UDim2.new(0, 40, 0, 20),
                Position = UDim2.new(1, -55, 0.5, -10),
                Theme = { BackgroundColor3 = default and "Accent" or "Background" },
                Parent = frame
            })
            Utility:ApplyCorner(pill, 100)
            local pillStroke = Utility:ApplyStroke(pill, default and "Accent" or "Border", 1)

            local circle = Utility:Create("Frame", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, default and 23 or 3, 0.5, -7),
                Theme = { BackgroundColor3 = default and "Background" or "TextDark" },
                Parent = pill
            })
            Utility:ApplyCorner(circle, 100)

            local button = Utility:Create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = frame
            })

            local obj = { Value = default }
            function obj:SetValue(val)
                self.Value = val == true
                SaveManager.Flags[flag] = self.Value
                Utility:Tween(pill, { BackgroundColor3 = ThemeManager:Get(self.Value and "Accent" or "Background") }, 0.16)
                Utility:Tween(pillStroke, { Color = ThemeManager:Get(self.Value and "Accent" or "Border") }, 0.16)
                Utility:Tween(circle, {
                    Position = UDim2.new(0, self.Value and 23 or 3, 0.5, -7),
                    BackgroundColor3 = ThemeManager:Get(self.Value and "Background" or "TextDark")
                }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                if cfg.Callback then
                    cfg.Callback(self.Value)
                end
            end
            button.MouseButton1Click:Connect(function()
                obj:SetValue(not obj.Value)
            end)

            SaveManager.Options[flag] = obj
            if default then
                obj:SetValue(true)
            end
            return obj
        end

        function Tab:CreateSlider(cfg)
            cfg = cfg or {}
            local flag = cfg.Flag or cfg.Name or ("Slider_" .. tostring(#Tab.Elements + 1))
            local min = tonumber(cfg.Min) or 0
            local max = tonumber(cfg.Max) or 100
            local decimals = tonumber(cfg.Decimals) or 0
            local default = ClampNumber(cfg.Default or min, min, max)
            SaveManager.Flags[flag] = default

            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 60),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(frame, 6)
            Utility:ApplyStroke(frame, "Border", 1)

            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -65, 0, 30),
                Position = UDim2.new(0, 15, 0, 5),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Slider"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = frame
            })

            local valueBoxBg = Utility:Create("Frame", {
                Size = UDim2.new(0, 52, 0, 20),
                Position = UDim2.new(1, -63, 0, 10),
                Theme = { BackgroundColor3 = "Background" },
                Parent = frame
            })
            Utility:ApplyCorner(valueBoxBg, 4)
            Utility:ApplyStroke(valueBoxBg, "Border", 1)

            local valueBox = Utility:Create("TextBox", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(default),
                ClearTextOnFocus = false,
                Font = Enum.Font.Code,
                TextSize = 10,
                Theme = { TextColor3 = "Accent" },
                Parent = valueBoxBg
            })

            local trackBtn = Utility:Create("TextButton", {
                Size = UDim2.new(1, -30, 0, 20),
                Position = UDim2.new(0, 15, 0, 35),
                BackgroundTransparency = 1,
                Text = "",
                Parent = frame
            })

            local track = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 4),
                Position = UDim2.new(0, 0, 0.5, -2),
                Theme = { BackgroundColor3 = "Background" },
                Parent = trackBtn
            })
            Utility:ApplyCorner(track, 2)
            Utility:ApplyStroke(track, "Border", 1)

            local fill = Utility:Create("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                Theme = { BackgroundColor3 = "Accent" },
                Parent = track
            })
            Utility:ApplyCorner(fill, 2)

            local node = Utility:Create("Frame", {
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(1, -6, 0.5, -6),
                Theme = { BackgroundColor3 = "Text" },
                Parent = fill
            })
            Utility:ApplyCorner(node, 100)

            local obj = { Value = default }

            local function formatVal(v)
                return string.format("%." .. tostring(decimals) .. "f", v)
            end

            function obj:SetValue(v)
                local value = ClampNumber(v, min, max)
                if decimals == 0 then
                    value = math.floor(value + 0.5)
                end
                self.Value = value
                SaveManager.Flags[flag] = value
                valueBox.Text = formatVal(value)
                local pct = (value - min) / (max - min)
                Utility:Tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.08)
                if cfg.Callback then
                    cfg.Callback(value)
                end
            end

            local dragging = false
            local function updateDrag(input)
                local pct = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local value = min + ((max - min) * pct)
                obj:SetValue(value)
            end

            trackBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateDrag(input)
                    Utility:Tween(node, { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -8, 0.5, -8) }, 0.12)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
                    dragging = false
                    Utility:Tween(node, { Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -6, 0.5, -6) }, 0.12)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateDrag(input)
                end
            end)
            valueBox.FocusLost:Connect(function()
                local parsed = tonumber(valueBox.Text)
                if parsed then
                    obj:SetValue(parsed)
                else
                    valueBox.Text = formatVal(obj.Value)
                end
            end)

            SaveManager.Options[flag] = obj
            obj:SetValue(default)
            return obj
        end

        function Tab:CreateInput(cfg)
            cfg = cfg or {}
            local flag = cfg.Flag or cfg.Name or ("Input_" .. tostring(#Tab.Elements + 1))
            local default = tostring(cfg.Default or "")
            SaveManager.Flags[flag] = default

            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(frame, 6)
            Utility:ApplyStroke(frame, "Border", 1)

            Utility:Create("TextLabel", {
                Size = UDim2.new(0, 170, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Input"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = frame
            })

            local boxBg = Utility:Create("Frame", {
                Size = UDim2.new(1, -200, 0, 30),
                Position = UDim2.new(0, 190, 0.5, -15),
                Theme = { BackgroundColor3 = "Background" },
                Parent = frame
            })
            Utility:ApplyCorner(boxBg, 4)
            local boxStroke = Utility:ApplyStroke(boxBg, "Border", 1)

            local box = Utility:Create("TextBox", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = default,
                PlaceholderText = tostring(cfg.Placeholder or "Type here..."),
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                Theme = { TextColor3 = "Text" },
                Parent = boxBg
            })

            local obj = { Value = default }
            box.Focused:Connect(function()
                Utility:Tween(boxStroke, { Color = ThemeManager:Get("Accent") }, 0.16)
            end)
            box.FocusLost:Connect(function()
                Utility:Tween(boxStroke, { Color = ThemeManager:Get("Border") }, 0.16)
                obj.Value = tostring(box.Text or "")
                SaveManager.Flags[flag] = obj.Value
                if cfg.Callback then
                    cfg.Callback(obj.Value)
                end
            end)

            function obj:SetValue(v)
                obj.Value = tostring(v or "")
                box.Text = obj.Value
                SaveManager.Flags[flag] = obj.Value
                if cfg.Callback then
                    cfg.Callback(obj.Value)
                end
            end

            SaveManager.Options[flag] = obj
            return obj
        end

        function Tab:CreateDropdown(cfg)
            cfg = cfg or {}
            local options = cfg.Options or {}
            local flag = cfg.Flag or cfg.Name or ("Dropdown_" .. tostring(#Tab.Elements + 1))
            local default = tostring(cfg.Default or options[1] or "None")
            SaveManager.Flags[flag] = default

            local holder = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 45),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(holder, 6)
            Utility:ApplyStroke(holder, "Border", 1)

            Utility:Create("TextLabel", {
                Size = UDim2.new(0, 170, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Dropdown"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = holder
            })

            local selectorBg = Utility:Create("Frame", {
                Size = UDim2.new(1, -200, 0, 30),
                Position = UDim2.new(0, 190, 0.5, -15),
                Theme = { BackgroundColor3 = "Background" },
                ZIndex = 20,
                Parent = holder
            })
            Utility:ApplyCorner(selectorBg, 4)
            local selectorStroke = Utility:ApplyStroke(selectorBg, "Border", 1)

            local button = Utility:Create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 21,
                Parent = selectorBg
            })

            local valueLabel = Utility:Create("TextLabel", {
                Size = UDim2.new(1, -25, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = default,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                ZIndex = 22,
                Parent = selectorBg
            })

            local arrow = Utility:Create("TextLabel", {
                Size = UDim2.new(0, 15, 1, 0),
                Position = UDim2.new(1, -18, 0, 0),
                BackgroundTransparency = 1,
                Text = "v",
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Center,
                Theme = { TextColor3 = "TextDark" },
                ZIndex = 22,
                Parent = selectorBg
            })

            local listFrame = Utility:Create("ScrollingFrame", {
                Size = UDim2.fromOffset(140, 0),
                Position = UDim2.fromOffset(0, 0),
                ClipsDescendants = true,
                Visible = false,
                ScrollBarThickness = 2,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                Theme = {
                    BackgroundColor3 = "Panel",
                    ScrollBarImageColor3 = "BorderHighlight"
                },
                ZIndex = 120,
                Parent = GUI
            })
            Utility:ApplyCorner(listFrame, 4)
            Utility:ApplyStroke(listFrame, "Border", 1)
            local listLayout = Utility:Create("UIListLayout", {
                Padding = UDim.new(0, 3),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = listFrame
            })
            listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
            end)
            Utility:Create("UIPadding", {
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                Parent = listFrame
            })

            local opened = false
            local dropdownObj = { Value = default }

            local function updatePopupPosition()
                local selectorAbsPos = selectorBg.AbsolutePosition
                local selectorAbsSize = selectorBg.AbsoluteSize
                listFrame.Position = UDim2.fromOffset(
                    selectorAbsPos.X,
                    selectorAbsPos.Y + selectorAbsSize.Y + 2
                )
            end

            local function refreshHolderHeight()
                local expected = (listLayout.AbsoluteContentSize.Y > 0 and (listLayout.AbsoluteContentSize.Y + 12))
                    or (math.max(1, #options) * 27 + 10)
                local target = opened and math.min(180, expected) or 0
                local width = math.max(90, selectorBg.AbsoluteSize.X)
                updatePopupPosition()
                Utility:Tween(listFrame, { Size = UDim2.fromOffset(width, target) }, 0.16)
            end

            local function setValue(v)
                local value = tostring(v or "")
                dropdownObj.Value = value
                valueLabel.Text = value
                SaveManager.Flags[flag] = value
                if cfg.Callback then
                    cfg.Callback(value)
                end
            end

            function dropdownObj:SetValue(v)
                setValue(v)
            end

            local function rebuildOptions(newOptions)
                for _, child in ipairs(listFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                options = newOptions or options

                for _, option in ipairs(options) do
                    local text = tostring(option)
                    local item = Utility:Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundTransparency = 1,
                        Text = "",
                        ZIndex = 122,
                        Parent = listFrame
                    })
                    local bg = Utility:Create("Frame", {
                        Size = UDim2.new(1, 0, 1, 0),
                        Theme = { BackgroundColor3 = "Background" },
                        ZIndex = 123,
                        Parent = item
                    })
                    Utility:ApplyCorner(bg, 4)
                    Utility:Create("TextLabel", {
                        Size = UDim2.new(1, -12, 1, 0),
                        Position = UDim2.new(0, 6, 0, 0),
                        BackgroundTransparency = 1,
                        Text = text,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Theme = { TextColor3 = "Text" },
                        ZIndex = 124,
                        Parent = bg
                    })
                    item.MouseEnter:Connect(function()
                        Utility:Tween(bg, { BackgroundColor3 = ThemeManager:Get("PanelHover") }, 0.12)
                    end)
                    item.MouseLeave:Connect(function()
                        Utility:Tween(bg, { BackgroundColor3 = ThemeManager:Get("Background") }, 0.12)
                    end)
                    item.MouseButton1Click:Connect(function()
                        setValue(text)
                        opened = false
                        arrow.Text = "v"
                        refreshHolderHeight()
                        Utility:Tween(selectorStroke, { Color = ThemeManager:Get("Border") }, 0.14)
                        task.delay(0.18, function()
                            if listFrame and listFrame.Parent then
                                listFrame.Visible = false
                            end
                        end)
                    end)
                end
                listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
                refreshHolderHeight()
            end

            function dropdownObj:SetOptions(newOptions)
                rebuildOptions(newOptions or {})
            end

            local function isPointInside(guiObj, position)
                local abs = guiObj.AbsolutePosition
                local size = guiObj.AbsoluteSize
                return position.X >= abs.X and position.X <= (abs.X + size.X)
                    and position.Y >= abs.Y and position.Y <= (abs.Y + size.Y)
            end

            local function closeDropdown(immediate)
                if not opened and not listFrame.Visible then
                    return
                end
                opened = false
                arrow.Text = "v"
                Utility:Tween(selectorStroke, { Color = ThemeManager:Get("Border") }, 0.14)
                if immediate then
                    listFrame.Visible = false
                    listFrame.Size = UDim2.fromOffset(math.max(90, selectorBg.AbsoluteSize.X), 0)
                    return
                end
                refreshHolderHeight()
                task.delay(0.18, function()
                    if listFrame and listFrame.Parent and not opened then
                        listFrame.Visible = false
                    end
                end)
            end

            button.MouseButton1Click:Connect(function()
                if not MainFrame.Visible then
                    return
                end
                opened = not opened
                if opened then
                    updatePopupPosition()
                    listFrame.Visible = true
                    arrow.Text = "^"
                    Utility:Tween(selectorStroke, { Color = ThemeManager:Get("Accent") }, 0.14)
                    refreshHolderHeight()
                else
                    closeDropdown(false)
                end
            end)

            selectorBg:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                if opened and listFrame.Visible then
                    updatePopupPosition()
                end
            end)
            selectorBg:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if opened and listFrame.Visible then
                    refreshHolderHeight()
                end
            end)
            MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if not MainFrame.Visible then
                    closeDropdown(true)
                end
            end)
            UserInputService.InputBegan:Connect(function(input)
                if not opened or not listFrame.Visible then
                    return
                end
                local userInputType = input.UserInputType
                if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local pos = input.Position
                if not isPointInside(selectorBg, pos) and not isPointInside(listFrame, pos) then
                    closeDropdown(false)
                end
            end)

            rebuildOptions(options)
            setValue(default)
            SaveManager.Options[flag] = dropdownObj
            return dropdownObj
        end

        function Tab:CreateKeybind(cfg)
            cfg = cfg or {}
            local flag = cfg.Flag or cfg.Name or ("Keybind_" .. tostring(#Tab.Elements + 1))
            local defaultKey = NormalizeKeyCode(cfg.Default or Enum.KeyCode.K, Enum.KeyCode.K)
            SaveManager.Flags[flag] = defaultKey.Name

            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 45),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(frame, 6)
            Utility:ApplyStroke(frame, "Border", 1)

            Utility:Create("TextLabel", {
                Size = UDim2.new(0, 170, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(cfg.Name or "Keybind"),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = frame
            })

            local keyBtn = Utility:Create("TextButton", {
                Size = UDim2.new(0, 130, 0, 28),
                Position = UDim2.new(1, -145, 0.5, -14),
                Text = defaultKey.Name,
                Font = Enum.Font.Code,
                TextSize = 12,
                Theme = { TextColor3 = "Accent", BackgroundColor3 = "Background" },
                AutoButtonColor = false,
                Parent = frame
            })
            Utility:ApplyCorner(keyBtn, 4)
            local stroke = Utility:ApplyStroke(keyBtn, "Border", 1)

            local waiting = false
            local obj = { Value = defaultKey }

            local function setKey(newKey)
                local resolved = NormalizeKeyCode(newKey, obj.Value)
                obj.Value = resolved
                keyBtn.Text = resolved.Name
                SaveManager.Flags[flag] = resolved.Name
                if cfg.Callback then
                    cfg.Callback(resolved)
                end
            end

            function obj:SetValue(v)
                setKey(v)
            end

            keyBtn.MouseButton1Click:Connect(function()
                waiting = true
                keyBtn.Text = "PRESS KEY..."
                Utility:Tween(stroke, { Color = ThemeManager:Get("Accent") }, 0.12)
            end)

            track(UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe or not waiting then
                    return
                end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    waiting = false
                    Utility:Tween(stroke, { Color = ThemeManager:Get("Border") }, 0.12)
                    setKey(input.KeyCode)
                end
            end))

            SaveManager.Options[flag] = obj
            return obj
        end

        function Tab:CreateLabel(text)
            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Parent = Page
            })
            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(text or ""),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "TextDark" },
                Parent = frame
            })
        end

        function Tab:CreateParagraph(cfg)
            cfg = cfg or {}
            local title = tostring(cfg.Title or "Info")
            local content = tostring(cfg.Content or "")
            local height = math.max(56, Utility:GetTextBounds(content, Enum.Font.Gotham, 11, Vector2.new(800, 1000)).Y + 34)
            local frame = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, height),
                Theme = { BackgroundColor3 = "Panel" },
                Parent = Page
            })
            Utility:ApplyCorner(frame, 6)
            Utility:ApplyStroke(frame, "Border", 1)
            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -20, 0, 16),
                Position = UDim2.new(0, 10, 0, 8),
                BackgroundTransparency = 1,
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Theme = { TextColor3 = "Text" },
                Parent = frame
            })
            Utility:Create("TextLabel", {
                Size = UDim2.new(1, -20, 1, -30),
                Position = UDim2.new(0, 10, 0, 24),
                BackgroundTransparency = 1,
                Text = content,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Theme = { TextColor3 = "TextDark" },
                Parent = frame
            })
        end

        function Tab:CreateSpacer(height)
            Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, ClampNumber(height or 8, 2, 80)),
                BackgroundTransparency = 1,
                Parent = Page
            })
        end

        function Tab:CreateDashboardStats(stats)
            local list = stats or {}
            local count = #list
            if count <= 0 then
                return
            end

            local cols = count == 1 and 1 or 2
            local rows = math.ceil(count / cols)
            local height = rows * 78

            local container = Utility:Create("Frame", {
                Size = UDim2.new(1, 0, 0, height),
                BackgroundTransparency = 1,
                Parent = Page
            })
            local grid = Utility:Create("UIGridLayout", {
                CellPadding = UDim2.new(0, 10, 0, 10),
                CellSize = UDim2.new(1 / cols, -((cols == 1) and 0 or 5), 0, 68),
                Parent = container
            })
            grid.FillDirectionMaxCells = cols

            for _, stat in ipairs(list) do
                local card = Utility:Create("Frame", {
                    Theme = { BackgroundColor3 = "Panel" },
                    Parent = container
                })
                Utility:ApplyCorner(card, 8)
                Utility:ApplyStroke(card, "Border", 1)

                Utility:Create("TextLabel", {
                    Size = UDim2.new(1, -20, 0, 16),
                    Position = UDim2.new(0, 10, 0, 8),
                    BackgroundTransparency = 1,
                    Text = string.upper(tostring(stat.Title or "STAT")),
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Theme = { TextColor3 = "TextDark" },
                    Parent = card
                })

                local valueLabel = Utility:Create("TextLabel", {
                    Size = UDim2.new(1, -20, 0, 30),
                    Position = UDim2.new(0, 10, 0, 30),
                    BackgroundTransparency = 1,
                    Text = tostring(stat.Value or "..."),
                    Font = Enum.Font.GothamBold,
                    TextSize = 18,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Theme = { TextColor3 = "Text" },
                    Parent = card
                })

                if stat.UpdateHook then
                    task.spawn(function()
                        while card.Parent and not Window.IsDestroyed do
                            local ok, value = pcall(stat.UpdateHook)
                            if ok and value ~= nil then
                                valueLabel.Text = tostring(value)
                            end
                            task.wait(1)
                        end
                    end)
                end
            end
        end

        return Tab
    end

    local function buildDefaultConfigTab()
        local tab = Window:CreateTab("Config", "rbxassetid://6031280882")
        Window.ConfigTab = tab

        tab:CreateSection("Visual")
        local themeDropdown = tab:CreateDropdown({
            Name = "Theme Preset",
            Flag = "__lib_theme_preset",
            Options = ThemeManager.ThemeOrder,
            Default = ThemeManager.Current,
            Callback = function(theme)
                Window:SetTheme(theme)
            end
        })

        local accent = ThemeManager:Get("Accent")
        local rSlider, gSlider, bSlider
        local function applyAccentFromSliders()
            if not rSlider or not gSlider or not bSlider then
                return
            end
            local color = Color3.fromRGB(
                math.floor(rSlider.Value + 0.5),
                math.floor(gSlider.Value + 0.5),
                math.floor(bSlider.Value + 0.5)
            )
            Window:SetAccent(color)
        end

        rSlider = tab:CreateSlider({
            Name = "Accent Red",
            Flag = "__lib_accent_r",
            Min = 0,
            Max = 255,
            Default = math.floor(accent.R * 255 + 0.5),
            Callback = applyAccentFromSliders
        })
        gSlider = tab:CreateSlider({
            Name = "Accent Green",
            Flag = "__lib_accent_g",
            Min = 0,
            Max = 255,
            Default = math.floor(accent.G * 255 + 0.5),
            Callback = applyAccentFromSliders
        })
        bSlider = tab:CreateSlider({
            Name = "Accent Blue",
            Flag = "__lib_accent_b",
            Min = 0,
            Max = 255,
            Default = math.floor(accent.B * 255 + 0.5),
            Callback = applyAccentFromSliders
        })

        tab:CreateSection("Window")
        local keyInput = tab:CreateInput({
            Name = "Open/Close Key",
            Flag = "__lib_toggle_key",
            Default = Window.ToggleKey.Name,
            Placeholder = "Example: K"
        })

        tab:CreateButton({
            Name = "Apply Toggle Key",
            Callback = function()
                local resolved = NormalizeKeyCode(keyInput.Value, Window.ToggleKey)
                Window:SetToggleKey(resolved)
                keyInput:SetValue(resolved.Name)
                Window:Notify({
                    Title = "Key Updated",
                    Content = "New toggle key: " .. resolved.Name,
                    Duration = 2.5
                })
            end
        })

        local widthSlider = tab:CreateSlider({
            Name = "Window Width",
            Flag = "__lib_window_width",
            Min = 520,
            Max = 1400,
            Default = defaultW,
            Callback = function(v)
                Window:SetSize(v, MainFrame.Size.Y.Offset)
            end
        })
        local heightSlider = tab:CreateSlider({
            Name = "Window Height",
            Flag = "__lib_window_height",
            Min = 360,
            Max = 920,
            Default = defaultH,
            Callback = function(v)
                Window:SetSize(MainFrame.Size.X.Offset, v)
            end
        })
        local sidebarSlider = tab:CreateSlider({
            Name = "Sidebar Width",
            Flag = "__lib_sidebar_width",
            Min = 160,
            Max = 360,
            Default = defaultSidebar,
            Callback = function(v)
                Window:SetSidebarWidth(v)
            end
        })
        tab:CreateSlider({
            Name = "UI Scale",
            Flag = "__lib_ui_scale",
            Min = 70,
            Max = 150,
            Default = math.floor(defaultScale * 100),
            Callback = function(v)
                Window:SetUIScale(v / 100)
            end
        })

        tab:CreateToggle({
            Name = "Enable Notifications",
            Flag = "__lib_enable_notifs",
            Default = true,
            Callback = function(v)
                Window.NotificationsEnabled = v == true
            end
        })

        tab:CreateButton({
            Name = "Hide Window (Animated)",
            Callback = function()
                Window:HideWithPrompt()
            end
        })

        tab:CreateButton({
            Name = "Reset Window Layout",
            Callback = function()
                themeDropdown:SetValue("Default")
                Window:SetTheme("Default")
                Window:SetAccent(ThemeManager:Get("Accent"))
                rSlider:SetValue(255)
                gSlider:SetValue(255)
                bSlider:SetValue(255)
                widthSlider:SetValue(800)
                heightSlider:SetValue(500)
                sidebarSlider:SetValue(200)
                Window:SetUIScale(1)
                keyInput:SetValue("K")
                Window:SetToggleKey(Enum.KeyCode.K)
                Window:Notify({
                    Title = "Layout Reset",
                    Content = "Theme, size, key and accent were reset.",
                    Duration = 2.8
                })
            end
        })

        tab:CreateSection("Script Control")
        tab:CreateButton({
            Name = "Save UI Config",
            Callback = function()
                SaveManager:Save("ui_default")
                Window:Notify({
                    Title = "Config Saved",
                    Content = "UI config saved to " .. tostring(SaveManager.Folder) .. "/configs/ui_default.json",
                    Duration = 3
                })
            end
        })
        tab:CreateButton({
            Name = "Load UI Config",
            Callback = function()
                local ok = SaveManager:Load("ui_default")
                Window:Notify({
                    Title = ok and "Config Loaded" or "Config Missing",
                    Content = ok and "Loaded ui_default successfully." or "ui_default.json was not found.",
                    Duration = 3
                })
            end
        })
        tab:CreateButton({
            Name = "Kill Script (Destroy UI)",
            Callback = function()
                Window:Notify({
                    Title = "Script Terminated",
                    Content = "UI destroyed by user request.",
                    Duration = 1.8
                })
                task.delay(0.2, function()
                    Window:Destroy()
                end)
            end
        })
        tab:CreateLabel("Use this panel in any script built with this library.")
    end

    if Settings.DisableDefaultConfig ~= true then
        buildDefaultConfigTab()
    end

    table.insert(self.Windows, Window)
    self.ActiveWindow = Window
    return Window
end

return Library
