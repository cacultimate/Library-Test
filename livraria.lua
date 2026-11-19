--!strict
--[[
    CAC Ultimate UI library (livraria.lua)
    Version: 7.0.0 (B "Lobby": square black window, block city backdrop, type does the hierarchy)
    Public API: identical to 6.x (see lib_contract.md in the redesign folder). Additions are optional.
    Executor note: top-level locals stay far below 200; state lives in tables.
    UI text: English only.
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local Env = {
    ProtectGui = protectgui or (syn and syn.protect_gui) or function() end,
    isfolder = isfolder or function() return false end,
    makefolder = makefolder or function() end,
    isfile = isfile or function() return false end,
    readfile = readfile or function() return "{}" end,
    writefile = writefile or function() end,
    delfile = delfile or function() end,
    -- survives a second run of the script (executor globals first, Roblox shared otherwise)
    Shared = (function()
        local ok, genv = pcall(function()
            return getgenv and getgenv()
        end)
        return (ok and type(genv) == "table") and genv or shared
    end)(),
}

-- ==============================================================================
-- 1) TOKENS (B geometry at the contract window 800 x 500, before UIScale)
-- ==============================================================================

local Tokens = {
    Space = { S1 = 2, S2 = 4, S3 = 8, S4 = 12, S5 = 14, S6 = 16, S7 = 20, S8 = 24, S9 = 32 },
    Size = {
        TopBand = 48, Item = 36, SubItem = 26, ItemCompact = 44, SubItemCompact = 36,
        Row = 34, RowCompact = 44, Check = 26, CheckCompact = 36,
        SliderRow = 56, SliderRowCompact = 60, -- the 6.x two-line slider until the B rows land
        Field = 26, FieldCompact = 36, SmallButton = 28, Hit = 28, HitCompact = 44,
        ContentMax = 640, Toast = 300, MiniBar = 34, MiniBarCompact = 44, Chip = 44,
        Logo = 22, Glyph = 16, Chrome = 14,
    },
    B = {
        ContentY = 52, InsetRight = 24, InsetBottom = 16, ListBottom = 44, SidebarGap = 20,
        StackBelow = 420, DrawerBelow = 600, Line = 1.5, EdgeTransparency = 0.6,
    },
    Radius = { Window = 0, Block = 0, Control = 0, Chip = 2, Bar = 0 },
    FontFamily = { Sans = "rbxasset://fonts/families/GothamSSm.json" },
    Text = {
        Dialog = 20, Title = 18, Section = 15, Label = 14, Value = 14, Small = 13, Body = 13, Key = 13,
        Caption = 12, StatTitle = 11, Version = 11,
        -- names the 6.x and reused component code still read
        Wordmark = 18, PageTitle = 18, ModalTitle = 20, Status = 12, StatValue = 15, Tiny = 12,
    },
    Z = {
        -- ScreenGui children
        Main = 10, ActionBar = 11, MiniBar = 12, Reopen = 13, Overlay = 20, Tooltip = 25, Toasts = 30,
        -- MainFrame children
        Backdrop = 1, Fade = 2, Sidebar = 3, Content = 3, Band = 4, DrawerScrim = 6, Drawer = 7, Loading = 8,
        Palette = 10, Modal = 12, Veil = 40,
    },
    Asset = {
        DefaultIcon = "rbxassetid://10888331510",
        ConfigIcon = "rbxassetid://6031280882",
    },
    Limits = {
        WidthMin = 520, WidthMax = 1400, HeightMin = 360, HeightMax = 920,
        SidebarMin = 160, SidebarMax = 360, ScaleMin = 0.7, ScaleMax = 1.5,
        DrawFloor = 0.9, PhoneShortSide = 520,
    },
    Version = "v6.2.0",
}

-- ==============================================================================
-- 2) MOTION
-- ==============================================================================

local Motion = {
    -- legacy numbers (6.x kept these names; internal code may still read them)
    Tap = 0.08, Fast = 0.14, Normal = 0.2, Smooth = 0.28, Slow = 0.36,
    Style = Enum.EasingStyle.Quint,
    Reduced = false,
    SystemReduced = false,
    UserReduced = false,
    Running = {},
    Goals = setmetatable({}, { __mode = "k" }), -- tween -> target props, so a fader scan reads where a tween ends
    Info = {
        Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Release = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        State = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Enter = TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        EnterLarge = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Exit = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        Fade = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Jump = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Resize = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Scrim = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Backdrop = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Star = TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
    },
}

-- token: a name from Motion.Info, "Move" (needs px), a number (Linear seconds) or a TweenInfo
function Motion:GetInfo(token, px)
    if type(token) == "number" then
        -- timers (confirm countdown line) are information, not motion: never shortened
        return TweenInfo.new(math.max(token, 0), Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    end
    local info
    if typeof(token) == "TweenInfo" then
        info = token
    elseif token == "Move" then
        local d = math.clamp(0.12 + 0.012 * math.sqrt(math.abs(tonumber(px) or 0)), 0.15, 0.40)
        info = TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    else
        info = self.Info[token] or self.Info.Enter
    end
    -- F11: with reduced motion every colour change and fade lasts at most 0.10 s (one rule for all parts)
    if self.Reduced and info.Time > 0.10 and info.RepeatCount == 0 then
        return self.Info.Fade
    end
    return info
end

-- the token to use for a movement: "Fade" (0.10, no travel) when motion is reduced
function Motion:Pick(token)
    if self.Reduced then
        return "Fade"
    end
    return token
end

-- Plays a tween and cancels the previous one on the same instance and channel (default "_"),
-- so rapid input always ends in the last requested state.
function Motion:Play(instance, props, token, channel, px)
    if not instance then
        return nil
    end
    channel = channel or "_"
    local slots = self.Running[instance]
    if not slots then
        slots = {}
        self.Running[instance] = slots
    end
    local previous = slots[channel]
    if previous then
        slots[channel] = nil
        pcall(function()
            previous:Cancel()
        end)
    end
    local ok, tween = pcall(function()
        return TweenService:Create(instance, self:GetInfo(token, px), props)
    end)
    if not ok or not tween then
        pcall(function()
            for prop, value in pairs(props) do
                instance[prop] = value
            end
        end)
        return nil
    end
    slots[channel] = tween
    self.Goals[tween] = props
    tween.Completed:Connect(function()
        local current = self.Running[instance]
        if current and current[channel] == tween then
            current[channel] = nil
            if next(current) == nil then
                self.Running[instance] = nil
            end
        end
    end)
    tween:Play()
    return tween
end

function Motion:Stop(instance, channel)
    local slots = self.Running[instance]
    if not slots then
        return
    end
    channel = channel or "_"
    local previous = slots[channel]
    if previous then
        slots[channel] = nil
        pcall(function()
            previous:Cancel()
        end)
    end
end

function Motion:Refresh()
    local ok, value = pcall(function()
        return GuiService.ReducedMotionEnabled
    end)
    self.SystemReduced = ok and value == true
    self.Reduced = self.SystemReduced or self.UserReduced
    return self.Reduced
end

Motion:Refresh()
pcall(function()
    GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
        Motion:Refresh()
    end)
end)

-- ==============================================================================
-- 3) THEME MANAGER (contract presets, B derived keys)
-- ==============================================================================

local ThemeManager = {
    Themes = {},
    ThemeOrder = { "Default", "Purple", "Sapphire", "Emerald", "Crimson", "Black and White" },
    Current = "Default",
    Registry = {},
    RegisterCount = 0,
    Listeners = {},
    -- accents the 6.x presets shipped with (and white from the old reset bug): a saved accent equal to one
    -- of these was never customised, so the preset accent is used instead
    LegacyAccents = {
        { 15, 87, 212 }, { 165, 121, 255 }, { 92, 186, 255 }, { 94, 230, 167 }, { 255, 107, 136 }, { 255, 255, 255 }, { 235, 235, 235 },
    },
}

do
    local function rgb(r, g, b)
        return Color3.fromRGB(r, g, b)
    end
    -- order of each tuple: Default, Purple, Sapphire, Emerald, Crimson (lib_contract.md section 7), Black and White
    local base = {
        Background = { { 0, 0, 0 }, { 7, 7, 10 }, { 5, 9, 14 }, { 6, 10, 8 }, { 11, 6, 7 }, { 0, 0, 0 } },
        Panel = { { 7, 8, 11 }, { 17, 16, 24 }, { 11, 18, 27 }, { 13, 22, 18 }, { 22, 11, 13 }, { 10, 10, 10 } },
        PanelHover = { { 12, 15, 21 }, { 23, 22, 32 }, { 16, 25, 38 }, { 18, 30, 24 }, { 31, 16, 18 }, { 18, 18, 18 } },
        Border = { { 21, 25, 34 }, { 38, 34, 52 }, { 25, 42, 61 }, { 26, 45, 36 }, { 52, 24, 29 }, { 34, 34, 34 } },
        BorderHighlight = { { 32, 44, 68 }, { 58, 49, 81 }, { 41, 66, 93 }, { 38, 67, 52 }, { 78, 34, 42 }, { 58, 58, 58 } },
        Text = { { 231, 233, 234 }, { 240, 240, 255 }, { 232, 246, 255 }, { 238, 252, 245 }, { 255, 238, 240 }, { 240, 240, 240 } },
        TextDark = { { 121, 132, 151 }, { 172, 165, 206 }, { 151, 186, 211 }, { 160, 204, 184 }, { 214, 161, 170 }, { 150, 150, 150 } },
        TextMuted = { { 71, 82, 102 }, { 107, 99, 138 }, { 102, 130, 151 }, { 104, 140, 123 }, { 151, 102, 112 }, { 92, 92, 92 } },
        Accent = { { 15, 87, 212 }, { 165, 121, 255 }, { 92, 186, 255 }, { 94, 230, 167 }, { 255, 107, 136 }, { 235, 235, 235 } },
        Success = { { 0, 186, 124 }, { 140, 255, 180 }, { 120, 255, 195 }, { 132, 255, 186 }, { 130, 255, 190 }, { 225, 225, 225 } },
        Error = { { 244, 33, 46 }, { 255, 110, 130 }, { 255, 105, 105 }, { 255, 115, 115 }, { 255, 120, 120 }, { 255, 255, 255 } },
        Warning = { { 255, 200, 80 }, { 255, 200, 120 }, { 255, 204, 117 }, { 255, 204, 112 }, { 255, 198, 115 }, { 190, 190, 190 } },
        Shadow = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
        AccentGlow = { { 45, 119, 255 }, { 195, 167, 255 }, { 143, 212, 255 }, { 138, 255, 200 }, { 255, 149, 169 }, { 255, 255, 255 } },
    }
    for index, name in ipairs(ThemeManager.ThemeOrder) do
        local preset = {}
        for key, values in pairs(base) do
            local v = values[index]
            preset[key] = rgb(v[1], v[2], v[3])
        end
        preset.PresetAccent = preset.Accent
        preset.PresetGlow = preset.AccentGlow
        ThemeManager.Themes[name] = preset
    end
end

local function LinearChannel(c)
    if c <= 0.03928 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

function ThemeManager.Luminance(c)
    return 0.2126 * LinearChannel(c.R) + 0.7152 * LinearChannel(c.G) + 0.0722 * LinearChannel(c.B)
end

function ThemeManager.Contrast(a, b)
    local la, lb = ThemeManager.Luminance(a), ThemeManager.Luminance(b)
    if la < lb then
        la, lb = lb, la
    end
    return (la + 0.05) / (lb + 0.05)
end

function ThemeManager.SameColor(a, b)
    if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then
        return false
    end
    return math.abs(a.R - b.R) < 0.003 and math.abs(a.G - b.G) < 0.003 and math.abs(a.B - b.B) < 0.003
end

-- Recomputes the derived keys. AccentGlow is never touched here (presets keep their table value).
function ThemeManager:Derive(t)
    t.Field = t.PanelHover:Lerp(t.Text, 0.12)
    t.FieldHover = t.Field:Lerp(t.Text, 0.07)
    t.Chrome = t.Text:Lerp(t.TextDark, 0.2)
    t.Edge = t.TextDark
    if ThemeManager.Contrast(t.AccentGlow, t.Field) >= 4.5 then
        t.AccentText = t.AccentGlow
    else
        t.AccentText = t.AccentGlow:Lerp(t.Text, 0.3)
    end
    t.OnAccent = Color3.new(0, 0, 0)
    -- On a white accent the usual light knob would disappear into the track.
    t.SwitchKnob = ThemeManager.Contrast(t.Text, t.Accent) < 1.3 and t.Background or t.Text
    t.AccentSoft = t.Panel:Lerp(t.Accent, 0.16)
    t.Focus = t.Text
    t.Inset = t.Background
    t.Surface = t.Panel
    t.Track = t.BorderHighlight
    t.Overlay = t.Background
    return t
end

-- Writes an accent into a preset: the preset's own accent restores its table AccentGlow, any other
-- colour gets AccentGlow = accent lerped 35 % to white (contract).
function ThemeManager:ApplyAccent(t, color)
    t.Accent = color
    if t.PresetAccent and ThemeManager.SameColor(color, t.PresetAccent) then
        t.AccentGlow = t.PresetGlow or color:Lerp(Color3.new(1, 1, 1), 0.35)
    else
        t.AccentGlow = color:Lerp(Color3.new(1, 1, 1), 0.35)
    end
    return self:Derive(t)
end

for _, name in ipairs(ThemeManager.ThemeOrder) do
    ThemeManager:Derive(ThemeManager.Themes[name])
end

function ThemeManager:Get(key)
    local selected = self.Themes[self.Current] or self.Themes.Default
    local value = selected[key]
    if value == nil then
        value = self.Themes.Default[key]
    end
    return value
end

-- key: a colour key string, or function(ThemeManager) returning a Color3 (derived tones)
function ThemeManager:Resolve(key)
    if type(key) == "function" then
        local ok, value = pcall(key, self)
        if ok and typeof(value) == "Color3" then
            return value
        end
        return self:Get("Text")
    end
    return self:Get(key)
end

function ThemeManager:Register(instance, property, colorKey)
    if not instance then
        return
    end
    local entry = self.Registry[instance]
    if not entry then
        entry = {}
        self.Registry[instance] = entry
        self.RegisterCount = self.RegisterCount + 1
        if self.RegisterCount % 600 == 0 then
            self:Prune()
        end
    end
    entry[property] = colorKey
    pcall(function()
        instance[property] = self:Resolve(colorKey)
    end)
end

function ThemeManager:Unregister(instance, property)
    local entry = self.Registry[instance]
    if entry then
        if property then
            entry[property] = nil
        else
            self.Registry[instance] = nil
        end
    end
end

function ThemeManager:IsAlive(instance)
    local ok, alive = pcall(function()
        return instance.Parent ~= nil and instance:IsDescendantOf(game)
    end)
    return ok and alive
end

function ThemeManager:Prune()
    for instance in pairs(self.Registry) do
        if not self:IsAlive(instance) then
            self.Registry[instance] = nil
        end
    end
end

-- One instant pass (no tweens: hundreds of simultaneous tweens are a frame spike).
function ThemeManager:UpdateAll()
    local running = Motion.Running
    for instance, properties in pairs(self.Registry) do
        if self:IsAlive(instance) then
            local slots = running[instance]
            for prop, key in pairs(properties) do
                -- a colour tween still running (hover, tab change) would finish on the old preset
                if slots and slots[prop] then
                    Motion:Stop(instance, prop)
                end
                pcall(function()
                    instance[prop] = self:Resolve(key)
                end)
            end
        else
            self.Registry[instance] = nil
        end
    end
    for _, fn in ipairs(self.Listeners) do
        pcall(fn, self.Current)
    end
end

function ThemeManager:OnChanged(fn)
    table.insert(self.Listeners, fn)
    return function()
        local i = table.find(self.Listeners, fn)
        if i then
            table.remove(self.Listeners, i)
        end
    end
end

function ThemeManager:SetTheme(themeName)
    if type(themeName) == "string" and self.Themes[themeName] then
        self.Current = themeName
        self:UpdateAll()
        return true
    end
    return false
end

-- Mutates the current preset (6.x behaviour: a custom accent survives until the process ends).
function ThemeManager:SetAccent(color)
    if typeof(color) == "Color3" then
        local t = self.Themes[self.Current] or self.Themes.Default
        self:ApplyAccent(t, color)
        self:UpdateAll()
        return true
    end
    return false
end

function ThemeManager:IsLegacyAccent(r, g, b)
    r, g, b = math.floor((tonumber(r) or -1) + 0.5), math.floor((tonumber(g) or -1) + 0.5), math.floor((tonumber(b) or -1) + 0.5)
    for _, v in ipairs(self.LegacyAccents) do
        if v[1] == r and v[2] == g and v[3] == b then
            return true
        end
    end
    return false
end

-- ==============================================================================
-- 4) UTILITY
-- ==============================================================================

local Utility = { FontCache = {} }

local function ClampNumber(value, min, max)
    local n = tonumber(value)
    if not n or n ~= n then
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
            local ok, item = pcall(function()
                return Enum.KeyCode[upper]
            end)
            if ok and item then
                return item
            end
            -- "LeftShift" style names are mixed case in the enum
            for _, k in ipairs(Enum.KeyCode:GetEnumItems()) do
                if k.Name:upper() == upper then
                    return k
                end
            end
            return fallback
        end
    end
    return fallback
end

Utility.ClampNumber = ClampNumber
Utility.NormalizeKeyCode = NormalizeKeyCode

function Utility.ColorToHex(c)
    if typeof(c) ~= "Color3" then
        return "#FFFFFF"
    end
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- "#0F57D4", "0f57d4", "0F5" -> Color3 or nil
function Utility.HexToColor(text)
    local hex = tostring(text or ""):gsub("[%s#]", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 or hex:find("[^%x]") then
        return nil
    end
    return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

-- One family everywhere (Montserrat through GothamSSm). Bold and SemiBold map to Medium.
Utility.WeightMap = { Bold = "Medium", SemiBold = "Medium", ExtraBold = "Medium", Heavy = "Medium", Medium = "Medium" }
function Utility:Font(family, weight)
    local w = self.WeightMap[weight or "Regular"] or "Regular"
    local cached = self.FontCache[w]
    if cached then
        return cached
    end
    local ok, font = pcall(function()
        return Font.new(Tokens.FontFamily.Sans, Enum.FontWeight[w])
    end)
    if not ok or not font then
        ok, font = pcall(function()
            return Font.fromEnum(w == "Medium" and Enum.Font.GothamMedium or Enum.Font.Gotham)
        end)
    end
    self.FontCache[w] = font
    return font
end

-- Legacy enums give the same advance widths as Montserrat; used only to size wrapped text.
function Utility:Measure(text, size, weight, width)
    local ok, v = pcall(function()
        return TextService:GetTextSize(tostring(text or ""), size or 14, (weight == "Medium") and Enum.Font.GothamMedium or Enum.Font.Gotham, Vector2.new(width or 10000, 10000))
    end)
    if ok and v then
        return v
    end
    return Vector2.new(#tostring(text or "") * (size or 14) * 0.55, size or 14)
end

function Utility:Tween(obj, props, time, style, direction)
    if not obj then
        return nil
    end
    local ok, tween = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(time or Motion.Normal, style or Motion.Style, direction or Enum.EasingDirection.Out), props or {})
    end)
    if ok and tween then
        tween:Play()
        return tween
    end
    return nil
end

-- Creates an instance. Special keys: Theme = { Prop = "ColorKey" | fn }, Parent is set last.
function Utility:Create(className, properties, children)
    local inst = Instance.new(className)
    local parent = nil
    for key, value in pairs(properties or {}) do
        if key == "Theme" then
            for prop, colorKey in pairs(value) do
                ThemeManager:Register(inst, prop, colorKey)
            end
        elseif key == "Parent" then
            parent = value
        else
            inst[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

-- Text helper: Utility:Text(className, { Text, Font = {"Sans","Medium"}, TextSize, Color = key, ... })
function Utility:Text(className, props)
    local font = props.Font or { "Sans", "Regular" }
    props.Font = nil
    props.FontFace = self:Font(font[1], font[2])
    if props.BackgroundTransparency == nil then
        props.BackgroundTransparency = 1
    end
    if props.TextSize == nil then
        props.TextSize = Tokens.Text.Body
    end
    if props.BorderSizePixel == nil then
        props.BorderSizePixel = 0
    end
    if props.LineHeight == nil and className ~= "TextBox" then
        props.LineHeight = 1
    end
    local color = props.Color
    props.Color = nil
    if color then
        props.Theme = props.Theme or {}
        props.Theme.TextColor3 = color
    end
    return self:Create(className or "TextLabel", props)
end

function Utility:Corner(parent, radius)
    return self:Create("UICorner", {
        CornerRadius = type(radius) == "number" and UDim.new(0, radius) or (radius or UDim.new(0, 0)),
        Parent = parent,
    })
end
Utility.ApplyCorner = Utility.Corner

function Utility:Stroke(parent, colorKey, thickness, transparency)
    return self:Create("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = colorKey or "Border" },
        Parent = parent,
    })
end
Utility.ApplyStroke = Utility.Stroke

-- F3: the faint 1 px edge (TextDark at 0.6) that keeps floating surfaces visible on night maps. No shadow anywhere.
function Utility:Edge(parent)
    local stroke = self:Create("UIStroke", {
        Name = "Edge",
        Thickness = 1,
        Transparency = Tokens.B.EdgeTransparency,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = "Edge" },
        Parent = parent,
    })
    pcall(function()
        (stroke :: any).BorderStrokePosition = (Enum :: any).BorderStrokePosition.Inner
    end)
    return stroke
end

function Utility:Padding(parent, top, right, bottom, left)
    right = right or top
    bottom = bottom or top
    left = left or right
    return self:Create("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft = UDim.new(0, left or 0),
        Parent = parent,
    })
end

function Utility:List(parent, direction, padding, halign, valign)
    return self:Create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        Parent = parent,
    })
end

function Utility:Gradient(parent, keypoints, rotation)
    local seq = {}
    for _, kp in ipairs(keypoints) do
        table.insert(seq, NumberSequenceKeypoint.new(kp[1], kp[2]))
    end
    return self:Create("UIGradient", { Rotation = rotation or 0, Transparency = NumberSequence.new(seq), Parent = parent })
end

function Utility:IsPointInside(gui, point)
    if not gui or not gui.Parent then
        return false
    end
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

-- Legacy frame icons, kept for component code that still asks for them (chevron, check, search).
Utility.IconShapes = {
    close = { { 8, 8, 11, 1.5, 45 }, { 8, 8, 11, 1.5, -45 } },
    minimize = { { 8, 8, 10, 1.5, 0 } },
    plus = { { 8, 8, 10, 1.5, 0 }, { 8, 8, 1.5, 10, 0 } },
    minus = { { 8, 8, 10, 1.5, 0 } },
    chevron = { { 6.1, 8, 6.4, 1.5, 45 }, { 9.9, 8, 6.4, 1.5, -45 } },
    check = { { 5.2, 9.6, 4.6, 1.5, 45 }, { 9.4, 8.2, 8.6, 1.5, -45 } },
    menu = { { 8, 4, 12, 1.5, 0 }, { 8, 8, 12, 1.5, 0 }, { 8, 12, 12, 1.5, 0 } },
    search = { { 7, 7, 8, 8, 0, "circle" }, { 12, 12, 4.5, 1.5, 45 } },
}

function Utility:Icon(kind, size, colorKey, parent)
    size = size or 16
    local k = size / 16
    local holder = self:Create("Frame", {
        Name = "Icon_" .. tostring(kind),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Parent = parent,
    })
    for _, part in ipairs(self.IconShapes[kind] or {}) do
        local cx, cy, w, h, rot, style = part[1], part[2], part[3], part[4], part[5], part[6]
        local ring = style == "circle"
        local frame = self:Create("Frame", {
            Name = ring and "Ring" or "Bar",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx * k, cy * k),
            Size = UDim2.fromOffset(w * k, h * k),
            Rotation = rot or 0,
            BorderSizePixel = 0,
            BackgroundTransparency = ring and 1 or 0,
            Parent = holder,
        })
        if ring then
            self:Corner(frame, UDim.new(1, 0))
            self:Create("UIStroke", { Thickness = 1.5 * k, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Theme = { Color = colorKey or "TextDark" }, Parent = frame })
        else
            ThemeManager:Register(frame, "BackgroundColor3", colorKey or "TextDark")
        end
    end
    return holder
end

-- Recolours an icon built by Utility:Icon or Glyph.Draw (registry updated so theme changes keep the new key).
function Utility:IconColor(icon, colorKey, token)
    if not icon then
        return
    end
    if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
        self:SetColor(icon, "ImageColor3", colorKey, token)
        return
    end
    for _, part in ipairs(icon:GetDescendants()) do
        if part:IsA("Frame") and part.Name == "Bar" then
            self:SetColor(part, "BackgroundColor3", colorKey, token)
        elseif part:IsA("ImageLabel") then
            self:SetColor(part, "ImageColor3", colorKey, token)
        elseif part:IsA("UIStroke") then
            self:SetColor(part, "Color", colorKey, token)
        end
    end
end

-- Sets a themed colour property and keeps the registry in sync; optional tween token.
function Utility:SetColor(instance, property, colorKey, token)
    if not instance then
        return
    end
    local entry = ThemeManager.Registry[instance]
    if not entry then
        entry = {}
        ThemeManager.Registry[instance] = entry
    end
    entry[property] = colorKey
    local color = ThemeManager:Resolve(colorKey)
    if token and not Motion.Reduced then
        Motion:Play(instance, { [property] = color }, token, property)
    else
        Motion:Stop(instance, property)
        pcall(function()
            instance[property] = color
        end)
    end
end

-- Fade helper without CanvasGroup: records base transparencies of a tree and moves them toward 1.
-- alpha 0 = as built, 1 = fully transparent.
function Utility:Fader(root)
    local fader = { Items = {} }
    function fader:Scan()
        self.Items = {}
        -- a state tween still running (a checkbox filled while its page was hidden) counts at its target,
        -- or the fade would bring the control back to a half-way value
        local function base(inst, prop)
            local slots = Motion.Running[inst]
            if slots then
                for channel, tween in pairs(slots) do
                    local goal = channel ~= "fade" and Motion.Goals[tween]
                    if goal and goal[prop] ~= nil then
                        return goal[prop]
                    end
                end
            end
            return inst[prop]
        end
        local function record(inst)
            local entry = {}
            local any = false
            if inst:IsA("GuiObject") then
                entry.BackgroundTransparency = base(inst, "BackgroundTransparency")
                any = true
                if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                    entry.TextTransparency = base(inst, "TextTransparency")
                elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
                    entry.ImageTransparency = base(inst, "ImageTransparency")
                elseif inst:IsA("ScrollingFrame") then
                    entry.ScrollBarImageTransparency = base(inst, "ScrollBarImageTransparency")
                end
            elseif inst:IsA("UIStroke") then
                entry.Transparency = base(inst, "Transparency")
                any = true
            end
            if any then
                table.insert(self.Items, { Instance = inst, Base = entry })
            end
        end
        record(root)
        for _, d in ipairs(root:GetDescendants()) do
            record(d)
        end
        return self
    end
    function fader:Targets(item, alpha)
        local out = {}
        for prop, base in pairs(item.Base) do
            out[prop] = base + (1 - base) * alpha
        end
        return out
    end
    function fader:Set(alpha)
        for _, item in ipairs(self.Items) do
            Motion:Stop(item.Instance, "fade")
            for prop, value in pairs(self:Targets(item, alpha)) do
                pcall(function()
                    item.Instance[prop] = value
                end)
            end
        end
    end
    function fader:Tween(alpha, token)
        for _, item in ipairs(self.Items) do
            Motion:Play(item.Instance, self:Targets(item, alpha), token, "fade")
        end
    end
    return fader:Scan()
end

-- Minimal Trove (cleanup bag): connections, instances, functions, objects with Clean/Destroy.
local Trove = {}
Trove.__index = Trove

function Trove.new()
    return setmetatable({ Items = {} }, Trove)
end

function Trove:Add(item)
    if item ~= nil then
        table.insert(self.Items, item)
    end
    return item
end

function Trove:Connect(signal, fn)
    return self:Add(signal:Connect(fn))
end

function Trove:Clean()
    local items = self.Items
    self.Items = {}
    for i = #items, 1, -1 do
        local item = items[i]
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then
            pcall(function()
                item:Disconnect()
            end)
        elseif kind == "Instance" then
            pcall(function()
                item:Destroy()
            end)
        elseif kind == "function" then
            pcall(item)
        elseif kind == "table" then
            if type(item.Clean) == "function" then
                pcall(item.Clean, item)
            elseif type(item.Destroy) == "function" then
                pcall(item.Destroy, item)
            elseif type(item.Disconnect) == "function" then
                pcall(item.Disconnect, item)
            end
        end
    end
end

Utility.Trove = Trove

function Utility:GetViewportSize(gui)
    if gui and gui.AbsoluteSize.X > 0 then
        return gui.AbsoluteSize
    end
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

-- Top inset of the Roblox top bar in screen pixels (never hard-coded).
function Utility:GetTopInset()
    local ok, rect = pcall(function()
        return GuiService.TopbarInset
    end)
    if ok and typeof(rect) == "Rect" and rect.Max.Y > 0 then
        return rect.Max.Y
    end
    local ok2, inset = pcall(function()
        return GuiService:GetGuiInset()
    end)
    if ok2 and typeof(inset) == "Vector2" then
        return inset.Y
    end
    return 36
end

-- ==============================================================================
-- 5) GLYPHS (Frame-drawn, 1.5 px strokes, no image ids; shapes from mockup B)
-- ==============================================================================

local Glyph = { Line = 1.5, Shapes = {} }
-- native box of each shape: coordinates below are in that box and scale with the drawn size
Glyph.Native = {
    interface = 16, security = 16, dashboard = 16, extractors = 16, settings = 16, chevron = 10,
    close = 14, minimize = 14, arrow = 14, check = 14, zoomOut = 14, zoomIn = 14, fit = 14, expand = 14,
    shrink = 14, search = 14, menu = 14,
}

-- every coloured part registers with ThemeManager under `key`; Paint recolours them later
function Glyph.Seg(h, x1, y1, x2, y2, key, k)
    k = k or 1
    x1, y1, x2, y2 = x1 * k, y1 * k, x2 * k, y2 * k
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    return Utility:Create("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
        Size = UDim2.fromOffset(len + Glyph.Line * 0.5, Glyph.Line),
        Rotation = math.deg(math.atan2(dy, dx)),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = key },
        Parent = h,
    })
end

function Glyph.Ring(h, x, y, w, hh, r, key, k)
    k = k or 1
    local f = Utility:Create("Frame", {
        Name = "Ring",
        Position = UDim2.fromOffset(x * k, y * k),
        Size = UDim2.fromOffset(w * k, hh * k),
        BackgroundTransparency = 1,
        Parent = h,
    })
    Utility:Create("UIStroke", { Thickness = Glyph.Line, Theme = { Color = key }, Parent = f })
    if r > 0 then
        Utility:Corner(f, r * k)
    end
    return f
end

function Glyph.Dot(h, cx, cy, d, key, k)
    k = k or 1
    local f = Utility:Create("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx * k, cy * k),
        Size = UDim2.fromOffset(d * k, d * k),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = key },
        Parent = h,
    })
    Utility:Corner(f, UDim.new(0.5, 0))
    return f
end

-- Plus and minus on whole pixels. A bar turned 90 degrees renders differently from a straight
-- one, which left the plus with two mismatched arms, so both arms are straight frames here.
function Glyph.PlusMinus(h, key, k, withVertical)
    local size = math.round(14 * (k or 1))
    local length = 2 * math.floor(math.min(size - 2, size * 5 / 6) / 2)
    local thick = 2
    local along = math.floor((size - length) / 2)
    local across = math.floor((size - thick) / 2)
    local function arm(x, y, w, t)
        Utility:Create("Frame", {
            Name = "Bar",
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w, t),
            BorderSizePixel = 0,
            Theme = { BackgroundColor3 = key },
            Parent = h,
        })
    end
    arm(along, across, length, thick)
    if withVertical then
        arm(across, along, thick, length)
    end
end

do
    local S, Seg, Ring, Dot = Glyph.Shapes, Glyph.Seg, Glyph.Ring, Glyph.Dot
    S.interface = function(h, c, k)
        Ring(h, 2, 3, 12, 10, 2, c, k)
        Seg(h, 2, 6.5, 14, 6.5, c, k)
    end
    S.security = function(h, c, k)
        Ring(h, 3, 8, 10, 6, 1.5, c, k)
        local clip = Utility:Create("Frame", {
            Name = "Clip",
            Position = UDim2.fromOffset(2.5 * k, 0),
            Size = UDim2.fromOffset(11 * k, 8.2 * k),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Parent = h,
        })
        Ring(clip, 3, 1.5, 5, 12, 2.5, c, k)
    end
    S.dashboard = function(h, c, k)
        Ring(h, 2, 2, 4.5, 4.5, 1, c, k)
        Ring(h, 9.5, 2, 4.5, 4.5, 1, c, k)
        Ring(h, 2, 9.5, 4.5, 4.5, 1, c, k)
        Ring(h, 9.5, 9.5, 4.5, 4.5, 1, c, k)
    end
    S.extractors = function(h, c, k)
        Seg(h, 2, 10, 2, 14, c, k)
        Seg(h, 2, 14, 14, 14, c, k)
        Seg(h, 14, 14, 14, 10, c, k)
        Seg(h, 8, 1.5, 8, 10, c, k)
        Seg(h, 4.5, 6.5, 8, 10, c, k)
        Seg(h, 11.5, 6.5, 8, 10, c, k)
    end
    S.settings = function(h, c, k)
        Seg(h, 1.5, 3.5, 14.5, 3.5, c, k)
        Seg(h, 1.5, 8, 14.5, 8, c, k)
        Seg(h, 1.5, 12.5, 14.5, 12.5, c, k)
        Dot(h, 10.5, 3.5, 4.5, c, k)
        Dot(h, 5, 8, 4.5, c, k)
        Dot(h, 11, 12.5, 4.5, c, k)
    end
    S.chevron = function(h, c, k)
        Seg(h, 1.5, 3.5, 5, 7, c, k)
        Seg(h, 5, 7, 8.5, 3.5, c, k)
    end
    S.close = function(h, c, k)
        Seg(h, 1.5, 1.5, 12.5, 12.5, c, k)
        Seg(h, 12.5, 1.5, 1.5, 12.5, c, k)
    end
    S.minimize = function(h, c, k)
        Seg(h, 1.5, 7, 12.5, 7, c, k)
    end
    S.arrow = function(h, c, k)
        Seg(h, 1, 7, 12, 7, c, k)
        Seg(h, 8, 3, 12, 7, c, k)
        Seg(h, 8, 11, 12, 7, c, k)
    end
    S.check = function(h, c, k)
        Seg(h, 2.5, 6, 5, 8.5, c, k)
        Seg(h, 5, 8.5, 9.5, 3.5, c, k)
    end
    S.zoomOut = function(h, c, k)
        Glyph.PlusMinus(h, c, k, false)
    end
    S.zoomIn = function(h, c, k)
        Glyph.PlusMinus(h, c, k, true)
    end
    S.fit = function(h, c, k)
        Seg(h, 1.5, 4.5, 1.5, 1.5, c, k)
        Seg(h, 1.5, 1.5, 4.5, 1.5, c, k)
        Seg(h, 9.5, 1.5, 12.5, 1.5, c, k)
        Seg(h, 12.5, 1.5, 12.5, 4.5, c, k)
        Seg(h, 12.5, 9.5, 12.5, 12.5, c, k)
        Seg(h, 12.5, 12.5, 9.5, 12.5, c, k)
        Seg(h, 4.5, 12.5, 1.5, 12.5, c, k)
        Seg(h, 1.5, 12.5, 1.5, 9.5, c, k)
    end
    S.expand = function(h, c, k)
        Seg(h, 8, 6, 12.5, 1.5, c, k)
        Seg(h, 8.5, 1.5, 12.5, 1.5, c, k)
        Seg(h, 12.5, 1.5, 12.5, 5.5, c, k)
        Seg(h, 6, 8, 1.5, 12.5, c, k)
        Seg(h, 1.5, 8.5, 1.5, 12.5, c, k)
        Seg(h, 1.5, 12.5, 5.5, 12.5, c, k)
    end
    S.shrink = function(h, c, k)
        Seg(h, 12.5, 1.5, 8, 6, c, k)
        Seg(h, 8, 6, 8, 2.5, c, k)
        Seg(h, 8, 6, 11.5, 6, c, k)
        Seg(h, 1.5, 12.5, 6, 8, c, k)
        Seg(h, 6, 8, 6, 11.5, c, k)
        Seg(h, 6, 8, 2.5, 8, c, k)
    end
    S.search = function(h, c, k)
        Ring(h, 1.5, 1.5, 8, 8, 4, c, k)
        Seg(h, 8.5, 8.5, 12.5, 12.5, c, k)
    end
    S.menu = function(h, c, k)
        Seg(h, 1.5, 3.5, 12.5, 3.5, c, k)
        Seg(h, 1.5, 7, 12.5, 7, c, k)
        Seg(h, 1.5, 10.5, 12.5, 10.5, c, k)
    end
end

-- Window and zoom controls use the published Lucide icons (ISC licence). Their art fills about
-- two thirds of the image, so the image is drawn larger than the glyph box.
Glyph.Images = {
    close = "rbxassetid://10747384394",
    minimize = "rbxassetid://10734896206",
    zoomOut = "rbxassetid://10734896206",
    zoomIn = "rbxassetid://10734924532",
}
Glyph.ImageTimeout = 6

-- Draws glyph `name` in a transparent holder of `size` px. Returns the holder (nil for an unknown name).
function Glyph.Draw(parent, name, size, colorKey, props)
    local shape = Glyph.Shapes[name]
    if not shape then
        return nil
    end
    size = size or Glyph.Native[name] or 14
    local key = colorKey or "TextDark"
    local scale = size / (Glyph.Native[name] or size)
    local holder = Utility:Create("Frame", {
        Name = "Glyph_" .. name,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
    })
    local imageId = Glyph.Images[name]
    if imageId then
        local side = 2 * math.round(size * 2 / 3)
        local image = Utility:Create("ImageLabel", {
            Name = "Icon",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(side, side),
            BackgroundTransparency = 1,
            Image = imageId,
            Theme = { ImageColor3 = key },
            Parent = holder,
        })
        -- A control must never end up blank: if the icon cannot load, draw the shape instead.
        task.delay(Glyph.ImageTimeout, function()
            if image.Parent == holder and not image.IsLoaded then
                image:Destroy()
                shape(holder, key, scale)
            end
        end)
    else
        shape(holder, key, scale)
    end
    for k, v in pairs(props or {}) do
        holder[k] = v
    end
    holder.Parent = parent
    return holder
end

-- Recolours every stroke and fill of a glyph holder (theme registry kept in sync).
function Glyph.Paint(holder, colorKey, token)
    Utility:IconColor(holder, colorKey, token)
end

-- Four-point star of the logo: two crossed tapered strokes and a small centre diamond.
function Glyph.Star(parent, size, colorKey, props)
    local holder = Utility:Create("Frame", {
        Name = "Glyph_star",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
    })
    local thick = math.max(1.5, size * 0.12)
    for i = 1, 2 do
        local bar = Utility:Create("Frame", {
            Name = "Bar",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = i == 1 and UDim2.fromOffset(size, thick) or UDim2.fromOffset(thick, size),
            BorderSizePixel = 0,
            Theme = { BackgroundColor3 = colorKey or "Text" },
            Parent = holder,
        })
        Utility:Gradient(bar, { { 0, 0.9 }, { 0.5, 0 }, { 1, 0.9 } }, i == 1 and 0 or 90)
    end
    Utility:Create("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size * 0.3, size * 0.3),
        Rotation = 45,
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = colorKey or "Text" },
        Parent = holder,
    })
    for k, v in pairs(props or {}) do
        holder[k] = v
    end
    holder.Parent = parent
    return holder
end

-- ==============================================================================
-- 6) ART: embedded logo and the backdrop sources (rendered once, no uploaded assets)
-- ==============================================================================

local Art = {}

-- the real CACLOGO.png art as a 32 x 32 copy: 16-colour palette (RGBA hex) + one palette index per pixel
Art.LogoPalette = "00000000fcfcfc08e4e4e6efa5a5a6fe5f5f60fe212125fffcfcfca5fcfcfc601a1962ff5e5d9fff201e8bffa6a5ccff7f7f7f02bfbfbf04fefefefd010102ff"
Art.LogoPixels = [[
0000000110017766667710001000000000000010076eeeeeeeeee67001100000
000011016eeee223eeeeeee2701100000001107eee2355ff2eeeeeeee6d01000
001116eee45fffff2eeeeeeeee610100011c6ee25ffff5542eeeeeeeeee21110
0106ee3ffff53eeeeeeeeeeeeeee6010107ee2ffff3ee3444432eeeeeeeee701
112ee5fff3e35ffffff53eeeeeeeee1107ee4fff3e4ffffff43eeeeeeeeeee70
12e2fff4e4ffffff3ee22eeeeeeeee211ee3ff5e3ffffff3eeeb9eeeeeeeeee7
7ee5ff4e5fffff4eeee9a2eeeeeeeee66e2fff23ffffff2eeebaa9eeeeeeeee2
2e2fffe4fffff5ee2baaa892eeeeeeeeee3ff5e4fffff429888888889beeeeee
ee3ff5e4fffff429888888888beeeeee2e2fffe4fffff4ee2988884beeeeeeee
6e2fff23fffff5eeee3558eeeeeeeee26ee5ff32ffffff3eeee5f3eeeeeeeee6
7ee4ff5e4fffff5eeee95eeeeeeeeee712e2fff3effffff4eee23eeeeeeeeee1
07ee4fff22ffffff42eeeeeeeeeeee6011ee25ff5225ffffff432eeeeeeeee11
107ee3fff53e35fffff43eeeeeeee7010106ee3ffff42ee222eeeeeeeeee6111
01112ee35ffff543eeeeeeeeeee211c0001012ee24ffffff2eeeeeeeee210100
0001016eee245fff2eeeeeeee6101000000010072eeee233eeeeeee270010000
00000110172eeeeeeeeee2710110000000000001000176622667100010000000
]]

function Art.LogoContent()
    if Art.Logo ~= nil then
        return Art.Logo or nil
    end
    Art.Logo = false
    local ok, result = pcall(function()
        local pixels = (string.gsub(Art.LogoPixels, "%s", ""))
        local buf = buffer.create(#pixels * 4)
        for i = 1, #pixels do
            local index = tonumber(string.sub(pixels, i, i), 16) or 0
            for channel = 0, 3 do
                local at = index * 8 + channel * 2 + 1
                buffer.writeu8(buf, (i - 1) * 4 + channel, tonumber(string.sub(Art.LogoPalette, at, at + 1), 16) or 0)
            end
        end
        local image = (game:GetService("AssetService") :: any):CreateEditableImage({ Size = Vector2.new(32, 32) })
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(32, 32), buf)
        return (Content :: any).fromObject(image)
    end)
    if ok and result then
        Art.Logo = result
    end
    return Art.Logo or nil
end

-- ImageLabel with the product logo (LogoImage), else the embedded copy; nil when neither can show
function Art.MakeLogo(image, size, props)
    local logo = Utility:Create("ImageLabel", {
        Name = "Logo",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        ScaleType = Enum.ScaleType.Fit,
    })
    if type(image) == "string" and image ~= "" then
        logo.Image = image
    else
        local content = Art.LogoContent()
        local ok = content ~= nil and pcall(function()
            (logo :: any).ImageContent = content
        end)
        if not ok then
            logo:Destroy()
            return nil
        end
    end
    for k, v in pairs(props or {}) do
        logo[k] = v
    end
    return logo
end

Art.BackdropOptions = { "My Avatar", "Block City" }
Art.BackdropDefault = "My Avatar"
Art.BackdropBase = { ["Block City"] = 0.75, ["My Avatar"] = 0.82 }
Art.CityCamera = CFrame.lookAt(Vector3.new(0, 28, 46), Vector3.new(0, 6, 0))
Art.Light = Vector3.new(-0.55, -1, -0.4)

function Art.Viewport(name)
    return Utility:Create("ViewportFrame", {
        Name = name,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0.75),
        Ambient = Color3.fromRGB(110, 112, 118),
        LightColor = Color3.fromRGB(190, 190, 195),
        LightDirection = Art.Light,
        ZIndex = 1,
    })
end

function Art.Box(model, size, cf, color, ball)
    return Utility:Create("Part", {
        Anchored = true,
        CanCollide = false,
        CastShadow = false,
        Material = Enum.Material.SmoothPlastic,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
        Shape = ball and Enum.PartType.Ball or Enum.PartType.Block,
        Color = color,
        Size = size,
        CFrame = cf,
        Parent = model,
    })
end

-- Block City: ground + 9 x 6 boxes + back wall = 56 parts, deterministic (Random seed 7)
function Art.BlockCity()
    local vf = Art.Viewport("BlockCity")
    local model = Instance.new("Model")
    Art.Box(model, Vector3.new(260, 1, 200), CFrame.new(0, -0.5, -60), Color3.fromRGB(120, 120, 124))
    local rnd = Random.new(7)
    local grey = Color3.fromRGB(163, 162, 165)
    for r = 0, 5 do
        for c = 0, 8 do
            local w = rnd:NextInteger(6, 10)
            local d = rnd:NextInteger(6, 10)
            local h = rnd:NextInteger(4, 24) + r * 4
            local x = (c - 4) * 12 + rnd:NextNumber(-1.5, 1.5)
            local z = -r * 12 + rnd:NextNumber(-1.5, 1.5)
            Art.Box(model, Vector3.new(w, h, d), CFrame.new(x, h / 2, z), grey)
        end
    end
    -- back wall: gaps between the tall back roofs showed the void as black slits at the top edge
    Art.Box(model, Vector3.new(220, 40, 2), CFrame.new(0, 20, -84), grey)
    model.Parent = vf
    local cam = Utility:Create("Camera", { FieldOfView = 40, CFrame = Art.CityCamera, Parent = vf })
    vf.CurrentCamera = cam
    return vf
end

-- My Avatar: the player's full-body thumbnail at the right, faded to black toward the left
function Art.Avatar()
    local holder = Utility:Create("Frame", {
        Name = "MyAvatar",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    })
    local userId = LocalPlayer and LocalPlayer.UserId or 1
    if userId <= 0 then
        userId = 1
    end
    local image = Utility:Create("ImageLabel", {
        Name = "Image",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 100, 0, -30),
        Size = UDim2.fromScale(1.25, 1.25),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        Image = "rbxthumb://type=Avatar&id=" .. tostring(userId) .. "&w=420&h=420",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 1,
        Parent = holder,
    })
    local side = Utility:Create("Frame", {
        Name = "FadeSide",
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Background" },
        Parent = holder,
    })
    Utility:Gradient(side, { { 0, 0 }, { 0.33, 0 }, { 0.66, 1 }, { 1, 1 } }, 0)
    return holder, image
end

-- ==============================================================================
-- 7) SAVE MANAGER (same folder, file and keys as 6.x)
-- ==============================================================================

local SaveManager = {
    Folder = "CAC_Ultimate",
    Flags = {},
    Options = {},
    Ignore = {},
    Persistent = {},
    Loaded = {},
    AutoSaveName = "ui_default",
    SaveRevision = 0,
}

function SaveManager:Path(name)
    return self.Folder .. "/configs/" .. tostring(name) .. ".json"
end

function SaveManager:Init(folderName)
    if type(folderName) == "string" and folderName ~= "" then
        self.Folder = folderName
    end
    pcall(function()
        if not Env.isfolder(self.Folder) then
            Env.makefolder(self.Folder)
        end
        if not Env.isfolder(self.Folder .. "/configs") then
            Env.makefolder(self.Folder .. "/configs")
        end
    end)
    local filePath = self:Path(self.AutoSaveName)
    local ok, data = pcall(function()
        if not Env.isfile(filePath) then
            return {}
        end
        return HttpService:JSONDecode(Env.readfile(filePath))
    end)
    self.Loaded = ok and type(data) == "table" and data or {}
end

function SaveManager:IsPersistent(flag, cfg)
    if type(cfg) == "table" and cfg.Persist == true then
        return true
    end
    return type(flag) == "string" and flag:sub(1, 6) == "__lib_"
end

function SaveManager:GetInitialValue(flag, fallback, persistent)
    if persistent and self.Loaded[flag] ~= nil then
        return self.Loaded[flag]
    end
    return fallback
end

function SaveManager:RegisterOption(flag, option, persistent)
    self.Options[flag] = option
    if persistent then
        self.Persistent[flag] = true
    end
end

function SaveManager:SetFlag(flag, value, persistent)
    self.Flags[flag] = value
    if persistent then
        self.Persistent[flag] = true
        self:QueueSave()
    end
end

function SaveManager:QueueSave()
    self.SaveRevision = self.SaveRevision + 1
    local revision = self.SaveRevision
    task.delay(0.2, function()
        if revision ~= self.SaveRevision then
            return
        end
        pcall(function()
            self:Save(self.AutoSaveName)
        end)
    end)
end

local function SerializableValue(value)
    local kind = typeof(value)
    if kind == "EnumItem" then
        return value.Name
    end
    if kind == "boolean" or kind == "number" or kind == "string" then
        return value
    end
    if kind == "table" then
        local out = {}
        for i, v in ipairs(value) do
            out[i] = SerializableValue(v)
        end
        return out
    end
    return nil
end

-- Writes every persistent option. Keys loaded from the file whose option does not exist yet (product
-- controls created after login) are kept, so a save never erases them (fixes the 6.x data loss).
function SaveManager:Save(name)
    local filePath = self:Path(name)
    local data = {}
    for flag, value in pairs(self.Loaded) do
        if not self.Ignore[flag] then
            data[flag] = value
        end
    end
    for flag, optionObj in pairs(self.Options) do
        if self.Persistent[flag] and not self.Ignore[flag] and optionObj then
            local value = SerializableValue(self.Flags[flag])
            if value ~= nil then
                data[flag] = value
            end
        end
    end
    local ok, err = pcall(function()
        Env.writefile(filePath, HttpService:JSONEncode(data))
    end)
    self.Loaded = data
    return ok, err
end

function SaveManager:Load(name)
    local filePath = self:Path(name)
    local exists = false
    pcall(function()
        exists = Env.isfile(filePath)
    end)
    if not exists then
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(Env.readfile(filePath))
    end)
    if not ok or type(data) ~= "table" then
        return false
    end
    self.Loaded = data
    for flag, val in pairs(data) do
        local option = self.Options[flag]
        if self.Persistent[flag] and option and option.SetValue then
            pcall(function()
                option:SetValue(val)
            end)
        end
    end
    return true
end

-- ==============================================================================
-- 8) LIBRARY + WINDOW SHELL (B "Lobby")
-- ==============================================================================

local Library = {
    Windows = {},
    ActiveWindow = nil,
    Keybind = Enum.KeyCode.K,
    Version = "7.0.0",
}

local Shell = {}
local WindowMethods = {}
local TabMethods = {}   -- component constructors, filled in the components part
local Components = {}   -- rows and controls, components part
local Overlays = {}     -- toasts, modal, action bar, tooltip, popovers, overlays part

-- F7: glyph by tab name (lower-cased, trimmed); unknown names show text only
Shell.GlyphMap = {
    interface = "interface", config = "interface", configuration = "interface",
    security = "security", license = "security", key = "security",
    dashboard = "dashboard", home = "dashboard", overview = "dashboard",
    extractors = "extractors",
    settings = "settings", options = "settings",
}
-- icon ids the products pass to every tab: ignored (an explicit other id is honoured)
Shell.DefaultIcons = {
    ["rbxassetid://10888331510"] = true, ["rbxassetid://6031280882"] = true,
    ["10888331510"] = true, ["6031280882"] = true,
}

-- Library:SetGlobalKeybind also applies the key to every open window (6.x stored it only).
function Library:SetGlobalKeybind(keycode)
    self.Keybind = NormalizeKeyCode(keycode, self.Keybind)
    for _, window in ipairs(self.Windows) do
        if type(window) == "table" and not window.IsDestroyed then
            window.ToggleKey = self.Keybind
        end
    end
end

local function KeyText(keycode)
    return tostring(keycode and keycode.Name or "K")
end

-- Converts an AbsolutePosition (inset relative) to an Offset inside the IgnoreGuiInset ScreenGui.
function Shell.ToGui(W, absPos)
    local origin = W._I.GUI.AbsolutePosition
    return Vector2.new(absPos.X - origin.X, absPos.Y - origin.Y)
end

function Shell.ViewSize(W)
    return Utility:GetViewportSize(W._I.GUI)
end

-- "AUTHENTICATING..." -> "Authenticating"; mixed-case text is kept, only trailing dots go
function Shell.SentenceCase(text)
    local s = tostring(text or "")
    local before
    repeat
        before = s
        s = s:gsub("%s+$", ""):gsub("%.+$", ""):gsub("\226\128\166$", "")
    until s == before
    if s ~= "" and not s:find("%l") then
        s = s:sub(1, 1):upper() .. s:sub(2):lower()
    end
    return s
end

function Shell.Hit(W)
    return W._I.Family == "Compact" and Tokens.Size.HitCompact or Tokens.Size.Hit
end

-- ------------------------------------------------------------------------------
-- settings and saved state (contract order: theme, accent, sizes, scale, key, then interface extras)
-- ------------------------------------------------------------------------------

function Shell.ResolveState(Settings)
    SaveManager:Init(Settings.Folder)
    local L = SaveManager.Loaded

    local savedTheme = tostring(SaveManager:GetInitialValue("__lib_theme_preset", ThemeManager.Current, true))
    if ThemeManager.Themes[savedTheme] then
        ThemeManager.Current = savedTheme
    end
    local preset = ThemeManager.Themes[ThemeManager.Current]

    -- a saved accent equal to an old 6.x preset accent was never customised: use the preset accent
    if L.__lib_accent_r ~= nil and L.__lib_accent_g ~= nil and L.__lib_accent_b ~= nil
        and ThemeManager:IsLegacyAccent(L.__lib_accent_r, L.__lib_accent_g, L.__lib_accent_b) then
        local a = preset.PresetAccent or preset.Accent
        L.__lib_accent_r = math.floor(a.R * 255 + 0.5)
        L.__lib_accent_g = math.floor(a.G * 255 + 0.5)
        L.__lib_accent_b = math.floor(a.B * 255 + 0.5)
    end
    local current = preset.Accent
    local r = ClampNumber(SaveManager:GetInitialValue("__lib_accent_r", current.R * 255, true), 0, 255)
    local g = ClampNumber(SaveManager:GetInitialValue("__lib_accent_g", current.G * 255, true), 0, 255)
    local b = ClampNumber(SaveManager:GetInitialValue("__lib_accent_b", current.B * 255, true), 0, 255)
    ThemeManager:ApplyAccent(preset, Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)))

    local Lm = Tokens.Limits
    local mode = tostring(SaveManager:GetInitialValue("__lib_backdrop_mode", Art.BackdropDefault, true))
    if not table.find(Art.BackdropOptions, mode) then
        mode = Art.BackdropDefault
    end
    local state = {
        Width = ClampNumber(SaveManager:GetInitialValue("__lib_window_width", tonumber(Settings.Width) or 800, true), Lm.WidthMin, Lm.WidthMax),
        Height = ClampNumber(SaveManager:GetInitialValue("__lib_window_height", tonumber(Settings.Height) or 500, true), Lm.HeightMin, Lm.HeightMax),
        SidebarW = ClampNumber(SaveManager:GetInitialValue("__lib_sidebar_width", tonumber(Settings.SidebarWidth) or 200, true), Lm.SidebarMin, Lm.SidebarMax),
        UserScale = ClampNumber((tonumber(SaveManager:GetInitialValue("__lib_ui_scale", (tonumber(Settings.UIScale) or 1) * 100, true)) or 100) / 100, Lm.ScaleMin, Lm.ScaleMax),
        ToggleKey = NormalizeKeyCode(SaveManager:GetInitialValue("__lib_toggle_key", Settings.ToggleKey or "K", true), Enum.KeyCode.K),
        Backdrop = {
            Mode = mode,
            Strength = ClampNumber(SaveManager:GetInitialValue("__lib_backdrop_strength", 100, true), 0, 100),
            HidePreview = SaveManager:GetInitialValue("__lib_backdrop_hide_preview", true, true) ~= false,
            Token = 0,
        },
    }
    if L.__lib_reduce_motion == true then
        Motion.UserReduced = true
        Motion:Refresh()
    end
    return state
end

-- ------------------------------------------------------------------------------
-- CreateWindow
-- ------------------------------------------------------------------------------

function Library:CreateWindow(Settings)
    Settings = type(Settings) == "table" and Settings or {}
    -- a second run of the script replaces the window of the same name (no doubled input, no orphan GUI)
    local registry = Env.Shared and Env.Shared.__LivrariaWindows
    if Env.Shared and type(registry) ~= "table" then
        registry = {}
        Env.Shared.__LivrariaWindows = registry
    end
    local regKey = tostring(Settings.Name or "CAC Ultimate")
    if registry and type(registry[regKey]) == "table" and registry[regKey].IsDestroyed == false then
        local old = registry[regKey]
        pcall(function()
            old:Destroy()
        end)
        pcall(function()
            old.UI.GUI:Destroy()
        end)
    end
    local state = Shell.ResolveState(Settings)
    local skipLoading = Settings.SkipLoading == true

    local Window = {
        Tabs = {},
        Elements = {},
        IsLoaded = skipLoading,
        IsToggled = true,
        IsDestroyed = false,
        IsMinimized = false,
        IsHidden = false,
        NotificationsEnabled = true,
        ToggleKey = state.ToggleKey,
        SavedOpenSize = UDim2.fromOffset(state.Width, state.Height),
        SavedOpenPosition = UDim2.fromScale(0.5, 0.5),
        ThemeName = ThemeManager.Current,
        Accent = ThemeManager:Get("Accent"),
        CurrentTab = nil,
        ConfigTab = nil,
        UI = {},
        _TransitionId = 0,
    }
    for name, fn in pairs(WindowMethods) do
        Window[name] = fn
    end
    Window._I = {
        Settings = Settings,
        Name = tostring(Settings.Name or "CAC Ultimate"),
        LogoImage = tostring(Settings.LogoImage or ""),
        LoadingTitle = Shell.SentenceCase(Settings.LoadingTitle or "Initializing framework"),
        Trove = Trove.new(),
        Width = state.Width,
        Height = state.Height,
        W = state.Width,
        H = state.Height,
        SidebarW = state.SidebarW,
        UserScale = state.UserScale,
        Scale = 1,
        Base = 1,
        Family = "Regular",
        Drawer = false,
        DrawerOpen = false,
        BandH = Tokens.Size.TopBand,
        ContentX = state.SidebarW + 4,
        ContentW = 572,
        ContentH = 432,
        ItemOrder = 0,
        Items = {},
        Groups = {},
        NoDrag = {},
        GlyphButtons = {},
        KeyHandlers = {},
        Toasts = { Visible = {}, Queue = {} },
        ModalCount = 0,
        Backdrop = state.Backdrop,
        Popover = nil,
        Capture = nil,
        Drag = nil,
    }

    Shell.BuildRoot(Window)
    Shell.BuildBackdrop(Window)
    Shell.BuildTopBand(Window)
    Shell.BuildSidebar(Window)
    Shell.BuildContent(Window)
    Shell.BuildLoading(Window, skipLoading)
    Shell.BuildMiniBar(Window)
    Shell.BuildReopenChip(Window)
    Shell.BuildResizeGrip(Window)
    Shell.WireInput(Window)
    Overlays.InstallPalette(Window)
    Shell.Relayout(Window, false)
    Shell.ApplyBackdrop(Window)

    if Settings.DisableDefaultConfig ~= true then
        Components.BuildInterfacePage(Window)
    end

    if not skipLoading then
        task.delay(12, function()
            if not Window.IsDestroyed and not Window.IsLoaded then
                Window:FinishLoading()
            end
        end)
    end

    table.insert(self.Windows, Window)
    self.ActiveWindow = Window
    if registry then
        registry[regKey] = Window
    end
    return Window
end

-- ------------------------------------------------------------------------------
-- root: ScreenGui, window frame (no shadow), floating layers
-- ------------------------------------------------------------------------------

function Shell.BuildRoot(W)
    local I = W._I
    local GUI = Utility:Create("ScreenGui", {
        Name = "CAC_Ultimate_Core_" .. tostring(math.random(1000, 9999)),
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    })
    pcall(Env.ProtectGui, GUI)
    GUI.Parent = CoreGui
    I.Trove:Add(GUI)

    local MainFrame = Utility:Create("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = W.SavedOpenPosition,
        Size = W.SavedOpenSize,
        ClipsDescendants = true,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = Tokens.Z.Main,
        Theme = { BackgroundColor3 = "Background" },
        Parent = GUI,
    })
    Utility:Edge(MainFrame)
    local UIScale = Utility:Create("UIScale", { Scale = 1, Parent = MainFrame })

    -- gamepad selection: transparent frame with a faint text-coloured line
    local ring = Utility:Create("Frame", { Name = "SelectRing", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
    Utility:Stroke(ring, "Text", 1, 0.3)
    I.SelectRing = ring

    local Veil = Utility:Create("Frame", {
        Name = "Veil",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = Tokens.Z.Veil,
        Theme = { BackgroundColor3 = "Background" },
        Parent = MainFrame,
    })

    local Overlay = Utility:Create("Frame", {
        Name = "Overlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Overlay,
        Parent = GUI,
    })
    local OverlayScale = Utility:Create("UIScale", { Scale = 1, Parent = Overlay })

    local Toasts = Utility:Create("Frame", {
        Name = "Toasts",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Toasts,
        Parent = GUI,
    })
    local ToastScale = Utility:Create("UIScale", { Scale = 1, Parent = Toasts })

    I.GUI, I.MainFrame, I.UIScale, I.Veil = GUI, MainFrame, UIScale, Veil
    I.Overlay, I.OverlayScale, I.ToastLayer, I.ToastScale = Overlay, OverlayScale, Toasts, ToastScale
    W.UI.GUI = GUI
    W.UI.MainFrame = MainFrame
    W.UI.UIScale = UIScale
    W.UI.Overlay = Overlay
    W.UI.Toasts = Toasts

    local tr = I.Trove
    local function sync()
        Shell.SyncFloating(W)
    end
    tr:Connect(MainFrame:GetPropertyChangedSignal("AbsolutePosition"), sync)
    tr:Connect(MainFrame:GetPropertyChangedSignal("AbsoluteSize"), sync)
    tr:Connect(MainFrame:GetPropertyChangedSignal("Visible"), function()
        if not MainFrame.Visible then
            Overlays.ClosePopover(W)
        end
    end)
    tr:Connect(GUI:GetPropertyChangedSignal("AbsoluteSize"), function()
        Shell.Relayout(W, false)
    end)
end

-- glyph button: transparent hit box (28, 44 on touch) with a centred glyph; rest Chrome, hover Text, pressed TextDark
function Shell.GlyphButton(W, parent, glyph, glyphSize, onClick, props, restKey)
    local I = W._I
    restKey = restKey or "Chrome"
    local hit = Shell.Hit(W)
    local btn = Utility:Create("TextButton", {
        Name = "Btn_" .. glyph,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(hit, hit),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        SelectionImageObject = I.SelectRing,
        Parent = parent,
    })
    for k, v in pairs(props or {}) do
        btn[k] = v
    end
    local g = Glyph.Draw(btn, glyph, glyphSize, restKey, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
    })
    local hovered = false
    btn.MouseEnter:Connect(function()
        hovered = true
        Glyph.Paint(g, "Text", "Hover")
    end)
    btn.MouseLeave:Connect(function()
        hovered = false
        Glyph.Paint(g, restKey, "Hover")
    end)
    btn.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(g, "TextDark", "Press")
        end
    end)
    btn.InputEnded:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(g, hovered and "Text" or restKey, "Release")
        end
    end)
    btn.Activated:Connect(function()
        if not W.IsDestroyed and onClick then
            onClick()
        end
    end)
    table.insert(I.GlyphButtons, btn)
    return btn, g
end

-- ------------------------------------------------------------------------------
-- backdrop (F8): source (Z 1) under a fade to Background by 69 % of the height (Z 2)
-- ------------------------------------------------------------------------------

function Shell.BuildBackdrop(W)
    local I = W._I
    I.BackdropHolder = Utility:Create("Frame", {
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Backdrop,
        Parent = I.MainFrame,
    })
    I.Fade = Utility:Create("Frame", {
        Name = "Fade",
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = Tokens.Z.Fade,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.MainFrame,
    })
    Utility:Gradient(I.Fade, { { 0, 1 }, { 0.35, 0.4 }, { 0.69, 0 }, { 1, 0 } }, 90)
end

function Shell.BackdropTransparency(W)
    local B = W._I.Backdrop
    local base = Art.BackdropBase[B.Mode] or 0.75
    return 1 - (1 - base) * B.Strength / 100
end

-- rebuilds the source (only when the option or the custom id changes); 3D sources render once
function Shell.ApplyBackdrop(W)
    local I = W._I
    local B = I.Backdrop
    B.Token = (B.Token or 0) + 1
    local token = B.Token
    if B.Source then
        pcall(function()
            B.Source:Destroy()
        end)
        B.Source, B.Target = nil, nil
    end
    if W.IsDestroyed then
        return
    end
    local mode = B.Mode
    local ok, source, image = pcall(function()
        if mode == "Block City" then
            return Art.BlockCity()
        elseif mode == "My Avatar" then
            return Art.Avatar()
        end
        return nil
    end)
    if not ok then
        warn("[CAC UI] backdrop fell back to None: " .. tostring(source))
        source = nil
    end
    if source then
        B.Source, B.Target = source, image or source
        B.Target.ImageTransparency = Shell.BackdropTransparency(W)
        source.Parent = I.BackdropHolder
        if source:IsA("ViewportFrame") then
            task.defer(function()
                RunService.Heartbeat:Wait()
                if B.Token == token and B.Source == source and source.AbsoluteSize.X == 0 then
                    warn("[CAC UI] 3D backdrop did not render, using None")
                    pcall(function()
                        source:Destroy()
                    end)
                    B.Source, B.Target = nil, nil
                end
            end)
        end
    end
    Shell.UpdateBackdrop(W, false)
end

-- visibility and strength: hidden while minimized or hidden, and behind a shown docked preview
function Shell.UpdateBackdrop(W, animate)
    local I = W._I
    local B = I.Backdrop
    local source, target = B.Source, B.Target
    if not source or not target then
        return
    end
    local open = not W.IsMinimized and not W.IsHidden and not W.IsDestroyed
    if not open or B.Strength <= 0 then
        Motion:Stop(target, "backdrop")
        source.Visible = false
        return
    end
    local tab = W.CurrentTab
    local behind = B.HidePreview and tab ~= nil and tab._previewShown == true
    if behind then
        if animate and source.Visible and not Motion.Reduced then
            local token = B.Token
            Motion:Play(target, { ImageTransparency = 1 }, "Backdrop", "backdrop")
            task.delay(0.3, function()
                if B.Token == token and B.Source == source and W.CurrentTab == tab and tab._previewShown then
                    source.Visible = false
                end
            end)
        else
            Motion:Stop(target, "backdrop")
            source.Visible = false
        end
        return
    end
    local goal = Shell.BackdropTransparency(W)
    if animate and not source.Visible and not Motion.Reduced then
        target.ImageTransparency = 1
        source.Visible = true
        Motion:Play(target, { ImageTransparency = goal }, "Backdrop", "backdrop")
    else
        Motion:Stop(target, "backdrop")
        source.Visible = true
        target.ImageTransparency = goal
    end
end

-- for the docked preview: tell the shell whether the tab's pane is shown (hides the backdrop behind it)
function Shell.SetPreviewShown(W, tab, shown)
    if not tab then
        return
    end
    shown = shown == true
    if tab._previewShown == shown then
        return
    end
    tab._previewShown = shown
    if W.CurrentTab == tab then
        Shell.UpdateBackdrop(W, true)
    end
end

-- ------------------------------------------------------------------------------
-- title band: logo + wordmark, thin minus and X (drawer mode adds the menu glyph)
-- ------------------------------------------------------------------------------

function Shell.BuildTopBand(W)
    local I = W._I
    local band = Utility:Create("Frame", {
        Name = "TitleBand",
        Size = UDim2.new(1, 0, 0, I.BandH),
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Band,
        Parent = I.MainFrame,
    })
    I.MenuButton = Shell.GlyphButton(W, band, "menu", 14, function()
        Shell.SetDrawer(W, not I.DrawerOpen)
    end, { Name = "Menu", Position = UDim2.fromOffset(23, 23), Visible = false })
    I.Logo = Art.MakeLogo(I.LogoImage, Tokens.Size.Logo, { Position = UDim2.fromOffset(16, 12), Parent = band })
    I.Wordmark = Utility:Text("TextLabel", {
        Name = "Wordmark",
        Position = UDim2.fromOffset(I.Logo and 46 or 16, 12),
        Size = UDim2.new(1, -((I.Logo and 46 or 16) + 90), 0, 22),
        Text = I.Name,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = band,
    })
    local minBtn = Shell.GlyphButton(W, band, "minimize", 14, function()
        W:Minimize(false)
    end, { Name = "Minimize", Position = UDim2.new(1, -55, 0, 23) })
    local closeBtn = Shell.GlyphButton(W, band, "close", 14, function()
        W:HideAll(false)
    end, { Name = "Close", Position = UDim2.new(1, -27, 0, 23) })
    table.insert(I.NoDrag, I.MenuButton)
    table.insert(I.NoDrag, minBtn)
    table.insert(I.NoDrag, closeBtn)
    I.TopBand, I.MinButton, I.CloseButton = band, minBtn, closeBtn
    W.UI.DragBar = band
    W.UI.TopBand = band

    band.InputBegan:Connect(function(input)
        Shell.TryBeginWindowDrag(W, input)
    end)
end

-- ------------------------------------------------------------------------------
-- sidebar: thin glyphs with labels, indented sub-tabs, no boxes; VersionLabel at the bottom
-- ------------------------------------------------------------------------------

function Shell.BuildSidebar(W)
    local I = W._I
    local sidebar = Utility:Create("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(0, Tokens.B.ContentY),
        Size = UDim2.new(0, I.SidebarW - Tokens.B.SidebarGap, 1, -Tokens.B.ContentY),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Tokens.Z.Sidebar,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.MainFrame,
    })
    I.SidebarPad = Utility:Padding(sidebar, 0, 0, 0, 0)
    -- drawer mode only: the 1 px edge on the right side
    I.DrawerEdge = Utility:Create("Frame", {
        Name = "DrawerEdge",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, -4),
        Size = UDim2.new(0, 1, 1, 4),
        BorderSizePixel = 0,
        BackgroundTransparency = Tokens.B.EdgeTransparency,
        Visible = false,
        Theme = { BackgroundColor3 = "Edge" },
        Parent = sidebar,
    })
    local list = Utility:Create("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -Tokens.B.ListBottom),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        Theme = { ScrollBarImageColor3 = "TextMuted" },
        Parent = sidebar,
    })
    Utility:List(list, Enum.FillDirection.Vertical, 0)
    Shell.AutoScrollbar(W, list)

    local versionText = I.Settings.Version
    if type(versionText) ~= "string" or versionText == "" then
        versionText = Tokens.Version
    end
    -- One TextLabel "CAC Ultimate | vX.Y.Z": the products rewrite it to their build tag (contract 8.3).
    local versionLabel = Utility:Text("TextLabel", {
        Name = "VersionLabel",
        Position = UDim2.new(0, 24, 1, -32),
        Size = UDim2.new(1, -16, 0, 16),
        Text = "CAC Ultimate | " .. versionText,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Version,
        TextXAlignment = Enum.TextXAlignment.Left,
        Color = "TextMuted",
        Parent = sidebar,
    })

    I.DrawerScrim = Utility:Create("TextButton", {
        Name = "DrawerScrim",
        Selectable = false,
        Position = UDim2.fromOffset(0, I.BandH),
        Size = UDim2.new(1, 0, 1, -I.BandH),
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = Tokens.Z.DrawerScrim,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.MainFrame,
    })
    I.DrawerScrim.Activated:Connect(function()
        Shell.SetDrawer(W, false)
    end)

    I.Sidebar, I.TabList, I.VersionLabel = sidebar, list, versionLabel
    W.UI.Sidebar = sidebar
    W.UI.TabContainer = list
    W.UI.VersionLabel = versionLabel
end

-- F5: 2 px native scrollbar, transparent at rest; shows while the canvas moves or the pointer is over it
function Shell.AutoScrollbar(W, sf)
    sf.ScrollBarImageTransparency = 1
    local state = { Token = 0, Hover = false }
    local function scrollable()
        return sf.AbsoluteCanvasSize.Y > sf.AbsoluteWindowSize.Y + 1
    end
    local function hideLater()
        state.Token = state.Token + 1
        local token = state.Token
        task.delay(0.8, function()
            if state.Token == token and not state.Hover and sf.Parent then
                Motion:Play(sf, { ScrollBarImageTransparency = 1 }, 0.3, "scrollbar")
            end
        end)
    end
    local function show()
        if not scrollable() then
            return
        end
        Motion:Play(sf, { ScrollBarImageTransparency = 0.3 }, 0.12, "scrollbar")
        hideLater()
    end
    sf:GetPropertyChangedSignal("CanvasPosition"):Connect(show)
    sf.MouseEnter:Connect(function()
        state.Hover = true
        show()
    end)
    sf.MouseLeave:Connect(function()
        state.Hover = false
        hideLater()
    end)
    return state
end

-- icon decision per top-level tab or group (F7): explicit non-default id -> image, known name -> glyph, else nothing
function Shell.ResolveIcon(name, iconId)
    local id = iconId ~= nil and tostring(iconId) or ""
    if id ~= "" and not Shell.DefaultIcons[id] then
        return "image", id
    end
    local key = Shell.GlyphMap[string.lower((tostring(name):gsub("^%s+", ""):gsub("%s+$", "")))]
    if key then
        return "glyph", key
    end
    return nil, nil
end

-- Sidebar row (top tab, group header or sub-tab). Returns { Btn, Icon, Label, Indicator, Chevron }.
function Shell.MakeItem(W, parent, name, iconId, isSub, isGroup)
    local I = W._I
    I.ItemOrder = I.ItemOrder + 1
    local compact = I.Family == "Compact"
    local height = isSub and (compact and Tokens.Size.SubItemCompact or Tokens.Size.SubItem)
        or (compact and Tokens.Size.ItemCompact or Tokens.Size.Item)
    local btn = Utility:Create("TextButton", {
        Name = "Item_" .. name,
        Size = UDim2.new(1, 0, 0, height),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = I.ItemOrder,
        SelectionImageObject = I.SelectRing,
        Parent = parent,
    })
    local label = Utility:Text("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(52, 0),
        Size = UDim2.new(1, -(52 + (isGroup and 34 or 8)), 1, 0),
        Text = name,
        Font = { "Sans", "Regular" },
        TextSize = isSub and Tokens.Text.Small or Tokens.Text.Label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "TextDark",
        Parent = btn,
    })
    local icon = nil
    if not isSub then
        local kind, value = Shell.ResolveIcon(name, iconId)
        if kind == "image" then
            icon = Utility:Create("ImageLabel", {
                Name = "Icon",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 22, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1,
                Image = value,
                ScaleType = Enum.ScaleType.Fit,
                Theme = { ImageColor3 = "TextDark" },
                Parent = btn,
            })
        elseif kind == "glyph" then
            icon = Glyph.Draw(btn, value, 16, "TextDark", {
                Name = "Icon",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 22, 0.5, 0),
            })
        end
    end
    local indicator
    if isSub then
        indicator = Utility:Create("Frame", {
            Name = "Indicator",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 27, 0.5, 0),
            Size = UDim2.fromOffset(8, 1.5),
            BorderSizePixel = 0,
            Visible = false,
            Theme = { BackgroundColor3 = "AccentGlow" },
            Parent = btn,
        })
    else
        -- contract field kept: top-level tabs show their state on the glyph, not on a bar
        indicator = Utility:Create("Frame", { Name = "Indicator", Size = UDim2.new(), BackgroundTransparency = 1, Visible = false, Parent = btn })
    end
    local chevron = nil
    if isGroup then
        chevron = Glyph.Draw(btn, "chevron", 10, "TextDark", {
            Name = "Chevron",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, -23, 0.5, 0),
        })
    end
    local item = { Btn = btn, Icon = icon, Label = label, Indicator = indicator, Chevron = chevron, Name = name, IsSub = isSub, Active = false, Cue = false }
    btn.MouseEnter:Connect(function()
        item.Hover = true
        if not item.Cue then
            Utility:SetColor(label, "TextColor3", "Text", "Hover")
        end
        if chevron then
            Glyph.Paint(chevron, "Text", "Hover")
        end
    end)
    btn.MouseLeave:Connect(function()
        item.Hover = false
        if not item.Cue then
            Utility:SetColor(label, "TextColor3", "TextDark", "Hover")
        end
        if chevron then
            Glyph.Paint(chevron, "TextDark", "Hover")
        end
    end)
    btn.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) and not item.Cue then
            Utility:SetColor(label, "TextColor3", "TextDark", "Press")
        end
    end)
    table.insert(I.Items, item)
    return item
end

-- one cue per kind: top tabs light the glyph (AccentGlow) and the label (Text); sub-tabs show the dash
function Shell.PaintItem(item, cue)
    if not item then
        return
    end
    item.Cue = cue == true
    local token = "State"
    Utility:SetColor(item.Label, "TextColor3", (cue or item.Hover) and "Text" or "TextDark", token)
    if item.Icon then
        Glyph.Paint(item.Icon, cue and "AccentGlow" or "TextDark", token)
    end
    if item.IsSub then
        item.Indicator.Visible = cue == true
    end
end

-- ------------------------------------------------------------------------------
-- content area: pages (no title, no breadcrumb, no status strip)
-- ------------------------------------------------------------------------------

function Shell.BuildContent(W)
    local I = W._I
    local content = Utility:Create("Frame", {
        Name = "ContentArea",
        Position = UDim2.fromOffset(I.ContentX, Tokens.B.ContentY),
        Size = UDim2.new(1, -I.ContentX - Tokens.B.InsetRight, 1, -Tokens.B.ContentY - Tokens.B.InsetBottom),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Tokens.Z.Content,
        Parent = I.MainFrame,
    })
    I.Content, I.Pages = content, content
    W.UI.ContentArea = content
end

-- ------------------------------------------------------------------------------
-- loading (F9): the logo's four-point star turns in eased 90 degree steps over the backdrop
-- ------------------------------------------------------------------------------

function Shell.BuildLoading(W, skip)
    local I = W._I
    if skip then
        return
    end
    I.Sidebar.Visible = false
    I.Content.Visible = false
    local layer = Utility:Create("Frame", {
        Name = "Loading",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Loading,
        Parent = I.MainFrame,
    })
    local column = Utility:Create("Frame", {
        Name = "Column",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(280, 52),
        BackgroundTransparency = 1,
        Parent = layer,
    })
    local star = Glyph.Star(column, 22, "Text", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) })
    Utility:Text("TextLabel", {
        Name = "LoadingTitle",
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 16),
        Text = I.LoadingTitle,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "TextDark",
        Parent = column,
    })
    I.Loading, I.LoadingColumn, I.LoadingStar = layer, column, star
    task.spawn(function()
        local rotation = 0
        while I.Loading == layer and not W.IsDestroyed do
            if not Motion.Reduced then
                rotation = rotation + 90
                Motion:Play(star, { Rotation = rotation }, "Star", "spin")
            end
            task.wait(0.85)
        end
    end)
end

-- ------------------------------------------------------------------------------
-- mini bar and reopen chip (floating, siblings of MainFrame, opaque with the edge)
-- ------------------------------------------------------------------------------

function Shell.BuildMiniBar(W)
    local I = W._I
    local holder = Utility:Create("Frame", {
        Name = "MiniBar",
        Size = UDim2.fromOffset(300, Tokens.Size.MiniBar),
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
        ZIndex = Tokens.Z.MiniBar,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.GUI,
    })
    Utility:Edge(holder)
    I.MiniScale = Utility:Create("UIScale", { Parent = holder })
    local logo = Art.MakeLogo(I.LogoImage, 20, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = holder })
    local x = logo and 38 or 12
    Utility:Text("TextLabel", {
        Name = "Wordmark",
        Position = UDim2.fromOffset(x, 0),
        Size = UDim2.new(1, -(x + 72), 1, 0),
        Text = I.Name,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = holder,
    })
    local restoreBtn = Shell.GlyphButton(W, holder, "minimize", 12, function()
        W:Restore(false)
    end, { Name = "Restore", Position = UDim2.new(1, -52, 0.5, 0) })
    local closeBtn = Shell.GlyphButton(W, holder, "close", 12, function()
        W:HideAll(false)
    end, { Name = "Close", Position = UDim2.new(1, -24, 0.5, 0) })
    I.MiniBar, I.MiniBody = holder, holder
    W.UI.MiniBar = holder
    holder.InputBegan:Connect(function(input)
        Shell.TryBeginFloatingDrag(W, input, holder, { restoreBtn, closeBtn })
    end)
end

function Shell.BuildReopenChip(W)
    local I = W._I
    local holder = Utility:Create("TextButton", {
        Name = "ReopenChip",
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(Tokens.Size.Chip, Tokens.Size.Chip),
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = Tokens.Z.Reopen,
        SelectionImageObject = I.SelectRing,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.GUI,
    })
    Utility:Edge(holder)
    local logo = Art.MakeLogo(I.LogoImage, 24, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = holder })
    if not logo then
        Utility:Text("TextLabel", {
            Name = "Mark",
            Size = UDim2.fromScale(1, 1),
            Text = "CAC",
            Font = { "Sans", "Medium" },
            TextSize = Tokens.Text.Caption,
            Color = "Text",
            Parent = holder,
        })
    end
    local moved = false
    holder.InputBegan:Connect(function(input)
        moved = false
        Shell.TryBeginFloatingDrag(W, input, holder, {}, function(delta)
            if delta.Magnitude > 6 then
                moved = true
            end
        end)
    end)
    holder.Activated:Connect(function()
        if not moved then
            W:Restore(false)
        end
    end)
    I.Reopen = holder
end

function Shell.UpdateReopen(W)
    local I = W._I
    if not I.Reopen then
        return
    end
    local show = W.IsHidden and UserInputService.TouchEnabled and not W.IsDestroyed
    if show and not I.Reopen.Visible then
        local view = Shell.ViewSize(W)
        I.Reopen.Position = UDim2.fromOffset(12, view.Y / 2)
    end
    I.Reopen.Visible = show
end

-- invisible 16 x 16 grip at the bottom-right corner (mouse and touch); not in Compact
function Shell.BuildResizeGrip(W)
    local I = W._I
    local grip = Utility:Create("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(16, 16),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Selectable = false,
        ZIndex = Tokens.Z.Band + 1,
        Parent = I.MainFrame,
    })
    I.Grip = grip
    grip.InputBegan:Connect(function(input)
        if W.IsDestroyed or I.Family == "Compact" or I.ModalCount > 0 or not Shell.IsPointer(input) then
            return
        end
        if input.UserInputState ~= Enum.UserInputState.Begin then
            return
        end
        local Lm = Tokens.Limits
        local startW, startH = I.Width, I.Height
        local frame = I.MainFrame
        local startPos = Shell.ToGui(W, frame.AbsolutePosition + frame.AbsoluteSize / 2)
        Shell.BeginDrag(W, input, function(delta)
            local s = I.Scale > 0 and I.Scale or 1
            local nw = math.clamp(startW + delta.X / s, Lm.WidthMin, Lm.WidthMax)
            local nh = math.clamp(startH + delta.Y / s, Lm.HeightMin, Lm.HeightMax)
            I.Width, I.Height = math.floor(nw + 0.5), math.floor(nh + 0.5)
            W.SavedOpenSize = UDim2.fromOffset(I.Width, I.Height)
            frame.Position = UDim2.fromOffset(startPos.X + (nw - startW) * s / 2, startPos.Y + (nh - startH) * s / 2)
            Shell.Relayout(W, false)
        end, function()
            if W.IsDestroyed then
                return
            end
            W.SavedOpenPosition = frame.Position
            local sliders = I.LayoutSliders
            if sliders and sliders.Width and sliders.Height then
                sliders.Width:SetValue(I.Width)
                sliders.Height:SetValue(I.Height)
            else
                SaveManager:SetFlag("__lib_window_width", I.Width, true)
                SaveManager:SetFlag("__lib_window_height", I.Height, true)
            end
        end)
    end)
end

-- ------------------------------------------------------------------------------
-- dragging (mouse and touch, one tracked dispatcher per window)
-- ------------------------------------------------------------------------------

function Shell.IsPointer(input)
    local t = input.UserInputType
    return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

function Shell.BeginDrag(W, input, onMove, onEnd)
    W._I.Drag = {
        Input = input,
        Mouse = input.UserInputType == Enum.UserInputType.MouseButton1,
        Start = Vector2.new(input.Position.X, input.Position.Y),
        Move = onMove,
        End = onEnd,
    }
end

function Shell.TryBeginWindowDrag(W, input)
    local I = W._I
    if W.IsDestroyed or I.Family == "Compact" or I.ModalCount > 0 or not Shell.IsPointer(input) then
        return
    end
    if input.UserInputState ~= Enum.UserInputState.Begin then
        return
    end
    for _, gui in ipairs(I.NoDrag) do
        if gui.Visible and Utility:IsPointInside(gui, input.Position) then
            return
        end
    end
    local frame = I.MainFrame
    local center = Shell.ToGui(W, frame.AbsolutePosition + frame.AbsoluteSize / 2)
    Shell.BeginDrag(W, input, function(delta)
        frame.Position = UDim2.fromOffset(center.X + delta.X, center.Y + delta.Y)
        Shell.ClampPosition(W)
    end, function()
        if not W.IsDestroyed and frame.Visible then
            W.SavedOpenPosition = frame.Position
        end
    end)
end

function Shell.TryBeginFloatingDrag(W, input, holder, exclude, onMove)
    if W.IsDestroyed or not Shell.IsPointer(input) or input.UserInputState ~= Enum.UserInputState.Begin then
        return
    end
    for _, gui in ipairs(exclude or {}) do
        if Utility:IsPointInside(gui, input.Position) then
            return
        end
    end
    local start = holder.Position
    Shell.BeginDrag(W, input, function(delta)
        holder.Position = UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
        if onMove then
            onMove(delta)
        end
    end)
end

-- keeps the title band reachable: at least 48 px of it inside the viewport
function Shell.ClampPosition(W)
    local I = W._I
    local frame = I.MainFrame
    local p = frame.Position
    if p.X.Scale ~= 0 or p.Y.Scale ~= 0 then
        return
    end
    local view = Shell.ViewSize(W)
    local s = I.Scale
    local dw, dh = frame.Size.X.Offset * s, frame.Size.Y.Offset * s
    local cx = math.clamp(p.X.Offset, -dw / 2 + 96, view.X + dw / 2 - 96)
    local top = math.clamp(p.Y.Offset - dh / 2, 0, math.max(0, view.Y - I.BandH * s))
    local cy = top + dh / 2
    if cx ~= p.X.Offset or cy ~= p.Y.Offset then
        frame.Position = UDim2.fromOffset(cx, cy)
    end
end

-- the attached action bar follows the window rectangle
function Shell.SyncFloating(W)
    if W.IsDestroyed then
        return
    end
    if Overlays.PlaceActionBar then
        Overlays.PlaceActionBar(W)
    end
end

-- ------------------------------------------------------------------------------
-- global input (tracked: disconnected on Destroy)
-- ------------------------------------------------------------------------------

function Shell.WireInput(W)
    local I = W._I
    local tr = I.Trove
    tr:Connect(UserInputService.InputBegan, function(input, gameProcessed)
        Shell.OnInputBegan(W, input, gameProcessed)
    end)
    tr:Connect(UserInputService.InputChanged, function(input)
        local d = I.Drag
        if not d then
            return
        end
        if (d.Mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or (not d.Mouse and input == d.Input) then
            local delta = Vector2.new(input.Position.X - d.Start.X, input.Position.Y - d.Start.Y)
            local ok, err = pcall(d.Move, delta, input)
            if not ok then
                I.Drag = nil
                warn("[CAC UI] drag handler error: " .. tostring(err))
            end
        end
    end)
    tr:Connect(UserInputService.InputEnded, function(input)
        local d = I.Drag
        if not d then
            return
        end
        if (d.Mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or (not d.Mouse and input == d.Input) then
            I.Drag = nil
            if d.End then
                pcall(d.End, input)
            end
        end
    end)
end

function Shell.OnInputBegan(W, input, gameProcessed)
    local I = W._I
    if W.IsDestroyed then
        return
    end
    local t = input.UserInputType
    if I.Capture and t == Enum.UserInputType.Keyboard then
        if UserInputService:GetFocusedTextBox() then
            return
        end
        local capture = I.Capture
        I.Capture = nil
        pcall(capture, input.KeyCode)
        return
    end
    if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and I.Popover then
        local pop = I.Popover
        if not Utility:IsPointInside(pop.Frame, input.Position) and not (pop.Anchor and Utility:IsPointInside(pop.Anchor, input.Position)) then
            Overlays.ClosePopover(W)
        end
    end
    if t ~= Enum.UserInputType.Keyboard then
        return
    end
    for i = #I.KeyHandlers, 1, -1 do
        local handler = I.KeyHandlers[i]
        local ok, handled = pcall(handler, input, gameProcessed)
        if ok and handled then
            return
        end
    end
    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == Enum.KeyCode.Escape and I.DrawerOpen then
        Shell.SetDrawer(W, false)
        return
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
        return
    end
    if input.KeyCode == W.ToggleKey then
        W:ToggleVisible(nil, false)
    end
end

-- ------------------------------------------------------------------------------
-- responsive layout: device base scale x user scale; families Regular / Compact; drawer under 600
-- ------------------------------------------------------------------------------

function Shell.Relayout(W, animate)
    local I = W._I
    if W.IsDestroyed then
        return
    end
    local view = Shell.ViewSize(W)
    if view.X <= 0 or view.Y <= 0 then
        return
    end
    local Lm = Tokens.Limits
    local compact = UserInputService.TouchEnabled and math.min(view.X, view.Y) < Lm.PhoneShortSide
    local base = math.clamp(view.Y / 1080, 1, 1.3)
    local scale, w, h
    if compact then
        scale = 1
        local top = Utility:GetTopInset()
        w = view.X - 16
        h = view.Y - top - 16
        I.CompactPos = UDim2.fromOffset(view.X / 2, top + 8 + h / 2)
    else
        scale = math.clamp(base * I.UserScale, Lm.DrawFloor, Lm.ScaleMax)
        w, h = I.Width, I.Height
        local maxW, maxH = view.X - 24, view.Y - 24
        if w * scale > maxW or h * scale > maxH then
            scale = math.max(Lm.DrawFloor, math.min(scale, maxW / w, maxH / h))
            w = math.min(w, maxW / scale)
            h = math.min(h, maxH / scale)
        end
    end
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    local family = compact and "Compact" or "Regular"
    local familyChanged = family ~= I.Family
    I.Base, I.Scale, I.Family, I.W, I.H = base, scale, family, w, h
    I.UIScale.Scale = scale
    I.OverlayScale.Scale = scale
    I.ToastScale.Scale = compact and 1 or base
    if I.MiniScale then
        I.MiniScale.Scale = scale
    end
    local size = UDim2.fromOffset(w, h)
    if animate and W.IsToggled and not Motion.Reduced then
        Motion:Play(I.MainFrame, { Size = size }, "Resize", "size")
    else
        Motion:Stop(I.MainFrame, "size")
        I.MainFrame.Size = size
    end
    if compact and I.CompactPos then
        I.MainFrame.Position = I.CompactPos
    end
    if familyChanged then
        Shell.ApplyFamily(W)
    end
    Shell.ApplySidebar(W, animate)
    Shell.ClampPosition(W)
    Shell.SyncFloating(W)
    if Overlays.LayoutToasts then
        Overlays.LayoutToasts(W, false)
    end
end

-- touch family: 44 px hit boxes and rows; desktop keeps B sizes exactly
function Shell.ApplyFamily(W)
    local I = W._I
    local compact = I.Family == "Compact"
    local hit = Shell.Hit(W)
    for _, btn in ipairs(I.GlyphButtons) do
        btn.Size = UDim2.fromOffset(hit, hit)
    end
    if I.MinButton then
        I.MinButton.Position = UDim2.new(1, compact and -71 or -55, 0, 23)
    end
    for _, item in ipairs(I.Items) do
        local h = item.IsSub and (compact and Tokens.Size.SubItemCompact or Tokens.Size.SubItem)
            or (compact and Tokens.Size.ItemCompact or Tokens.Size.Item)
        item.Btn.Size = UDim2.new(1, 0, 0, h)
    end
    for _, group in ipairs(I.Groups) do
        Shell.RefreshGroup(group, false)
    end
    if I.MiniBar then
        I.MiniBar.Size = UDim2.fromOffset(I.MiniBar.Size.X.Offset, compact and Tokens.Size.MiniBarCompact or Tokens.Size.MiniBar)
    end
    if I.Grip then
        I.Grip.Visible = not compact
    end
    if Overlays.UpdateSearchButton then
        Overlays.UpdateSearchButton(W)
    end
end

-- sidebar in the layout, or (window under 600 wide) a drawer behind the menu glyph
function Shell.ApplySidebar(W, animate)
    local I = W._I
    local drawer = I.W < Tokens.B.DrawerBelow
    local sideFrame = I.SidebarW - Tokens.B.SidebarGap
    local contentX = drawer and 24 or (sideFrame + 24)
    I.ContentX = contentX
    I.ContentW = I.W - contentX - Tokens.B.InsetRight
    I.ContentH = I.H - Tokens.B.ContentY - Tokens.B.InsetBottom
    local function set(inst, props)
        if animate and not Motion.Reduced then
            Motion:Play(inst, props, "Resize", "side")
        else
            Motion:Stop(inst, "side")
            for k, v in pairs(props) do
                inst[k] = v
            end
        end
    end
    if drawer ~= I.Drawer then
        I.Drawer = drawer
        I.DrawerOpen = false
        I.DrawerScrim.Visible = false
        I.MenuButton.Visible = drawer
        local logoX = drawer and 44 or 16
        if I.Logo then
            I.Logo.Position = UDim2.fromOffset(logoX, 12)
        end
        local wordX = I.Logo and (logoX + 30) or logoX
        I.Wordmark.Position = UDim2.fromOffset(wordX, 12)
        I.Wordmark.Size = UDim2.new(1, -(wordX + 90), 0, 22)
        I.DrawerEdge.Visible = drawer
        I.Sidebar.BackgroundTransparency = drawer and 0 or 1
        I.Sidebar.ZIndex = drawer and Tokens.Z.Drawer or Tokens.Z.Sidebar
        I.SidebarPad.PaddingTop = UDim.new(0, drawer and 4 or 0)
        Motion:Stop(I.Sidebar, "drawer")
    end
    if drawer then
        local dw = sideFrame + 20
        I.Sidebar.Size = UDim2.new(0, dw, 1, -I.BandH)
        I.Sidebar.Position = UDim2.fromOffset(I.DrawerOpen and 0 or -dw, I.BandH)
        I.Sidebar.Visible = I.DrawerOpen and not I.Loading
    else
        set(I.Sidebar, { Size = UDim2.new(0, sideFrame, 1, -Tokens.B.ContentY) })
        I.Sidebar.Position = UDim2.fromOffset(0, Tokens.B.ContentY)
        I.Sidebar.Visible = not I.Loading
    end
    set(I.Content, {
        Position = UDim2.fromOffset(contentX, Tokens.B.ContentY),
        Size = UDim2.new(1, -contentX - Tokens.B.InsetRight, 1, -Tokens.B.ContentY - Tokens.B.InsetBottom),
    })
    Shell.LayoutTabs(W)
end

function Shell.SetDrawer(W, open)
    local I = W._I
    open = open == true and I.Drawer
    if I.DrawerOpen == open then
        return
    end
    I.DrawerOpen = open
    local sidebar = I.Sidebar
    local dw = sidebar.Size.X.Offset
    if open then
        Overlays.ClosePopover(W)
        sidebar.Visible = not I.Loading
        I.DrawerScrim.Visible = true
        Motion:Play(I.DrawerScrim, { BackgroundTransparency = 0.35 }, "Scrim", "scrim")
        if Motion.Reduced then
            sidebar.Position = UDim2.fromOffset(0, I.BandH)
        else
            sidebar.Position = UDim2.fromOffset(-dw, I.BandH)
            Motion:Play(sidebar, { Position = UDim2.fromOffset(0, I.BandH) }, "Enter", "drawer")
        end
    else
        Motion:Play(I.DrawerScrim, { BackgroundTransparency = 1 }, "Exit", "scrim")
        local function finish()
            if not I.DrawerOpen and I.Drawer then
                sidebar.Visible = false
                I.DrawerScrim.Visible = false
            end
        end
        if Motion.Reduced then
            sidebar.Position = UDim2.fromOffset(-dw, I.BandH)
            finish()
        else
            Motion:Play(sidebar, { Position = UDim2.fromOffset(-dw, I.BandH) }, "Exit", "drawer")
            task.delay(Motion:GetInfo("Exit").Time, finish)
        end
    end
end

-- per-tab measure (F1): rows live in min(region, 640); stacked under 420; hooks let rows and panes follow
function Shell.LayoutTab(W, tab)
    local I = W._I
    local region = math.max(120, I.ContentW)
    local measure = math.min(region, Tokens.Size.ContentMax)
    if type(tab._measureFor) == "function" then
        local ok, value = pcall(tab._measureFor, tab, region, I.ContentH)
        if ok and type(value) == "number" then
            measure = math.max(120, value)
        end
    end
    measure = math.floor(measure + 0.5)
    local top = tab._pageTop or 0
    tab.Page.Position = UDim2.fromOffset(0, top)
    tab.Page.Size = UDim2.new(0, measure + 14, 1, -top)
    if tab.Measure == measure and tab._region == region and tab._regionH == I.ContentH then
        return
    end
    tab.Measure, tab._region, tab._regionH = measure, region, I.ContentH
    tab.Stacked = measure < Tokens.B.StackBelow
    for _, fn in ipairs(tab._layoutHooks) do
        local ok, err = pcall(fn, measure, tab.Stacked, region)
        if not ok then
            warn("[CAC UI] layout hook error: " .. tostring(err))
        end
    end
end

function Shell.LayoutTabs(W)
    for _, tab in ipairs(W.Tabs) do
        Shell.LayoutTab(W, tab)
    end
end

-- ------------------------------------------------------------------------------
-- tabs and groups
-- ------------------------------------------------------------------------------

function Shell.CreateTab(W, name, iconId, description, group, isConfig)
    local I = W._I
    name = tostring(name or "Tab")
    local Tab = {
        Name = name,
        Elements = {},
        Window = W,
        Group = group,
        IsConfig = isConfig == true,
        Measure = 572,
        Stacked = false,
        _rows = {},
        _order = 0,
        _layoutHooks = {},
    }
    for key, fn in pairs(TabMethods) do
        Tab[key] = fn
    end

    local root = Utility:Create("Frame", {
        Name = "Page_" .. name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = I.Content,
    })
    local page = Utility:Create("ScrollingFrame", {
        Name = "Page",
        Size = UDim2.new(0, 586, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        Theme = { ScrollBarImageColor3 = "TextMuted" },
        Parent = root,
    })
    Tab._pad = Utility:Padding(page, 0, 14, Tokens.B.InsetBottom, 0)
    Utility:List(page, Enum.FillDirection.Vertical, 0)
    Shell.AutoScrollbar(W, page)

    Tab._root = root
    Tab.Page = page

    local parent = group and group._inner or I.TabList
    local item = Shell.MakeItem(W, parent, name, iconId, group ~= nil, false)
    Tab._item = item
    Tab.BtnBg = item.Btn
    Tab.Btn = item.Btn
    Tab.Label = item.Label
    Tab.Icon = item.Icon
    Tab.Indicator = item.Indicator
    item.Btn.Activated:Connect(function()
        Tab:Show()
    end)

    table.insert(W.Tabs, Tab)
    Shell.LayoutTab(W, Tab)
    if group then
        Shell.RefreshGroup(group, false)
    end
    if not W.CurrentTab then
        Tab:Show()
    end
    return Tab
end

function TabMethods.Show(self)
    Shell.ShowTab(self.Window, self)
end

-- B draws no subtitles: kept for the API, does nothing
function TabMethods.SetDescription(self, text)
    self._description = tostring(text or "")
end

function Shell.ShowTab(W, tab)
    local I = W._I
    if W.IsDestroyed or not tab then
        return
    end
    Overlays.ClosePopover(W)
    if Overlays.HideTooltip then
        Overlays.HideTooltip(W)
    end
    local previous = W.CurrentTab
    if previous and previous ~= tab then
        previous._root.Visible = false
        Shell.PaintItem(previous._item, false)
    end
    W.CurrentTab = tab
    tab._root.Visible = true
    Shell.PaintItem(tab._item, true)
    if tab.Group and not tab.Group.Open then
        tab.Group:SetOpen(true)
    end
    for _, group in ipairs(I.Groups) do
        Shell.PaintGroup(group)
    end
    if I.DrawerOpen then
        Shell.SetDrawer(W, false)
    end
    Shell.LayoutTab(W, tab)
    Shell.UpdateBackdrop(W, previous ~= nil)
    if previous and previous ~= tab and not Motion.Reduced and not I.Loading then
        local fader = Utility:Fader(tab._root)
        fader:Set(1)
        fader:Tween(0, "State")
    end
end

function Shell.CreateGroup(W, name, iconId)
    local I = W._I
    name = tostring(name or "Group")
    local Group = { Name = name, Tabs = {}, Open = true, Window = W }
    local item = Shell.MakeItem(W, I.TabList, name, iconId, false, true)
    local holder = Utility:Create("Frame", {
        Name = "Children_" .. name,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = I.TabList,
    })
    -- MakeItem already advanced the order; the holder sorts right after its header
    I.ItemOrder = I.ItemOrder + 1
    holder.LayoutOrder = I.ItemOrder
    local inner = Utility:Create("Frame", {
        Name = "Inner",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder,
    })
    Utility:List(inner, Enum.FillDirection.Vertical, 0)

    Group.Btn = item.Btn
    Group.BtnBg = item.Btn
    Group.Label = item.Label
    Group.Icon = item.Icon
    Group.Chevron = item.Chevron
    Group.ChildrenHolder = holder
    Group._item = item
    Group._inner = inner

    function Group:CreateTab(subName, subIconId)
        local tab = Shell.CreateTab(W, subName, subIconId, nil, Group, false)
        table.insert(Group.Tabs, tab)
        Shell.RefreshGroup(Group, false)
        return tab
    end

    function Group:SetOpen(open)
        Group.Open = open == true
        Shell.RefreshGroup(Group, true)
        Shell.PaintGroup(Group)
    end

    function Group:Toggle()
        Group:SetOpen(not Group.Open)
    end

    item.Btn.Activated:Connect(function()
        Group:Toggle()
    end)

    table.insert(I.Groups, Group)
    Shell.RefreshGroup(Group, false)
    return Group
end

-- closed group with the active tab inside: the header carries the active cue
function Shell.PaintGroup(group)
    local W = group.Window
    local active = false
    if not group.Open and W.CurrentTab and W.CurrentTab.Group == group then
        active = true
    end
    Shell.PaintItem(group._item, active)
end

function Shell.RefreshGroup(group, animate)
    local full = 0
    for _, tab in ipairs(group.Tabs) do
        local btn = tab._item and tab._item.Btn
        if btn and btn.Visible then
            full = full + btn.Size.Y.Offset
        end
    end
    local target = group.Open and full or 0
    local size = UDim2.new(1, 0, 0, target)
    if animate and not Motion.Reduced then
        Motion:Play(group.ChildrenHolder, { Size = size }, Motion.Info.State, "size")
    else
        Motion:Stop(group.ChildrenHolder, "size")
        group.ChildrenHolder.Size = size
    end
    if group.Chevron then
        local rot = group.Open and 0 or -90
        if animate and not Motion.Reduced then
            Motion:Play(group.Chevron, { Rotation = rot }, "State", "rot")
        else
            group.Chevron.Rotation = rot
        end
    end
end

-- ------------------------------------------------------------------------------
-- window transitions (veil fade + 0.98 scale; no CanvasGroup over the whole window)
-- ------------------------------------------------------------------------------

function Shell.WindowExit(W, onDone)
    local I = W._I
    W._TransitionId = (W._TransitionId or 0) + 1
    local id = W._TransitionId
    Overlays.ClosePopover(W)
    if Overlays.HideTooltip then
        Overlays.HideTooltip(W)
    end
    local frame = I.MainFrame
    if not frame.Visible then
        Shell.UpdateBackdrop(W, false)
        if onDone then
            onDone()
        end
        return
    end
    local token = Motion.Reduced and "Fade" or "Exit"
    I.Veil.Visible = true
    Motion:Play(I.Veil, { BackgroundTransparency = 0 }, token, "veil")
    if not Motion.Reduced then
        Motion:Play(I.UIScale, { Scale = I.Scale * 0.98 }, token, "scale")
    end
    task.delay(Motion:GetInfo(token).Time, function()
        if W.IsDestroyed or W._TransitionId ~= id then
            return
        end
        frame.Visible = false
        I.Veil.Visible = false
        I.Veil.BackgroundTransparency = 1
        I.UIScale.Scale = I.Scale
        Shell.UpdateBackdrop(W, false)
        if onDone then
            onDone()
        end
    end)
end

function Shell.WindowEnter(W, target, fromPos)
    local I = W._I
    W._TransitionId = (W._TransitionId or 0) + 1
    local id = W._TransitionId
    local frame = I.MainFrame
    local token = Motion.Reduced and "Fade" or "EnterLarge"
    Motion:Stop(frame, "pos")
    if fromPos and not Motion.Reduced then
        frame.Position = fromPos
        Motion:Play(frame, { Position = target }, token, "pos")
    else
        frame.Position = target
    end
    I.Veil.Visible = true
    I.Veil.BackgroundTransparency = 0
    if not Motion.Reduced then
        I.UIScale.Scale = I.Scale * 0.97
        Motion:Play(I.UIScale, { Scale = I.Scale }, token, "scale")
    end
    frame.Visible = true
    Shell.UpdateBackdrop(W, false)
    Motion:Play(I.Veil, { BackgroundTransparency = 1 }, token, "veil")
    task.delay(Motion:GetInfo(token).Time + 0.02, function()
        if not W.IsDestroyed and W._TransitionId == id then
            I.Veil.Visible = false
        end
    end)
end

function Shell.ShowMiniBar(W)
    local I = W._I
    local holder = I.MiniBar
    local frame = I.MainFrame
    local topLeft = Shell.ToGui(W, frame.AbsolutePosition)
    local width = math.clamp(I.W * 0.45, 260, 420)
    holder.Size = UDim2.fromOffset(width, I.Family == "Compact" and Tokens.Size.MiniBarCompact or Tokens.Size.MiniBar)
    local target = UDim2.fromOffset(topLeft.X, topLeft.Y)
    holder.Visible = true
    if I.MiniFader == nil then
        I.MiniFader = Utility:Fader(holder)
    end
    if Motion.Reduced then
        holder.Position = target
        I.MiniFader:Set(1)
        I.MiniFader:Tween(0, "Fade")
    else
        holder.Position = target + UDim2.fromOffset(0, 6)
        I.MiniFader:Set(1)
        I.MiniFader:Tween(0, "Enter")
        Motion:Play(holder, { Position = target }, "Enter", "pos")
    end
end

function Shell.HideMiniBar(W)
    local I = W._I
    if I.MiniBar.Visible then
        Motion:Stop(I.MiniBar, "pos")
        if I.MiniFader then
            I.MiniFader:Set(0)
        end
        I.MiniBar.Visible = false
    end
end

-- ------------------------------------------------------------------------------
-- window methods
-- ------------------------------------------------------------------------------

function WindowMethods:CreateTab(name, iconId, description)
    return Shell.CreateTab(self, name, iconId, description, nil, false)
end

function WindowMethods:CreateTabGroup(name, iconId)
    return Shell.CreateGroup(self, name, iconId)
end

function WindowMethods:Minimize(silent)
    if self.IsDestroyed or self.IsMinimized then
        return
    end
    self.IsMinimized = true
    self.IsHidden = false
    self.IsToggled = false
    local W = self
    local id
    Shell.WindowExit(self, function()
        if W.IsMinimized and W._TransitionId == id then
            Shell.ShowMiniBar(W)
        end
    end)
    id = self._TransitionId
    if not self._I.MainFrame.Visible and not self._I.MiniBar.Visible then
        Shell.ShowMiniBar(self)
    end
    Shell.UpdateReopen(self)
    if not silent then
        self:Notify({
            Title = "Script Hidden",
            Content = "To open the script again, press " .. KeyText(self.ToggleKey) .. ".",
            Duration = 3.2,
        })
    end
end

function WindowMethods:Restore(silent)
    if self.IsDestroyed then
        return
    end
    if not self.IsMinimized and not self.IsHidden then
        return
    end
    local I = self._I
    local wasMinimized = self.IsMinimized
    self.IsMinimized = false
    self.IsHidden = false
    self.IsToggled = true
    local target = (I.Family == "Compact" and I.CompactPos) or self.SavedOpenPosition or I.MainFrame.Position
    local fromPos = nil
    if wasMinimized and I.MiniBar.Visible then
        local view = Shell.ViewSize(self)
        local tx = target.X.Scale * view.X + target.X.Offset
        local ty = target.Y.Scale * view.Y + target.Y.Offset
        local mini = Shell.ToGui(self, I.MiniBar.AbsolutePosition + I.MiniBar.AbsoluteSize / 2)
        fromPos = UDim2.fromOffset(tx + (mini.X - tx) * 0.2, ty + (mini.Y - ty) * 0.2)
    end
    Shell.HideMiniBar(self)
    Shell.WindowEnter(self, target, fromPos)
    Shell.UpdateReopen(self)
    if not silent then
        self:Notify({
            Title = "Window Opened",
            Content = "UI restored. Press " .. KeyText(self.ToggleKey) .. " to hide again.",
            Duration = 2.5,
        })
    end
end

function WindowMethods:HideAll(silent)
    if self.IsDestroyed then
        return
    end
    self.IsMinimized = false
    self.IsHidden = true
    self.IsToggled = false
    Shell.WindowExit(self)
    Shell.HideMiniBar(self)
    Shell.UpdateReopen(self)
    if not silent then
        self:Notify({
            Title = "Script Hidden",
            Content = "To open the script again, press " .. KeyText(self.ToggleKey) .. ".",
            Duration = 3.2,
        })
    end
end

function WindowMethods:ToggleVisible(forceState, silent)
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

function WindowMethods:HideWithPrompt()
    self:HideAll(false)
end

function WindowMethods:SetToggleKey(newKey)
    local resolved = NormalizeKeyCode(newKey, nil)
    if resolved then
        self.ToggleKey = resolved
        Library.Keybind = resolved
        return true
    end
    return false
end

function WindowMethods:SetSize(width, height)
    local Lm = Tokens.Limits
    local I = self._I
    I.Width = ClampNumber(width, Lm.WidthMin, Lm.WidthMax)
    I.Height = ClampNumber(height, Lm.HeightMin, Lm.HeightMax)
    self.SavedOpenSize = UDim2.fromOffset(I.Width, I.Height)
    Shell.Relayout(self, true)
end

function WindowMethods:SetSidebarWidth(value)
    local Lm = Tokens.Limits
    self._I.SidebarW = ClampNumber(value, Lm.SidebarMin, Lm.SidebarMax)
    Shell.Relayout(self, true)
end

function WindowMethods:SetUIScale(scale)
    local Lm = Tokens.Limits
    self._I.UserScale = ClampNumber(scale, Lm.ScaleMin, Lm.ScaleMax)
    Shell.Relayout(self, false)
end

-- the rejected core's icon rail is gone; kept as a no-op so old calls do not fail
function WindowMethods:SetCompactSidebar(enabled)
    self._I.CompactSidebar = enabled == true
end

function WindowMethods:SetTheme(themeName)
    if ThemeManager:SetTheme(themeName) then
        self.ThemeName = themeName
        self.Accent = ThemeManager:Get("Accent")
        return true
    end
    return false
end

function WindowMethods:SetAccent(color)
    if ThemeManager:SetAccent(color) then
        self.Accent = color
        return true
    end
    return false
end

function WindowMethods:SetReducedMotion(enabled)
    Motion.UserReduced = enabled == true
    Motion:Refresh()
end

-- backdrop (F8): "My Avatar" | "Block City"
function WindowMethods:SetBackdrop(mode)
    local B = self._I.Backdrop
    mode = tostring(mode or "")
    if not table.find(Art.BackdropOptions, mode) then
        return false
    end
    if B.Mode ~= mode or not B.Source then
        B.Mode = mode
        Shell.ApplyBackdrop(self)
    end
    if self._I.SyncBackdropRows then
        self._I.SyncBackdropRows()
    end
    return true
end

function WindowMethods:SetBackdropStrength(value)
    self._I.Backdrop.Strength = ClampNumber(value, 0, 100)
    Shell.UpdateBackdrop(self, false)
end

function WindowMethods:SetBackdropHidePreview(enabled)
    self._I.Backdrop.HidePreview = enabled ~= false
    Shell.UpdateBackdrop(self, true)
end

-- B shows no status strip (tell 4): the text is kept for products that set it, nothing is drawn
function WindowMethods:SetStatus(text, kind)
    self._I.StatusText = text ~= nil and tostring(text) or nil
    self._I.StatusKind = kind
end

function WindowMethods:FinishLoading()
    if self.IsLoaded then
        return
    end
    self.IsLoaded = true
    local I = self._I
    local layer = I.Loading
    if not layer then
        return
    end
    pcall(function()
        Utility:Fader(I.LoadingColumn):Tween(1, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    end)
    task.wait(0.15)
    I.Loading = nil
    if self.IsDestroyed then
        return
    end
    I.Content.Visible = true
    I.Sidebar.Visible = not I.Drawer or I.DrawerOpen
    if not Motion.Reduced then
        pcall(function()
            local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            local parts = { I.Sidebar }
            if self.CurrentTab then
                table.insert(parts, self.CurrentTab._root)
            end
            for _, part in ipairs(parts) do
                local fader = Utility:Fader(part)
                fader:Set(1)
                fader:Tween(0, info)
            end
        end)
    end
    task.wait(0.35)
    pcall(function()
        layer:Destroy()
    end)
end

function WindowMethods:Destroy()
    if self.IsDestroyed then
        return
    end
    local I = self._I
    pcall(Overlays.ClosePopover, self)
    self.IsDestroyed = true
    I.Drag = nil
    I.Capture = nil
    I.Loading = nil
    I.Trove:Clean()
end

-- ==============================================================================
-- 9) OVERLAYS: popovers, tooltip, toasts, modal (Confirm, Dialog), action bar
--    Opaque Background surfaces with the 1 px edge (F3); no shadow, no badges.
-- ==============================================================================

-- popovers (dropdown lists and similar) live in the Overlay layer under Window.UI.GUI
function Overlays.ClosePopover(W)
    local I = W and W._I
    if not I or not I.Popover then
        return
    end
    local pop = I.Popover
    I.Popover = nil
    if pop.Close then
        pcall(pop.Close)
    end
end

-- pop = { Frame = GuiObject, Anchor = GuiObject?, Close = function }
-- F4: nothing opens above a modal scrim (the popover is closed again at once)
function Overlays.OpenPopover(W, pop)
    Overlays.ClosePopover(W)
    if W._I.ModalCount > 0 then
        if pop and pop.Close then
            task.defer(pcall, pop.Close)
        end
        return false
    end
    W._I.Popover = pop
    return true
end

-- anchor rectangle in Overlay layer units (the layer carries the window scale)
function Overlays.AnchorRect(W, gui)
    local s = W._I.OverlayScale.Scale
    local pos = Shell.ToGui(W, gui.AbsolutePosition)
    return pos.X / s, pos.Y / s, gui.AbsoluteSize.X / s, gui.AbsoluteSize.Y / s
end

-- places `frame` under the anchor (or above when there is no room); returns true when above
function Overlays.Place(W, anchor, frame, width, height, gap)
    gap = gap or 0
    local s = W._I.OverlayScale.Scale
    local view = Shell.ViewSize(W)
    local vw, vh = view.X / s, view.Y / s
    local x, y, _, h = Overlays.AnchorRect(W, anchor)
    local top = y + h + gap
    local above = false
    if top + height > vh - 8 and y - gap - height >= 8 then
        top = y - gap - height
        above = true
    end
    local left = math.clamp(x, 8, math.max(8, vw - width - 8))
    frame.Position = UDim2.fromOffset(left, top)
    return above
end

-- ------------------------------------------------------------------------------
-- tooltip (one per window): Background, edge, 12 Regular; 0.45 s hover, 0.5 s long press on touch
-- ------------------------------------------------------------------------------

function Overlays.GetTip(W)
    local I = W._I
    if I.Tip and I.Tip.Frame.Parent then
        return I.Tip
    end
    local frame = Utility:Create("Frame", {
        Name = "Tooltip",
        Size = UDim2.new(),
        AutomaticSize = Enum.AutomaticSize.XY,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.Overlay,
    })
    Utility:Edge(frame)
    Utility:Padding(frame, 5, 8, 5, 8)
    local label = Utility:Text("TextLabel", {
        Name = "Text",
        Size = UDim2.new(),
        AutomaticSize = Enum.AutomaticSize.XY,
        Text = "",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Caption,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 51,
        Color = "Text",
        Parent = frame,
    })
    Utility:Create("UISizeConstraint", { MaxSize = Vector2.new(244, math.huge), Parent = label })
    I.Tip = { Frame = frame, Label = label }
    return I.Tip
end

function Overlays.ShowTooltip(W, owner, text, delay, hold)
    local I = W._I
    if W.IsDestroyed or type(text) ~= "string" or text == "" or not owner or I.ModalCount > 0 then
        return
    end
    I.TipOwner = owner
    I.TipToken = (I.TipToken or 0) + 1
    local token = I.TipToken
    task.delay(delay or 0.45, function()
        if W.IsDestroyed or I.TipToken ~= token or I.TipOwner ~= owner or not owner.Parent or not owner.Visible then
            return
        end
        local tip = Overlays.GetTip(W)
        tip.Label.Text = text
        tip.Frame.Visible = true
        tip.Frame.Position = UDim2.fromOffset(-1000, -1000)
        RunService.Heartbeat:Wait()
        if I.TipToken ~= token then
            return
        end
        local s = I.OverlayScale.Scale
        local view = Shell.ViewSize(W)
        local x, y, w, h = Overlays.AnchorRect(W, owner)
        local tw, th = tip.Frame.AbsoluteSize.X / s, tip.Frame.AbsoluteSize.Y / s
        local top = y - th - 6
        if top < 8 then
            top = y + h + 6
        end
        local left = math.clamp(x + w / 2 - tw / 2, 8, math.max(8, view.X / s - tw - 8))
        tip.Frame.Position = UDim2.fromOffset(left, top)
        if hold then
            task.delay(hold, function()
                if I.TipToken == token then
                    Overlays.HideTooltip(W, owner)
                end
            end)
        end
    end)
end

function Overlays.HideTooltip(W, owner)
    local I = W._I
    if owner ~= nil and I.TipOwner ~= owner then
        return
    end
    I.TipToken = (I.TipToken or 0) + 1
    I.TipOwner = nil
    if I.Tip then
        I.Tip.Frame.Visible = false
    end
end

-- wires a tooltip on `owner`: getText() returns the text or nil (nil = no tooltip right now)
function Overlays.AttachTooltip(W, owner, getText)
    local function text()
        if type(getText) == "function" then
            local ok, value = pcall(getText)
            return ok and value or nil
        end
        return getText
    end
    owner.MouseEnter:Connect(function()
        local t = text()
        if t then
            Overlays.ShowTooltip(W, owner, t)
        end
    end)
    owner.MouseLeave:Connect(function()
        Overlays.HideTooltip(W, owner)
    end)
    owner.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local t = text()
            if t then
                Overlays.ShowTooltip(W, owner, t, 0.5, 2.5)
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseWheel then
            Overlays.HideTooltip(W, owner)
        end
    end)
    owner.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and W._I.TipOwner == owner and not (W._I.Tip and W._I.Tip.Frame.Visible) then
            Overlays.HideTooltip(W, owner)
        end
    end)
end

-- ------------------------------------------------------------------------------
-- toasts (F2): opaque edged cards, bottom right, newest at the bottom; repeats refresh silently
-- ------------------------------------------------------------------------------

Overlays.ToastKinds = { Info = true, Success = true, Warning = "Warning", Error = "Error" }

function Overlays.ToastCap(W)
    return W._I.Family == "Compact" and 2 or 3
end

function Overlays.Notify(W, config)
    if type(config) ~= "table" then
        config = {}
    end
    if W.IsDestroyed or W.NotificationsEnabled == false then
        return nil
    end
    local I = W._I
    local T = I.Toasts
    local title = tostring(config.Title or "Notification")
    local content = tostring(config.Content or "...")
    local duration = math.max(tonumber(config.Duration) or 4, 0.5)
    local kind = config.Type or config.Kind
    if kind == nil then
        -- the products pass no kind: titles like "Error", "Export failed" or "Slow Scan Warning" get the edge
        local low = string.lower(title)
        if string.find(low, "error", 1, true) or string.find(low, "fail", 1, true) then
            kind = "Error"
        elseif string.find(low, "warning", 1, true) then
            kind = "Warning"
        end
    end
    if not Overlays.ToastKinds[kind] then
        kind = "Info"
    end
    local now = os.clock()

    -- same title and content while visible: restart its timer, no visual change
    for _, t in ipairs(T.Visible) do
        if not t.Closing and t.Title == title and t.Content == content then
            t.Remaining = math.max(t.Duration, duration)
            t.Duration = t.Remaining
            task.wait(0.08)
            return t.Handle
        end
    end
    for _, t in ipairs(T.Queue) do
        if t.Title == title and t.Content == content then
            t.Created = now
            task.wait(0.08)
            return t.Handle
        end
    end

    local entry = {
        Title = title,
        Content = content,
        Duration = duration,
        Kind = kind,
        Created = now,
    }
    entry.Handle = {
        Dismiss = function()
            Overlays.DismissToast(W, entry)
        end,
    }
    if #T.Visible >= Overlays.ToastCap(W) then
        table.insert(T.Queue, entry)
        while #T.Queue > 8 do
            table.remove(T.Queue, 1)
        end
    else
        Overlays.ShowToast(W, entry)
    end
    Overlays.EnsureTicker(W)
    task.wait(0.08)
    return entry.Handle
end

function Overlays.ToastWidth(W)
    local I = W._I
    if I.Family == "Compact" then
        local view = Shell.ViewSize(W)
        return math.min(320, view.X / I.ToastScale.Scale - 32)
    end
    return Tokens.Size.Toast
end

function Overlays.BuildToast(W, entry)
    local I = W._I
    local width = Overlays.ToastWidth(W)
    local holder = Utility:Create("TextButton", {
        Name = "Toast",
        Size = UDim2.fromOffset(width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        Selectable = false,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.ToastLayer,
    })
    Utility:Edge(holder)
    local edgeKey = Overlays.ToastKinds[entry.Kind]
    if type(edgeKey) == "string" then
        Utility:Create("Frame", {
            Name = "Kind",
            Size = UDim2.new(0, 2, 1, 0),
            BorderSizePixel = 0,
            ZIndex = 2,
            Theme = { BackgroundColor3 = edgeKey },
            Parent = holder,
        })
    end
    local inner = Utility:Create("Frame", {
        Name = "Inner",
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder,
    })
    Utility:Padding(inner, 11, 14, 12, 14)
    Utility:List(inner, Enum.FillDirection.Vertical, 3)
    local textW = width - 28
    local titleH = math.ceil(Utility:Measure(entry.Title, 14, "Medium", textW).Y)
    Utility:Text("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, titleH),
        Text = entry.Title,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 1,
        Color = "Text",
        Parent = inner,
    })
    local line = math.ceil(Utility:Measure("Ag", 13, "Regular", 1000).Y)
    local bodyH = math.min(math.ceil(Utility:Measure(entry.Content, 13, "Regular", textW).Y), line * 4)
    Utility:Text("TextLabel", {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, bodyH),
        Text = entry.Content,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Color = "TextDark",
        Parent = inner,
    })
    entry.Height = 11 + titleH + 3 + bodyH + 12
    entry.Holder = holder
    holder.MouseEnter:Connect(function()
        entry.Hovered = true
    end)
    holder.MouseLeave:Connect(function()
        entry.Hovered = false
    end)
    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            entry.Hovered = true
        end
    end)
    holder.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            entry.Hovered = false
        end
    end)
    holder.Activated:Connect(function()
        Overlays.DismissToast(W, entry)
    end)
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not entry.Closing then
            Overlays.LayoutToasts(W, true)
        end
    end)
    return entry
end

function Overlays.ShowToast(W, entry)
    local I = W._I
    local T = I.Toasts
    entry.Remaining = entry.Duration
    Overlays.BuildToast(W, entry)
    table.insert(T.Visible, 1, entry)
    entry.Fader = Utility:Fader(entry.Holder)
    Overlays.LayoutToasts(W, true)
    local target = entry.Holder.Position
    entry.Fader:Set(1)
    if Motion.Reduced then
        entry.Fader:Tween(0, "Fade")
    else
        local dx = I.Family == "Compact" and 0 or 12
        entry.Holder.Position = target + UDim2.fromOffset(dx, I.Family == "Compact" and -6 or 0)
        entry.Fader:Tween(0, "Enter")
        Motion:Play(entry.Holder, { Position = target }, "Enter", "pos")
    end
end

-- desktop: bottom right of the safe area, newest at the bottom, stacking upward; touch phones: top centre, downward
function Overlays.LayoutToasts(W, animate)
    local I = W._I
    local T = I.Toasts
    if not T or #T.Visible == 0 then
        return
    end
    local s = I.ToastScale.Scale
    local view = Shell.ViewSize(W)
    local compact = I.Family == "Compact"
    local width = Overlays.ToastWidth(W)
    local x = compact and (view.X / s / 2) or (view.X / s - 16)
    local y = compact and ((Utility:GetTopInset() + 8) / s) or (view.Y / s - 16)
    for _, t in ipairs(T.Visible) do
        local holder = t.Holder
        holder.AnchorPoint = compact and Vector2.new(0.5, 0) or Vector2.new(1, 1)
        holder.Size = UDim2.fromOffset(width, 0)
        local target = UDim2.fromOffset(x, y)
        if t.Placed and animate and not Motion.Reduced then
            if holder.Position.Y.Offset ~= y or holder.Position.X.Offset ~= x then
                Motion:Play(holder, { Position = target }, "Move", "pos", math.abs(holder.Position.Y.Offset - y))
            end
        else
            Motion:Stop(holder, "pos")
            holder.Position = target
        end
        t.Placed = true
        local h = holder.AbsoluteSize.Y / s
        if h < 20 then
            h = t.Height or 64
        end
        if compact then
            y = y + h + 8
        else
            y = y - h - 8
        end
    end
end

function Overlays.DismissToast(W, entry)
    local I = W._I
    local T = I.Toasts
    if entry.Closing then
        return
    end
    entry.Closing = true
    local index = table.find(T.Visible, entry)
    if index then
        table.remove(T.Visible, index)
    else
        local q = table.find(T.Queue, entry)
        if q then
            table.remove(T.Queue, q)
        end
        return
    end
    local holder = entry.Holder
    if holder then
        if entry.Fader then
            entry.Fader:Tween(1, Motion.Reduced and "Fade" or "Exit")
        end
        task.delay(0.16, function()
            pcall(function()
                holder:Destroy()
            end)
        end)
    end
    Overlays.LayoutToasts(W, true)
    Overlays.EnsureTicker(W)
end

-- one ticker per window, alive only while toasts exist
function Overlays.EnsureTicker(W)
    local I = W._I
    local T = I.Toasts
    if T.Ticking then
        return
    end
    T.Ticking = true
    task.spawn(function()
        local last = os.clock()
        while not W.IsDestroyed and (#T.Visible > 0 or #T.Queue > 0) do
            task.wait(0.1)
            local now = os.clock()
            local dt = now - last
            last = now
            for i = #T.Visible, 1, -1 do
                local t = T.Visible[i]
                if t and not t.Closing and not t.Hovered then
                    t.Remaining = t.Remaining - dt
                    if t.Remaining <= 0 then
                        Overlays.DismissToast(W, t)
                    end
                end
            end
            for i = #T.Queue, 1, -1 do
                if now - T.Queue[i].Created > 15 then
                    table.remove(T.Queue, i)
                end
            end
            while #T.Visible < Overlays.ToastCap(W) and #T.Queue > 0 and not W.IsDestroyed do
                Overlays.ShowToast(W, table.remove(T.Queue, 1))
            end
        end
        T.Ticking = false
    end)
end

-- ------------------------------------------------------------------------------
-- modal (Confirm and Dialog, F4): text on the scrim at content x, B action rows, countdown line
-- ------------------------------------------------------------------------------

-- B action row: arrow glyph + label; hover nudges 2 px right, press dims to TextDark
function Overlays.ActionRow(W, parent, text, danger, order, onClick)
    local row = Utility:Create("TextButton", {
        Name = "Action_" .. tostring(order),
        Size = UDim2.new(1, 0, 0, W._I.Family == "Compact" and Tokens.Size.RowCompact or Tokens.Size.Row),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = order,
        SelectionImageObject = W._I.SelectRing,
        Parent = parent,
    })
    local restKey = danger and "Error" or "Text"
    local glyph = Glyph.Draw(row, "arrow", 14, restKey, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
    local label = Utility:Text("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Text = text,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = restKey,
        Parent = row,
    })
    local hovered = false
    local function nudge(on)
        if Motion.Reduced then
            return
        end
        Motion:Play(glyph, { Position = UDim2.new(0, on and 2 or 0, 0.5, 0) }, "Hover", "nudge")
        Motion:Play(label, { Position = UDim2.fromOffset(on and 26 or 24, 0) }, "Hover", "nudge")
    end
    row.MouseEnter:Connect(function()
        hovered = true
        nudge(true)
    end)
    row.MouseLeave:Connect(function()
        hovered = false
        nudge(false)
        Glyph.Paint(glyph, restKey, "Hover")
        Utility:SetColor(label, "TextColor3", restKey, "Hover")
    end)
    row.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(glyph, "TextDark", "Press")
            Utility:SetColor(label, "TextColor3", "TextDark", "Press")
        end
    end)
    row.InputEnded:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(glyph, restKey, "Release")
            Utility:SetColor(label, "TextColor3", restKey, "Release")
        end
    end)
    row.Activated:Connect(function()
        if onClick then
            onClick()
        end
    end)
    return row, label, glyph, function()
        return hovered
    end
end

-- closes everything that could sit above or beside the scrim
function Overlays.ClearForModal(W)
    Overlays.ClosePopover(W)
    Overlays.HideTooltip(W)
    pcall(Shell.SetDrawer, W, false)
    if Overlays.ClosePalette then
        pcall(Overlays.ClosePalette, W)
    end
end

-- spec: { Title, Content, Buttons = {texts in display order}, Primary = index, Danger = index, Timeout,
-- TimeoutIndex, EscapeIndex } -> chosen index (TimeoutIndex on timeout, 0 if the window is destroyed)
function Overlays.Modal(W, spec)
    local I = W._I
    if W.IsDestroyed then
        return 0
    end
    if W.IsMinimized or W.IsHidden then
        W:Restore(true)
    end
    local frame = I.MainFrame
    frame.Visible = true
    Overlays.ClearForModal(W)
    I.ModalCount = I.ModalCount + 1
    local timeout = spec.Timeout
    local measure = (W.CurrentTab and W.CurrentTab.Measure) or I.ContentW
    local width = math.max(200, math.min(360, measure, I.W - I.ContentX - 24))

    local scrim = Utility:Create("TextButton", {
        Name = "ModalScrim",
        Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Selectable = false,
        ZIndex = Tokens.Z.Modal,
        Theme = { BackgroundColor3 = "Background" },
        Parent = frame,
    })
    local card = Utility:Create("Frame", {
        Name = "Modal",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, I.ContentX, 0.5, 0),
        Size = UDim2.fromOffset(width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = Tokens.Z.Modal + 1,
        Parent = scrim,
    })
    Utility:List(card, Enum.FillDirection.Vertical, 0)
    Utility:Text("TextLabel", {
        Name = "Title",
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = spec.Title,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Dialog,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Color = "Text",
        Parent = card,
    })
    local hasContent = spec.Content ~= ""
    if hasContent then
        Utility:Create("Frame", { Name = "Gap1", Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 2, Parent = card })
        Utility:Text("TextLabel", {
            Name = "Content",
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = spec.Content,
            Font = { "Sans", "Regular" },
            TextSize = Tokens.Text.Label,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 3,
            Color = "TextDark",
            Parent = card,
        })
    end
    Utility:Create("Frame", { Name = "Gap2", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 4, Parent = card })

    local decided, result = false, 0
    local function choose(index)
        if decided then
            return
        end
        decided = true
        result = index
    end
    local rows = {}
    local countdown = nil
    for index, text in ipairs(spec.Buttons) do
        local row, label = Overlays.ActionRow(W, card, tostring(text), index == spec.Danger, 10 + index, function()
            choose(index)
        end)
        rows[index] = row
        if timeout and index == spec.TimeoutIndex then
            local textW = math.ceil(Utility:Measure(tostring(text), Tokens.Text.Label, "Regular", 10000).X)
            countdown = Utility:Create("Frame", {
                Name = "Countdown",
                Position = UDim2.new(0, 24, 0.5, 10),
                Size = UDim2.fromOffset(textW, 1),
                BorderSizePixel = 0,
                Theme = { BackgroundColor3 = "TextDark" },
                Parent = row,
            })
            label.Name = "Label"
        end
    end
    local function keyHandler(input)
        local key = input.KeyCode
        if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
            if not UserInputService:GetFocusedTextBox() then
                choose(spec.Primary or 1)
                return true
            end
        elseif key == Enum.KeyCode.Escape and spec.EscapeIndex then
            choose(spec.EscapeIndex)
            return true
        end
        return false
    end
    table.insert(I.KeyHandlers, keyHandler)
    local firstRow = rows[spec.Primary or 1]
    if UserInputService.GamepadEnabled and firstRow then
        pcall(function()
            GuiService.SelectedObject = firstRow
        end)
    end

    local fader = Utility:Fader(card)
    fader:Set(1)
    Motion:Play(scrim, { BackgroundTransparency = 0.06 }, "Scrim", "scrim")
    fader:Tween(0, Motion.Reduced and "Fade" or "Enter")
    if countdown then
        Motion:Play(countdown, { Size = UDim2.fromOffset(0, 1) }, timeout, "timer")
    end

    local started = os.clock()
    while not decided do
        if W.IsDestroyed then
            decided = true
            result = 0
            break
        end
        if timeout and os.clock() - started >= timeout then
            choose(spec.TimeoutIndex or 0)
            break
        end
        task.wait(0.05)
    end

    local h = table.find(I.KeyHandlers, keyHandler)
    if h then
        table.remove(I.KeyHandlers, h)
    end
    if not W.IsDestroyed then
        pcall(function()
            if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(scrim) then
                GuiService.SelectedObject = nil
            end
        end)
        local out = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        fader:Tween(1, out)
        Motion:Play(scrim, { BackgroundTransparency = 1 }, out, "scrim")
        task.wait(0.12)
    end
    I.ModalCount = math.max(0, I.ModalCount - 1)
    pcall(function()
        scrim:Destroy()
    end)
    return result
end

function Overlays.Confirm(W, config)
    config = type(config) == "table" and config or {}
    if W.IsDestroyed then
        return false
    end
    local timeout = ClampNumber(config.Timeout or 10, 3, 60)
    local timeoutResult = config.TimeoutResult
    if timeoutResult == nil then
        timeoutResult = config.DefaultResult
    end
    local defaultIndex = timeoutResult == true and 1 or 2
    local index = Overlays.Modal(W, {
        Title = tostring(config.Title or "Confirmation"),
        Content = tostring(config.Content or "Continue?"),
        Buttons = { tostring(config.ConfirmText or "Yes"), tostring(config.CancelText or "No") },
        Primary = defaultIndex,
        Danger = config.Danger == true and 1 or nil,
        Timeout = timeout,
        TimeoutIndex = defaultIndex,
        EscapeIndex = 2,
    })
    return index == 1
end

-- General dialog: returns the index of the chosen button (0 if the window is gone).
function Overlays.Dialog(W, config)
    config = type(config) == "table" and config or {}
    if W.IsDestroyed then
        return 0
    end
    local buttons = type(config.Buttons) == "table" and #config.Buttons > 0 and config.Buttons or { "OK" }
    local timeout = config.Timeout and ClampNumber(config.Timeout, 3, 120) or nil
    local timeoutIndex = math.clamp(math.floor(tonumber(config.TimeoutIndex) or 1), 1, #buttons)
    return Overlays.Modal(W, {
        Title = tostring(config.Title or "Notice"),
        Content = tostring(config.Content or ""),
        Buttons = buttons,
        Primary = tonumber(config.Primary) or timeoutIndex,
        Danger = tonumber(config.Danger),
        Timeout = timeout,
        TimeoutIndex = timeoutIndex,
    })
end

-- ------------------------------------------------------------------------------
-- action bar (F9): opaque edged bar under the window, text + one arrow action; follows the window
-- ------------------------------------------------------------------------------

function Overlays.EnsureActionBar(W)
    local I = W._I
    if I.ActionBar and I.ActionBar.Parent then
        return I.ActionBar
    end
    local holder = Utility:Create("Frame", {
        Name = "ActionBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(420, 42),
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
        ZIndex = Tokens.Z.ActionBar,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.GUI,
    })
    Utility:Edge(holder)
    I.ActionScale = Utility:Create("UIScale", { Scale = I.Scale, Parent = holder })
    local button = Utility:Create("TextButton", {
        Name = "Button",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 100, 1, 0),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        SelectionImageObject = I.SelectRing,
        Parent = holder,
    })
    local glyph = Glyph.Draw(button, "arrow", 14, "Text", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
    local buttonLabel = Utility:Text("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -40, 1, 0),
        Text = "Cancel",
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Enum.TextXAlignment.Left,
        Color = "Text",
        Parent = button,
    })
    local label = Utility:Text("TextLabel", {
        Name = "Text",
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -140, 1, 0),
        Text = "",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = holder,
    })
    local function nudge(on)
        if Motion.Reduced then
            return
        end
        Motion:Play(glyph, { Position = UDim2.new(0, on and 2 or 0, 0.5, 0) }, "Hover", "nudge")
        Motion:Play(buttonLabel, { Position = UDim2.fromOffset(on and 26 or 24, 0) }, "Hover", "nudge")
    end
    button.MouseEnter:Connect(function()
        nudge(true)
    end)
    button.MouseLeave:Connect(function()
        nudge(false)
        Glyph.Paint(glyph, "Text", "Hover")
        Utility:SetColor(buttonLabel, "TextColor3", "Text", "Hover")
    end)
    button.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(glyph, "TextDark", "Press")
            Utility:SetColor(buttonLabel, "TextColor3", "TextDark", "Press")
        end
    end)
    button.InputEnded:Connect(function(input)
        if Shell.IsPointer(input) then
            Glyph.Paint(glyph, "Text", "Release")
            Utility:SetColor(buttonLabel, "TextColor3", "Text", "Release")
        end
    end)
    button.Activated:Connect(function()
        local cb = I.ActionCallback
        if type(cb) == "function" then
            cb()
        end
    end)
    Overlays.AttachTooltip(W, label, function()
        if label.TextFits == false then
            return label.Text
        end
        return nil
    end)
    I.ActionBar, I.ActionLabel, I.ActionButton, I.ActionButtonLabel = holder, label, button, buttonLabel
    I.ActionRise = 0
    I.ActionFader = Utility:Fader(holder)
    W.UI.ActionBar = holder
    return holder
end

function Overlays.SetActionText(W, text, buttonText)
    local I = W._I
    I.ActionLabel.Text = text
    I.ActionButtonLabel.Text = buttonText
    local bw = math.ceil(Utility:Measure(buttonText, Tokens.Text.Value, "Medium", 10000).X) + 40
    I.ActionButton.Size = UDim2.new(0, bw, 1, 0)
    I.ActionLabel.Size = UDim2.new(1, -(16 + bw + 12), 1, 0)
end

function Overlays.PlaceActionBar(W)
    local I = W._I
    local holder = I.ActionBar
    if not holder or not holder.Visible then
        return
    end
    local frame = I.MainFrame
    local pos = Shell.ToGui(W, frame.AbsolutePosition)
    local size = frame.AbsoluteSize
    I.ActionScale.Scale = I.Scale
    holder.Size = UDim2.fromOffset(math.clamp(frame.Size.X.Offset - 44, 340, 640), 42)
    holder.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y + 9 * I.Scale + (I.ActionRise or 0))
end

function Overlays.ShowActionBar(W, config)
    config = type(config) == "table" and config or {}
    if W.IsDestroyed then
        return
    end
    local I = W._I
    local holder = Overlays.EnsureActionBar(W)
    Overlays.SetActionText(W, tostring(config.Text or config.Content or "If you want to cancel active auto rejoin, click here."), tostring(config.ButtonText or "Cancel"))
    I.ActionCallback = config.Callback
    I.ActionId = (I.ActionId or 0) + 1
    local wasVisible = holder.Visible and not I.ActionHiding
    I.ActionHiding = false
    holder.Visible = true
    if wasVisible then
        I.ActionFader:Set(0)
        Overlays.PlaceActionBar(W)
        return
    end
    if Motion.Reduced then
        I.ActionRise = 0
        Overlays.PlaceActionBar(W)
        I.ActionFader:Set(1)
        I.ActionFader:Tween(0, "Fade")
        return
    end
    I.ActionRise = 8
    Overlays.PlaceActionBar(W)
    I.ActionFader:Set(1)
    I.ActionFader:Tween(0, "Enter")
    I.ActionRise = 0
    local frame = I.MainFrame
    local pos = Shell.ToGui(W, frame.AbsolutePosition)
    local size = frame.AbsoluteSize
    Motion:Play(holder, { Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y + 9 * I.Scale) }, "Enter", "pos")
end

function Overlays.HideActionBar(W)
    local I = W._I
    local holder = I.ActionBar
    I.ActionCallback = nil
    if not holder or not holder.Visible then
        return
    end
    I.ActionId = (I.ActionId or 0) + 1
    local id = I.ActionId
    I.ActionHiding = true
    I.ActionFader:Tween(1, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
    task.delay(0.14, function()
        if W.IsDestroyed or I.ActionId ~= id then
            return
        end
        holder.Visible = false
        I.ActionHiding = false
        I.ActionFader:Set(0)
    end)
end

-- ------------------------------------------------------------------------------
-- window methods for overlays
-- ------------------------------------------------------------------------------

function WindowMethods:Notify(config)
    return Overlays.Notify(self, config)
end

function WindowMethods:Confirm(config)
    return Overlays.Confirm(self, config)
end

function WindowMethods:Dialog(config)
    return Overlays.Dialog(self, config)
end

function WindowMethods:ShowActionBar(config)
    return Overlays.ShowActionBar(self, config)
end

function WindowMethods:HideActionBar()
    return Overlays.HideActionBar(self)
end

-- ==============================================================================
-- 10) COMPONENTS (B "Lobby"): no containers, label left and control right, type does the hierarchy.
--     obj.Instance is the row, a direct child of the page list: Visible = false removes it and its space.
--     Every row lays out again from the tab measure: stacked under 420 (F1), Compact sizes on phones.
--     Touch (F6): whole-row hits, 24 px or taller slider strips, pointer drags for mouse and touch.
-- ==============================================================================

local Rows = {}

Rows.Left = Enum.TextXAlignment.Left
Rows.Right = Enum.TextXAlignment.Right
Rows.Center = Enum.TextXAlignment.Center
Rows.Top = Enum.TextYAlignment.Top
Rows.Mid = Enum.TextYAlignment.Center
Rows.BadgeKinds = { Neutral = "TextDark", Accent = "AccentText", Success = "Success", Warning = "Warning", Error = "Error" }

function Rows.ControlWidth(measure)
    return math.clamp(math.floor(measure * 0.385 + 0.5), 212, 248)
end

-- geometry of a tab at its current measure (B at 572: CW 220, label 336)
function Rows.Metrics(tab)
    local I = tab.Window._I
    local m = math.max(120, tab.Measure or 572)
    local stacked = tab.Stacked == true
    local compact = I.Family == "Compact"
    local cw = stacked and m or Rows.ControlWidth(m)
    return {
        M = m,
        CW = cw,
        LW = stacked and m or math.max(60, m - cw - 16),
        Stacked = stacked,
        Compact = compact,
        RowH = compact and Tokens.Size.RowCompact or Tokens.Size.Row,
        CheckH = compact and Tokens.Size.CheckCompact or Tokens.Size.Check,
        FieldH = compact and Tokens.Size.FieldCompact or Tokens.Size.Field,
        LineH = compact and 44 or 28,
        ItemH = compact and Tokens.Size.ItemCompact or 28,
        HitH = compact and 44 or 26,
        TextW = stacked and m or math.min(m, 470),
    }
end

function Rows.StringList(list)
    local out = {}
    for _, v in ipairs(type(list) == "table" and list or {}) do
        table.insert(out, tostring(v))
    end
    return out
end

-- multi-select values: array of strings from a table, a JSON array, one name, or nothing
function Rows.ToArray(v)
    if type(v) == "table" then
        return Rows.StringList(v)
    end
    if type(v) == "string" then
        if v:sub(1, 1) == "[" then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(v)
            end)
            if ok and type(data) == "table" then
                return Rows.StringList(data)
            end
        end
        if v == "" or v == "None" then
            return {}
        end
        return { v }
    end
    return {}
end

function Rows.TextH(text, size, weight, width)
    return math.ceil(Utility:Measure(text, size, weight, math.max(1, width)).Y)
end

function Rows.TextW(text, size, weight)
    return math.ceil(Utility:Measure(text, size, weight, 10000).X)
end

-- ------------------------------------------------------------------------------
-- row entries: { Tab, W, Kind, Instance, Body, Auto, Layout(entry, mt) -> height, Paint(animate), ... }
-- ------------------------------------------------------------------------------

function Rows.New(tab, kind, auto)
    local axis = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
    local row = Utility:Create("Frame", {
        Name = "Row_" .. kind,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = axis,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local body = Utility:Create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = axis,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = row,
    })
    local entry = {
        Tab = tab,
        W = tab.Window,
        Kind = kind,
        Instance = row,
        Body = body,
        Auto = auto == true,
        Height = 0,
        LeadAir = 0,
        Collapsed = false,
        Empty = false,
        First = false,
    }
    return row, body, entry
end

-- 14 Regular row label (wraps; the row grows)
function Rows.Label(parent, text, size, weight, colorKey)
    return Utility:Text("TextLabel", {
        Name = "Label",
        Text = tostring(text or ""),
        Font = { "Sans", weight or "Regular" },
        TextSize = size or Tokens.Text.Label,
        TextWrapped = true,
        TextXAlignment = Rows.Left,
        TextYAlignment = Rows.Mid,
        Color = colorKey or "Text",
        Parent = parent,
    })
end

-- transparent hit area over the row (F6: the whole row reacts, mouse and touch)
function Rows.Hit(entry, parent, z)
    return Utility:Create("TextButton", {
        Name = "Hit",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = z or 2,
        SelectionImageObject = entry.W._I.SelectRing,
        Parent = parent or entry.Body,
    })
end

function Rows.HoverWire(entry, hit)
    hit.MouseEnter:Connect(function()
        entry.Hover = true
        if entry.Paint then
            entry.Paint(true)
        end
    end)
    hit.MouseLeave:Connect(function()
        entry.Hover = false
        if entry.Paint then
            entry.Paint(true)
        end
    end)
end

function Rows.BadgeRoom(entry)
    if entry.Badge and entry.BadgeText then
        return Rows.TextW(entry.BadgeText, 12, "Medium") + 10
    end
    return 0
end

-- badge 10 px after the label text, on the first line
function Rows.PlaceBadge(entry, label, x, maxW, y, h, size, weight)
    local b = entry.Badge
    if not (b and entry.BadgeText) then
        return
    end
    local bw = Rows.TextW(entry.BadgeText, 12, "Medium")
    local tw = math.min(Rows.TextW(label.Text, size or 14, weight or "Regular"), math.max(0, maxW))
    b.Position = UDim2.fromOffset(x + tw + 10, y)
    b.Size = UDim2.fromOffset(bw + 2, h)
end

-- side label (not stacked): fills the row height, vertically centred; returns the row height
function Rows.SideLabel(entry, mt, label, minH, pad, width)
    local lw = width or mt.LW
    local room = Rows.BadgeRoom(entry)
    local th = Rows.TextH(label.Text, 14, "Regular", lw - room)
    local h = math.max(minH, th + (pad or 14))
    label.Position = UDim2.fromOffset(0, 0)
    label.Size = UDim2.fromOffset(lw - room, h)
    if room > 0 then
        local lineY = th > 20 and math.floor((h - th) / 2) or (math.floor(h / 2) - 8)
        Rows.PlaceBadge(entry, label, 0, lw - room, lineY, 16)
    end
    return h
end

-- stacked rows: label on top at full width (wraps), 6 px gap; returns the y of the control line
function Rows.StackTop(entry, mt, label, rightRoom)
    local room = Rows.BadgeRoom(entry)
    local lw = mt.M - (rightRoom or 0) - room
    local th = math.max(18, Rows.TextH(label.Text, 14, "Regular", lw))
    label.Position = UDim2.fromOffset(0, 6)
    label.Size = UDim2.fromOffset(lw, th)
    if room > 0 then
        Rows.PlaceBadge(entry, label, 0, lw, 7, 16)
    end
    return 6 + th + 6
end

-- description (13 TextDark under the label) and error caption (12 Error under the control)
function Rows.Extras(entry, mt, h)
    local errH, descH = 0, 0
    local err, desc = entry.ErrorLabel, entry.Desc
    if err then
        local show = entry.ErrorText ~= nil
        err.Visible = show
        if show then
            local x = mt.Stacked and 0 or (entry.ControlX or (mt.M - mt.CW))
            local w = math.max(60, mt.M - x)
            err.Text = entry.ErrorText
            errH = math.max(16, Rows.TextH(entry.ErrorText, 12, "Regular", w))
            err.Position = UDim2.fromOffset(x, h - 2)
            err.Size = UDim2.fromOffset(w, errH)
        end
    end
    if desc then
        local show = entry.DescText ~= nil
        desc.Visible = show
        if show then
            local w = mt.Stacked and mt.M or mt.LW
            desc.Text = entry.DescText
            descH = Rows.TextH(entry.DescText, 13, "Regular", w)
            local y = (mt.Stacked and errH > 0) and (h - 2 + errH + 2) or (h - 4)
            desc.Position = UDim2.fromOffset(0, y)
            desc.Size = UDim2.fromOffset(w, descH)
            if mt.Stacked and errH > 0 then
                return h + errH + descH + 6
            end
        end
    end
    local grow = math.max(errH > 0 and errH + 2 or 0, descH > 0 and descH + 2 or 0)
    return h + grow
end

function Rows.UpdateVisible(entry)
    if entry.Legacy then
        return
    end
    local shown = not entry.Collapsed and not entry.Empty
    entry.Body.Visible = shown
    if entry.Auto then
        entry.Instance.AutomaticSize = shown and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
        entry.Instance.Size = UDim2.new(1, 0, 0, 0)
    else
        local lead = entry.LeadAir or 0
        entry.Body.Position = UDim2.fromOffset(0, lead)
        entry.Instance.Size = UDim2.new(1, 0, 0, shown and (entry.Height + lead) or 0)
    end
end

function Rows.Apply(entry, mt)
    if entry.Legacy or not entry.Layout then
        return
    end
    mt = mt or Rows.Metrics(entry.Tab)
    local ok, h = pcall(entry.Layout, entry, mt)
    if not ok then
        warn("[CAC UI] row layout error: " .. tostring(h))
        h = entry.Height
    end
    if entry.Auto then
        return
    end
    h = Rows.Extras(entry, mt, tonumber(h) or mt.RowH)
    entry.Height = h
    entry.Body.Size = UDim2.new(1, 0, 0, h)
    Rows.UpdateVisible(entry)
end

function Rows.LayoutAll(tab)
    local mt = Rows.Metrics(tab)
    for _, e in ipairs(tab._rows) do
        Rows.Apply(e, mt)
    end
end

-- one layout hook per tab: the shell calls it when the measure changes (window, sidebar, drawer, pane)
function Rows.Install(tab)
    if tab._rowsHook then
        return
    end
    tab._rowsHook = true
    table.insert(tab._layoutHooks, function()
        Rows.LayoutAll(tab)
    end)
end

-- entry from Rows.New, or a legacy Instance block (viewport): Rows.Add(tab, frame, "block")
function Rows.Add(tab, entry, kind)
    if typeof(entry) == "Instance" then
        entry = { Tab = tab, W = tab.Window, Kind = (kind == nil or kind == "block") and "Block" or tostring(kind), Instance = entry, Legacy = true }
    end
    Rows.Install(tab)
    local row = entry.Instance
    tab._order = tab._order + 1
    row.LayoutOrder = tab._order
    table.insert(tab._rows, entry)
    if entry.Kind == "Section" and entry.Label then
        tab._section = entry.Label.Text
    end
    entry.Section = tab._section
    if not entry.Legacy then
        Rows.Apply(entry)
        if entry.Auto then
            Rows.UpdateVisible(entry)
        end
    end
    row.Parent = tab.Page
    row:GetPropertyChangedSignal("Visible"):Connect(function()
        Rows.Schedule(tab)
    end)
    row.AncestryChanged:Connect(function()
        Rows.Schedule(tab)
    end)
    Rows.Schedule(tab)
    return entry
end

function Rows.Schedule(tab)
    if tab._refreshQueued then
        return
    end
    tab._refreshQueued = true
    task.defer(function()
        tab._refreshQueued = false
        Rows.Refresh(tab)
    end)
end

-- deferred pass: toggle style runs, section air, collapsed sections
function Rows.Refresh(tab)
    local alive = {}
    for _, e in ipairs(tab._rows) do
        if e.Instance.Parent == tab.Page then
            table.insert(alive, e)
        end
    end
    tab._rows = alive
    local dirty = {}
    -- 3 or more toggles without Style created one after another (visibility ignored) show checkboxes (5.0)
    local run = {}
    local function flush()
        local check = #run >= 3
        for i, t in ipairs(run) do
            local style = check and "Check" or "Switch"
            local lead = (check and i == 1) and 4 or 0
            if t.Style ~= style or t.LeadAir ~= lead then
                t.LeadAir = lead
                t.SetStyle(style)
                dirty[t] = true
            end
        end
        table.clear(run)
    end
    for _, e in ipairs(alive) do
        if e.Kind == "Toggle" and not e.FixedStyle then
            table.insert(run, e)
        else
            flush()
            if e.Kind == "Toggle" and (e.Style ~= e.FixedStyle or e.LeadAir ~= 0) then
                e.LeadAir = 0
                e.SetStyle(e.FixedStyle)
                dirty[e] = true
            end
        end
    end
    flush()
    local seen, collapsed = false, false
    for _, e in ipairs(alive) do
        if e.Kind == "Section" then
            collapsed = e.CollapsedSelf == true
            local first = not seen
            if e.First ~= first then
                e.First = first
                dirty[e] = true
            end
        elseif not e.Legacy and e.Collapsed ~= collapsed then
            e.Collapsed = collapsed
            Rows.UpdateVisible(e)
        end
        if e.Instance.Visible and not e.Collapsed and not e.Empty then
            seen = true
        end
    end
    local mt = Rows.Metrics(tab)
    for e in pairs(dirty) do
        Rows.Apply(e, mt)
    end
end

-- index of controls for search tools: { Kind, Name, Tab, Section, Instance, Object }
function Rows.Register(tab, kind, name, entry, object)
    local I = tab.Window._I
    I.Index = I.Index or {}
    table.insert(I.Index, { Kind = kind, Name = tostring(name or ""), Tab = tab, Section = entry and entry.Section, Instance = entry and entry.Instance, Object = object })
end

function Rows.SetError(entry, text)
    text = text ~= nil and tostring(text) or nil
    if text == "" then
        text = nil
    end
    if text and not entry.ErrorLabel then
        entry.ErrorLabel = Utility:Text("TextLabel", {
            Name = "Error",
            Text = "",
            Font = { "Sans", "Regular" },
            TextSize = Tokens.Text.Caption,
            TextWrapped = true,
            TextXAlignment = Rows.Left,
            TextYAlignment = Rows.Top,
            Color = "Error",
            ZIndex = 3,
            Parent = entry.Body,
        })
    end
    entry.ErrorText = text
    if entry.Paint then
        entry.Paint(false)
    end
    Rows.Apply(entry)
end

function Rows.SetBadge(entry, spec)
    local text, kind = nil, nil
    if type(spec) == "table" then
        text, kind = spec.Text, spec.Kind
    elseif spec ~= nil then
        text = spec
    end
    text = text ~= nil and tostring(text):sub(1, 12) or nil
    if text == "" then
        text = nil
    end
    if text and not entry.Badge then
        entry.Badge = Utility:Text("TextLabel", {
            Name = "Badge",
            Text = "",
            Font = { "Sans", "Medium" },
            TextSize = Tokens.Text.Caption,
            TextXAlignment = Rows.Left,
            Color = "TextDark",
            ZIndex = 3,
            Parent = entry.Body,
        })
    end
    entry.BadgeText = text
    if entry.Badge then
        entry.Badge.Visible = text ~= nil
        entry.Badge.Text = text or ""
        Utility:SetColor(entry.Badge, "TextColor3", Rows.BadgeKinds[kind or "Neutral"] or "TextDark")
    end
    Rows.Apply(entry)
end

-- optional cfg on every control: Description, Tooltip, Badge, Disabled (+ methods of the same names)
function Rows.Decorate(entry, obj, cfg)
    local W = entry.W
    entry.Obj = obj
    entry.Tooltip = type(cfg.Tooltip) == "string" and cfg.Tooltip ~= "" and cfg.Tooltip or nil
    function obj:SetDescription(text)
        text = text ~= nil and tostring(text) or nil
        if text == "" then
            text = nil
        end
        if text and not entry.Desc then
            entry.Desc = Utility:Text("TextLabel", {
                Name = "Description",
                Text = "",
                Font = { "Sans", "Regular" },
                TextSize = Tokens.Text.Small,
                TextWrapped = true,
                TextXAlignment = Rows.Left,
                TextYAlignment = Rows.Top,
                Color = "TextDark",
                Parent = entry.Body,
            })
        end
        entry.DescText = text
        Rows.Apply(entry)
    end
    function obj:SetTooltip(text)
        entry.Tooltip = type(text) == "string" and text ~= "" and text or nil
    end
    function obj:SetBadge(spec)
        Rows.SetBadge(entry, spec)
    end
    function obj:SetDisabled(on, reason)
        entry.Disabled = on == true
        entry.DisabledReason = (on == true and type(reason) == "string" and reason ~= "") and reason or nil
        if entry.OnDisabled then
            entry.OnDisabled(entry.Disabled)
        end
        if entry.Paint then
            entry.Paint(true)
        end
    end
    function obj:SetVisible(visible)
        entry.Instance.Visible = visible ~= false
    end
    function obj:SetError(text)
        Rows.SetError(entry, text)
    end
    if cfg.Description ~= nil then
        obj:SetDescription(cfg.Description)
    end
    if cfg.Badge ~= nil then
        obj:SetBadge(cfg.Badge)
    end
    if cfg.Disabled then
        obj:SetDisabled(true, type(cfg.Disabled) == "string" and cfg.Disabled or nil)
    end
    local owner = entry.TipOwner or entry.Hit
    if owner then
        Overlays.AttachTooltip(W, owner, function()
            if entry.Disabled and entry.DisabledReason then
                return entry.DisabledReason
            end
            if entry.Tooltip then
                return entry.Tooltip
            end
            local t = entry.Trunc
            if t and t.Parent and t.Text ~= "" and not t.TextFits then
                return t.Text
            end
            return nil
        end)
    end
end

-- four-point star turning in eased 90 degree steps while `alive()` (static when motion is reduced)
function Rows.Spin(W, star, alive)
    task.spawn(function()
        local angle = 0
        while alive() and star.Parent and not W.IsDestroyed do
            if not Motion.Reduced then
                angle = angle + 90
                Motion:Play(star, { Rotation = angle }, "Star", "spin")
            end
            task.wait(0.85)
        end
    end)
end

-- the focused-field line: 1 px at the field bottom (Text at 0.3, Error while an error shows)
function Rows.FieldLine(field)
    return Utility:Create("Frame", {
        Name = "Line",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.3,
        Visible = false,
        ZIndex = 4,
        Theme = { BackgroundColor3 = "Text" },
        Parent = field,
    })
end

-- B checkbox 14 x 14 r2: off = 1.5 px TextDark stroke at 0.35, on = Text fill + check in Background.
-- State lives in Visible / Enabled (not transparency) so a page or popover fade never reverts it.
function Rows.CheckBox(parent)
    local box = Utility:Create("Frame", {
        Name = "Check",
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Utility:Corner(box, 2)
    local stroke = Utility:Create("UIStroke", {
        Thickness = 1.5,
        Transparency = 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = "TextDark" },
        Parent = box,
    })
    local fill = Utility:Create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Visible = false,
        Theme = { BackgroundColor3 = "Text" },
        Parent = box,
    })
    Utility:Corner(fill, 2)
    Glyph.Draw(fill, "check", 12, "Background", { Position = UDim2.fromOffset(1, 1) })
    return box, fill, stroke
end

function Rows.PaintCheck(fill, stroke, on, hover, disabled, animate)
    Utility:SetColor(fill, "BackgroundColor3", disabled and "TextMuted" or "Text")
    local was = fill.Visible
    fill.Visible = on
    stroke.Enabled = not on
    stroke.Transparency = (hover and not disabled) and 0 or 0.35
    if on and not was and animate and not Motion.Reduced then
        fill.BackgroundTransparency = 1
        Motion:Play(fill, { BackgroundTransparency = 0 }, "State", "fill")
    elseif not animate then
        Motion:Stop(fill, "fill")
        fill.BackgroundTransparency = 0
    end
end

-- popover fade (no CanvasGroup): restore, rescan, fade in; Close fades out then hides
function Rows.PopIn(state, holder)
    if state.Fader then
        state.Fader:Set(0)
        state.Fader:Scan()
    else
        state.Fader = Utility:Fader(holder)
    end
    state.Fader:Set(1)
    state.Fader:Tween(0, Motion.Reduced and "Fade" or "Enter")
end

function Rows.PopOut(state, holder, isOpen)
    if state.Fader and not Motion.Reduced then
        state.Fader:Tween(1, "Exit")
        task.delay(Motion:GetInfo("Exit").Time, function()
            if not isOpen() then
                holder.Visible = false
                state.Fader:Set(0)
            end
        end)
    else
        holder.Visible = false
        if state.Fader then
            state.Fader:Set(0)
        end
    end
end

-- ------------------------------------------------------------------------------
-- Section: 15 Medium Text, 18 px air above (0 for the first visible row); optional collapse (N)
-- ------------------------------------------------------------------------------

function Components.Section(tab, title, opts)
    opts = type(opts) == "table" and opts or {}
    local row, body, entry = Rows.New(tab, "Section")
    local label = Utility:Text("TextLabel", {
        Name = "Title",
        Text = tostring(title or "Section"),
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Section,
        TextXAlignment = Rows.Left,
        TextYAlignment = Rows.Top,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = body,
    })
    entry.Label = label
    local collapsible = opts.Collapsible == true
    entry.CollapsedSelf = collapsible and opts.Collapsed == true
    local chevron = nil
    local obj = { Instance = row, Label = label }
    if collapsible then
        chevron = Glyph.Draw(body, "chevron", 10, "TextDark", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = entry.CollapsedSelf and -90 or 0 })
        local hit = Rows.Hit(entry)
        entry.Hit = hit
        hit.MouseEnter:Connect(function()
            Glyph.Paint(chevron, "Text", "Hover")
        end)
        hit.MouseLeave:Connect(function()
            Glyph.Paint(chevron, "TextDark", "Hover")
        end)
        hit.Activated:Connect(function()
            obj:SetCollapsed(not entry.CollapsedSelf)
        end)
    end
    entry.Layout = function(e, mt)
        local air = e.First and 0 or 18
        local tw = Rows.TextW(label.Text, 15, "Medium")
        local room = Rows.BadgeRoom(e) + (chevron and 18 or 0)
        local shown = math.min(tw, mt.M - room)
        label.Position = UDim2.fromOffset(0, air)
        label.Size = UDim2.fromOffset(math.max(10, mt.M - room), 22)
        local x = shown
        if chevron then
            chevron.Position = UDim2.fromOffset(x + 13, air + 9)
            x = x + 18
        end
        if e.Badge and e.BadgeText then
            local bw = Rows.TextW(e.BadgeText, 12, "Medium")
            e.Badge.Position = UDim2.fromOffset(x + 10, air + 1)
            e.Badge.Size = UDim2.fromOffset(bw + 2, 16)
        end
        return air + 26
    end
    function obj:SetCollapsed(collapsed)
        entry.CollapsedSelf = collapsed == true
        if chevron then
            local rot = entry.CollapsedSelf and -90 or 0
            if Motion.Reduced then
                chevron.Rotation = rot
            else
                Motion:Play(chevron, { Rotation = rot }, "State", "rot")
            end
        end
        Rows.Refresh(tab)
        if type(opts.Callback) == "function" then
            task.spawn(opts.Callback, entry.CollapsedSelf)
        end
    end
    function obj:SetTitle(text)
        label.Text = tostring(text or "")
        Rows.Apply(entry)
    end
    function obj:SetBadge(spec)
        Rows.SetBadge(entry, spec)
    end
    if opts.Badge ~= nil then
        Rows.SetBadge(entry, opts.Badge)
    end
    Rows.Add(tab, entry)
    Rows.Register(tab, "Section", label.Text, entry, obj)
    return obj
end

-- ------------------------------------------------------------------------------
-- Button: B action row (arrow glyph + label); waits 0.08 s inside the click, then Callback()
-- ------------------------------------------------------------------------------

function Components.Button(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Button")
    local rest = cfg.Style == "Danger" and "Error" or "Text"
    local row, body, entry = Rows.New(tab, "Button")
    local visual = Utility:Create("Frame", {
        Name = "Visual",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = body,
    })
    local arrow = Glyph.Draw(visual, "arrow", 14, rest)
    local label = Rows.Label(visual, name, 14, "Regular", rest)
    local hit = Rows.Hit(entry)
    entry.Hit = hit
    local state = { Busy = false, Pressed = false, Star = nil, Spin = 0, GlyphY = 10 }
    local obj = { Instance = row, Button = hit, Label = label }
    entry.Paint = function(animate)
        local key = rest
        if entry.Disabled then
            key = "TextMuted"
        elseif state.Busy or state.Pressed then
            key = "TextDark"
        end
        local token = animate and (state.Pressed and "Press" or "Release") or nil
        Utility:SetColor(label, "TextColor3", key, token)
        Glyph.Paint(arrow, key, token)
        if state.Star then
            Glyph.Paint(state.Star, key, token)
        end
        local nudge = (entry.Hover and not entry.Disabled and not state.Busy and not Motion.Reduced) and 2 or 0
        if animate and not Motion.Reduced then
            Motion:Play(visual, { Position = UDim2.fromOffset(nudge, 0) }, "Hover", "nudge")
        else
            Motion:Stop(visual, "nudge")
            visual.Position = UDim2.fromOffset(nudge, 0)
        end
    end
    entry.Layout = function(e, mt)
        local room = Rows.BadgeRoom(e)
        local tw = math.max(40, mt.M - 24 - room)
        local th = Rows.TextH(label.Text, 14, "Regular", tw)
        local h = math.max(mt.RowH, th + 14)
        local gy = th > 20 and 8 or (math.floor(h / 2) - 7)
        state.GlyphY = gy
        arrow.Position = UDim2.fromOffset(0, gy)
        if state.Star then
            state.Star.Position = UDim2.fromOffset(7, gy + 7)
        end
        label.Position = UDim2.fromOffset(24, 0)
        label.Size = UDim2.fromOffset(tw, h)
        if room > 0 then
            Rows.PlaceBadge(e, label, 24, tw, th > 20 and 7 or (math.floor(h / 2) - 8), 16)
        end
        return h
    end
    Rows.HoverWire(entry, hit)
    hit.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) and not entry.Disabled and not state.Busy then
            state.Pressed = true
            entry.Paint(true)
        end
    end)
    hit.InputEnded:Connect(function(input)
        if Shell.IsPointer(input) and state.Pressed then
            state.Pressed = false
            entry.Paint(true)
        end
    end)
    hit.Activated:Connect(function()
        if W.IsDestroyed or entry.Disabled or state.Busy then
            return
        end
        task.wait(0.08)
        if cfg.Callback then
            cfg.Callback()
        end
    end)
    function obj:SetText(text)
        label.Text = tostring(text or "")
        Rows.Apply(entry)
    end
    -- busy (N): the arrow becomes a turning star, label TextDark, clicks ignored
    function obj:SetBusy(on)
        on = on == true
        if state.Busy == on then
            return
        end
        state.Busy = on
        state.Spin = state.Spin + 1
        arrow.Visible = not on
        if on then
            state.Star = Glyph.Star(visual, 14, "TextDark", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(7, state.GlyphY + 7),
            })
            local token = state.Spin
            Rows.Spin(W, state.Star, function()
                return state.Spin == token
            end)
        elseif state.Star then
            state.Star:Destroy()
            state.Star = nil
        end
        entry.Paint(false)
    end
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Button", name, entry, obj)
    entry.Paint(false)
    return obj
end

-- ------------------------------------------------------------------------------
-- Toggle: B switch, or B checkbox inside a run of 3+ toggles; the whole row toggles
-- callback once at creation and on every click and SetValue (contract)
-- ------------------------------------------------------------------------------

function Components.Toggle(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local name = tostring(cfg.Name or "Toggle")
    local flag = cfg.Flag or cfg.Name or "Toggle_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local default = SaveManager:GetInitialValue(flag, cfg.Default == true, persistent) == true
    SaveManager:SetFlag(flag, default, false)

    local row, body, entry = Rows.New(tab, "Toggle")
    entry.FixedStyle = (cfg.Style == "Switch" or cfg.Style == "Check") and cfg.Style or nil
    entry.Style = entry.FixedStyle or "Switch"
    local label = Rows.Label(body, name)
    local track = Utility:Create("Frame", {
        Name = "Switch",
        Size = UDim2.fromOffset(28, 14),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "TextMuted" },
        Parent = body,
    })
    Utility:Corner(track, UDim.new(0.5, 0))
    local knob = Utility:Create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(7, 7),
        Size = UDim2.fromOffset(10, 10),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Utility:Corner(knob, UDim.new(0.5, 0))
    local box, boxFill, boxStroke = Rows.CheckBox(body)
    box.Visible = false
    local hit = Rows.Hit(entry)
    entry.Hit = hit

    local obj = { Value = default, Instance = row }
    local painted = false
    entry.Paint = function(animate)
        local on, dis = obj.Value, entry.Disabled == true
        local hover = entry.Hover and not dis
        local token = animate and "State" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        if entry.Style == "Check" then
            Rows.PaintCheck(boxFill, boxStroke, on, hover, dis, animate)
        else
            local key = dis and "Border" or (on and (hover and "AccentGlow" or "Accent") or (hover and "TextDark" or "TextMuted"))
            Utility:SetColor(track, "BackgroundColor3", key, token)
            Utility:SetColor(knob, "BackgroundColor3", dis and "TextMuted" or (on and "SwitchKnob" or "Text"), token)
            local pos = UDim2.fromOffset(on and 21 or 7, 7)
            if animate and not Motion.Reduced then
                Motion:Play(knob, { Position = pos }, "State", "pos")
            else
                Motion:Stop(knob, "pos")
                knob.Position = pos
            end
        end
    end
    entry.SetStyle = function(style)
        entry.Style = style
        track.Visible = style ~= "Check"
        box.Visible = style == "Check"
        entry.Paint(false)
    end
    entry.Layout = function(e, mt)
        local check = e.Style == "Check"
        local cw = check and 14 or 28
        local lw = mt.Stacked and (mt.M - cw - 16) or mt.LW
        local h = Rows.SideLabel(e, mt, label, check and mt.CheckH or mt.RowH, check and 10 or 14, lw)
        local cy = math.floor(h / 2)
        track.Position = UDim2.fromOffset(mt.M - 28, cy - 7)
        box.Position = UDim2.fromOffset(mt.M - 14, cy - 7)
        e.ControlX = mt.M - cw
        return h
    end
    function obj:SetValue(val)
        self.Value = val == true
        SaveManager:SetFlag(flag, self.Value, persistent)
        entry.Paint(painted)
        painted = true
        if cfg.Callback then
            cfg.Callback(self.Value)
        end
    end
    Rows.HoverWire(entry, hit)
    hit.Activated:Connect(function()
        if tab.Window.IsDestroyed or entry.Disabled then
            return
        end
        obj:SetValue(not obj.Value)
    end)
    entry.SetStyle(entry.Style)
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Toggle", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    obj:SetValue(default)
    return obj
end

-- ------------------------------------------------------------------------------
-- Slider: 2 px track, Text fill, 10 px knob, typed value box; 24 px+ hit strip, mouse and touch drag
-- callback at creation, on every drag move, typed value and SetValue (synchronous)
-- ------------------------------------------------------------------------------

function Components.Slider(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Slider")
    local flag = cfg.Flag or cfg.Name or "Slider_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local min = tonumber(cfg.Min) or 0
    local max = tonumber(cfg.Max) or 100
    if max < min then
        min, max = max, min
    end
    local decimals = math.max(0, math.floor(tonumber(cfg.Decimals) or 0))
    local function normalize(v)
        local n = tonumber(v)
        if not n or n ~= n then
            n = min
        end
        n = math.clamp(n, min, max)
        if decimals == 0 then
            n = math.floor(n + 0.5)
        end
        return n
    end
    local function format(v)
        if decimals == 0 then
            return tostring(math.floor(v + 0.5))
        end
        return string.format("%." .. tostring(decimals) .. "f", v)
    end
    local default = normalize(SaveManager:GetInitialValue(flag, cfg.Default or min, persistent))
    SaveManager:SetFlag(flag, default, false)

    local row, body, entry = Rows.New(tab, "Slider")
    local label = Rows.Label(body, name)
    local track = Utility:Create("Frame", {
        Name = "Track",
        Size = UDim2.fromOffset(168, 2),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "BorderHighlight" },
        Parent = body,
    })
    local fill = Utility:Create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    local knob = Utility:Create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Utility:Corner(knob, UDim.new(0.5, 0))
    local knobScale = Utility:Create("UIScale", { Parent = knob })
    local strip = Utility:Create("TextButton", {
        Name = "Hit",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 2,
        SelectionImageObject = W._I.SelectRing,
        Parent = body,
    })
    local box = Utility:Text("TextBox", {
        Name = "Value",
        SelectionImageObject = tab.Window._I.SelectRing,
        ClearTextOnFocus = false,
        Text = format(default),
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Rows.Right,
        BackgroundTransparency = 1,
        ZIndex = 3,
        Color = "Text",
        Theme = { BackgroundColor3 = "Field" },
        Parent = body,
    })
    entry.Hit = strip
    entry.TipOwner = strip

    local obj = { Value = default, Instance = row }
    local state = { Dragging = false, Animate = false, Flash = 0, Error = false }
    local function paintValue()
        local range = max - min
        local frac = range > 0 and math.clamp((obj.Value - min) / range, 0, 1) or 0
        local fsize, kpos = UDim2.fromScale(frac, 1), UDim2.fromScale(frac, 0.5)
        if state.Animate and not Motion.Reduced then
            Motion:Play(fill, { Size = fsize }, "Jump", "size")
            Motion:Play(knob, { Position = kpos }, "Jump", "pos")
        else
            Motion:Stop(fill, "size")
            Motion:Stop(knob, "pos")
            fill.Size = fsize
            knob.Position = kpos
        end
        if not box:IsFocused() then
            box.Text = format(obj.Value)
        end
    end
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(track, "BackgroundColor3", dis and "Border" or "BorderHighlight", token)
        Utility:SetColor(fill, "BackgroundColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(knob, "BackgroundColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(box, "TextColor3", state.Error and "Error" or (dis and "TextMuted" or "Text"), token)
        box.TextEditable = not dis
        local big = (state.Dragging or entry.Hover) and not dis
        Motion:Play(knobScale, { Scale = big and 1.2 or 1 }, "Hover", "scale")
    end
    entry.Layout = function(e, mt)
        local h, x0, trackW, cy
        if mt.Stacked then
            local want = mt.M - 52
            local onLabel = want < 160
            local lineY = Rows.StackTop(e, mt, label, onLabel and 48 or 0)
            local lineH = mt.Compact and 44 or 24
            -- the knob (10 px) must not be cut by the page edge at the minimum: the track starts at its radius
            trackW = (onLabel and mt.M - 10 or want - 5)
            x0 = 5
            cy = lineY + math.floor(lineH / 2)
            h = lineY + lineH + 8
            if onLabel then
                box.Position = UDim2.fromOffset(mt.M - 40, 6)
                box.Size = UDim2.fromOffset(40, 18)
            else
                box.Position = UDim2.fromOffset(mt.M - 40, lineY)
                box.Size = UDim2.fromOffset(40, lineH)
            end
            strip.Position = UDim2.fromOffset(0, lineY)
            strip.Size = UDim2.fromOffset(trackW + 10, lineH)
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14)
            x0 = mt.M - mt.CW
            trackW = mt.CW - 52
            cy = math.floor(h / 2)
            box.Position = UDim2.fromOffset(mt.M - 40, math.floor((h - mt.FieldH) / 2))
            box.Size = UDim2.fromOffset(40, mt.FieldH)
            strip.Position = UDim2.fromOffset(x0 - 6, 0)
            strip.Size = UDim2.fromOffset(trackW + 12, h)
        end
        track.Position = UDim2.fromOffset(x0, cy - 1)
        track.Size = UDim2.fromOffset(trackW, 2)
        e.ControlX = x0
        return h
    end
    function obj:SetValue(val)
        self.Value = normalize(val)
        SaveManager:SetFlag(flag, self.Value, persistent)
        paintValue()
        if cfg.Callback then
            cfg.Callback(self.Value)
        end
    end
    local function valueAt(x)
        local absX, width = track.AbsolutePosition.X, track.AbsoluteSize.X
        local rel = width > 0 and math.clamp((x - absX) / width, 0, 1) or 0
        return min + rel * (max - min)
    end
    strip.InputBegan:Connect(function(input)
        if W.IsDestroyed or entry.Disabled or not Shell.IsPointer(input) or input.UserInputState ~= Enum.UserInputState.Begin then
            return
        end
        state.Dragging = true
        local touch = input.UserInputType == Enum.UserInputType.Touch
        local page = tab.Page
        local scrollWas = page.ScrollingEnabled
        if touch then
            page.ScrollingEnabled = false
        end
        entry.Paint(true)
        state.Animate = true
        obj:SetValue(valueAt(input.Position.X))
        state.Animate = false
        Shell.BeginDrag(W, input, function(_, move)
            obj:SetValue(valueAt(move.Position.X))
        end, function()
            state.Dragging = false
            if touch then
                page.ScrollingEnabled = scrollWas
            end
            entry.Paint(true)
        end)
    end)
    Rows.HoverWire(entry, strip)
    box.Focused:Connect(function()
        box.BackgroundTransparency = 0
    end)
    box.FocusLost:Connect(function()
        box.BackgroundTransparency = 1
        local parsed = tonumber((box.Text:gsub("%s", "")))
        if parsed and not entry.Disabled then
            obj:SetValue(parsed)
            return
        end
        box.Text = format(obj.Value)
        state.Error = true
        state.Flash = state.Flash + 1
        local token = state.Flash
        entry.Paint(false)
        task.delay(2, function()
            if state.Flash == token then
                state.Error = false
                entry.Paint(true)
            end
        end)
    end)
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Slider", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    entry.Paint(false)
    obj:SetValue(default)
    return obj
end

-- ------------------------------------------------------------------------------
-- Input: flat Field (no stroke); focused = FieldHover + 1 px line; no callback at creation,
-- Callback on every FocusLost; obj.Value stays a writable plain field (contract)
-- ------------------------------------------------------------------------------

function Components.Input(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local name = tostring(cfg.Name or "Input")
    local flag = cfg.Flag or cfg.Name or "Input_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local default = tostring(SaveManager:GetInitialValue(flag, cfg.Default or "", persistent))
    SaveManager:SetFlag(flag, default, false)

    local row, body, entry = Rows.New(tab, "Input")
    local label = Rows.Label(body, name)
    local hit = Rows.Hit(entry)
    entry.Hit = hit
    local field = Utility:Create("Frame", {
        Name = "Field",
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 3,
        Theme = { BackgroundColor3 = "Field" },
        Parent = body,
    })
    local box = Utility:Text("TextBox", {
        Name = "TextBox",
        SelectionImageObject = tab.Window._I.SelectRing,
        Size = UDim2.fromScale(1, 1),
        ClearTextOnFocus = false,
        Text = default,
        PlaceholderText = tostring(cfg.Placeholder or "Type here..."),
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Rows.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Color = "Text",
        Theme = { PlaceholderColor3 = "TextDark" },
        Parent = field,
    })
    Utility:Padding(box, 0, 9, 0, 9)
    local line = Rows.FieldLine(field)

    local obj = { Value = default, Instance = row, TextBox = box }
    local state = { Focused = false, FieldHover = false }
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(field, "BackgroundColor3", ((state.Focused or state.FieldHover) and not dis) and "FieldHover" or "Field", token)
        Utility:SetColor(box, "TextColor3", dis and "TextMuted" or "Text")
        local err = entry.ErrorText ~= nil
        line.Visible = state.Focused or err
        Utility:SetColor(line, "BackgroundColor3", err and "Error" or "Text")
        line.BackgroundTransparency = err and 0 or 0.3
        box.TextEditable = not dis
    end
    entry.Layout = function(e, mt)
        local h
        if mt.Stacked then
            local lineY = Rows.StackTop(e, mt, label)
            field.Position = UDim2.fromOffset(0, lineY)
            field.Size = UDim2.fromOffset(mt.M, mt.FieldH)
            h = lineY + mt.FieldH + 8
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14)
            field.Position = UDim2.fromOffset(mt.M - mt.CW, math.floor((h - mt.FieldH) / 2))
            field.Size = UDim2.fromOffset(mt.CW, mt.FieldH)
        end
        e.ControlX = mt.Stacked and 0 or (mt.M - mt.CW)
        return h
    end
    function obj:SetValue(val)
        box.Text = tostring(val or "")
        self.Value = box.Text
        SaveManager:SetFlag(flag, self.Value, persistent)
        if cfg.Callback then
            cfg.Callback(self.Value)
        end
    end
    field.MouseEnter:Connect(function()
        state.FieldHover = true
        entry.Paint(true)
    end)
    field.MouseLeave:Connect(function()
        state.FieldHover = false
        entry.Paint(true)
    end)
    hit.Activated:Connect(function()
        if not entry.Disabled then
            box:CaptureFocus()
        end
    end)
    box.Focused:Connect(function()
        state.Focused = true
        entry.Paint(true)
    end)
    box.FocusLost:Connect(function()
        state.Focused = false
        entry.Paint(true)
        obj.Value = box.Text
        SaveManager:SetFlag(flag, obj.Value, persistent)
        if cfg.Callback then
            cfg.Callback(obj.Value)
        end
    end)
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Input", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    entry.Paint(false)
    return obj
end

-- ------------------------------------------------------------------------------
-- Dropdown: value text + chevron; list popover (Field fill + edge) under Window.UI.GUI.
-- Search above 8 options (or cfg.Search); Multi = true (or CreateMultiDropdown) adds checkboxes.
-- Contract: callback at creation, on every option click and SetValue; SetOptions never fires.
-- ------------------------------------------------------------------------------

function Components.DropdownPopover(W, name, multi)
    local I = W._I
    local P = { W = W }
    P.Holder = Utility:Create("Frame", {
        Name = "DropdownList_" .. name,
        Size = UDim2.fromOffset(220, 100),
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 30,
        Theme = { BackgroundColor3 = "Field" },
        Parent = I.Overlay,
    })
    Utility:Edge(P.Holder)
    P.Search = Utility:Text("TextBox", {
        Name = "Search",
        SelectionImageObject = W._I.SelectRing,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -40, 0, 30),
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "Search",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Rows.Left,
        Visible = false,
        Color = "Text",
        Theme = { PlaceholderColor3 = "TextDark" },
        Parent = P.Holder,
    })
    P.SearchGlyph = Glyph.Draw(P.Holder, "search", 12, "TextDark", { Position = UDim2.new(1, -20, 0, 9), Visible = false })
    P.SearchLine = Utility:Create("Frame", {
        Name = "SearchLine",
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.9,
        Visible = false,
        Theme = { BackgroundColor3 = "Text" },
        Parent = P.Holder,
    })
    P.List = Utility:Create("ScrollingFrame", {
        Name = "List",
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        Theme = { ScrollBarImageColor3 = "TextMuted" },
        Parent = P.Holder,
    })
    Utility:List(P.List, Enum.FillDirection.Vertical, 0)
    Shell.AutoScrollbar(W, P.List)
    P.Empty = Utility:Text("TextLabel", {
        Name = "Empty",
        Size = UDim2.new(1, 0, 0, 28),
        Text = "No options",
        Visible = false,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Rows.Left,
        LayoutOrder = 1000000,
        Color = "TextDark",
        Parent = P.List,
    })
    Utility:Padding(P.Empty, 0, 12, 0, 12)
    if multi then
        P.Footer = Utility:Create("Frame", {
            Name = "Footer",
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Parent = P.Holder,
        })
        local function footerButton(text, right)
            local b = Utility:Text("TextButton", {
                Name = text:gsub("%s", ""),
                SelectionImageObject = W._I.SelectRing,
                AnchorPoint = Vector2.new(right and 1 or 0, 0),
                Position = right and UDim2.new(1, -12, 0, 0) or UDim2.fromOffset(12, 0),
                Size = UDim2.fromOffset(Rows.TextW(text, 13, "Regular") + 4, 28),
                AutoButtonColor = false,
                Text = text,
                Font = { "Sans", "Regular" },
                TextSize = Tokens.Text.Small,
                TextXAlignment = right and Rows.Right or Rows.Left,
                Color = "TextDark",
                Parent = P.Footer,
            })
            b.MouseEnter:Connect(function()
                Utility:SetColor(b, "TextColor3", "Text", "Hover")
            end)
            b.MouseLeave:Connect(function()
                Utility:SetColor(b, "TextColor3", "TextDark", "Hover")
            end)
            return b
        end
        P.All = footerButton("Select all", false)
        P.Clear = footerButton("Clear", true)
    end
    return P
end

function Components.DropdownItem(P, text, index, itemH, multi)
    local btn = Utility:Create("TextButton", {
        Name = "Option",
        SelectionImageObject = P.W._I.SelectRing,
        Size = UDim2.new(1, 0, 0, itemH),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = index,
        Theme = { BackgroundColor3 = "FieldHover" },
        Parent = P.List,
    })
    local lbl = Utility:Text("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, multi and -50 or -24, 1, 0),
        Text = text,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Label,
        TextXAlignment = Rows.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = btn,
    })
    local it = { Button = btn, Label = lbl, Text = text, Index = index }
    if multi then
        local box, fill, stroke = Rows.CheckBox(btn)
        box.AnchorPoint = Vector2.new(1, 0.5)
        box.Position = UDim2.new(1, -12, 0.5, 0)
        it.Box, it.Fill, it.Stroke = box, fill, stroke
    end
    return it
end

function Components.Dropdown(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local I = W._I
    local multi = cfg.Multi == true
    local name = tostring(cfg.Name or "Dropdown")
    local flag = cfg.Flag or cfg.Name or "Dropdown_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local options = Rows.StringList(cfg.Options)
    local default
    if multi then
        default = Rows.ToArray(SaveManager:GetInitialValue(flag, cfg.Default or {}, persistent))
    else
        default = SaveManager:GetInitialValue(flag, cfg.Default or options[1] or "None", persistent)
    end

    local row, body, entry = Rows.New(tab, multi and "MultiDropdown" or "Dropdown")
    local label = Rows.Label(body, name)
    local valueLabel = Utility:Text("TextLabel", {
        Name = "Value",
        Text = "",
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Rows.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = body,
    })
    local chevron = Glyph.Draw(body, "chevron", 10, "TextDark", { AnchorPoint = Vector2.new(0.5, 0.5) })
    local anchor = Utility:Create("Frame", { Name = "Anchor", BackgroundTransparency = 1, Parent = body })
    local hit = Rows.Hit(entry)
    entry.Hit = hit
    entry.Trunc = valueLabel

    local P = Components.DropdownPopover(W, name, multi)
    local obj = { Value = multi and {} or "", Instance = row, List = P.List }
    local items = {}
    local state = { Open = false, Highlight = nil, Follow = nil, Key = nil, ListW = 220 }

    local function itemH()
        return I.Family == "Compact" and Tokens.Size.ItemCompact or 28
    end
    local function isSelected(text)
        if multi then
            return table.find(obj.Value, text) ~= nil
        end
        return text == obj.Value
    end
    local function paintItems()
        for _, it in ipairs(items) do
            local sel = isSelected(it.Text)
            it.Button.BackgroundTransparency = state.Highlight == it and 0 or 1
            if multi then
                Utility:SetColor(it.Label, "TextColor3", "Text")
                Rows.PaintCheck(it.Fill, it.Stroke, sel, false, false, false)
            else
                Utility:SetColor(it.Label, "TextColor3", sel and "AccentText" or "Text")
            end
        end
    end
    local function visibleItems()
        local out = {}
        for _, it in ipairs(items) do
            if it.Button.Visible then
                table.insert(out, it)
            end
        end
        return out
    end
    local function applyFilter()
        local query = string.lower(P.Search.Text or "")
        local shown = 0
        for _, it in ipairs(items) do
            local visible = query == "" or string.find(string.lower(it.Text), query, 1, true) ~= nil
            it.Button.Visible = visible
            if visible then
                shown = shown + 1
            end
        end
        P.Empty.Text = #items == 0 and "No options" or "No match"
        P.Empty.Visible = shown == 0
        return shown
    end
    local function place()
        if state.Open then
            Overlays.Place(W, anchor, P.Holder, P.Holder.Size.X.Offset, P.Holder.Size.Y.Offset, 0)
        end
    end
    local function layoutList()
        local useSearch = cfg.Search == true or #items > 8
        P.Search.Visible, P.SearchGlyph.Visible, P.SearchLine.Visible = useSearch, useSearch, useSearch
        local top = useSearch and 30 or 0
        local ih = itemH()
        local shown = math.max(1, math.min(applyFilter(), 8))
        local listH = shown * ih
        for _, it in ipairs(items) do
            it.Button.Size = UDim2.new(1, 0, 0, ih)
        end
        P.Empty.Size = UDim2.new(1, 0, 0, ih)
        P.List.Position = UDim2.fromOffset(0, top + 4)
        P.List.Size = UDim2.new(1, 0, 0, listH)
        local height = top + 4 + listH + 4
        if P.Footer then
            P.Footer.Position = UDim2.fromOffset(0, height)
            height = height + 28
        end
        P.Holder.Size = UDim2.fromOffset(state.ListW, height)
        place()
    end
    local function highlight(it, scroll)
        state.Highlight = it
        paintItems()
        if it and scroll then
            local ih = itemH()
            local y = (table.find(visibleItems(), it) or 1) - 1
            local view = P.List.AbsoluteWindowSize.Y / math.max(0.01, I.OverlayScale.Scale)
            local pos = P.List.CanvasPosition.Y
            if y * ih < pos then
                P.List.CanvasPosition = Vector2.new(0, y * ih)
            elseif (y + 1) * ih > pos + view then
                P.List.CanvasPosition = Vector2.new(0, (y + 1) * ih - view)
            end
        end
    end

    local function setValue(v)
        if multi then
            local arr = Rows.ToArray(v)
            obj.Value = arr
            valueLabel.Text = #arr == 0 and "None" or (#arr == 1 and arr[1] or (tostring(#arr) .. " selected"))
            SaveManager:SetFlag(flag, table.clone(arr), persistent)
            paintItems()
            if cfg.Callback then
                cfg.Callback(table.clone(arr))
            end
        else
            obj.Value = tostring(v or "")
            valueLabel.Text = obj.Value
            SaveManager:SetFlag(flag, obj.Value, persistent)
            paintItems()
            if cfg.Callback then
                cfg.Callback(obj.Value)
            end
        end
    end
    local function close()
        if not state.Open then
            return
        end
        state.Open = false
        if state.Follow then
            state.Follow:Disconnect()
            state.Follow = nil
        end
        if state.Key then
            local index = table.find(I.KeyHandlers, state.Key)
            if index then
                table.remove(I.KeyHandlers, index)
            end
            state.Key = nil
        end
        if P.Search:IsFocused() then
            P.Search:ReleaseFocus()
        end
        if Motion.Reduced then
            chevron.Rotation = 0
        else
            Motion:Play(chevron, { Rotation = 0 }, "State", "rot")
        end
        entry.Paint(true)
        Rows.PopOut(state, P.Holder, function()
            return state.Open
        end)
    end
    local function choose(it)
        if multi then
            local set = {}
            for _, v in ipairs(obj.Value) do
                set[v] = true
            end
            set[it.Text] = not set[it.Text] or nil
            local out = {}
            for _, o in ipairs(options) do
                if set[o] then
                    table.insert(out, o)
                    set[o] = nil
                end
            end
            for _, v in ipairs(obj.Value) do
                if set[v] then
                    table.insert(out, v)
                end
            end
            setValue(out)
        else
            Overlays.ClosePopover(W)
            setValue(it.Text)
        end
    end
    local function open(byTouch)
        if state.Open or W.IsDestroyed or entry.Disabled or not I.MainFrame.Visible then
            return
        end
        if not Overlays.OpenPopover(W, { Frame = P.Holder, Anchor = hit, Close = close }) then
            return
        end
        state.Open = true
        state.Highlight = nil
        P.Search.Text = ""
        P.List.CanvasPosition = Vector2.new()
        P.Holder.Visible = true
        layoutList()
        paintItems()
        Rows.PopIn(state, P.Holder)
        if Motion.Reduced then
            chevron.Rotation = 180
        else
            Motion:Play(chevron, { Rotation = 180 }, "State", "rot")
        end
        entry.Paint(true)
        state.Follow = anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
        state.Key = function(input)
            if not state.Open then
                return false
            end
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Down or kc == Enum.KeyCode.Up then
                local list = visibleItems()
                if #list == 0 then
                    return true
                end
                local i = table.find(list, state.Highlight) or (kc == Enum.KeyCode.Down and 0 or #list + 1)
                i = math.clamp(i + (kc == Enum.KeyCode.Down and 1 or -1), 1, #list)
                highlight(list[i], true)
                return true
            elseif (kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter) and state.Highlight then
                choose(state.Highlight)
                return true
            elseif kc == Enum.KeyCode.Escape then
                Overlays.ClosePopover(W)
                return true
            end
            return false
        end
        table.insert(I.KeyHandlers, state.Key)
        if P.Search.Visible and not byTouch then
            P.Search:CaptureFocus()
        end
    end
    local function rebuild()
        for _, it in ipairs(items) do
            it.Button:Destroy()
        end
        table.clear(items)
        state.Highlight = nil
        for index, text in ipairs(options) do
            local it = Components.DropdownItem(P, text, index, itemH(), multi)
            it.Button.MouseEnter:Connect(function()
                highlight(it, false)
            end)
            it.Button.MouseLeave:Connect(function()
                if state.Highlight == it then
                    highlight(nil, false)
                end
            end)
            it.Button.Activated:Connect(function()
                choose(it)
            end)
            table.insert(items, it)
        end
        paintItems()
        applyFilter()
        if state.Open then
            layoutList()
        end
    end

    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(valueLabel, "TextColor3", dis and "TextMuted" or "Text", token)
        Glyph.Paint(chevron, dis and "TextMuted" or ((entry.Hover or state.Open) and "Text" or "TextDark"), token)
    end
    entry.OnDisabled = function(on)
        if on and state.Open then
            Overlays.ClosePopover(W)
        end
    end
    entry.Layout = function(e, mt)
        local h
        if mt.Stacked then
            local lineY = Rows.StackTop(e, mt, label)
            local lineH = mt.LineH
            valueLabel.TextXAlignment = Rows.Left
            valueLabel.Position = UDim2.fromOffset(0, lineY)
            valueLabel.Size = UDim2.fromOffset(mt.M - 20, lineH)
            chevron.Position = UDim2.fromOffset(mt.M - 5, lineY + math.floor(lineH / 2))
            anchor.Position = UDim2.fromOffset(0, lineY)
            anchor.Size = UDim2.fromOffset(mt.M, lineH)
            h = lineY + lineH + 8
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14)
            valueLabel.TextXAlignment = Rows.Right
            valueLabel.Position = UDim2.fromOffset(mt.M - mt.CW, 0)
            valueLabel.Size = UDim2.fromOffset(mt.CW - 20, h)
            chevron.Position = UDim2.fromOffset(mt.M - 5, math.floor(h / 2))
            anchor.Position = UDim2.fromOffset(mt.M - mt.CW, 0)
            anchor.Size = UDim2.fromOffset(mt.CW, h)
        end
        state.ListW = mt.Stacked and mt.M or mt.CW
        e.ControlX = mt.Stacked and 0 or (mt.M - mt.CW)
        if state.Open then
            task.defer(layoutList)
        end
        return h
    end

    function obj:SetValue(v)
        setValue(v)
    end
    function obj:SetOptions(newOptions)
        options = Rows.StringList(newOptions)
        rebuild()
    end
    function obj:GetOptions()
        return table.clone(options)
    end
    function obj:Open()
        open(false)
    end
    function obj:Close()
        if state.Open then
            Overlays.ClosePopover(W)
        end
    end

    P.Search:GetPropertyChangedSignal("Text"):Connect(function()
        if state.Open then
            state.Highlight = nil
            layoutList()
            paintItems()
        end
    end)
    if P.All then
        P.All.Activated:Connect(function()
            setValue(table.clone(options))
        end)
        P.Clear.Activated:Connect(function()
            setValue({})
        end)
    end
    Rows.HoverWire(entry, hit)
    hit.Activated:Connect(function(input)
        if state.Open then
            Overlays.ClosePopover(W)
        else
            open(input ~= nil and typeof(input) == "Instance" and input.UserInputType == Enum.UserInputType.Touch)
        end
    end)
    row.AncestryChanged:Connect(function()
        if not row:IsDescendantOf(game) then
            if state.Open then
                Overlays.ClosePopover(W)
            end
            if not row.Parent then
                pcall(function()
                    P.Holder:Destroy()
                end)
            end
        end
    end)

    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, multi and "MultiDropdown" or "Dropdown", name, entry, obj)
    rebuild()
    entry.Paint(false)
    setValue(default)
    SaveManager:RegisterOption(flag, obj, persistent)
    return obj
end

-- ------------------------------------------------------------------------------
-- Keybind: key cap (Field, 13 Medium); listening says "Press a key"; Escape cancels; no callback at creation
-- ------------------------------------------------------------------------------

function Components.Keybind(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Keybind")
    local flag = cfg.Flag or cfg.Name or "Keybind_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local default = NormalizeKeyCode(SaveManager:GetInitialValue(flag, cfg.Default or "K", persistent), Enum.KeyCode.K)
    SaveManager:SetFlag(flag, default.Name, false)

    local row, body, entry = Rows.New(tab, "Keybind")
    local label = Rows.Label(body, name)
    local cap = Utility:Text("TextLabel", {
        Name = "Keycap",
        Text = default.Name,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Key,
        TextXAlignment = Rows.Center,
        BackgroundTransparency = 0,
        ZIndex = 3,
        Color = "Text",
        Theme = { BackgroundColor3 = "Field" },
        Parent = body,
    })
    local hit = Rows.Hit(entry)
    entry.Hit = hit
    local obj = { Value = default, Instance = row }
    local state = { Listening = false }
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(cap, "BackgroundColor3", ((entry.Hover or state.Listening) and not dis) and "FieldHover" or "Field", token)
        Utility:SetColor(cap, "TextColor3", dis and "TextMuted" or (state.Listening and "TextDark" or "Text"))
    end
    entry.Layout = function(e, mt)
        local text = state.Listening and "Press a key" or obj.Value.Name
        local w = math.max(34, Rows.TextW(text, 13, state.Listening and "Regular" or "Medium") + 18)
        local lw = mt.Stacked and math.max(60, mt.M - w - 16) or mt.LW
        local h = Rows.SideLabel(e, mt, label, mt.RowH, 14, lw)
        cap.Text = text
        cap.FontFace = Utility:Font("Sans", state.Listening and "Regular" or "Medium")
        cap.Position = UDim2.fromOffset(mt.M - w, math.floor((h - mt.FieldH) / 2))
        cap.Size = UDim2.fromOffset(w, mt.FieldH)
        e.ControlX = mt.M - w
        return h
    end
    local function stopListening()
        state.Listening = false
        if W._I.Capture == state.Capture then
            W._I.Capture = nil
        end
        Rows.Apply(entry)
        entry.Paint(true)
    end
    function obj:SetValue(key)
        local resolved = NormalizeKeyCode(key, self.Value)
        self.Value = resolved
        SaveManager:SetFlag(flag, resolved.Name, persistent)
        stopListening()
        if cfg.Callback then
            cfg.Callback(resolved)
        end
    end
    Rows.HoverWire(entry, hit)
    hit.Activated:Connect(function()
        if W.IsDestroyed or entry.Disabled then
            return
        end
        if state.Listening then
            stopListening()
            return
        end
        state.Listening = true
        state.Capture = function(keyCode)
            if not state.Listening then
                return
            end
            if keyCode == Enum.KeyCode.Escape or keyCode == Enum.KeyCode.Unknown then
                stopListening()
                return
            end
            obj:SetValue(keyCode)
        end
        W._I.Capture = state.Capture
        Rows.Apply(entry)
        entry.Paint(true)
    end)
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Keybind", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    entry.Paint(false)
    return obj
end

-- ------------------------------------------------------------------------------
-- Label: product sentence (13 Regular TextDark), wraps at min(measure, 470), grows with its text.
-- A short heading-like label (32 characters or fewer, no sentence punctuation) gets 10 px air above, as B.
-- ------------------------------------------------------------------------------

function Components.Label(tab, text)
    local row, body, entry = Rows.New(tab, "Label", true)
    local pad = Utility:Padding(body, 6, 0, 6, 0)
    local label = Utility:Text("TextLabel", {
        Name = "Label",
        Size = UDim2.fromOffset(470, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = tostring(text or ""),
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextWrapped = true,
        TextXAlignment = Rows.Left,
        TextYAlignment = Rows.Top,
        Color = "TextDark",
        Parent = body,
    })
    entry.Label = label
    local function sync()
        local t = label.Text
        entry.Empty = t == ""
        local lead = (#t <= 32 and not t:find("[%.,:;!%?]")) and 10 or 0
        pad.PaddingTop = UDim.new(0, 6 + lead)
        Rows.UpdateVisible(entry)
    end
    entry.Layout = function(_, mt)
        label.Size = UDim2.fromOffset(mt.TextW, 0)
    end
    label:GetPropertyChangedSignal("Text"):Connect(function()
        local wasEmpty = entry.Empty
        sync()
        if wasEmpty ~= entry.Empty then
            Rows.Schedule(tab)
        end
    end)
    sync()
    local obj = { Instance = row, Label = label }
    function obj:SetText(value)
        label.Text = tostring(value or "")
    end
    Rows.Add(tab, entry)
    return obj
end

-- ------------------------------------------------------------------------------
-- Paragraph: no card; title 14 Medium, 4 px, content 13 Regular TextDark at the real width
-- ------------------------------------------------------------------------------

function Components.Paragraph(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local row, body, entry = Rows.New(tab, "Paragraph", true)
    Utility:Padding(body, 6, 0, 8, 0)
    Utility:List(body, Enum.FillDirection.Vertical, 4)
    local title = Utility:Text("TextLabel", {
        Name = "Title",
        Size = UDim2.fromOffset(470, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = tostring(cfg.Title or "Info"),
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Label,
        TextWrapped = true,
        TextXAlignment = Rows.Left,
        TextYAlignment = Rows.Top,
        LayoutOrder = 1,
        Color = "Text",
        Parent = body,
    })
    local content = Utility:Text("TextLabel", {
        Name = "Content",
        Size = UDim2.fromOffset(470, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = tostring(cfg.Content or ""),
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextWrapped = true,
        TextXAlignment = Rows.Left,
        TextYAlignment = Rows.Top,
        LayoutOrder = 2,
        Color = "TextDark",
        Parent = body,
    })
    entry.Layout = function(_, mt)
        title.Size = UDim2.fromOffset(mt.TextW, 0)
        content.Size = UDim2.fromOffset(mt.TextW, 0)
    end
    local obj = { Instance = row, Title = title, Content = content }
    function obj:SetTitle(text)
        title.Text = tostring(text or "")
    end
    function obj:SetContent(text)
        content.Text = tostring(text or "")
    end
    Rows.Add(tab, entry)
    return obj
end

-- ------------------------------------------------------------------------------
-- Spacer: transparent row, 2..80 px (default 8)
-- ------------------------------------------------------------------------------

function Components.Spacer(tab, height)
    local row, _, entry = Rows.New(tab, "Spacer")
    local h = ClampNumber(height or 8, 2, 80)
    entry.Layout = function()
        return h
    end
    Rows.Add(tab, entry)
    return { Instance = row }
end

-- ------------------------------------------------------------------------------
-- Divider (N): 1 px Text line with B's floor fade; optional 13 TextDark text at the left
-- ------------------------------------------------------------------------------

function Components.Divider(tab, spec)
    local text = type(spec) == "table" and spec.Text or spec
    text = text ~= nil and tostring(text) or ""
    local row, body, entry = Rows.New(tab, "Divider")
    local label = Utility:Text("TextLabel", {
        Name = "Label",
        Text = text,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Rows.Left,
        Color = "TextDark",
        Parent = body,
    })
    local line = Utility:Create("Frame", {
        Name = "Line",
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Text" },
        Parent = body,
    })
    local grad = Utility:Gradient(line, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } })
    entry.Layout = function(_, mt)
        local t = label.Text
        if t ~= "" then
            local tw = math.min(Rows.TextW(t, 13, "Regular"), mt.M - 40)
            label.Visible = true
            label.Position = UDim2.fromOffset(0, 0)
            label.Size = UDim2.fromOffset(tw + 2, 17)
            line.Position = UDim2.fromOffset(tw + 12, 8)
            line.Size = UDim2.fromOffset(math.max(0, mt.M - tw - 12), 1)
            grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
        else
            label.Visible = false
            line.Position = UDim2.fromOffset(0, 8)
            line.Size = UDim2.fromOffset(mt.M, 1)
            grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
        end
        return 17
    end
    local obj = { Instance = row }
    function obj:SetText(value)
        label.Text = value ~= nil and tostring(value) or ""
        Rows.Apply(entry)
    end
    Rows.Add(tab, entry)
    return obj
end

-- ------------------------------------------------------------------------------
-- Dashboard stats: transparent cells, 2 columns (1 for one stat or under 420), gap 24.
-- Each StatCell holds exactly two TextLabels (upper-cased title, value) so product restyles keep working.
-- ------------------------------------------------------------------------------

function Components.DashboardStats(tab, stats)
    if type(stats) ~= "table" or #stats == 0 then
        return nil
    end
    local W = tab.Window
    local row, body, entry = Rows.New(tab, "DashboardStats", true)
    Utility:List(body, Enum.FillDirection.Vertical, 0)
    local cells, values = {}, {}
    for i, stat in ipairs(stats) do
        local cell = Utility:Create("Frame", {
            Name = "StatCell",
            Size = UDim2.fromOffset(274, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = i,
        })
        Utility:List(cell, Enum.FillDirection.Vertical, 4)
        Utility:Padding(cell, 6, 0, 14, 0)
        Utility:Text("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, 0, 0, 14),
            Text = string.upper(tostring(stat.Title or "")),
            Font = { "Sans", "Medium" },
            TextSize = Tokens.Text.StatTitle,
            TextXAlignment = Rows.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = 1,
            Color = "TextDark",
            Parent = cell,
        })
        values[i] = Utility:Text("TextLabel", {
            Name = "Value",
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(stat.Value or ""),
            Font = { "Sans", "Medium" },
            TextSize = Tokens.Text.Section,
            TextWrapped = true,
            TextXAlignment = Rows.Left,
            TextYAlignment = Rows.Top,
            LayoutOrder = 2,
            Color = "Text",
            Parent = cell,
        })
        cells[i] = cell
    end
    local lines, columns = {}, 0
    entry.Layout = function(_, mt)
        local cols = (#cells == 1 or mt.M < Tokens.B.StackBelow) and 1 or 2
        local cw = cols == 2 and math.floor((mt.M - 24) / 2) or mt.M
        if cols ~= columns then
            columns = cols
            for _, c in ipairs(cells) do
                c.Parent = nil
            end
            for _, l in ipairs(lines) do
                l:Destroy()
            end
            table.clear(lines)
            for i = 1, #cells, cols do
                local line = Utility:Create("Frame", {
                    Name = "StatRow",
                    Size = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = i,
                })
                Utility:List(line, Enum.FillDirection.Horizontal, 24)
                for j = i, math.min(i + cols - 1, #cells) do
                    cells[j].Parent = line
                end
                line.Parent = body
                table.insert(lines, line)
            end
        end
        for _, c in ipairs(cells) do
            c.Size = UDim2.fromOffset(cw, 0)
        end
    end
    Rows.Add(tab, entry)
    for i, stat in ipairs(stats) do
        if type(stat.UpdateHook) == "function" then
            local hook, cell, value = stat.UpdateHook, cells[i], values[i]
            task.spawn(function()
                while row.Parent and not W.IsDestroyed do
                    local ok, result = pcall(hook)
                    if ok and result ~= nil and value.Parent then
                        value.Text = tostring(result)
                    end
                    task.wait(1)
                    if not cell.Parent then
                        break
                    end
                end
            end)
        end
    end
    return nil
end

-- ------------------------------------------------------------------------------
-- Color picker (N): swatch + hex field; popover with SV square, hue strip and preset swatches.
-- Callback(Color3) at creation, on every change; saved as "0F57D4".
-- ------------------------------------------------------------------------------

function Components.ColorPicker(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local I = W._I
    local name = tostring(cfg.Name or "Color")
    local flag = cfg.Flag or cfg.Name or "ColorPicker_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local function toColor(v)
        if typeof(v) == "Color3" then
            return v
        end
        if v ~= nil then
            return Utility.HexToColor(v)
        end
        return nil
    end
    local default = toColor(SaveManager:GetInitialValue(flag, cfg.Default, persistent)) or toColor(cfg.Default) or ThemeManager:Get("Accent")

    local row, body, entry = Rows.New(tab, "ColorPicker")
    local label = Rows.Label(body, name)
    local hit = Rows.Hit(entry)
    entry.Hit = hit
    local swHit = Utility:Create("TextButton", {
        Name = "Swatch",
        Size = UDim2.fromOffset(22, 26),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 3,
        SelectionImageObject = I.SelectRing,
        Parent = body,
    })
    local sw = Utility:Create("Frame", {
        Name = "Fill",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BorderSizePixel = 0,
        BackgroundColor3 = default,
        Parent = swHit,
    })
    Utility:Corner(sw, 2)
    local field = Utility:Create("Frame", {
        Name = "Hex",
        BorderSizePixel = 0,
        ZIndex = 3,
        Theme = { BackgroundColor3 = "Field" },
        Parent = body,
    })
    local box = Utility:Text("TextBox", {
        Name = "Value",
        SelectionImageObject = tab.Window._I.SelectRing,
        Size = UDim2.fromScale(1, 1),
        ClearTextOnFocus = false,
        Text = Utility.ColorToHex(default),
        PlaceholderText = "#0F57D4",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Rows.Left,
        ZIndex = 3,
        Color = "Text",
        Theme = { PlaceholderColor3 = "TextDark" },
        Parent = field,
    })
    Utility:Padding(box, 0, 9, 0, 9)
    local line = Rows.FieldLine(field)

    -- popover
    local pop = Utility:Create("Frame", {
        Name = "ColorPicker_" .. name,
        Size = UDim2.fromOffset(240, 186),
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
        ZIndex = 30,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.Overlay,
    })
    Utility:Edge(pop)
    local sv = Utility:Create("Frame", {
        Name = "SV",
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(216, 120),
        BorderSizePixel = 0,
        Active = true,
        Parent = pop,
    })
    local white = Utility:Create("Frame", { Name = "White", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
    Utility:Gradient(white, { { 0, 0 }, { 1, 1 } })
    local black = Utility:Create("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
    Utility:Gradient(black, { { 0, 1 }, { 1, 0 } }, 90)
    local cursor = Utility:Create("Frame", {
        Name = "Cursor",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = sv,
    })
    Utility:Corner(cursor, UDim.new(0.5, 0))
    Utility:Stroke(cursor, "Text", 1.5)
    local hue = Utility:Create("Frame", {
        Name = "Hue",
        Position = UDim2.fromOffset(12, 142),
        Size = UDim2.fromOffset(216, 8),
        BorderSizePixel = 0,
        Active = true,
        BackgroundColor3 = Color3.new(1, 1, 1),
        Parent = pop,
    })
    local keys = {}
    for i = 0, 6 do
        table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
    end
    Utility:Create("UIGradient", { Color = ColorSequence.new(keys), Parent = hue })
    local handle = Utility:Create("Frame", {
        Name = "Handle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(2, 12),
        BorderSizePixel = 0,
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = hue,
    })
    local presetColors = {}
    for _, c in ipairs(type(cfg.Presets) == "table" and cfg.Presets or {}) do
        local color = toColor(c)
        if color then
            table.insert(presetColors, color)
        end
    end
    if #presetColors == 0 then
        for _, n in ipairs(ThemeManager.ThemeOrder) do
            local t = ThemeManager.Themes[n]
            table.insert(presetColors, t.PresetAccent or t.Accent)
        end
    end
    local presetHits = {}
    for i, color in ipairs(presetColors) do
        if i > 9 then
            break
        end
        local ph = Utility:Create("TextButton", {
            Name = "Preset",
            SelectionImageObject = tab.Window._I.SelectRing,
            Position = UDim2.fromOffset(12 + (i - 1) * 22 - 4, 160),
            Size = UDim2.fromOffset(22, 22),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Parent = pop,
        })
        local f = Utility:Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(14, 14),
            BorderSizePixel = 0,
            BackgroundColor3 = color,
            Parent = ph,
        })
        Utility:Corner(f, 2)
        local ring = Utility:Create("Frame", {
            Name = "Ring",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = f,
        })
        Utility:Stroke(ring, "Text", 1)
        Utility:Corner(ring, 4)
        presetHits[i] = { Hit = ph, Ring = ring, Color = color }
    end

    local obj = { Value = default, Instance = row }
    local state = { Open = false, H = 0, S = 0, V = 0, FieldHover = false, Focused = false }
    state.H, state.S, state.V = default:ToHSV()
    local function paintPicker()
        sv.BackgroundColor3 = Color3.fromHSV(state.H, 1, 1)
        cursor.Position = UDim2.fromScale(state.S, 1 - state.V)
        handle.Position = UDim2.fromScale(state.H, 0.5)
        for _, p in ipairs(presetHits) do
            p.Ring.Visible = ThemeManager.SameColor(p.Color, obj.Value)
        end
    end
    local function setValue(c, keepHSV)
        obj.Value = c
        if not keepHSV then
            local h, s, v = c:ToHSV()
            if s > 0 and v > 0 then
                state.H = h
            end
            state.S, state.V = s, v
        end
        sw.BackgroundColor3 = c
        if not box:IsFocused() then
            box.Text = Utility.ColorToHex(c)
        end
        SaveManager:SetFlag(flag, Utility.ColorToHex(c):sub(2), persistent)
        paintPicker()
        if cfg.Callback then
            cfg.Callback(c)
        end
    end
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(field, "BackgroundColor3", ((state.Focused or state.FieldHover) and not dis) and "FieldHover" or "Field", token)
        Utility:SetColor(box, "TextColor3", dis and "TextMuted" or "Text")
        local err = entry.ErrorText ~= nil
        line.Visible = state.Focused or err
        Utility:SetColor(line, "BackgroundColor3", err and "Error" or "Text")
        line.BackgroundTransparency = err and 0 or 0.3
        box.TextEditable = not dis
    end
    entry.Layout = function(e, mt)
        local h
        if mt.Stacked then
            local lineY = Rows.StackTop(e, mt, label)
            swHit.Position = UDim2.fromOffset(-4, lineY + math.floor((mt.FieldH - 26) / 2))
            field.Position = UDim2.fromOffset(22, lineY)
            field.Size = UDim2.fromOffset(84, mt.FieldH)
            h = lineY + mt.FieldH + 8
            e.ControlX = 0
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14)
            field.Position = UDim2.fromOffset(mt.M - 84, math.floor((h - mt.FieldH) / 2))
            field.Size = UDim2.fromOffset(84, mt.FieldH)
            swHit.Position = UDim2.fromOffset(mt.M - 84 - 8 - 14 - 4, math.floor((h - 26) / 2))
            e.ControlX = mt.M - 84 - 22
        end
        return h
    end
    local function closePop()
        if not state.Open then
            return
        end
        state.Open = false
        if state.Follow then
            state.Follow:Disconnect()
            state.Follow = nil
        end
        Rows.PopOut(state, pop, function()
            return state.Open
        end)
    end
    local function openPop()
        if state.Open or W.IsDestroyed or entry.Disabled or not I.MainFrame.Visible then
            return
        end
        if not Overlays.OpenPopover(W, { Frame = pop, Anchor = swHit, Close = closePop }) then
            return
        end
        state.Open = true
        pop.Visible = true
        paintPicker()
        Overlays.Place(W, swHit, pop, 240, 186, 4)
        Rows.PopIn(state, pop)
        state.Follow = swHit:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if state.Open then
                Overlays.Place(W, swHit, pop, 240, 186, 4)
            end
        end)
    end
    local function dragOn(frame, apply)
        frame.InputBegan:Connect(function(input)
            if W.IsDestroyed or entry.Disabled or not Shell.IsPointer(input) or input.UserInputState ~= Enum.UserInputState.Begin then
                return
            end
            local function at(pos)
                local p, s = frame.AbsolutePosition, frame.AbsoluteSize
                local rx = s.X > 0 and math.clamp((pos.X - p.X) / s.X, 0, 1) or 0
                local ry = s.Y > 0 and math.clamp((pos.Y - p.Y) / s.Y, 0, 1) or 0
                apply(rx, ry)
            end
            at(input.Position)
            Shell.BeginDrag(W, input, function(_, move)
                at(move.Position)
            end)
        end)
    end
    dragOn(sv, function(rx, ry)
        state.S, state.V = rx, 1 - ry
        setValue(Color3.fromHSV(state.H, state.S, state.V), true)
    end)
    dragOn(hue, function(rx)
        state.H = math.min(rx, 0.999)
        setValue(Color3.fromHSV(state.H, state.S, state.V), true)
    end)
    for _, p in ipairs(presetHits) do
        p.Hit.Activated:Connect(function()
            if not entry.Disabled then
                setValue(p.Color)
            end
        end)
    end
    function obj:SetValue(v)
        local c = toColor(v)
        if c then
            Rows.SetError(entry, nil)
            setValue(c)
        end
    end
    swHit.Activated:Connect(function()
        if state.Open then
            Overlays.ClosePopover(W)
        else
            openPop()
        end
    end)
    hit.Activated:Connect(function()
        if state.Open then
            Overlays.ClosePopover(W)
        else
            openPop()
        end
    end)
    field.MouseEnter:Connect(function()
        state.FieldHover = true
        entry.Paint(true)
    end)
    field.MouseLeave:Connect(function()
        state.FieldHover = false
        entry.Paint(true)
    end)
    box.Focused:Connect(function()
        state.Focused = true
        entry.Paint(true)
    end)
    box.FocusLost:Connect(function()
        state.Focused = false
        local c = Utility.HexToColor(box.Text)
        if c and not entry.Disabled then
            Rows.SetError(entry, nil)
            setValue(c)
        else
            box.Text = Utility.ColorToHex(obj.Value)
            Rows.SetError(entry, "Use a hex colour like #0F57D4.")
        end
        entry.Paint(true)
    end)
    row.AncestryChanged:Connect(function()
        if not row:IsDescendantOf(game) then
            if state.Open then
                Overlays.ClosePopover(W)
            end
            if not row.Parent then
                pcall(function()
                    pop:Destroy()
                end)
            end
        end
    end)
    entry.OnDisabled = function(on)
        if on and state.Open then
            Overlays.ClosePopover(W)
        end
    end
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "ColorPicker", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    entry.Paint(false)
    setValue(default)
    return obj
end

-- ------------------------------------------------------------------------------
-- Progress (N): slider geometry without a knob; "64%", "Done" at 100, "Working" when indeterminate
-- ------------------------------------------------------------------------------

function Components.Progress(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Progress")
    local row, body, entry = Rows.New(tab, "Progress")
    local label = Rows.Label(body, name)
    local track = Utility:Create("Frame", {
        Name = "Track",
        Size = UDim2.fromOffset(168, 2),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Theme = { BackgroundColor3 = "BorderHighlight" },
        Parent = body,
    })
    local fill = Utility:Create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    local seg = Utility:Create("Frame", {
        Name = "Segment",
        Size = UDim2.fromScale(0.3, 1),
        BorderSizePixel = 0,
        Visible = false,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    local valueLabel = Utility:Text("TextLabel", {
        Name = "Value",
        Text = "",
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Rows.Right,
        Color = "Text",
        Parent = body,
    })
    local state = {
        Min = tonumber(cfg.Min) or 0,
        Max = tonumber(cfg.Max) or 100,
        Value = 0,
        Text = cfg.Text ~= nil and tostring(cfg.Text) or nil,
        Indeterminate = cfg.Indeterminate == true,
        Loop = nil,
    }
    if state.Max <= state.Min then
        state.Max = state.Min + 1
    end
    state.Value = math.clamp(tonumber(cfg.Value) or state.Min, state.Min, state.Max)
    local obj = { Instance = row, Value = state.Value }
    local function stopLoop()
        if state.Loop then
            pcall(function()
                state.Loop:Cancel()
            end)
            state.Loop = nil
        end
    end
    local function syncLoop()
        local run = state.Indeterminate and tab._root ~= nil and tab._root.Visible and row.Parent ~= nil and not W.IsDestroyed
        seg.Visible = state.Indeterminate
        if run and not Motion.Reduced then
            if not state.Loop then
                seg.Position = UDim2.fromScale(-0.3, 0)
                local ok, tw = pcall(function()
                    return TweenService:Create(seg, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Position = UDim2.fromScale(1, 0) })
                end)
                if ok and tw then
                    state.Loop = tw
                    tw:Play()
                end
            end
        else
            stopLoop()
            seg.Position = UDim2.fromScale(0, 0)
        end
    end
    local function render(animate)
        local frac = math.clamp((state.Value - state.Min) / (state.Max - state.Min), 0, 1)
        fill.Visible = not state.Indeterminate
        if animate and not Motion.Reduced then
            Motion:Play(fill, { Size = UDim2.fromScale(frac, 1) }, "Enter", "size")
        else
            Motion:Stop(fill, "size")
            fill.Size = UDim2.fromScale(frac, 1)
        end
        local text = state.Text
        if not text then
            if state.Indeterminate then
                text = "Working"
            elseif frac >= 1 then
                text = "Done"
            else
                text = tostring(math.floor(frac * 100 + 0.5)) .. "%"
            end
        end
        valueLabel.Text = text
        syncLoop()
    end
    entry.Layout = function(e, mt)
        local h, x0, trackW, cy
        local vw = math.max(40, Rows.TextW(valueLabel.Text, 14, "Medium") + 4)
        if mt.Stacked then
            local want = mt.M - math.max(52, vw + 12)
            local onLabel = want < 160
            local lineY = Rows.StackTop(e, mt, label, onLabel and (vw + 8) or 0)
            local lineH = 24
            trackW = onLabel and mt.M or want
            x0 = 0
            cy = lineY + 12
            h = lineY + lineH + 8
            valueLabel.Position = onLabel and UDim2.fromOffset(mt.M - vw, 6) or UDim2.fromOffset(mt.M - vw, lineY)
            valueLabel.Size = UDim2.fromOffset(vw, onLabel and 18 or lineH)
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14)
            x0 = mt.M - mt.CW
            trackW = mt.CW - math.max(52, vw + 12)
            cy = math.floor(h / 2)
            valueLabel.Position = UDim2.fromOffset(mt.M - vw, 0)
            valueLabel.Size = UDim2.fromOffset(vw, h)
        end
        track.Position = UDim2.fromOffset(x0, cy - 1)
        track.Size = UDim2.fromOffset(trackW, 2)
        e.ControlX = x0
        return h
    end
    function obj:SetValue(v)
        state.Value = math.clamp(tonumber(v) or state.Min, state.Min, state.Max)
        obj.Value = state.Value
        render(true)
    end
    function obj:SetText(text)
        state.Text = text ~= nil and tostring(text) or nil
        render(false)
        Rows.Apply(entry)
    end
    function obj:SetIndeterminate(on)
        state.Indeterminate = on == true
        render(false)
        Rows.Apply(entry)
    end
    if tab._root then
        tab._root:GetPropertyChangedSignal("Visible"):Connect(syncLoop)
    end
    row.AncestryChanged:Connect(function()
        if not row.Parent then
            stopLoop()
        end
    end)
    Rows.Decorate(entry, obj, cfg)
    render(false)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Progress", name, entry, obj)
    syncLoop()
    return obj
end

-- ------------------------------------------------------------------------------
-- Segmented (N): 2..5 text options, selected Text with a 1.5 px underline that slides
-- callback at creation, on every click and SetValue (as the dropdown)
-- ------------------------------------------------------------------------------

function Components.Segmented(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Segmented")
    local flag = cfg.Flag or cfg.Name or "Segmented_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local options = Rows.StringList(cfg.Options)
    if #options == 0 then
        options = { "On", "Off" }
    end
    local default = tostring(SaveManager:GetInitialValue(flag, cfg.Default or options[1], persistent))

    local row, body, entry = Rows.New(tab, "Segmented")
    local label = Rows.Label(body, name)
    local underline = Utility:Create("Frame", {
        Name = "Underline",
        Size = UDim2.fromOffset(20, 1.5),
        BorderSizePixel = 0,
        ZIndex = 3,
        Theme = { BackgroundColor3 = "Text" },
        Parent = body,
    })
    local obj = { Value = default, Instance = row }
    local buttons = {}
    local state = { Placed = false }
    local function build()
        for _, b in ipairs(buttons) do
            b.Button:Destroy()
        end
        table.clear(buttons)
        for i, text in ipairs(options) do
            local btn = Utility:Text("TextButton", {
                Name = "Option",
                AutoButtonColor = false,
                Text = text,
                Font = { "Sans", "Regular" },
                TextSize = Tokens.Text.Label,
                TextXAlignment = Rows.Center,
                ZIndex = 3,
                Color = "TextDark",
                SelectionImageObject = W._I.SelectRing,
                Parent = body,
            })
            local b = { Button = btn, Text = text, Index = i, Hover = false, W = Rows.TextW(text, 14, "Regular") }
            btn.MouseEnter:Connect(function()
                b.Hover = true
                entry.Paint(true)
            end)
            btn.MouseLeave:Connect(function()
                b.Hover = false
                entry.Paint(true)
            end)
            btn.Activated:Connect(function()
                if not entry.Disabled and not W.IsDestroyed then
                    obj:SetValue(text)
                end
            end)
            table.insert(buttons, b)
        end
    end
    local function placeUnderline(animate)
        local sel = nil
        for _, b in ipairs(buttons) do
            if b.Text == obj.Value then
                sel = b
            end
        end
        underline.Visible = sel ~= nil
        if not sel then
            return
        end
        local target = { Position = UDim2.fromOffset(sel.TX, sel.UY), Size = UDim2.fromOffset(sel.W, 1.5) }
        if animate and state.Placed and not Motion.Reduced then
            local dx = math.abs(underline.Position.X.Offset - sel.TX)
            Motion:Play(underline, target, "Move", "slide", dx)
        else
            Motion:Stop(underline, "slide")
            underline.Position, underline.Size = target.Position, target.Size
        end
        state.Placed = true
    end
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        for _, b in ipairs(buttons) do
            local sel = b.Text == obj.Value
            local key = dis and "TextMuted" or ((sel or b.Hover) and "Text" or "TextDark")
            Utility:SetColor(b.Button, "TextColor3", key, token)
        end
        Utility:SetColor(underline, "BackgroundColor3", dis and "TextMuted" or "Text")
    end
    entry.Layout = function(e, mt)
        local total = 0
        for i, b in ipairs(buttons) do
            total = total + b.W + (i > 1 and 18 or 0)
        end
        local h, x, lineY, lineH
        if mt.Stacked or total > mt.M - 120 then
            lineY = Rows.StackTop(e, mt, label)
            lineH = mt.Compact and 44 or 28
            h = lineY + lineH + 8
            x = 0
        else
            local lw = math.min(mt.LW, mt.M - total - 16)
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14, lw)
            lineY, lineH = 0, h
            x = mt.M - total
        end
        e.ControlX = x
        for _, b in ipairs(buttons) do
            b.TX = x
            b.UY = lineY + math.floor(lineH / 2) + 10
            b.Button.Position = UDim2.fromOffset(x - 6, lineY)
            b.Button.Size = UDim2.fromOffset(b.W + 12, lineH)
            x = x + b.W + 18
        end
        placeUnderline(false)
        return h
    end
    function obj:SetValue(v)
        obj.Value = tostring(v or "")
        SaveManager:SetFlag(flag, obj.Value, persistent)
        entry.Paint(true)
        placeUnderline(true)
        if cfg.Callback then
            cfg.Callback(obj.Value)
        end
    end
    function obj:SetOptions(list)
        local new = Rows.StringList(list)
        if #new > 0 then
            options = new
            build()
            Rows.Apply(entry)
            entry.Paint(false)
        end
    end
    build()
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Segmented", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    entry.Paint(false)
    obj:SetValue(default)
    return obj
end

-- ------------------------------------------------------------------------------
-- Stepper (N): minus / value / plus (96 x 26); hold repeats after 0.4 s every 0.08 s
-- callback at creation, on every step, typed value and SetValue (as the slider)
-- ------------------------------------------------------------------------------

function Components.Stepper(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local name = tostring(cfg.Name or "Stepper")
    local flag = cfg.Flag or cfg.Name or "Stepper_1"
    local persistent = SaveManager:IsPersistent(flag, cfg)
    local min = tonumber(cfg.Min) or 0
    local max = tonumber(cfg.Max) or 10
    if max < min then
        min, max = max, min
    end
    local step = math.abs(tonumber(cfg.Step) or 1)
    if step == 0 then
        step = 1
    end
    local decimals = math.max(0, math.floor(tonumber(cfg.Decimals) or 0))
    local suffix = cfg.Suffix ~= nil and tostring(cfg.Suffix) or ""
    local function normalize(v)
        local n = tonumber(v)
        if not n or n ~= n then
            n = min
        end
        n = math.clamp(n, min, max)
        local p = 10 ^ decimals
        return math.floor(n * p + 0.5) / p
    end
    local function format(v)
        local s = decimals == 0 and tostring(math.floor(v + 0.5)) or string.format("%." .. decimals .. "f", v)
        return s .. suffix
    end
    local default = normalize(SaveManager:GetInitialValue(flag, cfg.Default or min, persistent))

    local row, body, entry = Rows.New(tab, "Stepper")
    local label = Rows.Label(body, name)
    local ctl = Utility:Create("Frame", { Name = "Stepper", BackgroundTransparency = 1, ZIndex = 3, Parent = body })
    local function glyphButton(glyph)
        local b = Utility:Create("TextButton", {
            Name = glyph == "zoomOut" and "Minus" or "Plus",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 3,
            SelectionImageObject = W._I.SelectRing,
            Parent = ctl,
        })
        local g = Glyph.Draw(b, glyph, 12, "TextDark", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        return { Button = b, Glyph = g, Hover = false, Dir = glyph == "zoomOut" and -1 or 1 }
    end
    local minus, plus = glyphButton("zoomOut"), glyphButton("zoomIn")
    local box = Utility:Text("TextBox", {
        Name = "Value",
        SelectionImageObject = tab.Window._I.SelectRing,
        ClearTextOnFocus = false,
        Text = format(default),
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Rows.Center,
        BackgroundTransparency = 1,
        ZIndex = 3,
        Color = "Text",
        Theme = { BackgroundColor3 = "Field" },
        Parent = ctl,
    })
    local obj = { Value = default, Instance = row }
    local state = { Hold = 0 }
    entry.Paint = function(animate)
        local dis = entry.Disabled == true
        local token = animate and "Hover" or nil
        Utility:SetColor(label, "TextColor3", dis and "TextMuted" or "Text", token)
        Utility:SetColor(box, "TextColor3", dis and "TextMuted" or "Text")
        for _, g in ipairs({ minus, plus }) do
            local atLimit = (g.Dir < 0 and obj.Value <= min) or (g.Dir > 0 and obj.Value >= max)
            Glyph.Paint(g.Glyph, (dis or atLimit) and "TextMuted" or (g.Hover and "Text" or "TextDark"), token)
        end
        box.TextEditable = not dis
    end
    entry.Layout = function(e, mt)
        local hw = mt.HitH
        local cw = hw * 2 + 44
        local h, x, y
        if mt.Stacked then
            local lineY = Rows.StackTop(e, mt, label)
            h = lineY + math.max(mt.FieldH, hw) + 8
            x, y = 0, lineY
        else
            h = Rows.SideLabel(e, mt, label, mt.RowH, 14, math.min(mt.LW, mt.M - cw - 16))
            x, y = mt.M - cw, math.floor((h - math.max(mt.FieldH, hw)) / 2)
        end
        local ch = math.max(mt.FieldH, hw)
        ctl.Position = UDim2.fromOffset(x, y)
        ctl.Size = UDim2.fromOffset(cw, ch)
        minus.Button.Position = UDim2.fromOffset(0, 0)
        minus.Button.Size = UDim2.fromOffset(hw, ch)
        box.Position = UDim2.fromOffset(hw, math.floor((ch - mt.FieldH) / 2))
        box.Size = UDim2.fromOffset(44, mt.FieldH)
        plus.Button.Position = UDim2.fromOffset(hw + 44, 0)
        plus.Button.Size = UDim2.fromOffset(hw, ch)
        e.ControlX = x
        return h
    end
    function obj:SetValue(v)
        self.Value = normalize(v)
        SaveManager:SetFlag(flag, self.Value, persistent)
        if not box:IsFocused() then
            box.Text = format(self.Value)
        end
        entry.Paint(false)
        if cfg.Callback then
            cfg.Callback(self.Value)
        end
    end
    local function stepBy(dir)
        local target = normalize(obj.Value + dir * step)
        if target ~= obj.Value then
            obj:SetValue(target)
            return true
        end
        return false
    end
    for _, g in ipairs({ minus, plus }) do
        g.Button.MouseEnter:Connect(function()
            g.Hover = true
            entry.Paint(true)
        end)
        g.Button.MouseLeave:Connect(function()
            g.Hover = false
            state.Hold = state.Hold + 1
            entry.Paint(true)
        end)
        g.Button.InputBegan:Connect(function(input)
            if W.IsDestroyed or entry.Disabled or not Shell.IsPointer(input) or input.UserInputState ~= Enum.UserInputState.Begin then
                return
            end
            state.Hold = state.Hold + 1
            local token = state.Hold
            if not stepBy(g.Dir) then
                return
            end
            task.delay(0.4, function()
                while state.Hold == token and not W.IsDestroyed and not entry.Disabled do
                    if not stepBy(g.Dir) then
                        break
                    end
                    task.wait(0.08)
                end
            end)
        end)
        g.Button.InputEnded:Connect(function(input)
            if Shell.IsPointer(input) then
                state.Hold = state.Hold + 1
            end
        end)
    end
    box.Focused:Connect(function()
        box.BackgroundTransparency = 0
        if suffix ~= "" then
            box.Text = format(obj.Value):sub(1, -(#suffix + 1))
        end
    end)
    box.FocusLost:Connect(function()
        box.BackgroundTransparency = 1
        local raw = box.Text:gsub("%s", "")
        if suffix ~= "" and raw:sub(-#suffix) == suffix then
            raw = raw:sub(1, -(#suffix + 1))
        end
        local parsed = tonumber(raw)
        if parsed and not entry.Disabled then
            Rows.SetError(entry, nil)
            obj:SetValue(parsed)
        else
            box.Text = format(obj.Value)
            local fmt = decimals == 0 and "%d" or ("%." .. decimals .. "f")
            Rows.SetError(entry, "Use a number from " .. string.format(fmt, min) .. " to " .. string.format(fmt, max) .. ".")
        end
    end)
    Rows.Decorate(entry, obj, cfg)
    Rows.Add(tab, entry)
    Rows.Register(tab, "Stepper", name, entry, obj)
    SaveManager:RegisterOption(flag, obj, persistent)
    obj:SetValue(default)
    return obj
end

-- ------------------------------------------------------------------------------
-- tab methods (plain function fields: products feature-test them by indexing)
-- ------------------------------------------------------------------------------

function TabMethods.CreateSection(self, title, opts)
    return Components.Section(self, title, opts)
end
function TabMethods.CreateButton(self, cfg)
    return Components.Button(self, cfg)
end
function TabMethods.CreateToggle(self, cfg)
    return Components.Toggle(self, cfg)
end
function TabMethods.CreateSlider(self, cfg)
    return Components.Slider(self, cfg)
end
function TabMethods.CreateInput(self, cfg)
    return Components.Input(self, cfg)
end
function TabMethods.CreateDropdown(self, cfg)
    return Components.Dropdown(self, cfg)
end
function TabMethods.CreateMultiDropdown(self, cfg)
    local copy = {}
    for k, v in pairs(type(cfg) == "table" and cfg or {}) do
        copy[k] = v
    end
    copy.Multi = true
    return Components.Dropdown(self, copy)
end
function TabMethods.CreateKeybind(self, cfg)
    return Components.Keybind(self, cfg)
end
function TabMethods.CreateLabel(self, text)
    return Components.Label(self, text)
end
function TabMethods.CreateParagraph(self, cfg)
    return Components.Paragraph(self, cfg)
end
function TabMethods.CreateSpacer(self, height)
    return Components.Spacer(self, height)
end
function TabMethods.CreateDivider(self, text)
    return Components.Divider(self, text)
end
function TabMethods.CreateDashboardStats(self, stats)
    return Components.DashboardStats(self, stats)
end
function TabMethods.CreateColorPicker(self, cfg)
    return Components.ColorPicker(self, cfg)
end
function TabMethods.CreateProgress(self, cfg)
    return Components.Progress(self, cfg)
end
function TabMethods.CreateSegmented(self, cfg)
    return Components.Segmented(self, cfg)
end
function TabMethods.CreateStepper(self, cfg)
    return Components.Stepper(self, cfg)
end
function TabMethods.CreateViewport(self, cfg)
    return Components.Viewport(self, cfg)
end

-- a tab shown in the same frame its rows were created runs the deferred row pass first, so the
-- page fade-in records the final toggle styles and heights
do
    local showTab = Shell.ShowTab
    Shell.ShowTab = function(W, tab)
        if tab and tab._refreshQueued then
            Rows.Refresh(tab)
        end
        return showTab(W, tab)
    end
end

-- a family change (phone <-> desktop) re-lays out every row even when the measure stays the same
do
    local applyFamily = Shell.ApplyFamily
    Shell.ApplyFamily = function(W)
        applyFamily(W)
        for _, tab in ipairs(W.Tabs or {}) do
            tab._region = nil
        end
    end
end

-- ==============================================================================
-- 11) VIEWPORT (B "Lobby" docked live preview; contract API of 6.2 kept)
--     Side (default for the first viewport of a tab): a pane beside the list, no box, the rig stands on
--     the window's black; header "Name" + right slot, stage, floor line, toolbar glyphs at the bottom.
--     Stacked above the list when the region is under 520 px or on phones (chevron collapses it).
--     Inline (explicit, or a second viewport on a tab): the same pieces as a block row in the page.
--     Nothing runs per frame: the clip stops and the ViewportFrame hides whenever the pane is not shown.
-- ==============================================================================

local Preview = {}

Preview.SideMin, Preview.SideMax, Preview.SideShare = 240, 420, 0.448
Preview.StackBelow = 520
Preview.Tools = {
    { Key = "zoomOut", Tip = "Zoom out" },
    { Key = "zoomIn", Tip = "Zoom in" },
    { Key = "fit", Tip = "Reset view" },
    { Key = "expand", Tip = "Expand" },
    { Key = "shrink", Tip = "Shrink" },
}

function Preview.Warn(where, err)
    warn("[Viewport] " .. where .. ": " .. tostring(err))
end

-- geometry of a Side pane for a region (content width) and height; nil when the pane is not beside the list
function Preview.SideGeometry(V, region, regionH)
    local R = region + (Tokens.B.InsetRight - 16)
    -- stacked only when the region is narrow: a landscape phone (Compact, short and wide) keeps the side pane
    if region < Preview.StackBelow then
        local h = math.clamp(math.floor(regionH * 0.45 + 0.5), 200, 320)
        return { Stacked = true, Measure = math.min(region, Tokens.Size.ContentMax), PaneW = math.min(region, Tokens.Size.ContentMax), PaneH = h, R = R }
    end
    local paneW = math.clamp(math.floor(R * Preview.SideShare + 0.5), Preview.SideMin, Preview.SideMax)
    local measure = math.min(R - paneW - 32, Tokens.Size.ContentMax)
    return { Stacked = false, Measure = measure, PaneW = paneW, PaneH = regionH, R = R }
end

-- the tab asks this before it lays out its list (Shell.LayoutTab)
function Preview.MeasureFor(V, region, regionH)
    local tab = V.Tab
    if V.Destroyed or V.Dock ~= "Side" or not V.Pane.Visible then
        tab._pageTop = 0
        V.Geo = nil
        return math.min(region, Tokens.Size.ContentMax)
    end
    local g = Preview.SideGeometry(V, region, regionH)
    V.Geo = g
    if g.Stacked then
        tab._pageTop = (V.Collapsed and 18 or g.PaneH) + 16
    else
        tab._pageTop = 0
    end
    return g.Measure
end

function Preview.TabMeasure(tab, region, regionH)
    local side = tab._sidePane
    if side then
        return Preview.MeasureFor(side, region, regionH)
    end
    tab._pageTop = 0
    return math.min(region, Tokens.Size.ContentMax)
end

-- forces the tab through its layout pass (pane shown, hidden, collapsed, docked again)
function Preview.Relayout(V)
    local tab = V.Tab
    tab.Measure = nil
    Shell.LayoutTab(V.W, tab)
end

-- places the pane from the geometry MeasureFor computed (layout hook)
function Preview.Place(V, animate)
    if V.Destroyed then
        return
    end
    local pane = V.Pane
    if V.Dock == "Inline" then
        pane.Size = UDim2.new(1, 0, 0, V.Height + 50)
        V.StageBottom = 24
    else
        local g = V.Geo
        if not g then
            return
        end
        local x, y, w, h
        if V.Expanded then
            x, y, w, h = 0, 0, g.Stacked and V.Tab._region or g.R, V.Tab._regionH or g.PaneH
        elseif g.Stacked then
            x, y, w, h = 0, 0, g.PaneW, V.Collapsed and 18 or g.PaneH
        else
            x, y, w, h = g.Measure + 32, 0, g.PaneW, g.PaneH
        end
        local pos, size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
        if animate and not Motion.Reduced then
            Motion:Play(pane, { Position = pos, Size = size }, "Move", "pane", math.abs(pane.Size.X.Offset - w) + math.abs(pane.Position.X.Offset - x))
        else
            Motion:Stop(pane, "pane")
            pane.Position, pane.Size = pos, size
        end
        V.StageBottom = (g.Stacked and not V.Expanded) and 24 or 46
        V.Tab.Page.Visible = not V.Expanded
    end
    V.Stage.Size = UDim2.new(1, 0, 1, -(26 + V.StageBottom))
    V.Chevron.Visible = V.Dock == "Side" and V.Geo ~= nil and V.Geo.Stacked
    V.Chevron.Rotation = V.Collapsed and -90 or 0
    local nameW = Rows.TextW(V.Name.Text, Tokens.Text.Small, "Regular")
    V.Name.Size = UDim2.fromOffset(nameW + 2, 18)
    V.Chevron.Position = UDim2.fromOffset(nameW + 12, 9)
    local slotX = nameW + (V.Chevron.Visible and 30 or 16)
    V.Slot.Size = UDim2.new(1, -slotX, 0, 18)
    local collapsed = V.Collapsed and V.Chevron.Visible
    V.Stage.Visible = not collapsed
    V.Toolbar.Visible = not collapsed
    Preview.PlaceTools(V)
    Preview.UpdateFloor(V)
    Preview.RefreshShown(V)
end

-- toolbar: the glyphs that apply, centred, pitch 30 (44 on phones)
function Preview.PlaceTools(V)
    local cfg = V.Cfg
    local I = V.W._I
    local compact = I.Family == "Compact"
    local show = {
        zoomOut = cfg.Zoom ~= false,
        zoomIn = cfg.Zoom ~= false,
        fit = cfg.OnReset ~= nil or cfg.OnInput == nil,
        expand = V.Dock == "Side" and not compact and not V.Expanded and not V.Collapsed,
        shrink = V.Dock == "Side" and not compact and V.Expanded,
    }
    local pitch = compact and Tokens.Size.HitCompact or 30
    local list = {}
    for _, tool in ipairs(Preview.Tools) do
        local btn = V.Buttons[tool.Key]
        if btn then
            btn.Visible = show[tool.Key] == true
            if btn.Visible then
                table.insert(list, btn)
            end
        end
    end
    V.Toolbar.Size = UDim2.fromOffset(math.max(#list, 1) * pitch, 14)
    for i, btn in ipairs(list) do
        btn.Position = UDim2.fromOffset((i - 0.5) * pitch, 7)
    end
end

-- ------------------------------------------------------------------------------
-- header slot (F10): status while a model is shown > "Drag to turn" until the first drag > model name
-- ------------------------------------------------------------------------------

function Preview.SlotText(V)
    local model = V.Obj.Model
    if not model then
        return ""
    end
    if V.Status then
        return V.Status
    end
    if not V.W._I.PreviewHintDone and V.HintText ~= "" then
        return V.HintText
    end
    if V.Cfg.ShowModelName ~= false then
        local ok, name = pcall(function()
            return model.Name
        end)
        if ok and type(name) == "string" and name ~= model.ClassName and name ~= "Model" then
            return name
        end
    end
    return ""
end

function Preview.RefreshSlot(V)
    if V.Destroyed then
        return
    end
    if V.SlotFading then
        return
    end
    V.Slot.Text = Preview.SlotText(V)
    if V.Obj.Model then
        V.Placeholder.Visible = false
    else
        V.Placeholder.Text = V.Status or V.PlaceholderText
        V.Placeholder.Visible = true
    end
end

-- first drag of the session: the hint fades (0.3 s) and the model name takes its place
function Preview.HintDone(V)
    local I = V.W._I
    if I.PreviewHintDone then
        return
    end
    I.PreviewHintDone = true
    local slot = V.Slot
    if Motion.Reduced or V.Status then
        Preview.RefreshSlot(V)
        return
    end
    V.SlotFading = true
    Motion:Play(slot, { TextTransparency = 1 }, "Backdrop", "hint")
    task.delay(0.3, function()
        V.SlotFading = false
        if V.Destroyed then
            return
        end
        Preview.RefreshSlot(V)
        Motion:Play(slot, { TextTransparency = 0 }, "Backdrop", "hint")
    end)
end

-- ------------------------------------------------------------------------------
-- floor line: 1 px under the model's feet, from the camera projection (recomputed on change only)
-- ------------------------------------------------------------------------------

function Preview.UpdateFeet(V)
    V.Feet = nil
    local model = V.Obj.Model
    if not model then
        return
    end
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)
    if ok and cf then
        V.Feet = cf.Position - Vector3.new(0, size.Y / 2, 0)
    end
end

function Preview.UpdateFloor(V)
    local floor = V.Floor
    local feet = V.Feet
    if V.Destroyed or not feet or not V.Obj.Model or not V.Stage.Visible then
        floor.Visible = false
        return
    end
    local view, camera = V.View, V.Camera
    local size = view.AbsoluteSize
    if size.Y < 2 then
        floor.Visible = false
        return
    end
    local v = camera.CFrame:PointToObjectSpace(feet)
    if v.Z >= -0.01 then
        floor.Visible = false
        return
    end
    local ndcY = (v.Y / -v.Z) / math.tan(math.rad(camera.FieldOfView) / 2)
    local absY = view.AbsolutePosition.Y + (1 - ndcY) / 2 * size.Y
    local stageTop = V.Stage.AbsolutePosition.Y
    local stageBottom = stageTop + V.Stage.AbsoluteSize.Y
    if absY < stageTop + 4 or absY > stageBottom - 1 then
        floor.Visible = false
        return
    end
    local scale = math.max(V.W._I.Scale or 1, 0.01)
    -- B: 180 under a 260 picture; follows the picture width, never wider than the pane minus 40 each side
    local paneW = V.Pane.AbsoluteSize.X / scale
    local width = math.clamp(math.floor(size.X / scale * 0.7 + 0.5), 120, math.max(120, paneW - 80))
    floor.Size = UDim2.fromOffset(width, 1)
    floor.Position = UDim2.new(0.5, 0, 0, math.floor((absY - V.Pane.AbsolutePosition.Y) / scale + 0.5))
    floor.Visible = true
end

-- ------------------------------------------------------------------------------
-- shown state: window open, tab active, pane visible, not collapsed
-- ------------------------------------------------------------------------------

function Preview.IsShown(V)
    local W = V.W
    local pane = V.Pane
    if V.Destroyed or W.IsDestroyed or not pane.Parent or not pane.Visible then
        return false
    end
    if V.Collapsed and V.Chevron.Visible then
        return false
    end
    if not V.Tab._root.Visible or not W._I.MainFrame.Visible or W.IsMinimized or W.IsHidden then
        return false
    end
    if V.Dock == "Inline" and not V.Tab.Page.Visible then
        return false
    end
    return true
end

function Preview.RefreshShown(V)
    local obj = V.Obj
    local shown = Preview.IsShown(V)
    if V.Dock == "Side" then
        Shell.SetPreviewShown(V.W, V.Tab, not V.Destroyed and V.Pane.Visible and not (V.Collapsed and V.Chevron.Visible))
    end
    if shown == obj.Shown then
        return
    end
    obj.Shown = shown
    V.View.Visible = shown
    if shown then
        Preview.StartAnimation(V)
        Preview.UpdateFloor(V)
    else
        Preview.StopAnimation(V, true)
        V.Drag = nil
        V.Pinch = nil
        table.clear(V.Touches)
        V.Hovering = false
    end
    Preview.RefreshScrollLock(V)
    local cb = V.Cfg.VisibilityChanged
    if cb then
        task.spawn(function()
            local ok, err = pcall(cb, shown)
            if not ok then
                Preview.Warn("VisibilityChanged", err)
            end
        end)
    end
end

-- the wheel zooms instead of scrolling the page while the pointer is over the stage
function Preview.SetScrollLock(V, locked)
    local page = V.Tab.Page
    if locked then
        if V.ScrollWas == nil then
            V.ScrollWas = page.ScrollingEnabled
            page.ScrollingEnabled = false
        end
    elseif V.ScrollWas ~= nil then
        page.ScrollingEnabled = V.ScrollWas
        V.ScrollWas = nil
    end
end

function Preview.RefreshScrollLock(V)
    local touchDrag = (V.Drag ~= nil and V.Drag.Kind == Enum.UserInputType.Touch) or V.Pinch ~= nil
    Preview.SetScrollLock(V, V.Obj.Shown and ((V.Hovering and V.Cfg.Zoom ~= false) or touchDrag))
end

-- ------------------------------------------------------------------------------
-- animation (contract: stops while hidden, the clip is kept and restarts when shown)
-- ------------------------------------------------------------------------------

function Preview.Animator(V)
    local model = V.Obj.Model
    if not model or not model.Parent then
        return nil
    end
    local owner = model:FindFirstChildWhichIsA("Humanoid") or model:FindFirstChildWhichIsA("AnimationController")
    if not owner then
        return nil
    end
    local found = owner:FindFirstChildWhichIsA("Animator")
    if not found then
        found = Instance.new("Animator")
        found.Parent = owner
    end
    return found
end

function Preview.StopAnimation(V, keep)
    V.AnimTicket = V.AnimTicket + 1
    local playing = V.Track
    V.Track = nil
    if playing then
        pcall(function()
            playing:Stop(0)
            playing:Destroy()
        end)
    end
    if not keep then
        V.Anim = nil
        V.AnimOptions = nil
    end
end

function Preview.StartAnimation(V)
    if V.Track or not V.Anim or not V.Obj.Shown or V.Destroyed then
        return
    end
    local target = Preview.Animator(V)
    if not target then
        return
    end
    local anim = V.Anim
    if typeof(anim) ~= "Instance" then
        local id = tostring(anim)
        if id:match("^%d+$") then
            id = "rbxassetid://" .. id
        end
        anim = Instance.new("Animation")
        anim.AnimationId = id
    end
    local options = V.AnimOptions or {}
    local ok, loaded = pcall(function()
        return target:LoadAnimation(anim)
    end)
    if not ok or not loaded then
        return
    end
    V.Track = loaded
    local speed = tonumber(options.Speed) or 1
    pcall(function()
        loaded.Looped = options.Looped ~= false
        loaded:Play(0, 1, speed == 0 and 1 or speed)
    end)
    local at = tonumber(options.TimePosition)
    if speed == 0 or at then
        -- a clip has no length until it has loaded: hold the frame once it has
        local ticket = V.AnimTicket
        task.spawn(function()
            local waited = 0
            while loaded.Length <= 0 and waited < 8 and V.AnimTicket == ticket do
                waited = waited + task.wait()
            end
            if V.AnimTicket ~= ticket then
                return
            end
            pcall(function()
                if at then
                    loaded.TimePosition = math.clamp(at, 0, math.max(loaded.Length - 1e-3, 0))
                end
                if speed == 0 then
                    loaded:AdjustSpeed(0)
                end
            end)
        end)
    end
end

-- ------------------------------------------------------------------------------
-- camera and input (contract mapping: left drag / one finger turns, right drag pans, wheel and pinch zoom)
-- ------------------------------------------------------------------------------

function Preview.ApplyLight(V)
    local dir = V.LightCam
    if dir then
        local cf = V.Camera.CFrame
        local shine = cf.RightVector * dir.X + cf.UpVector * dir.Y + cf.LookVector * dir.Z
        if shine.Magnitude > 1e-6 then
            V.View.LightDirection = shine.Unit
        end
    end
end

function Preview.ApplyOrbit(V)
    local obj = V.Obj
    local turn = CFrame.Angles(0, math.rad(obj.Yaw), 0) * CFrame.Angles(math.rad(-obj.Pitch), 0, 0)
    V.Camera.CFrame = CFrame.new(obj.Focus) * turn * CFrame.new(0, 0, obj.Distance)
    V.Camera.FieldOfView = obj.FieldOfView
    Preview.ApplyLight(V)
    Preview.UpdateFloor(V)
end

function Preview.UserMoved(V, dragging)
    local cb = V.Cfg.Changed
    if cb then
        local ok, err = pcall(cb, V.Obj:GetState(dragging))
        if not ok then
            Preview.Warn("Changed", err)
        end
    end
end

function Preview.HandleInput(V, turn, tilt, zoom, pan, dragging)
    local obj = V.Obj
    local cfg = V.Cfg
    if cfg.OnInput then
        local ok, err = pcall(cfg.OnInput, { Yaw = turn, Pitch = tilt, Zoom = zoom, Pan = pan, Dragging = dragging })
        if not ok then
            Preview.Warn("OnInput", err)
        end
    else
        obj.Yaw = (obj.Yaw + turn) % 360
        obj.Pitch = math.clamp(obj.Pitch + tilt, -85, 85)
        obj.Distance = math.clamp(obj.Distance / zoom, obj.MinDistance, obj.MaxDistance)
        if pan ~= 0 then
            local frameHeight = 2 * obj.Distance * math.tan(math.rad(obj.FieldOfView) / 2)
            obj.Focus = obj.Focus + V.Camera.CFrame.UpVector * (pan * frameHeight)
        end
        Preview.ApplyOrbit(V)
    end
    Preview.UserMoved(V, dragging)
end

function Preview.Reset(V)
    local cfg = V.Cfg
    if cfg.OnReset then
        local ok, err = pcall(cfg.OnReset)
        if not ok then
            Preview.Warn("OnReset", err)
        end
    else
        V.Obj:FrameModel(true)
    end
    Preview.UserMoved(V, false)
end

function Preview.SetExpanded(V, expanded)
    expanded = expanded == true and V.Dock == "Side"
    if V.Expanded == expanded or V.Destroyed then
        return
    end
    Overlays.HideTooltip(V.W)
    V.Expanded = expanded
    if expanded then
        Overlays.ClosePopover(V.W)
    end
    Preview.Place(V, true)
end

function Preview.SetCollapsed(V, collapsed)
    collapsed = collapsed == true
    if V.Collapsed == collapsed or V.Destroyed then
        return
    end
    V.Collapsed = collapsed
    if collapsed then
        V.Expanded = false
    end
    Preview.Relayout(V)
    Preview.Place(V, false)
end

function Preview.PointerBegan(V, input)
    local obj = V.Obj
    local cfg = V.Cfg
    local kind = input.UserInputType
    if not obj.Shown then
        return
    end
    if kind == Enum.UserInputType.Touch then
        V.Touches[input] = Vector2.new(input.Position.X, input.Position.Y)
        local list = {}
        for t in pairs(V.Touches) do
            table.insert(list, t)
        end
        if #list == 2 and cfg.Zoom ~= false then
            -- second finger: pinch zoom takes over from turning
            local a, b = V.Touches[list[1]], V.Touches[list[2]]
            V.Pinch = { A = list[1], B = list[2], Dist = math.max((a - b).Magnitude, 1), Moved = V.Drag ~= nil and V.Drag.Moved }
            V.Drag = nil
            Preview.RefreshScrollLock(V)
            return
        end
        if #list > 1 then
            return
        end
    end
    local allowed = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
        or (kind == Enum.UserInputType.MouseButton2 and cfg.Pan ~= false)
    if not allowed or V.Drag or V.Pinch then
        return
    end
    V.Drag = {
        Kind = kind,
        Input = kind == Enum.UserInputType.Touch and input or nil,
        Last = Vector2.new(input.Position.X, input.Position.Y),
        Moved = false,
    }
    Preview.RefreshScrollLock(V)
end

function Preview.PointerChanged(V, input)
    local pinch = V.Pinch
    if pinch and input.UserInputType == Enum.UserInputType.Touch and V.Touches[input] then
        V.Touches[input] = Vector2.new(input.Position.X, input.Position.Y)
        local a, b = V.Touches[pinch.A], V.Touches[pinch.B]
        if not a or not b then
            return
        end
        local dist = math.max((a - b).Magnitude, 1)
        local factor = dist / pinch.Dist
        pinch.Dist = dist
        if math.abs(factor - 1) > 1e-3 then
            pinch.Moved = true
            Preview.HandleInput(V, 0, 0, factor, 0, true)
        end
        return
    end
    local drag = V.Drag
    if not drag then
        return
    end
    local follows
    if drag.Kind == Enum.UserInputType.Touch then
        follows = input == drag.Input
    else
        follows = input.UserInputType == Enum.UserInputType.MouseMovement
    end
    if not follows then
        return
    end
    if drag.Input then
        V.Touches[input] = Vector2.new(input.Position.X, input.Position.Y)
    end
    local now = Vector2.new(input.Position.X, input.Position.Y)
    local delta = now - drag.Last
    drag.Last = now
    if delta.X == 0 and delta.Y == 0 then
        return
    end
    drag.Moved = true
    local sens = V.Sensitivity
    if drag.Kind == Enum.UserInputType.MouseButton2 then
        Preview.HandleInput(V, 0, 0, 1, delta.Y / math.max(V.View.AbsoluteSize.Y, 1), true)
    else
        Preview.HandleInput(V, -delta.X * sens, delta.Y * sens, 1, 0, true)
        Preview.HintDone(V)
    end
end

function Preview.PointerEnded(V, input)
    local kind = input.UserInputType
    if kind == Enum.UserInputType.Touch and V.Touches[input] then
        V.Touches[input] = nil
        local pinch = V.Pinch
        if pinch and (input == pinch.A or input == pinch.B) then
            V.Pinch = nil
            Preview.RefreshScrollLock(V)
            if pinch.Moved then
                Preview.HandleInput(V, 0, 0, 1, 0, false)
            end
            return
        end
    end
    local drag = V.Drag
    if not drag or kind ~= drag.Kind then
        return
    end
    if drag.Kind == Enum.UserInputType.Touch and input ~= drag.Input then
        return
    end
    V.Drag = nil
    Preview.RefreshScrollLock(V)
    if drag.Moved then
        Preview.HandleInput(V, 0, 0, 1, 0, false)
    end
end

-- ------------------------------------------------------------------------------
-- build
-- ------------------------------------------------------------------------------

function Preview.BuildPane(V)
    local W = V.W
    local cfg = V.Cfg
    local pane = Utility:Create("Frame", {
        Name = V.Dock == "Side" and "PreviewPane" or "Viewport",
        Size = UDim2.fromOffset(260, 432),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Tokens.Z.Content,
    })
    V.Pane = pane
    local header = Utility:Create("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Selectable = false,
        Parent = pane,
    })
    V.Header = header
    V.Name = Utility:Text("TextLabel", {
        Name = "Title",
        Size = UDim2.fromOffset(120, 18),
        Text = tostring(cfg.Name or "Preview"),
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Left,
        Color = "Text",
        Parent = header,
    })
    V.Chevron = Glyph.Draw(header, "chevron", 10, "TextDark", { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
    V.Slot = Utility:Text("TextLabel", {
        Name = "Hint",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(1, -136, 0, 18),
        Text = "",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "TextDark",
        Parent = header,
    })
    V.Floor = Utility:Create("Frame", {
        Name = "Floor",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 300),
        Size = UDim2.fromOffset(180, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
        Theme = { BackgroundColor3 = "Text" },
        Parent = pane,
    })
    Utility:Gradient(V.Floor, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } }, 0)
    local stage = Utility:Create("Frame", {
        Name = "Stage",
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 1, -72),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 2,
        Parent = pane,
    })
    V.Stage = stage
    -- the picture keeps the render shape (SetAspectRatio); no box, no fill unless SetBackground paints one
    local pic = Utility:Create("Frame", {
        Name = "Picture",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = stage,
    })
    V.Aspect = Utility:Create("UIAspectRatioConstraint", {
        AspectRatio = ClampNumber(cfg.AspectRatio or 1, 0.2, 5),
        AspectType = Enum.AspectType.FitWithinMaxSize,
        Parent = pic,
    })
    V.Back = Utility:Create("Frame", {
        Name = "Background",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = pic,
    })
    V.Gradient = Utility:Create("UIGradient", { Rotation = 90, Enabled = false, Parent = V.Back })
    V.View = Utility:Create("ViewportFrame", {
        Name = "View",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Ambient = typeof(cfg.Ambient) == "Color3" and cfg.Ambient or Color3.fromRGB(200, 200, 200),
        LightColor = typeof(cfg.LightColor) == "Color3" and cfg.LightColor or Color3.fromRGB(140, 140, 140),
        LightDirection = typeof(cfg.LightDirection) == "Vector3" and cfg.LightDirection or Vector3.new(-1, -1, -1),
        Parent = pic,
    })
    V.World = Instance.new("WorldModel")
    V.World.Parent = V.View
    V.Camera = Instance.new("Camera")
    V.Camera.FieldOfView = V.Obj.FieldOfView
    V.Camera.Parent = V.View
    V.View.CurrentCamera = V.Camera
    V.Placeholder = Utility:Text("TextLabel", {
        Name = "Placeholder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0.8, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = V.PlaceholderText,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        Color = "TextDark",
        Parent = stage,
    })
    V.Toolbar = Utility:Create("Frame", {
        Name = "Toolbar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, -18),
        Size = UDim2.fromOffset(120, 14),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = pane,
    })
    V.Buttons = {}
    local actions = {
        zoomOut = function()
            Preview.HandleInput(V, 0, 0, 1 / 1.12, 0, false)
        end,
        zoomIn = function()
            Preview.HandleInput(V, 0, 0, 1.12, 0, false)
        end,
        fit = function()
            Preview.Reset(V)
        end,
        expand = function()
            Preview.SetExpanded(V, true)
        end,
        shrink = function()
            Preview.SetExpanded(V, false)
        end,
    }
    for _, tool in ipairs(Preview.Tools) do
        local btn = Shell.GlyphButton(W, V.Toolbar, tool.Key, 14, actions[tool.Key], { Name = "Tool_" .. tool.Key }, "TextDark")
        Overlays.AttachTooltip(W, btn, tool.Tip)
        V.Buttons[tool.Key] = btn
    end
    return pane
end

function Preview.Wire(V)
    local W = V.W
    local I = W._I
    local conns = V.Conns
    local function bind(conn)
        table.insert(conns, conn)
        return conn
    end
    local function bindGlobal(conn)
        I.Trove:Add(conn)
        table.insert(conns, conn)
        return conn
    end
    local stage = V.Stage
    bind(stage.InputBegan:Connect(function(input)
        Preview.PointerBegan(V, input)
    end))
    bind(stage.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel and V.Cfg.Zoom ~= false and V.Obj.Shown then
            local steps = input.Position.Z
            if steps ~= 0 then
                Preview.HandleInput(V, 0, 0, 1.12 ^ steps, 0, false)
            end
        end
    end))
    bind(stage.MouseEnter:Connect(function()
        V.Hovering = true
        Preview.RefreshScrollLock(V)
    end))
    bind(stage.MouseLeave:Connect(function()
        V.Hovering = false
        Preview.RefreshScrollLock(V)
    end))
    bindGlobal(UserInputService.InputChanged:Connect(function(input)
        if V.Drag or V.Pinch then
            Preview.PointerChanged(V, input)
        end
    end))
    bindGlobal(UserInputService.InputEnded:Connect(function(input)
        Preview.PointerEnded(V, input)
    end))
    bind(V.Header.Activated:Connect(function()
        if V.Chevron.Visible then
            Preview.SetCollapsed(V, not V.Collapsed)
        end
    end))
    local function shownChanged()
        Preview.RefreshShown(V)
    end
    bind(V.Tab._root:GetPropertyChangedSignal("Visible"):Connect(shownChanged))
    bind(V.Tab.Page:GetPropertyChangedSignal("Visible"):Connect(shownChanged))
    bind(I.MainFrame:GetPropertyChangedSignal("Visible"):Connect(shownChanged))
    bind(V.Pane:GetPropertyChangedSignal("Visible"):Connect(function()
        if not V.Pane.Visible and V.Expanded then
            V.Expanded = false
            V.Tab.Page.Visible = true
        end
        if V.Dock == "Side" then
            Preview.Relayout(V)
        end
        Preview.RefreshShown(V)
    end))
    bind(V.Pane.AncestryChanged:Connect(shownChanged))
    local function floorChanged()
        if V.Feet then
            Preview.UpdateFloor(V)
        end
    end
    bind(V.View:GetPropertyChangedSignal("AbsoluteSize"):Connect(floorChanged))
    bind(V.View:GetPropertyChangedSignal("AbsolutePosition"):Connect(floorChanged))
    pcall(function()
        bind(V.Pane.Destroying:Connect(function()
            V.Obj:Destroy()
        end))
    end)
end

-- Side: the pane is a sibling of the page; Inline: a block row in the page at the order it was created
function Preview.Mount(V)
    local tab = V.Tab
    local pane = V.Pane
    if V.Dock == "Side" then
        if V.Entry then
            V.Entry = nil
        end
        tab._sidePane = V
        tab._measureFor = Preview.TabMeasure
        pane.Parent = tab._root
        if V.Absorbed then
            V.Absorbed.Instance.Visible = false
        end
    else
        if tab._sidePane == V then
            tab._sidePane = nil
        end
        if V.Absorbed then
            V.Absorbed.Instance.Visible = true
        end
        pane.Position = UDim2.new()
        V.Expanded = false
        tab.Page.Visible = true
        V.Entry = Rows.Add(tab, pane, "block")
        pane.LayoutOrder = V.Order
    end
    Preview.Relayout(V)
    Preview.Place(V, false)
end

function Preview.MakeObject(V)
    local obj = V.Obj

    function obj:GetState(dragging)
        return {
            CFrame = V.Camera.CFrame,
            FieldOfView = V.Camera.FieldOfView,
            Yaw = obj.Yaw,
            Pitch = obj.Pitch,
            Distance = obj.Distance,
            Focus = obj.Focus,
            Dragging = dragging == true,
            Size = V.View.AbsoluteSize,
        }
    end
    -- places the camera; with a focus the orbit turns around it, without one it keeps its distance
    function obj:SetCamera(cframe, fieldOfView, focus)
        if typeof(cframe) ~= "CFrame" then
            return
        end
        if tonumber(fieldOfView) then
            obj.FieldOfView = math.clamp(tonumber(fieldOfView), 1, 120)
        end
        V.Camera.CFrame = cframe
        V.Camera.FieldOfView = obj.FieldOfView
        local look = cframe.LookVector
        local distance
        if typeof(focus) == "Vector3" then
            distance = (focus - cframe.Position).Magnitude
        else
            distance = (obj.Focus - cframe.Position):Dot(look)
            if distance <= 0.05 then
                distance = obj.Distance
            end
        end
        obj.Distance = math.max(distance, 0.05)
        obj.Focus = typeof(focus) == "Vector3" and focus or (cframe.Position + look * obj.Distance)
        obj.Pitch = math.deg(math.asin(math.clamp(-look.Y, -1, 1)))
        obj.Yaw = math.deg(math.atan2(-look.X, -look.Z)) % 360
        Preview.ApplyLight(V)
        Preview.UpdateFloor(V)
    end
    -- moves the camera from code the way the pointer does; calls OnInput and Changed
    function obj:Input(delta)
        delta = type(delta) == "table" and delta or {}
        Preview.HandleInput(V, tonumber(delta.Yaw) or 0, tonumber(delta.Pitch) or 0, tonumber(delta.Zoom) or 1, tonumber(delta.Pan) or 0, delta.Dragging == true)
    end
    function obj:GetCamera()
        return V.Camera.CFrame, V.Camera.FieldOfView
    end
    -- fits the whole model for the current field of view and picture shape; faceFront turns to its front
    function obj:FrameModel(faceFront)
        local model = obj.Model
        if not model then
            return
        end
        local ok, at, size = pcall(function()
            return model:GetBoundingBox()
        end)
        if not ok then
            return
        end
        local radius = math.max(size.Magnitude * 0.5, 0.5)
        local half = math.rad(obj.FieldOfView) / 2
        local halfX = math.atan(math.tan(half) * V.Aspect.AspectRatio)
        obj.Focus = at.Position
        obj.Distance = math.clamp(radius / math.sin(math.min(half, halfX)), obj.MinDistance, obj.MaxDistance)
        if faceFront ~= false then
            local front = model:GetPivot().LookVector
            obj.Yaw = math.deg(math.atan2(front.X, front.Z)) % 360
            obj.Pitch = 5
        end
        Preview.UpdateFeet(V)
        Preview.ApplyOrbit(V)
    end
    -- takes the model into the WorldModel (destroyed with the pane); options: Frame, Animation, AnimationOptions, KeepOld
    function obj:SetModel(model, options)
        options = type(options) == "table" and options or {}
        Preview.StopAnimation(V, false)
        local old = obj.Model
        obj.Model = nil
        if old and old ~= model and options.KeepOld ~= true then
            pcall(function()
                old:Destroy()
            end)
        end
        if typeof(model) == "Instance" then
            obj.Model = model
            model.Parent = V.World
            Preview.UpdateFeet(V)
            if options.Frame ~= false then
                obj:FrameModel(true)
            end
            if options.Animation then
                V.Anim = options.Animation
                V.AnimOptions = options.AnimationOptions
                Preview.StartAnimation(V)
            end
        else
            V.Feet = nil
        end
        Preview.UpdateFloor(V)
        Preview.RefreshSlot(V)
    end
    function obj:GetModel()
        return obj.Model
    end
    -- animation: an Animation, an id or "rbxassetid://..."; options: Speed (0 holds a frame), TimePosition, Looped
    function obj:PlayAnimation(animation, options)
        Preview.StopAnimation(V, false)
        V.Anim = animation
        V.AnimOptions = type(options) == "table" and options or nil
        Preview.StartAnimation(V)
        return V.Track
    end
    function obj:StopAnimation()
        Preview.StopAnimation(V, false)
    end
    -- Ambient, LightColor, LightDirection; Space = "Camera" gives the direction as x right, y up, z ahead
    function obj:SetLighting(light)
        light = type(light) == "table" and light or {}
        if typeof(light.Ambient) == "Color3" then
            V.View.Ambient = light.Ambient
        end
        if typeof(light.LightColor) == "Color3" then
            V.View.LightColor = light.LightColor
        end
        if typeof(light.LightDirection) == "Vector3" then
            if light.Space == "Camera" then
                V.LightCam = light.LightDirection
                Preview.ApplyLight(V)
            else
                V.LightCam = nil
                V.View.LightDirection = light.LightDirection
            end
        end
    end
    -- nil: see-through (the rig stands on the window's black); one colour: solid; two: top to bottom
    function obj:SetBackground(top, bottom)
        local back, gradient = V.Back, V.Gradient
        if typeof(top) ~= "Color3" then
            back.BackgroundTransparency = 1
            gradient.Enabled = false
        elseif typeof(bottom) == "Color3" then
            back.BackgroundColor3 = Color3.new(1, 1, 1)
            gradient.Color = ColorSequence.new(top, bottom)
            gradient.Enabled = true
            back.BackgroundTransparency = 0
        else
            back.BackgroundColor3 = top
            gradient.Enabled = false
            back.BackgroundTransparency = 0
        end
    end
    function obj:SetAspectRatio(ratio)
        V.Aspect.AspectRatio = ClampNumber(ratio, 0.2, 5)
        Preview.UpdateFloor(V)
    end
    function obj:SetHeight(value)
        V.Height = ClampNumber(value, 120, 900)
        if V.Dock == "Inline" then
            Preview.Place(V, false)
        end
    end
    function obj:SetStatus(text)
        V.Status = text ~= nil and tostring(text) or nil
        Preview.RefreshSlot(V)
    end
    function obj:SetHint(text)
        V.HintText = text ~= nil and tostring(text) or ""
        Preview.RefreshSlot(V)
    end
    function obj:SetDock(mode)
        mode = mode == "Inline" and "Inline" or "Side"
        if V.Destroyed or mode == V.Dock then
            return
        end
        if mode == "Side" and V.Tab._sidePane and V.Tab._sidePane ~= V then
            return
        end
        if V.Entry then
            V.Pane.Parent = nil
            V.Entry = nil
        end
        V.Dock = mode
        V.Pane.Name = mode == "Side" and "PreviewPane" or "Viewport"
        Preview.Mount(V)
    end
    function obj:SetVisible(visible)
        V.Pane.Visible = visible ~= false
    end
    function obj:IsShown()
        return obj.Shown
    end
    function obj:Destroy()
        if obj.Destroyed then
            return
        end
        obj.Destroyed = true
        V.Destroyed = true
        Preview.StopAnimation(V, false)
        V.Drag, V.Pinch = nil, nil
        Preview.SetScrollLock(V, false)
        for _, conn in ipairs(V.Conns) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(V.Conns)
        local tab = V.Tab
        local hook = table.find(tab._layoutHooks, V.Hook)
        if hook then
            table.remove(tab._layoutHooks, hook)
        end
        if tab._sidePane == V then
            tab._sidePane = nil
            tab._measureFor = nil
            tab._pageTop = 0
            tab.Page.Visible = true
            Shell.SetPreviewShown(V.W, tab, false)
        end
        if V.Absorbed then
            pcall(function()
                V.Absorbed.Instance.Visible = true
            end)
        end
        local model = obj.Model
        obj.Model = nil
        if model then
            pcall(function()
                model:Destroy()
            end)
        end
        pcall(function()
            V.Pane:Destroy()
        end)
        if not V.W.IsDestroyed then
            pcall(Preview.Relayout, V)
        end
    end
end

function Components.Viewport(tab, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local W = tab.Window
    local dock = cfg.Dock == "Inline" and "Inline" or "Side"
    if dock == "Side" and tab._sidePane then
        dock = "Inline"
    end
    local obj = {
        Model = nil,
        Yaw = tonumber(cfg.Yaw) or 0,
        Pitch = tonumber(cfg.Pitch) or 5,
        Distance = tonumber(cfg.Distance) or 12,
        Focus = typeof(cfg.Focus) == "Vector3" and cfg.Focus or Vector3.zero,
        FieldOfView = ClampNumber(cfg.FieldOfView or 30, 1, 120),
        MinDistance = tonumber(cfg.MinDistance) or 0.5,
        MaxDistance = tonumber(cfg.MaxDistance) or 500,
        Shown = false,
        Destroyed = false,
    }
    local V = {
        Tab = tab,
        W = W,
        Cfg = cfg,
        Obj = obj,
        Dock = dock,
        Height = ClampNumber(cfg.Height or 320, 120, 900),
        Sensitivity = ClampNumber(cfg.Sensitivity or 0.4, 0.05, 2),
        HintText = cfg.Hint ~= nil and tostring(cfg.Hint) or "Drag to turn",
        PlaceholderText = tostring(cfg.Placeholder or "Nothing to show yet"),
        Status = nil,
        Touches = {},
        Conns = {},
        AnimTicket = 0,
        StageBottom = 46,
        Expanded = false,
        Collapsed = false,
        Destroyed = false,
    }
    -- the order the block would take in the list (Inline now, or after SetDock("Inline"))
    tab._order = tab._order + 1
    V.Order = tab._order
    -- section absorption: a section right before the first Side pane that repeats its name is carried by the header
    local last = tab._rows[#tab._rows]
    if last and last.Kind == "Section" and last.Label and string.lower(last.Label.Text) == string.lower(tostring(cfg.Name or "Preview")) then
        V.Absorbed = last
    end

    Preview.BuildPane(V)
    Preview.MakeObject(V)
    obj.Instance = V.Pane
    obj.Viewport = V.View
    obj.WorldModel = V.World
    obj.Camera = V.Camera
    obj.Hint = V.Slot

    V.Hook = function()
        Preview.Place(V, false)
    end
    table.insert(tab._layoutHooks, V.Hook)
    Preview.Wire(V)
    Preview.Mount(V)
    Preview.ApplyOrbit(V)
    if typeof(cfg.Model) == "Instance" then
        obj:SetModel(cfg.Model, { Animation = cfg.Animation })
    end
    Preview.RefreshSlot(V)
    Preview.RefreshShown(V)
    return obj
end

-- ==============================================================================
-- 11) INTERFACE PAGE (Window.ConfigTab: first sidebar tab, built with the library's own rows)
--     Same __lib_* flags as 6.x plus the backdrop and reduce-motion keys.
-- ==============================================================================

-- control column of a row at this measure (B: 220 at 572)
function Components.ControlWidth(measure)
    return math.clamp(math.floor(measure * 0.385 + 0.5), 212, 248)
end

-- Accent row (B): five preset swatches + one hex field; writes __lib_accent_r/g/b (numbers)
function Components.AccentRow(W, tab)
    local I = W._I
    local flags = { "__lib_accent_r", "__lib_accent_g", "__lib_accent_b" }
    local row = Utility:Create("Frame", {
        Name = "Row_Accent",
        Size = UDim2.new(1, 0, 0, Tokens.Size.Row),
        BackgroundTransparency = 1,
    })
    local body = Utility:Create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, Tokens.Size.Row),
        BackgroundTransparency = 1,
        Parent = row,
    })
    local label = Utility:Text("TextLabel", {
        Name = "Label",
        Size = UDim2.new(0, 300, 0, Tokens.Size.Row),
        Text = "Accent",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Color = "Text",
        Parent = body,
    })
    local controls = Utility:Create("Frame", {
        Name = "Controls",
        Size = UDim2.fromOffset(220, 26),
        BackgroundTransparency = 1,
        Parent = body,
    })
    local swatches = {}
    for i, name in ipairs(ThemeManager.ThemeOrder) do
        local color = ThemeManager.Themes[name].PresetAccent
        local hit = Utility:Create("TextButton", {
            Name = "Swatch_" .. name,
            Position = UDim2.fromOffset((i - 1) * 22 - 4, 0),
            Size = UDim2.fromOffset(22, 26),
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            SelectionImageObject = I.SelectRing,
            Parent = controls,
        })
        local sw = Utility:Create("Frame", {
            Name = "Fill",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(14, 14),
            BorderSizePixel = 0,
            BackgroundColor3 = color,
            Parent = hit,
        })
        Utility:Corner(sw, 2)
        local ring = Utility:Create("Frame", {
            Name = "Ring",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = sw,
        })
        Utility:Stroke(ring, "Text", 1)
        Utility:Corner(ring, 4)
        swatches[i] = { Hit = hit, Ring = ring, Color = color }
    end
    local field = Utility:Create("Frame", {
        Name = "Hex",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(84, 26),
        BorderSizePixel = 0,
        Theme = { BackgroundColor3 = "Field" },
        Parent = controls,
    })
    local box = Utility:Text("TextBox", {
        Name = "Value",
        SelectionImageObject = I.SelectRing,
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -18, 1, 0),
        Text = "",
        PlaceholderText = "#0F57D4",
        ClearTextOnFocus = false,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Left,
        Color = "Text",
        Theme = { PlaceholderColor3 = "TextDark" },
        Parent = field,
    })
    local caption = Utility:Text("TextLabel", {
        Name = "Error",
        Size = UDim2.new(1, 0, 0, 16),
        Text = "Use a hex colour like #0F57D4.",
        Visible = false,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Caption,
        TextXAlignment = Enum.TextXAlignment.Left,
        Color = "Error",
        Parent = body,
    })

    local obj = { Instance = row, Value = ThemeManager:Get("Accent") }
    local layout = { Measure = 572, Stacked = false, Error = false }
    local function relayout()
        local m = layout.Measure
        local cw = Components.ControlWidth(m)
        local h
        if layout.Stacked then
            label.Position = UDim2.fromOffset(0, 6)
            label.Size = UDim2.new(0, m, 0, 20)
            controls.Position = UDim2.fromOffset(0, 32)
            controls.Size = UDim2.fromOffset(math.min(m, cw), 26)
            h = 66
        else
            label.Position = UDim2.fromOffset(0, 0)
            label.Size = UDim2.new(0, m - cw - 16, 0, Tokens.Size.Row)
            controls.Position = UDim2.fromOffset(m - cw, 4)
            controls.Size = UDim2.fromOffset(cw, 26)
            h = Tokens.Size.Row
        end
        caption.Position = UDim2.fromOffset(layout.Stacked and 0 or (m - cw), h)
        caption.Visible = layout.Error
        if layout.Error then
            h = h + 18
        end
        body.Size = UDim2.new(1, 0, 0, h)
        row.Size = UDim2.new(1, 0, 0, h)
    end
    local function paint()
        local c = obj.Value
        box.Text = Utility.ColorToHex(c)
        for _, s in ipairs(swatches) do
            s.Ring.Visible = ThemeManager.SameColor(s.Color, c)
        end
    end
    -- apply = false only repaints (used when the theme preset already applied the colour)
    function obj:SetValue(color, silentFlags)
        if typeof(color) ~= "Color3" then
            return
        end
        obj.Value = color
        W:SetAccent(color)
        local r, g, b = math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
        if silentFlags then
            SaveManager.Flags[flags[1]], SaveManager.Flags[flags[2]], SaveManager.Flags[flags[3]] = r, g, b
        else
            SaveManager:SetFlag(flags[1], r, true)
            SaveManager:SetFlag(flags[2], g, true)
            SaveManager:SetFlag(flags[3], b, true)
        end
        layout.Error = false
        relayout()
        paint()
    end
    -- the three channel flags load back through these options (SaveManager:Load calls SetValue)
    for index, flag in ipairs(flags) do
        SaveManager:RegisterOption(flag, {
            SetValue = function(_, v)
                local n = ClampNumber(v, 0, 255)
                local c = obj.Value
                local rgb = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
                rgb[index] = math.floor(n + 0.5)
                obj:SetValue(Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
            end,
        }, true)
    end
    obj:SetValue(obj.Value, true)

    for _, s in ipairs(swatches) do
        s.Hit.Activated:Connect(function()
            obj:SetValue(s.Color)
        end)
        s.Hit.MouseEnter:Connect(function()
            if not s.Ring.Visible then
                Motion:Play(s.Hit.Fill, { Size = UDim2.fromOffset(16, 16) }, "Hover", "size")
            end
        end)
        s.Hit.MouseLeave:Connect(function()
            Motion:Play(s.Hit.Fill, { Size = UDim2.fromOffset(14, 14) }, "Hover", "size")
        end)
    end
    box.Focused:Connect(function()
        Utility:SetColor(field, "BackgroundColor3", "FieldHover", "Hover")
    end)
    box.FocusLost:Connect(function()
        Utility:SetColor(field, "BackgroundColor3", "Field", "Hover")
        local color = Utility.HexToColor(box.Text)
        if color then
            obj:SetValue(color)
        else
            layout.Error = true
            relayout()
            paint()
        end
    end)

    tab._order = tab._order + 1
    row.LayoutOrder = tab._order
    row.Parent = tab.Page
    table.insert(tab._layoutHooks, function(measure, stacked)
        layout.Measure, layout.Stacked = measure, stacked
        relayout()
    end)
    layout.Measure, layout.Stacked = tab.Measure or 572, tab.Stacked == true
    relayout()
    if I.Index then
        table.insert(I.Index, { Kind = "Accent", Name = "Accent", Tab = tab, Instance = row, Object = obj })
    end
    return obj
end

function Components.BuildInterfacePage(W)
    local I = W._I
    local B = I.Backdrop
    local tab = Shell.CreateTab(W, "Interface", nil, nil, nil, true)
    W.ConfigTab = tab
    local built = false
    local accentRow

    tab:CreateSection("Visual")
    tab:CreateDropdown({
        Name = "Theme Preset",
        Flag = "__lib_theme_preset",
        Options = ThemeManager.ThemeOrder,
        Default = ThemeManager.Current,
        Callback = function(theme)
            W:SetTheme(theme)
            if built and accentRow then
                -- the accent follows the preset (6.x kept the old RGB and overrode the new preset)
                accentRow:SetValue(ThemeManager:Get("Accent"))
            end
        end,
    })
    accentRow = Components.AccentRow(W, tab)
    local backdropRow
    backdropRow = tab:CreateDropdown({
        Name = "Backdrop",
        Flag = "__lib_backdrop_mode",
        Options = Art.BackdropOptions,
        Default = B.Mode,
        Callback = function(mode)
            W:SetBackdrop(mode)
        end,
    })
    -- W:SetBackdrop from code (or a loaded config) keeps the picker in step
    I.SyncBackdropRows = function()
        if backdropRow and backdropRow.Value ~= B.Mode then
            backdropRow:SetValue(B.Mode)
        end
    end
    tab:CreateSlider({
        Name = "Backdrop Strength",
        Flag = "__lib_backdrop_strength",
        Min = 0,
        Max = 100,
        Default = B.Strength,
        Callback = function(v)
            W:SetBackdropStrength(v)
        end,
    })
    tab:CreateToggle({
        Name = "Hide Behind Preview",
        Flag = "__lib_backdrop_hide_preview",
        Default = B.HidePreview,
        Style = "Switch",
        Callback = function(v)
            W:SetBackdropHidePreview(v)
        end,
    })

    tab:CreateSection("Window")
    tab:CreateKeybind({
        Name = "Open/Close Key",
        Flag = "__lib_toggle_key",
        Default = W.ToggleKey.Name,
        Callback = function(key)
            local name = typeof(key) == "EnumItem" and key.Name or tostring(key)
            W:SetToggleKey(key)
            W:Notify({ Title = "Key Updated", Content = "New toggle key: " .. name, Duration = 2.5 })
        end,
    })
    local scaleSlider = tab:CreateSlider({
        Name = "UI Scale",
        Flag = "__lib_ui_scale",
        Min = 70,
        Max = 150,
        Default = math.floor(I.UserScale * 100 + 0.5),
        Callback = function(v)
            W:SetUIScale(v / 100)
        end,
    })
    local widthSlider = tab:CreateSlider({
        Name = "Window Width",
        Flag = "__lib_window_width",
        Min = Tokens.Limits.WidthMin,
        Max = Tokens.Limits.WidthMax,
        Default = I.Width,
        Callback = function(v)
            W:SetSize(v, I.Height)
        end,
    })
    local heightSlider = tab:CreateSlider({
        Name = "Window Height",
        Flag = "__lib_window_height",
        Min = Tokens.Limits.HeightMin,
        Max = Tokens.Limits.HeightMax,
        Default = I.Height,
        Callback = function(v)
            W:SetSize(I.Width, v)
        end,
    })
    local sidebarSlider = tab:CreateSlider({
        Name = "Sidebar Width",
        Flag = "__lib_sidebar_width",
        Min = Tokens.Limits.SidebarMin,
        Max = Tokens.Limits.SidebarMax,
        Default = I.SidebarW,
        Callback = function(v)
            W:SetSidebarWidth(v)
        end,
    })
    I.LayoutSliders = { Width = widthSlider, Height = heightSlider }
    tab:CreateToggle({
        Name = "Enable Notifications",
        Flag = "__lib_enable_notifs",
        Default = true,
        Style = "Switch",
        Callback = function(v)
            W.NotificationsEnabled = v == true
        end,
    })
    tab:CreateToggle({
        Name = "Reduce Motion",
        Flag = "__lib_reduce_motion",
        Default = false,
        Style = "Switch",
        Callback = function(v)
            W:SetReducedMotion(v)
        end,
    })
    tab:CreateButton({
        Name = "Hide Window",
        Callback = function()
            W:HideWithPrompt()
        end,
    })
    tab:CreateButton({
        Name = "Reset Window Layout",
        Callback = function()
            widthSlider:SetValue(800)
            heightSlider:SetValue(500)
            sidebarSlider:SetValue(200)
            scaleSlider:SetValue(100)
            W:Notify({ Title = "Layout Reset", Content = "Size and scale were reset.", Duration = 2.8 })
        end,
    })

    tab:CreateSection("Script")
    tab:CreateButton({
        Name = "Save UI Config",
        Callback = function()
            SaveManager:Save("ui_default")
            W:Notify({ Title = "Config Saved", Content = "Saved to " .. tostring(SaveManager.Folder) .. "/configs/ui_default.json", Duration = 3 })
        end,
    })
    tab:CreateButton({
        Name = "Load UI Config",
        Callback = function()
            local ok = SaveManager:Load("ui_default")
            W:Notify({
                Title = ok and "Config Loaded" or "Config Missing",
                Content = ok and "Loaded ui_default." or "ui_default.json was not found.",
                Duration = 3,
                Type = ok and "Info" or "Warning",
            })
        end,
    })
    tab:CreateButton({
        Name = "Kill Script",
        Style = "Danger",
        Callback = function()
            local sure = W:Confirm({
                Title = "Kill Script?",
                Content = "This closes the UI and stops the script.",
                ConfirmText = "Kill",
                CancelText = "Cancel",
                Timeout = 10,
                TimeoutResult = false,
            })
            if not sure then
                return
            end
            W:Notify({ Title = "Script Terminated", Content = "UI destroyed by user request.", Duration = 1.8 })
            task.delay(0.2, function()
                W:Destroy()
            end)
        end,
    })
    built = true
    return tab
end

-- ==============================================================================
-- 13) COMMAND PALETTE (N, B grammar): Ctrl+F, the touch-only search glyph, or Window:OpenPalette().
--     Lives inside MainFrame on the modal scrim; search field at content x, results as plain rows (no boxes):
--     name with the matched part in Text, "Tab / Section" path, current value; the selected row gets B's dash.
-- ==============================================================================

local Palette = { RowH = 34, MaxRows = 60 }

function Palette.Escape(text)
    return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;"))
end

function Palette.Hex(key)
    local c = ThemeManager:Resolve(key)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- current value of a registered control as short text ("On", "Off", "400", "1024", "#0F57D4")
function Palette.ValueText(item)
    local o = item.Object
    if type(o) ~= "table" or item.Kind == "Button" or item.Kind == "Section" then
        return ""
    end
    local v = o.Value
    local t = typeof(v)
    if t == "boolean" then
        return v and "On" or "Off"
    elseif t == "number" then
        if math.abs(v - math.floor(v)) < 1e-6 then
            return tostring(math.floor(v))
        end
        return string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    elseif t == "string" then
        return v
    elseif t == "Color3" then
        return Utility.ColorToHex(v)
    elseif t == "EnumItem" then
        return v.Name
    elseif t == "table" then
        return #v == 1 and tostring(v[1]) or (#v .. " selected")
    end
    return ""
end

-- every tab, group and visible registered control, in creation order
function Palette.Collect(W)
    local I = W._I
    local out = {}
    for _, tab in ipairs(W.Tabs) do
        table.insert(out, { Kind = "Tab", Name = tab.Name, Tab = tab, Path = tab.Group and tab.Group.Name or "", IsTab = true })
    end
    for _, group in ipairs(I.Groups) do
        if group.Tabs[1] then
            table.insert(out, { Kind = "Group", Name = group.Name, Tab = group.Tabs[1], Group = group, Path = "", IsTab = true })
        end
    end
    for _, item in ipairs(I.Index or {}) do
        local inst = item.Instance
        if item.Kind ~= "Section" and inst and inst.Parent and inst.Visible and item.Tab and item.Name ~= "" then
            local path = item.Tab.Name
            if item.Section and item.Section ~= "" and item.Section ~= item.Tab.Name then
                path = path .. " / " .. item.Section
            end
            table.insert(out, { Kind = item.Kind, Name = item.Name, Tab = item.Tab, Path = path, Item = item })
        end
    end
    return out
end

-- rank: starts with > a word starts with > contains > path contains; ties keep creation order
function Palette.Rank(entry, q)
    local name = string.lower(entry.Name)
    local s, e = string.find(name, q, 1, true)
    if s == 1 then
        return 1, s, e
    end
    if s then
        local at = 1
        while true do
            local a, b = string.find(name, q, at, true)
            if not a then
                break
            end
            if a > 1 and not string.sub(name, a - 1, a - 1):match("%w") then
                return 2, a, b
            end
            at = a + 1
        end
        return 3, s, e
    end
    if entry.Path ~= "" and string.find(string.lower(entry.Path), q, 1, true) then
        return 4, nil, nil
    end
    return nil
end

function Palette.Search(P, query)
    local q = string.lower((tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")))
    local list = {}
    for i, entry in ipairs(P.Source) do
        if q == "" then
            entry.Score, entry.From, entry.To = entry.IsTab and 0 or 1, nil, nil
            table.insert(list, entry)
        else
            local score, a, b = Palette.Rank(entry, q)
            if score then
                entry.Score, entry.From, entry.To = score, a, b
                table.insert(list, entry)
            end
        end
        entry.Order = i
    end
    table.sort(list, function(x, y)
        if x.Score ~= y.Score then
            return x.Score < y.Score
        end
        return x.Order < y.Order
    end)
    while #list > Palette.MaxRows do
        table.remove(list)
    end
    return list
end

function Palette.NameText(entry, selected)
    local name = entry.Name
    if selected or not entry.From then
        return Palette.Escape(name), selected and "Text" or "TextDark"
    end
    local dark = Palette.Hex("TextDark")
    local lit = Palette.Hex("Text")
    local a, b = entry.From, entry.To
    local parts = {}
    if a > 1 then
        table.insert(parts, string.format('<font color="%s">%s</font>', dark, Palette.Escape(string.sub(name, 1, a - 1))))
    end
    table.insert(parts, string.format('<font color="%s">%s</font>', lit, Palette.Escape(string.sub(name, a, b))))
    if b < #name then
        table.insert(parts, string.format('<font color="%s">%s</font>', dark, Palette.Escape(string.sub(name, b + 1))))
    end
    return table.concat(parts), "TextDark"
end

-- ------------------------------------------------------------------------------
-- rows
-- ------------------------------------------------------------------------------

function Palette.PaintRow(P, i)
    local row = P.Rows[i]
    if not row then
        return
    end
    local selected = i == P.Selected
    local text, key = Palette.NameText(row.Entry, selected)
    row.Name.Text = text
    Utility:SetColor(row.Name, "TextColor3", key)
    row.Dash.Visible = selected
end

function Palette.Select(P, i, scroll)
    local n = #P.Rows
    if n == 0 then
        P.Selected = 0
        return
    end
    i = ((i - 1) % n) + 1
    local old = P.Selected
    P.Selected = i
    if old ~= i then
        Palette.PaintRow(P, old)
    end
    Palette.PaintRow(P, i)
    if scroll then
        local list = P.List
        local h = Palette.RowH
        local top = (i - 1) * h
        local viewH = list.AbsoluteWindowSize.Y / math.max(P.W._I.Scale, 0.01)
        local y = list.CanvasPosition.Y
        if top < y then
            list.CanvasPosition = Vector2.new(0, top)
        elseif top + h > y + viewH then
            list.CanvasPosition = Vector2.new(0, top + h - viewH)
        end
    end
end

function Palette.BuildRow(P, entry, i, width)
    local W = P.W
    local rowH = Palette.RowH
    local valueW = 80
    local row = Utility:Create("TextButton", {
        Name = "Result",
        Size = UDim2.new(1, 0, 0, rowH),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = i,
        SelectionImageObject = W._I.SelectRing,
        ZIndex = Tokens.Z.Palette + 2,
        Parent = P.List,
    })
    local dash = Utility:Create("Frame", {
        Name = "Dash",
        Position = UDim2.new(0, 0, 0.5, -1),
        Size = UDim2.fromOffset(8, Tokens.B.Line),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = Tokens.Z.Palette + 2,
        Theme = { BackgroundColor3 = "AccentGlow" },
        Parent = row,
    })
    local valueText = entry.Item and Palette.ValueText(entry.Item) or ""
    local value = Utility:Text("TextLabel", {
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, valueW, 1, 0),
        Text = valueText,
        Font = { "Sans", "Medium" },
        TextSize = Tokens.Text.Value,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Tokens.Z.Palette + 2,
        Color = "Text",
        Parent = row,
    })
    local room = width - 16 - valueW - 16
    local pathW = 0
    if entry.Path ~= "" then
        pathW = math.min(Rows.TextW(entry.Path, Tokens.Text.Small, "Regular") + 2, math.floor(room * 0.45))
    end
    local nameW = math.max(40, room - pathW - (pathW > 0 and 16 or 0))
    local path = Utility:Text("TextLabel", {
        Name = "Path",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -(valueW + 16), 0, 0),
        Size = UDim2.new(0, pathW, 1, 0),
        Text = entry.Path,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Tokens.Z.Palette + 2,
        Color = "TextDark",
        Parent = row,
    })
    local name = Utility:Text("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(0, nameW, 1, 0),
        Text = "",
        RichText = true,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Tokens.Z.Palette + 2,
        Color = "TextDark",
        Parent = row,
    })
    local r = { Entry = entry, Button = row, Name = name, Dash = dash, Value = value, Path = path }
    row.MouseEnter:Connect(function()
        if P.Open then
            Palette.Select(P, i, false)
        end
    end)
    row.InputBegan:Connect(function(input)
        if Shell.IsPointer(input) then
            P.Pressing = true
        end
    end)
    row.Activated:Connect(function()
        P.Pressing = false
        if P.Open then
            Palette.Go(P, entry)
        end
    end)
    return r
end

function Palette.Fill(P)
    for _, r in ipairs(P.Rows) do
        r.Button:Destroy()
    end
    table.clear(P.Rows)
    local width = P.Width
    local results = Palette.Search(P, P.Box.Text)
    for i, entry in ipairs(results) do
        P.Rows[i] = Palette.BuildRow(P, entry, i, width)
    end
    P.Empty.Visible = #results == 0
    P.List.CanvasPosition = Vector2.zero
    P.Selected = 0
    for i = 1, #P.Rows do
        Palette.PaintRow(P, i)
    end
    Palette.Select(P, 1, false)
end

-- ------------------------------------------------------------------------------
-- open / close / go
-- ------------------------------------------------------------------------------

function Palette.Enabled(W)
    return W._I.Settings.CommandPalette ~= false
end

function Overlays.OpenPalette(W)
    local I = W._I
    if W.IsDestroyed or not Palette.Enabled(W) or I.Palette or I.ModalCount > 0 then
        return false
    end
    if W.IsMinimized or W.IsHidden or not I.MainFrame.Visible or I.Loading then
        return false
    end
    Overlays.ClosePopover(W)
    Overlays.HideTooltip(W)
    pcall(Shell.SetDrawer, W, false)
    local P = { W = W, Rows = {}, Selected = 0, Open = true, Navigated = false }
    I.Palette = P
    P.Source = Palette.Collect(W)
    local x = I.ContentX
    local region = math.min(I.ContentW, Tokens.Size.ContentMax)
    P.Width = region
    local fieldH = I.Family == "Compact" and Tokens.Size.FieldCompact or Tokens.Size.Field
    local layer = Utility:Create("TextButton", {
        Name = "Palette",
        Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Selectable = false,
        ZIndex = Tokens.Z.Palette,
        Theme = { BackgroundColor3 = "Background" },
        Parent = I.MainFrame,
    })
    P.Layer = layer
    local field = Utility:Create("Frame", {
        Name = "Field",
        Position = UDim2.fromOffset(x, Tokens.B.ContentY),
        Size = UDim2.fromOffset(math.min(480, region), fieldH),
        BorderSizePixel = 0,
        Active = true,
        ZIndex = Tokens.Z.Palette + 1,
        Theme = { BackgroundColor3 = "FieldHover" },
        Parent = layer,
    })
    local line = Rows.FieldLine(field)
    line.Visible = true
    line.ZIndex = Tokens.Z.Palette + 2
    Glyph.Draw(field, "search", 12, "TextDark", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = Tokens.Z.Palette + 2 })
    local box = Utility:Text("TextBox", {
        Name = "Query",
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -36, 1, 0),
        Text = "",
        PlaceholderText = "Search controls and tabs",
        ClearTextOnFocus = false,
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Tokens.Z.Palette + 2,
        Color = "Text",
        Theme = { PlaceholderColor3 = "TextDark" },
        Parent = field,
    })
    P.Box = box
    local top = Tokens.B.ContentY + fieldH + 10
    local list = Utility:Create("ScrollingFrame", {
        Name = "Results",
        Position = UDim2.fromOffset(x, top),
        Size = UDim2.new(0, region + 14, 1, -(top + Tokens.B.InsetBottom)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        ZIndex = Tokens.Z.Palette + 1,
        Theme = { ScrollBarImageColor3 = "TextMuted" },
        Parent = layer,
    })
    Utility:Padding(list, 0, 14, 0, 0)
    Utility:List(list, Enum.FillDirection.Vertical, 0)
    Shell.AutoScrollbar(W, list)
    P.List = list
    P.Empty = Utility:Text("TextLabel", {
        Name = "Empty",
        Position = UDim2.fromOffset(x + 16, top),
        Size = UDim2.fromOffset(region - 16, Palette.RowH),
        Text = "No matches",
        Font = { "Sans", "Regular" },
        TextSize = Tokens.Text.Small,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        ZIndex = Tokens.Z.Palette + 2,
        Color = "TextDark",
        Parent = layer,
    })

    Palette.Fill(P)
    P.LastText = ""
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if not P.Open or P.Reverting then
            return
        end
        local text = box.Text
        local row = P.Rows[P.Selected]
        -- Space after arrow keys flips a selected toggle in place instead of typing
        if P.Navigated and row and row.Entry.Kind == "Toggle" and text == P.LastText .. " " then
            P.Reverting = true
            box.Text = P.LastText
            P.Reverting = false
            local o = row.Entry.Item and row.Entry.Item.Object
            if type(o) == "table" and type(o.SetValue) == "function" then
                pcall(o.SetValue, o, not o.Value)
                row.Value.Text = Palette.ValueText(row.Entry.Item)
            end
            return
        end
        P.Navigated = false
        P.LastText = text
        Palette.Fill(P)
    end)
    box.FocusLost:Connect(function(enter)
        if not P.Open then
            return
        end
        if enter then
            local row = P.Rows[P.Selected]
            if row then
                Palette.Go(P, row.Entry)
            else
                Overlays.ClosePalette(W)
            end
            return
        end
        task.delay(0.08, function()
            if P.Open and not P.Pressing and not box:IsFocused() then
                Overlays.ClosePalette(W)
            end
        end)
    end)
    layer.Activated:Connect(function()
        Overlays.ClosePalette(W)
    end)

    Motion:Play(layer, { BackgroundTransparency = 0.06 }, "Scrim", "scrim")
    local fader = Utility:Fader(field)
    fader:Set(1)
    fader:Tween(0, "Fade")
    if not UserInputService.GamepadEnabled or UserInputService.KeyboardEnabled then
        task.defer(function()
            if P.Open then
                pcall(function()
                    box:CaptureFocus()
                end)
            end
        end)
    elseif P.Rows[1] then
        pcall(function()
            GuiService.SelectedObject = P.Rows[1].Button
        end)
    end
    return true
end

function Overlays.ClosePalette(W)
    local I = W._I
    local P = I.Palette
    if not P then
        return
    end
    P.Open = false
    I.Palette = nil
    pcall(function()
        if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(P.Layer) then
            GuiService.SelectedObject = nil
        end
    end)
    pcall(function()
        if P.Box:IsFocused() then
            P.Box:ReleaseFocus(false)
        end
    end)
    local layer = P.Layer
    if Motion.Reduced then
        layer:Destroy()
        return
    end
    local fader = Utility:Fader(layer)
    fader:Tween(1, "Exit")
    task.delay(Motion:GetInfo("Exit").Time + 0.02, function()
        pcall(function()
            layer:Destroy()
        end)
    end)
end

-- close, switch tab (opens its group, closes the drawer), scroll the row into view, flash its label
function Palette.Go(P, entry)
    local W = P.W
    Overlays.ClosePalette(W)
    local tab = entry.Tab
    if not tab or W.IsDestroyed then
        return
    end
    if entry.Group then
        entry.Group:SetOpen(true)
    end
    if W.CurrentTab ~= tab then
        tab:Show()
    end
    local item = entry.Item
    if not item or not item.Instance then
        return
    end
    local row = item.Instance
    task.defer(function()
        local page = tab.Page
        if not row.Parent or W.IsDestroyed then
            return
        end
        local scale = math.max(W._I.Scale, 0.01)
        local y = (row.AbsolutePosition.Y - page.AbsolutePosition.Y) / scale + page.CanvasPosition.Y
        local maxY = math.max(0, page.AbsoluteCanvasSize.Y / scale - page.AbsoluteWindowSize.Y / scale)
        local target = Vector2.new(0, math.clamp(y - 24, 0, maxY))
        if Motion.Reduced then
            page.CanvasPosition = target
        else
            Motion:Play(page, { CanvasPosition = target }, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "scroll")
        end
        local label = row:FindFirstChild("Label", true)
        if label and label:IsA("TextLabel") then
            local reg = ThemeManager.Registry[label]
            local restKey = reg and reg.TextColor3 or "Text"
            if restKey == "AccentText" then
                return
            end
            Utility:SetColor(label, "TextColor3", "AccentText")
            local hold = Motion.Reduced and 1 or 0.4
            task.delay(hold, function()
                if label.Parent then
                    local reg2 = ThemeManager.Registry[label]
                    if reg2 and reg2.TextColor3 == "AccentText" then
                        Utility:SetColor(label, "TextColor3", restKey, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
                    end
                end
            end)
        end
    end)
end

-- keys while open: Up / Down (wrap), Escape closes; Ctrl+F opens (no TextBox focused)
function Palette.KeyHandler(W, input)
    local I = W._I
    local key = input.KeyCode
    local P = I.Palette
    if P and P.Open then
        if key == Enum.KeyCode.Down or key == Enum.KeyCode.Up then
            P.Navigated = true
            Palette.Select(P, P.Selected + (key == Enum.KeyCode.Down and 1 or -1), true)
            return true
        elseif key == Enum.KeyCode.Escape then
            Overlays.ClosePalette(W)
            return true
        end
        return false
    end
    if key == Enum.KeyCode.F and not UserInputService:GetFocusedTextBox()
        and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        return Overlays.OpenPalette(W)
    end
    return false
end

-- called once by CreateWindow: key handler (first in the list, so dialogs opened later take keys first),
-- the touch-only search glyph in the title band, and closing when the window goes away
function Overlays.InstallPalette(W)
    local I = W._I
    table.insert(I.KeyHandlers, 1, function(input)
        return Palette.KeyHandler(W, input)
    end)
    local btn = Shell.GlyphButton(W, I.TopBand, "search", 14, function()
        Overlays.OpenPalette(W)
    end, { Name = "Search", Position = UDim2.new(1, -83, 0, 23), Visible = false })
    table.insert(I.NoDrag, btn)
    I.SearchButton = btn
    Palette.UpdateSearchButton(W)
    I.Trove:Connect(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), function()
        Palette.UpdateSearchButton(W)
    end)
    I.Trove:Connect(I.MainFrame:GetPropertyChangedSignal("Visible"), function()
        if not I.MainFrame.Visible then
            Overlays.ClosePalette(W)
        end
    end)
end

function Palette.UpdateSearchButton(W)
    local I = W._I
    local btn = I.SearchButton
    if not btn then
        return
    end
    btn.Visible = Palette.Enabled(W) and UserInputService.KeyboardEnabled == false
    btn.Position = UDim2.new(1, I.Family == "Compact" and -115 or -83, 0, 23)
end

Overlays.UpdateSearchButton = Palette.UpdateSearchButton

function WindowMethods:OpenPalette()
    return Overlays.OpenPalette(self)
end

function WindowMethods:ClosePalette()
    Overlays.ClosePalette(self)
end

return Library
