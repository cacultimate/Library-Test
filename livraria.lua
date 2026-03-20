--[[
    MonochromeUILib.lua
    Single-file Roblox UI library intended for executor environments.
    Theme rules are intentionally strict: white, black, and dark gray only.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local CoreGui = (cloneref and cloneref(game:GetService("CoreGui"))) or game:GetService("CoreGui")

local Library = {}
Library.__index = Library
Library.Flags = {}
Library.Theme = {
    Background = Color3.fromRGB(32, 32, 32),
    Surface = Color3.fromRGB(0, 0, 0),
    Text = Color3.fromRGB(255, 255, 255)
}

local FAST_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SOFT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function safeCallback(callback, ...)
    if typeof(callback) ~= "function" then
        return
    end

    local arguments = table.pack(...)
    task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(arguments, 1, arguments.n))
        end)

        if not success then
            warn("[MonochromeUILib] Callback error:", err)
        end
    end)
end

local function tween(object, tweenInfo, properties)
    local animation = TweenService:Create(object, tweenInfo, properties)
    animation:Play()
    return animation
end

local function create(className, properties)
    local object = Instance.new(className)

    for key, value in pairs(properties or {}) do
        object[key] = value
    end

    return object
end

local function addCorner(instance, radius)
    local corner = create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    })

    corner.Parent = instance
    return corner
end

local function addStroke(instance, transparency)
    local stroke = create("UIStroke", {
        Color = Library.Theme.Text,
        Thickness = 1,
        Transparency = transparency or 0.82,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })

    stroke.Parent = instance
    return stroke
end

local function addPadding(instance, left, right, top, bottom)
    local padding = create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0)
    })

    padding.Parent = instance
    return padding
end

local function bindHover(button, target, stroke, normalColor, hoverColor, pressedColor)
    button.MouseEnter:Connect(function()
        tween(target, FAST_TWEEN, {BackgroundColor3 = hoverColor})
        if stroke then
            tween(stroke, FAST_TWEEN, {Transparency = 0.68})
        end
    end)

    button.MouseLeave:Connect(function()
        tween(target, FAST_TWEEN, {BackgroundColor3 = normalColor})
        if stroke then
            tween(stroke, FAST_TWEEN, {Transparency = 0.82})
        end
    end)

    button.MouseButton1Down:Connect(function()
        tween(target, FAST_TWEEN, {BackgroundColor3 = pressedColor})
        if stroke then
            tween(stroke, FAST_TWEEN, {Transparency = 0.58})
        end
    end)

    button.MouseButton1Up:Connect(function()
        local inside = false
        local mouseLocation = UserInputService:GetMouseLocation()

        pcall(function()
            inside = button:IsDescendantOf(game)
                and button.AbsolutePosition.X <= mouseLocation.X
                and button.AbsolutePosition.X + button.AbsoluteSize.X >= mouseLocation.X
                and button.AbsolutePosition.Y <= mouseLocation.Y
                and button.AbsolutePosition.Y + button.AbsoluteSize.Y >= mouseLocation.Y
        end)

        tween(target, FAST_TWEEN, {
            BackgroundColor3 = inside and hoverColor or normalColor
        })

        if stroke then
            tween(stroke, FAST_TWEEN, {
                Transparency = inside and 0.68 or 0.82
            })
        end
    end)
end

local function mouseInside(button)
    local inside = false
    local mouseLocation = UserInputService:GetMouseLocation()

    pcall(function()
        inside = button:IsDescendantOf(game)
            and button.AbsolutePosition.X <= mouseLocation.X
            and button.AbsolutePosition.X + button.AbsoluteSize.X >= mouseLocation.X
            and button.AbsolutePosition.Y <= mouseLocation.Y
            and button.AbsolutePosition.Y + button.AbsoluteSize.Y >= mouseLocation.Y
    end)

    return inside
end

local function updateScrollingCanvas(scrollingFrame, layout)
    local function refresh()
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
    refresh()
end

local function executorParent()
    if gethui then
        return gethui()
    end

    return CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function protectGui(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    elseif protectgui then
        pcall(protectgui, gui)
    end
end

local function clamp(number, minimum, maximum)
    return math.max(minimum, math.min(maximum, number))
end

local function roundToStep(value, minimum, maximum, increment)
    local clamped = clamp(value, minimum, maximum)

    if increment and increment > 0 then
        clamped = minimum + math.floor(((clamped - minimum) / increment) + 0.5) * increment
    end

    return clamp(clamped, minimum, maximum)
end

function Library:CreateWindow(options)
    options = options or {}

    local windowName = options.Name or "Monochrome UI"
    local windowSubtitle = options.Subtitle or "Executor-ready UI library"
    local windowSize = options.Size or UDim2.fromOffset(760, 520)

    local parent = executorParent()

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == windowName then
            child:Destroy()
        end
    end

    local screenGui = create("ScreenGui", {
        Name = windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    protectGui(screenGui)
    screenGui.Parent = parent

    local shadow = create("Frame", {
        Name = "Shadow",
        Parent = screenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, 10),
        Size = UDim2.new(windowSize.X.Scale, windowSize.X.Offset + 18, windowSize.Y.Scale, windowSize.Y.Offset + 18),
        BackgroundColor3 = Library.Theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 0
    })
    addCorner(shadow, 24)

    local main = create("Frame", {
        Name = "Main",
        Parent = screenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = windowSize,
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1
    })
    addCorner(main, 20)
    addStroke(main, 0.74)

    local topbar = create("Frame", {
        Name = "Topbar",
        Parent = main,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Library.Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 2
    })
    addCorner(topbar, 20)

    create("Frame", {
        Parent = topbar,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = Library.Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 2
    })

    create("TextLabel", {
        Name = "Title",
        Parent = topbar,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.new(1, -180, 0, 20),
        BackgroundTransparency = 1,
        Text = windowName,
        TextColor3 = Library.Theme.Text,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3
    })

    create("TextLabel", {
        Name = "Subtitle",
        Parent = topbar,
        Position = UDim2.fromOffset(18, 29),
        Size = UDim2.new(1, -180, 0, 16),
        BackgroundTransparency = 1,
        Text = windowSubtitle,
        TextColor3 = Library.Theme.Text,
        TextTransparency = 0.24,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3
    })

    local buttonRow = create("Frame", {
        Name = "WindowButtons",
        Parent = topbar,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(90, 32),
        BackgroundTransparency = 1,
        ZIndex = 3
    })

    create("UIListLayout", {
        Parent = buttonRow,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local collapseButton = create("TextButton", {
        Parent = buttonRow,
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel = 0,
        Text = "-",
        TextColor3 = Library.Theme.Text,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 4
    })
    addCorner(collapseButton, 10)
    local collapseStroke = addStroke(collapseButton, 0.82)

    local closeButton = create("TextButton", {
        Parent = buttonRow,
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel = 0,
        Text = "x",
        TextColor3 = Library.Theme.Text,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 4
    })
    addCorner(closeButton, 10)
    local closeStroke = addStroke(closeButton, 0.82)

    bindHover(collapseButton, collapseButton, collapseStroke, Library.Theme.Background, Library.Theme.Surface, Library.Theme.Background)
    bindHover(closeButton, closeButton, closeStroke, Library.Theme.Background, Library.Theme.Surface, Library.Theme.Background)

    local body = create("Frame", {
        Name = "Body",
        Parent = main,
        Position = UDim2.fromOffset(12, 68),
        Size = UDim2.new(1, -24, 1, -80),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2
    })

    local tabSidebar = create("Frame", {
        Name = "Sidebar",
        Parent = body,
        Size = UDim2.new(0, 184, 1, 0),
        BackgroundColor3 = Library.Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 2
    })
    addCorner(tabSidebar, 16)
    addStroke(tabSidebar, 0.82)
    addPadding(tabSidebar, 12, 12, 12, 12)

    create("TextLabel", {
        Parent = tabSidebar,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Tabs",
        TextColor3 = Library.Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3
    })

    local tabsContainer = create("Frame", {
        Parent = tabSidebar,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 1, -28),
        BackgroundTransparency = 1,
        ZIndex = 3
    })

    create("UIListLayout", {
        Parent = tabsContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    })

    local pagesHolder = create("Frame", {
        Name = "PagesHolder",
        Parent = body,
        Position = UDim2.new(0, 196, 0, 0),
        Size = UDim2.new(1, -196, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2
    })

    local window = {
        Gui = screenGui,
        Main = main,
        Body = body,
        Sidebar = tabSidebar,
        PagesHolder = pagesHolder,
        Tabs = {},
        CurrentTab = nil,
        Expanded = true,
        ExpandedSize = windowSize
    }

    local dragging = false
    local dragOrigin
    local startPosition

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragOrigin = input.Position
            startPosition = main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - dragOrigin
        local newPosition = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

        main.Position = newPosition
        shadow.Position = newPosition + UDim2.fromOffset(0, 10)
    end)

    function window:SelectTab(tabObject)
        if self.CurrentTab == tabObject then
            return
        end

        if self.CurrentTab then
            local currentPage = self.CurrentTab.Page
            local currentButton = self.CurrentTab.Button
            local previousTab = self.CurrentTab

            self.CurrentTab.Active = false
            tween(currentButton, FAST_TWEEN, {BackgroundColor3 = Library.Theme.Surface})
            tween(self.CurrentTab.Stroke, FAST_TWEEN, {Transparency = 0.82})
            tween(currentPage, FAST_TWEEN, {Position = UDim2.new(0, 14, 0, 0)})

            task.delay(0.12, function()
                if self.CurrentTab ~= previousTab and currentPage.Parent then
                    currentPage.Visible = false
                end
            end)
        end

        self.CurrentTab = tabObject
        tabObject.Active = true
        tabObject.Page.Visible = true
        tabObject.Page.Position = UDim2.new(0, -14, 0, 0)

        tween(tabObject.Button, FAST_TWEEN, {BackgroundColor3 = Library.Theme.Background})
        tween(tabObject.Stroke, FAST_TWEEN, {Transparency = 0.58})
        tween(tabObject.Page, OPEN_TWEEN, {Position = UDim2.new(0, 0, 0, 0)})
    end

    function window:SetVisible(state)
        self.Gui.Enabled = state
    end

    function window:Destroy()
        self.Gui:Destroy()
    end

    collapseButton.MouseButton1Click:Connect(function()
        window.Expanded = not window.Expanded

        local targetMainSize = window.Expanded and window.ExpandedSize or UDim2.new(window.ExpandedSize.X.Scale, window.ExpandedSize.X.Offset, 0, 56)
        local targetShadowSize = window.Expanded
            and UDim2.new(window.ExpandedSize.X.Scale, window.ExpandedSize.X.Offset + 18, window.ExpandedSize.Y.Scale, window.ExpandedSize.Y.Offset + 18)
            or UDim2.new(window.ExpandedSize.X.Scale, window.ExpandedSize.X.Offset + 18, 0, 74)
        local targetBodySize = window.Expanded and UDim2.new(1, -24, 1, -80) or UDim2.new(1, -24, 0, 0)

        tween(main, OPEN_TWEEN, {Size = targetMainSize})
        tween(shadow, OPEN_TWEEN, {Size = targetShadowSize})
        tween(body, OPEN_TWEEN, {Size = targetBodySize})
        tween(collapseButton, FAST_TWEEN, {Rotation = window.Expanded and 0 or -90})
    end)

    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    function window:CreateTab(name)
        local tabName = name or ("Tab " .. tostring(#self.Tabs + 1))

        local tabButton = create("TextButton", {
            Parent = tabsContainer,
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = Library.Theme.Surface,
            BorderSizePixel = 0,
            Text = tabName,
            TextColor3 = Library.Theme.Text,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            ZIndex = 4
        })
        addCorner(tabButton, 12)
        local tabStroke = addStroke(tabButton, 0.82)
        bindHover(tabButton, tabButton, tabStroke, Library.Theme.Surface, Library.Theme.Background, Library.Theme.Surface)

        local page = create("ScrollingFrame", {
            Parent = pagesHolder,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.Theme.Text,
            ScrollBarImageTransparency = 0.72,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.None,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false,
            Position = UDim2.new(0, 0, 0, 0),
            ZIndex = 2
        })

        addPadding(page, 0, 6, 0, 0)

        local pageLayout = create("UIListLayout", {
            Parent = page,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12)
        })
        updateScrollingCanvas(page, pageLayout)

        local tabObject = {
            Name = tabName,
            Button = tabButton,
            Stroke = tabStroke,
            Page = page,
            Active = false
        }

        local function refreshTabVisual(hovered, pressed)
            local background = Library.Theme.Surface
            local strokeTransparency = 0.82

            if tabObject.Active then
                background = Library.Theme.Background
                strokeTransparency = hovered and 0.5 or 0.58
            elseif hovered then
                background = Library.Theme.Background
                strokeTransparency = pressed and 0.58 or 0.68
            end

            tween(tabButton, FAST_TWEEN, {BackgroundColor3 = background})
            tween(tabStroke, FAST_TWEEN, {Transparency = strokeTransparency})
        end

        tabButton.MouseEnter:Connect(function()
            refreshTabVisual(true, false)
        end)

        tabButton.MouseLeave:Connect(function()
            refreshTabVisual(false, false)
        end)

        tabButton.MouseButton1Down:Connect(function()
            refreshTabVisual(true, true)
        end)

        tabButton.MouseButton1Up:Connect(function()
            refreshTabVisual(mouseInside(tabButton), false)
        end)

        function tabObject:CreateSection(sectionName)
            local section = create("Frame", {
                Parent = page,
                Size = UDim2.new(1, -6, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Library.Theme.Surface,
                BorderSizePixel = 0,
                ZIndex = 3
            })
            addCorner(section, 16)
            addStroke(section, 0.82)
            addPadding(section, 14, 14, 14, 14)

            create("TextLabel", {
                Parent = section,
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = sectionName or "Section",
                TextColor3 = Library.Theme.Text,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 4
            })

            create("Frame", {
                Parent = section,
                Position = UDim2.fromOffset(0, 28),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Library.Theme.Background,
                BorderSizePixel = 0,
                ZIndex = 4
            })

            local content = create("Frame", {
                Parent = section,
                Position = UDim2.fromOffset(0, 40),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                ZIndex = 4
            })

            create("UIListLayout", {
                Parent = content,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 10)
            })

            local sectionObject = {}

            local function createControlFrame(height, automatic)
                local frame = create("Frame", {
                    Parent = content,
                    Size = UDim2.new(1, 0, 0, height or 46),
                    AutomaticSize = automatic and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    BackgroundColor3 = Library.Theme.Background,
                    BorderSizePixel = 0,
                    ZIndex = 5
                })

                addCorner(frame, 12)
                local stroke = addStroke(frame, 0.84)

                return frame, stroke
            end

            function sectionObject:CreateButton(buttonOptions)
                buttonOptions = buttonOptions or {}

                local buttonFrame, buttonStroke = createControlFrame(44, false)
                local button = create("TextButton", {
                    Parent = buttonFrame,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = buttonOptions.Text or "Button",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 13,
                    Font = Enum.Font.GothamBold,
                    AutoButtonColor = false,
                    ZIndex = 6
                })

                bindHover(button, buttonFrame, buttonStroke, Library.Theme.Background, Library.Theme.Surface, Library.Theme.Background)

                button.MouseButton1Click:Connect(function()
                    tween(buttonFrame, FAST_TWEEN, {BackgroundColor3 = Library.Theme.Surface})
                    task.delay(0.08, function()
                        if buttonFrame.Parent then
                            tween(buttonFrame, FAST_TWEEN, {BackgroundColor3 = Library.Theme.Background})
                        end
                    end)

                    safeCallback(buttonOptions.Callback)
                end)

                return {
                    SetText = function(_, newText)
                        button.Text = tostring(newText)
                    end
                }
            end
            function sectionObject:CreateToggle(toggleOptions)
                toggleOptions = toggleOptions or {}

                local flag = toggleOptions.Flag or toggleOptions.Text or ("Toggle_" .. tostring(os.clock()))
                local state = toggleOptions.Default == true

                local toggleFrame, toggleStroke = createControlFrame(50, false)
                addPadding(toggleFrame, 14, 14, 0, 0)

                create("TextLabel", {
                    Parent = toggleFrame,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(1, -70, 0, 18),
                    BackgroundTransparency = 1,
                    Text = toggleOptions.Text or "Toggle",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 13,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local switch = create("Frame", {
                    Parent = toggleFrame,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(50, 26),
                    BackgroundColor3 = Library.Theme.Background,
                    BorderSizePixel = 0,
                    ZIndex = 6
                })
                addCorner(switch, 99)
                local switchStroke = addStroke(switch, 0.8)

                local knob = create("Frame", {
                    Parent = switch,
                    Position = UDim2.fromOffset(4, 4),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundColor3 = Library.Theme.Text,
                    BorderSizePixel = 0,
                    ZIndex = 7
                })
                addCorner(knob, 99)

                local hitbox = create("TextButton", {
                    Parent = toggleFrame,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 8
                })

                local function setToggle(newState, silent)
                    state = newState == true
                    Library.Flags[flag] = state

                    tween(toggleFrame, SOFT_TWEEN, {
                        BackgroundColor3 = state and Library.Theme.Surface or Library.Theme.Background
                    })
                    tween(toggleStroke, SOFT_TWEEN, {
                        Transparency = state and 0.7 or 0.84
                    })
                    tween(switch, SOFT_TWEEN, {
                        BackgroundColor3 = state and Library.Theme.Text or Library.Theme.Background
                    })
                    tween(switchStroke, SOFT_TWEEN, {
                        Transparency = state and 0.55 or 0.8
                    })
                    tween(knob, SOFT_TWEEN, {
                        Position = state and UDim2.new(1, -22, 0, 4) or UDim2.fromOffset(4, 4),
                        BackgroundColor3 = state and Library.Theme.Surface or Library.Theme.Text
                    })

                    if not silent then
                        safeCallback(toggleOptions.Callback, state)
                    end
                end

                local function refreshToggleHover(hovered, pressed)
                    local background = state and Library.Theme.Surface or Library.Theme.Background
                    local transparency = state and 0.7 or 0.84

                    if hovered and not state then
                        background = Library.Theme.Surface
                        transparency = pressed and 0.62 or 0.72
                    elseif hovered and state then
                        transparency = pressed and 0.56 or 0.64
                    end

                    tween(toggleFrame, FAST_TWEEN, {BackgroundColor3 = background})
                    tween(toggleStroke, FAST_TWEEN, {Transparency = transparency})
                end

                hitbox.MouseEnter:Connect(function()
                    refreshToggleHover(true, false)
                end)

                hitbox.MouseLeave:Connect(function()
                    refreshToggleHover(false, false)
                end)

                hitbox.MouseButton1Down:Connect(function()
                    refreshToggleHover(true, true)
                end)

                hitbox.MouseButton1Up:Connect(function()
                    refreshToggleHover(mouseInside(hitbox), false)
                end)

                hitbox.MouseButton1Click:Connect(function()
                    setToggle(not state, false)
                end)

                setToggle(state, true)

                return {
                    Set = function(_, newState)
                        setToggle(newState, false)
                    end,
                    Get = function()
                        return state
                    end
                }
            end

            function sectionObject:CreateSlider(sliderOptions)
                sliderOptions = sliderOptions or {}

                local minimum = sliderOptions.Min or 0
                local maximum = sliderOptions.Max or 100
                local increment = sliderOptions.Increment or 1
                local suffix = sliderOptions.Suffix or ""
                local flag = sliderOptions.Flag or sliderOptions.Text or ("Slider_" .. tostring(os.clock()))
                local value = roundToStep(sliderOptions.Default or minimum, minimum, maximum, increment)

                local sliderFrame, sliderStroke = createControlFrame(68, false)
                addPadding(sliderFrame, 14, 14, 10, 10)

                create("TextLabel", {
                    Parent = sliderFrame,
                    Position = UDim2.fromOffset(0, 0),
                    Size = UDim2.new(1, -70, 0, 18),
                    BackgroundTransparency = 1,
                    Text = sliderOptions.Text or "Slider",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 13,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local valueLabel = create("TextLabel", {
                    Parent = sliderFrame,
                    Position = UDim2.new(1, -70, 0, 0),
                    Size = UDim2.fromOffset(70, 18),
                    BackgroundTransparency = 1,
                    Text = "",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 6
                })

                local track = create("Frame", {
                    Parent = sliderFrame,
                    Position = UDim2.new(0, 0, 0, 34),
                    Size = UDim2.new(1, 0, 0, 10),
                    BackgroundColor3 = Library.Theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 6
                })
                addCorner(track, 99)
                local trackStroke = addStroke(track, 0.84)

                local fill = create("Frame", {
                    Parent = track,
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = Library.Theme.Text,
                    BorderSizePixel = 0,
                    ZIndex = 7
                })
                addCorner(fill, 99)

                local handle = create("Frame", {
                    Parent = track,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16),
                    BackgroundColor3 = Library.Theme.Text,
                    BorderSizePixel = 0,
                    ZIndex = 8
                })
                addCorner(handle, 99)
                local handleStroke = addStroke(handle, 0.7)

                local hitbox = create("TextButton", {
                    Parent = sliderFrame,
                    Position = UDim2.new(0, 0, 0, 26),
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 9
                })

                local draggingSlider = false

                local function renderSlider(rawValue, silent)
                    value = roundToStep(rawValue, minimum, maximum, increment)
                    Library.Flags[flag] = value

                    local denominator = (maximum - minimum)
                    local alpha = denominator == 0 and 0 or ((value - minimum) / denominator)
                    alpha = clamp(alpha, 0, 1)

                    valueLabel.Text = tostring(value) .. suffix

                    tween(fill, FAST_TWEEN, {Size = UDim2.new(alpha, 0, 1, 0)})
                    tween(handle, FAST_TWEEN, {Position = UDim2.new(alpha, 0, 0.5, 0)})

                    if not silent then
                        safeCallback(sliderOptions.Callback, value)
                    end
                end

                local function setFromInput(inputPositionX)
                    local relative = inputPositionX - track.AbsolutePosition.X
                    local alpha = clamp(relative / track.AbsoluteSize.X, 0, 1)
                    local rawValue = minimum + ((maximum - minimum) * alpha)
                    renderSlider(rawValue, false)
                end

                bindHover(hitbox, sliderFrame, sliderStroke, Library.Theme.Background, Library.Theme.Surface, Library.Theme.Background)

                hitbox.MouseButton1Down:Connect(function()
                    draggingSlider = true
                    tween(trackStroke, FAST_TWEEN, {Transparency = 0.62})
                    tween(handleStroke, FAST_TWEEN, {Transparency = 0.5})
                    setFromInput(UserInputService:GetMouseLocation().X)
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                        setFromInput(input.Position.X)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and draggingSlider then
                        draggingSlider = false
                        tween(trackStroke, FAST_TWEEN, {Transparency = 0.84})
                        tween(handleStroke, FAST_TWEEN, {Transparency = 0.7})
                    end
                end)

                renderSlider(value, true)

                return {
                    Set = function(_, newValue)
                        renderSlider(newValue, false)
                    end,
                    Get = function()
                        return value
                    end
                }
            end
            function sectionObject:CreateDropdown(dropdownOptions)
                dropdownOptions = dropdownOptions or {}

                local optionsList = dropdownOptions.Options or {}
                local flag = dropdownOptions.Flag or dropdownOptions.Text or ("Dropdown_" .. tostring(os.clock()))
                local selected = dropdownOptions.Default or optionsList[1]
                local isOpen = false

                local dropdownFrame, dropdownStroke = createControlFrame(48, false)
                addPadding(dropdownFrame, 14, 14, 10, 10)
                dropdownFrame.ClipsDescendants = true

                create("TextLabel", {
                    Parent = dropdownFrame,
                    Position = UDim2.fromOffset(0, 0),
                    Size = UDim2.new(1, -90, 0, 18),
                    BackgroundTransparency = 1,
                    Text = dropdownOptions.Text or "Dropdown",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 13,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local selectedLabel = create("TextLabel", {
                    Parent = dropdownFrame,
                    Position = UDim2.new(0, 0, 0, 18),
                    Size = UDim2.new(1, -28, 0, 16),
                    BackgroundTransparency = 1,
                    Text = tostring(selected or "None"),
                    TextColor3 = Library.Theme.Text,
                    TextTransparency = 0.2,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local arrow = create("TextLabel", {
                    Parent = dropdownFrame,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(20, 20),
                    BackgroundTransparency = 1,
                    Text = "v",
                    TextColor3 = Library.Theme.Text,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 6
                })

                local optionsHolder = create("Frame", {
                    Parent = dropdownFrame,
                    Position = UDim2.fromOffset(0, 48),
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundColor3 = Library.Theme.Surface,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 6
                })
                addCorner(optionsHolder, 12)
                local optionsStroke = addStroke(optionsHolder, 0.84)
                addPadding(optionsHolder, 8, 8, 8, 8)

                local optionsLayout = create("UIListLayout", {
                    Parent = optionsHolder,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 6)
                })

                local optionButtons = {}

                local function optionsHeight()
                    return math.min(optionsLayout.AbsoluteContentSize.Y + 16, 160)
                end

                local function setDropdown(newValue, silent)
                    selected = newValue
                    Library.Flags[flag] = selected
                    selectedLabel.Text = tostring(selected or "None")

                    for value, buttonData in pairs(optionButtons) do
                        local active = value == selected
                        tween(buttonData.Frame, FAST_TWEEN, {
                            BackgroundColor3 = active and Library.Theme.Background or Library.Theme.Surface
                        })
                        tween(buttonData.Stroke, FAST_TWEEN, {
                            Transparency = active and 0.58 or 0.84
                        })
                    end

                    if not silent then
                        safeCallback(dropdownOptions.Callback, selected)
                    end
                end

                local function refreshDropdownSize()
                    local expandedHeight = isOpen and optionsHeight() or 0
                    tween(optionsHolder, OPEN_TWEEN, {Size = UDim2.new(1, 0, 0, expandedHeight)})
                    tween(dropdownFrame, OPEN_TWEEN, {
                        Size = UDim2.new(1, 0, 0, 48 + expandedHeight + (isOpen and 10 or 0))
                    })
                    tween(arrow, FAST_TWEEN, {Rotation = isOpen and 180 or 0})
                    tween(optionsStroke, FAST_TWEEN, {Transparency = isOpen and 0.7 or 0.84})
                end

                local function rebuildOptions(newOptions)
                    for _, data in pairs(optionButtons) do
                        data.Frame:Destroy()
                    end
                    table.clear(optionButtons)

                    optionsList = newOptions or {}

                    for _, value in ipairs(optionsList) do
                        local optionButton = create("TextButton", {
                            Parent = optionsHolder,
                            Size = UDim2.new(1, 0, 0, 30),
                            BackgroundColor3 = Library.Theme.Surface,
                            BorderSizePixel = 0,
                            Text = tostring(value),
                            TextColor3 = Library.Theme.Text,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            AutoButtonColor = false,
                            ZIndex = 7
                        })
                        addCorner(optionButton, 10)
                        local optionStroke = addStroke(optionButton, 0.84)

                        local function refreshOptionVisual(hovered, pressed)
                            local active = selected == value
                            local background = active and Library.Theme.Background or Library.Theme.Surface
                            local transparency = active and 0.58 or 0.84

                            if hovered and not active then
                                background = Library.Theme.Background
                                transparency = pressed and 0.58 or 0.68
                            elseif hovered and active then
                                transparency = pressed and 0.5 or 0.56
                            end

                            tween(optionButton, FAST_TWEEN, {BackgroundColor3 = background})
                            tween(optionStroke, FAST_TWEEN, {Transparency = transparency})
                        end

                        optionButton.MouseEnter:Connect(function()
                            refreshOptionVisual(true, false)
                        end)

                        optionButton.MouseLeave:Connect(function()
                            refreshOptionVisual(false, false)
                        end)

                        optionButton.MouseButton1Down:Connect(function()
                            refreshOptionVisual(true, true)
                        end)

                        optionButton.MouseButton1Up:Connect(function()
                            refreshOptionVisual(mouseInside(optionButton), false)
                        end)

                        optionButton.MouseButton1Click:Connect(function()
                            setDropdown(value, false)
                            isOpen = false
                            refreshDropdownSize()
                        end)

                        optionButtons[value] = {
                            Frame = optionButton,
                            Stroke = optionStroke
                        }
                    end

                    if selected == nil and optionsList[1] ~= nil then
                        selected = optionsList[1]
                    end

                    setDropdown(selected, true)
                    refreshDropdownSize()
                end

                local hitbox = create("TextButton", {
                    Parent = dropdownFrame,
                    Size = UDim2.new(1, 0, 0, 48),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 8
                })

                bindHover(hitbox, dropdownFrame, dropdownStroke, Library.Theme.Background, Library.Theme.Surface, Library.Theme.Background)

                hitbox.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    refreshDropdownSize()
                end)

                optionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    if isOpen then
                        refreshDropdownSize()
                    end
                end)

                rebuildOptions(optionsList)

                return {
                    Set = function(_, newValue)
                        setDropdown(newValue, false)
                    end,
                    Get = function()
                        return selected
                    end,
                    SetOptions = function(_, newOptions, defaultValue)
                        selected = defaultValue
                        rebuildOptions(newOptions)
                    end
                }
            end

            return sectionObject
        end

        tabButton.MouseButton1Click:Connect(function()
            window:SelectTab(tabObject)
        end)

        table.insert(self.Tabs, tabObject)

        if not self.CurrentTab then
            self:SelectTab(tabObject)
        end

        return tabObject
    end

    return window
end

return Library
