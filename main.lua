--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.AnimationSpeed = 1
Library.ActivePopup = nil
Library.ThemeObjects = {}
Library.DynamicUpdates = {}
Library.Flags = {}
Library.WindowKeybind = nil
Library.WindowVisible = true
Library.MainFrame = nil
Library.Notifications = {}
Library.ConfigEnabled = false
Library.ConfigName = "SeraphConfig"
Library.NotificationQueue = {}
Library.Scale = 1
Library.MaxNotifications = 5
Library.CustomContainers = {}
Library.ViewportCache = {}
Library.NotificationContainer = nil
Library.MainFrameUIScale = nil
Library.MainFrameBuildScale = 1

-- Configuration
local Config = {
    Colors = {
        MainBg = Color3.fromRGB(17, 17, 22),
        PanelBg = Color3.fromRGB(24, 24, 30),
        SectionBg = Color3.fromRGB(19, 19, 24),
        ElementBg = Color3.fromRGB(15, 15, 19),
        Accent = Color3.fromRGB(218, 36, 155),
        TextMain = Color3.fromRGB(138, 138, 149),
        TextLight = Color3.fromRGB(231, 231, 235),
        Border = Color3.fromRGB(35, 35, 42),
        Separator = Color3.fromRGB(31, 24, 34),
        Success = Color3.fromRGB(67, 181, 129),
        Error = Color3.fromRGB(240, 71, 71),
        Warning = Color3.fromRGB(255, 193, 7)
    },
    Font = Font.new("rbxassetid://12187371840", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    TextSize = 12,
    ChevronImage = "rbxassetid://10709790948",
    PickerCursor = "rbxassetid://10709798174",
    CloseIcon = "rbxassetid://10709790948",
    FallbackTabIcon = "rbxassetid://10734962600"
}

-- Helper Functions
local function CreateTween(Time, Style, Direction)
    return TweenInfo.new(Time / Library.AnimationSpeed, Style or Enum.EasingStyle.Quad, Direction or Enum.EasingDirection.Out)
end

local function CreateInstance(Class, Properties, ThemeProps)
    local Inst = Instance.new(Class)
    for Key, Value in Properties do
        Inst[Key] = Value
    end
    if ThemeProps then
        for Prop, ColorKey in ThemeProps do
            Inst[Prop] = Config.Colors[ColorKey]
            table.insert(Library.ThemeObjects, {Inst, Prop, ColorKey})
        end
    end
    return Inst
end

local function Scale(Value)
    return math.floor(Value * Library.Scale)
end

local function GetBindText(Bind)
    if not Bind then return "None" end
    if Bind == Enum.UserInputType.MouseButton1 then return "MB1" end
    if Bind == Enum.UserInputType.MouseButton2 then return "MB2" end
    if Bind == Enum.UserInputType.MouseButton3 then return "MB3" end
    if typeof(Bind) == "EnumItem" then
        if Bind.Name == "MouseButton1" then return "MB1" end
        if Bind.Name == "MouseButton2" then return "MB2" end
        if Bind.Name == "MouseButton3" then return "MB3" end
        return Bind.Name
    end
    return "None"
end

local function MakeDraggable(TopBar, Object)
    local Dragging = nil
    local DragInput = nil
    local DragStart = nil
    local StartPosition = nil

    TopBar.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = Input.Position
            StartPosition = Object.Position

            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    TopBar.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
            DragInput = Input
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Input == DragInput and Dragging then
            local Delta = Input.Position - DragStart
            Object.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
        end
    end)
end

-- Config System with Serialization Support
function Library:EnableConfig(Name)
    Library.ConfigEnabled = true
    Library.ConfigName = Name or "SeraphConfig"
end

function Library:SaveConfig(Silent)
    if not Library.ConfigEnabled then return end

    local Data = {}
    for Flag, Func in pairs(Library.Flags) do
        if Func.GetValue then
            local Success, Value = pcall(function() return Func:GetValue() end)
            if Success then
                if Func.Serialize then
                    Data[Flag] = Func.Serialize(Value)
                else
                    Data[Flag] = Value
                end
            end
        end
    end

    local Encoded = HttpService:JSONEncode(Data)
    writefile(Library.ConfigName .. ".json", Encoded)
    if not Silent then
        Library:Notify("Configuration saved", 2, "Success")
    end
end

function Library:LoadConfig(Silent)
    if not Library.ConfigEnabled then return end

    if isfile(Library.ConfigName .. ".json") then
        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(readfile(Library.ConfigName .. ".json"))
        end)

        if Success and Decoded then
            for Flag, Value in pairs(Decoded) do
                if Library.Flags[Flag] then
                    if Library.Flags[Flag].Deserialize then
                        pcall(function() Library.Flags[Flag]:SetValue(Library.Flags[Flag].Deserialize(Value)) end)
                    elseif Library.Flags[Flag].SetValue then
                        pcall(function() Library.Flags[Flag]:SetValue(Value) end)
                    end
                end
            end
            if not Silent then
                Library:Notify("Configuration loaded", 2, "Success")
            end
        end
    end
end

-- Enhanced Confirmation Dialog with Custom Buttons
function Library:Confirm(Title, Message, Callback, Options)
    Options = Options or {}
    local Buttons = Options.Buttons or {{Text = "No", Color = Config.Colors.ElementBg, Result = false}, {Text = "Yes", Color = Config.Colors.Accent, Result = true}}

    local Dialog = CreateInstance("Frame", {
        Parent = Library.MainFrame,
        Size = UDim2.new(0, Scale(280), 0, Scale(130)),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 10000
    }, {BackgroundColor3 = "PanelBg"})

    CreateInstance("UICorner", {Parent = Dialog, CornerRadius = UDim.new(0, Scale(6))})
    CreateInstance("UIStroke", {Parent = Dialog, Thickness = 1}, {Color = "Accent"})

    local Backdrop = CreateInstance("Frame", {
        Parent = Library.MainFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 9999
    })

    CreateInstance("TextLabel", {
        Parent = Dialog,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Scale(26)),
        Position = UDim2.new(0, 0, 0, Scale(8)),
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
        Text = Title or "Confirm",
        TextSize = Scale(14),
        TextColor3 = Config.Colors.TextLight,
        ZIndex = 10001
    })

    CreateInstance("TextLabel", {
        Parent = Dialog,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, Scale(-16), 0, Scale(40)),
        Position = UDim2.new(0, Scale(8), 0, Scale(36)),
        FontFace = Config.Font,
        Text = Message or "Are you sure?",
        TextSize = Scale(11),
        TextColor3 = Config.Colors.TextMain,
        TextWrapped = true,
        ZIndex = 10001
    })

    local ButtonFrame = CreateInstance("Frame", {
        Parent = Dialog,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, Scale(-16), 0, Scale(30)),
        Position = UDim2.new(0, Scale(8), 1, Scale(-38)),
        ZIndex = 10001
    })

    CreateInstance("UIListLayout", {
        Parent = ButtonFrame,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, Scale(8))
    })

    for _, BtnData in ipairs(Buttons) do
        local Btn = CreateInstance("TextButton", {
            Parent = ButtonFrame,
            Size = UDim2.new(1 / #Buttons, Scale(-8), 1, 0),
            BackgroundColor3 = BtnData.Color or Config.Colors.ElementBg,
            BorderSizePixel = 0,
            Text = BtnData.Text or "Button",
            FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
            TextSize = Scale(12),
            TextColor3 = Config.Colors.TextLight,
            ZIndex = 10002
        })
        CreateInstance("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, Scale(5))})

        Btn.MouseEnter:Connect(function()
            TweenService:Create(Btn, CreateTween(0.2), {BackgroundColor3 = (BtnData.Color or Config.Colors.ElementBg):Lerp(Config.Colors.TextLight, 0.2)}):Play()
        end)
        Btn.MouseLeave:Connect(function()
            TweenService:Create(Btn, CreateTween(0.2), {BackgroundColor3 = BtnData.Color or Config.Colors.ElementBg}):Play()
        end)

        Btn.MouseButton1Click:Connect(function()
            TweenService:Create(Dialog, CreateTween(0.2), {GroupTransparency = 1}):Play()
            TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
            task.wait(0.2)
            Dialog:Destroy()
            Backdrop:Destroy()
            if Callback then Callback(BtnData.Result) end
        end)
    end

    return Dialog
end

-- Notification System with Queue Limit
function Library:Notify(Message, Duration, Type)
    Type = Type or "Info"
    Duration = Duration or 3

    if not Library.NotificationContainer then
        local NotificationParent = Library.MainFrame and Library.MainFrame.Parent or game.CoreGui
        Library.NotificationContainer = CreateInstance("Frame", {
            Name = "NotificationContainer",
            Parent = NotificationParent,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, Scale(14)),
            Size = UDim2.new(0, Scale(320), 1, 0),
            BorderSizePixel = 0,
            ZIndex = 4999
        })

        CreateInstance("UIListLayout", {
            Parent = Library.NotificationContainer,
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, Scale(6))
        })
    end

    local function dismissNotification(notificationGui)
        if not notificationGui or notificationGui:GetAttribute("Closing") then return end
        notificationGui:SetAttribute("Closing", true)

        local outTween = TweenService:Create(notificationGui, CreateTween(0.2), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        outTween:Play()
        outTween.Completed:Wait()

        local idx = table.find(Library.Notifications, notificationGui)
        if idx then
            table.remove(Library.Notifications, idx)
        end

        if notificationGui.Parent then
            notificationGui:Destroy()
        end
    end

    -- Check queue limit
    if #Library.Notifications >= Library.MaxNotifications then
        local oldest = table.remove(Library.Notifications, 1)
        if oldest then
            pcall(function()
                dismissNotification(oldest)
            end)
        end
    end

    local NotificationGui = CreateInstance("Frame", {
        Name = "Notification",
        Parent = Library.NotificationContainer,
        Size = UDim2.new(1, 0, 0, Scale(0)),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 5000,
        Visible = false
    }, {BackgroundColor3 = "PanelBg"})
    NotificationGui:SetAttribute("Closing", false)

    CreateInstance("UICorner", {Parent = NotificationGui, CornerRadius = UDim.new(0, Scale(5))})
    CreateInstance("UIStroke", {Parent = NotificationGui, Thickness = 1}, {Color = "Border"})

    local ColorMap = {
        Info = "Accent",
        Success = "Success",
        Error = "Error",
        Warning = "Warning"
    }

    CreateInstance("Frame", {
        Parent = NotificationGui,
        Size = UDim2.new(0, Scale(3), 1, 0),
        BorderSizePixel = 0
    }, {BackgroundColor3 = ColorMap[Type] or "Accent"})

    CreateInstance("TextLabel", {
        Parent = NotificationGui,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, Scale(-16), 0, Scale(50)),
        Position = UDim2.new(0, Scale(12), 0, 0),
        FontFace = Config.Font,
        TextSize = Scale(11),
        Text = Message,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true
    }, {TextColor3 = "TextLight"})

    table.insert(Library.Notifications, NotificationGui)

    NotificationGui.Visible = true
    local InTween = TweenService:Create(NotificationGui, CreateTween(0.2), {Size = UDim2.new(1, 0, 0, Scale(50))})
    InTween:Play()

    task.delay(Duration, function()
        pcall(function()
            dismissNotification(NotificationGui)
        end)
    end)
end

function Library:ClosePopups()
    if Library.ActivePopup then
        if Library.ActivePopup.Close then
            Library.ActivePopup.Close()
        end
        Library.ActivePopup = nil
    end
end

function Library:SetTheme(NewColors)
    for Key, Value in NewColors do
        if Config.Colors[Key] then
            Config.Colors[Key] = Value
        end
    end
    for _, ObjData in Library.ThemeObjects do
        local Instance, Prop, ColorKey = ObjData[1], ObjData[2], ObjData[3]
        if Instance and Instance.Parent then
            Instance[Prop] = Config.Colors[ColorKey]
        end
    end
    for _, Func in Library.DynamicUpdates do
        Func()
    end
end

function Library:GetTheme()
    local ThemeCopy = {}
    for Key, Value in Config.Colors do
        ThemeCopy[Key] = Value
    end
    return ThemeCopy
end

function Library:SetAnimationSpeed(NewSpeed)
    Library.AnimationSpeed = NewSpeed
end

function Library:SetScale(NewScale)
    local targetScale = tonumber(NewScale) or 1
    Library.Scale = targetScale

    if Library.MainFrameUIScale then
        local buildScale = Library.MainFrameBuildScale or 1
        Library.MainFrameUIScale.Scale = targetScale / buildScale
    end
end

function Library:SetWindowKeybind(KeyCode)
    Library.WindowKeybind = KeyCode
end

function Library:SetMaxNotifications(Max)
    Library.MaxNotifications = Max or 5
end

-- Input Handling
UserInputService.InputBegan:Connect(function(Input, Processed)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        if Library.ActivePopup and Library.ActivePopup.Element then
            local Ele = Library.ActivePopup.Element
            local Mx, My = Input.Position.X, Input.Position.Y
            local Px, Py = Ele.AbsolutePosition.X, Ele.AbsolutePosition.Y
            local Sx, Sy = Ele.AbsoluteSize.X, Ele.AbsoluteSize.Y

            if Mx < Px or Mx > Px + Sx or My < Py or My > Py + Sy then
                local InIgnore = false
                if Library.ActivePopup.Ignore then
                    for _, Ignore in Library.ActivePopup.Ignore do
                        local Ix, Iy = Ignore.AbsolutePosition.X, Ignore.AbsolutePosition.Y
                        local Isx, Isy = Ignore.AbsoluteSize.X, Ignore.AbsoluteSize.Y
                        if Mx >= Ix and Mx <= Ix + Isx and My >= Iy and My <= Iy + Isy then
                            InIgnore = true
                            break
                        end
                    end
                end
                if not InIgnore then
                    Library:ClosePopups()
                end
            end
        end
    end

    if not Processed and Library.WindowKeybind and Input.KeyCode == Library.WindowKeybind and Library.MainFrame then
        Library.WindowVisible = not Library.WindowVisible
        if Library.WindowVisible then
            Library.MainFrame.Visible = true
            TweenService:Create(Library.MainFrame, CreateTween(0.2), {GroupTransparency = 0}):Play()
            local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
            if Stroke then
                TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 0}):Play()
            end
        else
            local Tween = TweenService:Create(Library.MainFrame, CreateTween(0.2), {GroupTransparency = 1})
            local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
            if Stroke then
                TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 1}):Play()
            end
            Tween:Play()
            task.spawn(function()
                Tween.Completed:Wait()
                if not Library.WindowVisible then
                    Library.MainFrame.Visible = false
                end
            end)
        end
    end
end)

-- Main Window Function with Enhanced Features
function Library:Window(TitleOrIcon, WindowScale)
    Library.Scale = WindowScale or 1
    Library.MainFrameBuildScale = Library.Scale

    local ScreenGui = CreateInstance("ScreenGui", {
        Name = "Seraph",
        Parent = game.CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true
    })

    local MainFrame = CreateInstance("CanvasGroup", {
        Name = "MainFrame",
        Parent = ScreenGui,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, Scale(750), 0, Scale(500)),
        GroupTransparency = 0,
        ClipsDescendants = true
    }, {BackgroundColor3 = "PanelBg"})

    local SizeConstraint = CreateInstance("UISizeConstraint", {
        Parent = MainFrame,
        MaxSize = Vector2.new(Scale(900), Scale(650)),
        MinSize = Vector2.new(Scale(350), Scale(250))
    })

    Library.MainFrame = MainFrame
    Library.MainFrameUIScale = CreateInstance("UIScale", {
        Parent = MainFrame,
        Scale = 1
    })
    CreateInstance("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, Scale(6))})
    local MainStroke = CreateInstance("UIStroke", {Parent = MainFrame, Thickness = 1, Name = "UIStroke"}, {Color = "MainBg"})

    -- TopBar
    local TopBar = CreateInstance("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Scale(40)),
        ClipsDescendants = true
    }, {BackgroundColor3 = "MainBg"})

    MakeDraggable(TopBar, MainFrame)

    -- Title/Icon with fallback handling
    local IconImg = nil
    local TitleLabel = nil
    if tostring(TitleOrIcon):find("rbxassetid") then
        IconImg = CreateInstance("ImageLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, Scale(26), 0, Scale(26)),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, Scale(12), 0.5, 0),
            Image = TitleOrIcon,
            ScaleType = Enum.ScaleType.Fit
        }, {ImageColor3 = "Accent"})

        -- Fallback for failed image load
        local function checkIcon()
            if IconImg.Image ~= Config.FallbackTabIcon and IconImg.IsLoaded and IconImg.ImageRectSize == Vector2.zero then
                IconImg.Image = Config.FallbackTabIcon
            end
        end
        
        checkIcon()
        IconImg:GetPropertyChangedSignal("IsLoaded"):Connect(checkIcon)        
    else
        TitleLabel = CreateInstance("TextLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, Scale(16), 0, 0),
            Size = UDim2.new(1, Scale(-96), 1, 0),
            FontFace = Config.Font,
            Text = tostring(TitleOrIcon or "Library"),
            TextSize = Scale(16),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ClipsDescendants = true
        }, {TextColor3 = "Accent"})
    end

    -- Window Controls
    local MinimizeButton = CreateInstance("TextButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, Scale(28), 0, Scale(28)),
        Position = UDim2.new(1, Scale(-72), 0, Scale(6)),
        Text = "−",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextSize = Scale(20),
        AutoButtonColor = false
    }, {TextColor3 = "TextMain"})

    CreateInstance("UICorner", {Parent = MinimizeButton, CornerRadius = UDim.new(0, Scale(5))})

    local CloseButton = CreateInstance("TextButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, Scale(28), 0, Scale(28)),
        Position = UDim2.new(1, Scale(-38), 0, Scale(6)),
        Text = "X",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextSize = Scale(14),
        AutoButtonColor = false
    }, {TextColor3 = "TextMain"})

    CreateInstance("UICorner", {Parent = CloseButton, CornerRadius = UDim.new(0, Scale(5))})

    local Body = CreateInstance("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, Scale(40)),
        Size = UDim2.new(1, 0, 1, Scale(-40)),
        Name = "Body"
    })

    local TabContainer

    -- Window controls logic
    local IsMinimized = false
    local PreMinimizeSize = nil
    local PreMinimizePosition = nil

    local function SetMinimizedState(Minimized)
        IsMinimized = Minimized

        if Minimized then
            PreMinimizeSize = MainFrame.Size
            PreMinimizePosition = MainFrame.Position
            SizeConstraint.MinSize = Vector2.new(Scale(220), Scale(40))
            local minimizedWidth = Scale(220)

            TweenService:Create(MainFrame, CreateTween(0.2), {
                Size = UDim2.new(0, minimizedWidth, 0, Scale(40))
            }):Play()

            task.delay(0.2, function()
                if IsMinimized then
                    Body.Visible = false
                    if TabContainer then
                        TabContainer.Visible = false
                    end
                    if TitleLabel then
                        TitleLabel.Size = UDim2.new(1, Scale(-78), 1, 0)
                    end
                end
            end)

            MinimizeButton.Text = "+"
            return
        end

        Body.Visible = true
        if TabContainer then
            TabContainer.Visible = true
        end
        if TitleLabel then
            TitleLabel.Size = UDim2.new(1, Scale(-96), 1, 0)
        end

        TweenService:Create(MainFrame, CreateTween(0.2), {
            Size = PreMinimizeSize or UDim2.new(0, Scale(750), 0, Scale(500)),
            Position = PreMinimizePosition or MainFrame.Position
        }):Play()

        task.delay(0.2, function()
            SizeConstraint.MinSize = Vector2.new(Scale(350), Scale(250))
        end)

        MinimizeButton.Text = "−"
    end

    MinimizeButton.MouseEnter:Connect(function()
        TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.ElementBg, TextColor3 = Config.Colors.TextLight}):Play()
    end)

    MinimizeButton.MouseLeave:Connect(function()
        TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
    end)

    MinimizeButton.MouseButton1Click:Connect(function()
        SetMinimizedState(not IsMinimized)
    end)

    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.Error, TextColor3 = Color3.fromRGB(255,255,255)}):Play()
    end)

    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
    end)

    CloseButton.MouseButton1Click:Connect(function()
        if Library.CloseCallback then
            local ok, handled = pcall(Library.CloseCallback)
            if ok and handled then
                return
            end
        end
        local Tween = TweenService:Create(MainFrame, CreateTween(0.3), {GroupTransparency = 1})
        local StrokeTween = TweenService:Create(MainStroke, CreateTween(0.3), {Transparency = 1})
        Tween:Play()
        StrokeTween:Play()
        Tween.Completed:Wait()
        MainFrame.Visible = false
        Library.WindowVisible = false
        MainStroke.Transparency = 0
    end)

    -- TabContainer
    TabContainer = CreateInstance("Frame", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, Scale(-76), 0.5, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X
    })

    CreateInstance("UIListLayout", {
        Parent = TabContainer,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, Scale(4))
    })

    -- Sidebar
    local SidebarArea = CreateInstance("Frame", {
        Parent = Body,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, Scale(10), 0, Scale(10)),
        Size = UDim2.new(0, Scale(120), 1, Scale(-20))
    })

    CreateInstance("TextLabel", {
        Parent = SidebarArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Scale(16)),
        FontFace = Config.Font,
        Text = "CATEGORIES",
        TextSize = Scale(10),
        TextXAlignment = Enum.TextXAlignment.Left
    }, {TextColor3 = "TextMain"})

    local SidebarList = CreateInstance("ScrollingFrame", {
        Parent = SidebarArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, Scale(20)),
        Size = UDim2.new(1, 0, 1, Scale(-20)),
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })

    CreateInstance("UIListLayout", {Parent = SidebarList, Padding = UDim.new(0, Scale(6))})

    -- Content Area
    local ContentArea = CreateInstance("Frame", {
        Parent = Body,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, Scale(140), 0, Scale(10)),
        Size = UDim2.new(1, Scale(-155), 1, Scale(-20))
    })

    CreateInstance("TextLabel", {
        Parent = ContentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Scale(16)),
        FontFace = Config.Font,
        Text = "FEATURES",
        TextSize = Scale(10),
        TextXAlignment = Enum.TextXAlignment.Left
    }, {TextColor3 = "TextMain"})

    local SectionContainer = CreateInstance("ScrollingFrame", {
        Parent = ContentArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, Scale(20)),
        Size = UDim2.new(1, 0, 1, Scale(-20)),
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, {ScrollBarImageColor3 = "Border"})

    CreateInstance("UIListLayout", {Parent = SectionContainer, Padding = UDim.new(0, Scale(6))})

    local ContentFadeOverlay = CreateInstance("Frame", {
        Parent = ContentArea,
        Name = "ContentFadeOverlay",
        Size = UDim2.new(1, 0, 1, Scale(-20)),
        Position = UDim2.new(0, 0, 0, Scale(20)),
        ZIndex = 1000,
        BackgroundTransparency = 1,
        Visible = false,
        BorderSizePixel = 0
    }, {BackgroundColor3 = "PanelBg"})

    local TabFadeOverlay = CreateInstance("Frame", {
        Parent = Body,
        Name = "TabFadeOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ZIndex = 2000,
        BackgroundTransparency = 1,
        Visible = false,
        BorderSizePixel = 0
    }, {BackgroundColor3 = "PanelBg"})

    local WindowFunctions = {}
    local FirstTab = true
    local CurrentActiveSections = nil
    local IsAnimatingTab = false
    local AllTabs = {} -- Track all tabs for visibility

    function WindowFunctions:AddTab(IconAsset)
        local TabButton = CreateInstance("ImageButton", {
            Parent = TabContainer,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, Scale(28), 0, Scale(28)),
            Image = "",
            AutoButtonColor = false,
            Visible = true  -- Ensure visibility
        }, {BackgroundColor3 = "PanelBg"})

        CreateInstance("UICorner", {Parent = TabButton, CornerRadius = UDim.new(0, Scale(5))})

        local IconImg = CreateInstance("ImageLabel", {
            Parent = TabButton,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, Scale(18), 0, Scale(18)),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Image = IconAsset[1] or Config.FallbackTabIcon
        }, {ImageColor3 = "TextMain"})

        -- Fallback handling for tab icons
        local function checkIcon()
            if IconImg.Image ~= Config.FallbackTabIcon and IconImg.IsLoaded and IconImg.ImageRectSize == Vector2.zero then
                IconImg.Image = Config.FallbackTabIcon
            end
        end
        
        checkIcon()
        IconImg:GetPropertyChangedSignal("IsLoaded"):Connect(checkIcon)        

        table.insert(AllTabs, TabButton)

        local TabFunctions = {}
        local Categories = {}
        local TabSubCategories = {}
        local IsThisTabActive = FirstTab
        local TabFirstSubCategory = true
        local ActiveSubAction = nil

        table.insert(Library.DynamicUpdates, function()
            if IsThisTabActive then
                IconImg.ImageColor3 = Config.Colors.TextLight
                TabButton.BackgroundTransparency = 0.9
            else
                IconImg.ImageColor3 = Config.Colors.TextMain
                TabButton.BackgroundTransparency = 1
            end
        end)

        local function ActivateTab()
            if IsAnimatingTab then return end
            Library:ClosePopups()

            for _, Btn in ipairs(AllTabs) do
                if Btn:IsA("ImageButton") then
                    TweenService:Create(Btn, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
                    local InnerIcon = Btn:FindFirstChild("ImageLabel")
                    if InnerIcon then
                        TweenService:Create(InnerIcon, CreateTween(0.2), {ImageColor3 = Config.Colors.TextMain}):Play()
                    end
                end
            end

            TweenService:Create(TabButton, CreateTween(0.2), {BackgroundTransparency = 0.9}):Play()
            TweenService:Create(IconImg, CreateTween(0.2), {ImageColor3 = Config.Colors.TextLight}):Play()

            task.spawn(function()
                IsAnimatingTab = true
                TabFadeOverlay.Visible = true

                local OutTween = TweenService:Create(TabFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 0})
                OutTween:Play()
                OutTween.Completed:Wait()

                for _, Child in SidebarList:GetChildren() do
                    if Child:IsA("Frame") then
                        Child.Visible = false
                    end
                end

                for _, Cat in Categories do
                    Cat.Visible = true
                end

                if ActiveSubAction then
                    ActiveSubAction(true)
                else
                    for _, Child in SectionContainer:GetChildren() do
                        if Child:IsA("Frame") then
                            Child.Visible = false
                        end
                    end
                end

                local InTween = TweenService:Create(TabFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 1})
                InTween:Play()
                InTween.Completed:Wait()

                TabFadeOverlay.Visible = false
                IsAnimatingTab = false
            end)
        end

        TabButton.MouseButton1Click:Connect(ActivateTab)

        if FirstTab then
            FirstTab = false
            IconImg.ImageColor3 = Config.Colors.TextLight
            TabButton.BackgroundTransparency = 0.9
        end

        function TabFunctions:AddCategory(CatName)
            local CategoryFrame = CreateInstance("Frame", {
                Parent = SidebarList,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = IsThisTabActive,
                BorderSizePixel = 0
            }, {BackgroundColor3 = "SectionBg"})

            CreateInstance("UICorner", {Parent = CategoryFrame, CornerRadius = UDim.new(0, Scale(5))})
            CreateInstance("UIStroke", {Parent = CategoryFrame, Thickness = 1}, {Color = "Border"})
            table.insert(Categories, CategoryFrame)

            local CatHeader = CreateInstance("TextButton", {
                Parent = CategoryFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, Scale(28)),
                FontFace = Config.Font,
                Text = " " .. CatName,
                TextSize = Scale(11),
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false
            }, {TextColor3 = "TextLight"})

            local CatIcon = CreateInstance("ImageLabel", {
                Parent = CatHeader,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, Scale(14), 0, Scale(14)),
                Position = UDim2.new(1, Scale(-20), 0.5, Scale(-7)),
                Image = Config.ChevronImage,
                Rotation = 0
            }, {ImageColor3 = "TextMain"})

            local SubCatContainer = CreateInstance("Frame", {
                Parent = CategoryFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, Scale(28)),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                ClipsDescendants = true,
                Visible = true
            })

            CreateInstance("UIListLayout", {Parent = SubCatContainer, Padding = UDim.new(0, Scale(2))})
            CreateInstance("UIPadding", {
                Parent = SubCatContainer,
                PaddingBottom = UDim.new(0, Scale(4)),
                PaddingLeft = UDim.new(0, Scale(4)),
                PaddingRight = UDim.new(0, Scale(4))
            })

            local CatOpen = true
            CatHeader.MouseButton1Click:Connect(function()
                CatOpen = not CatOpen
                SubCatContainer.Visible = CatOpen
                TweenService:Create(CatIcon, CreateTween(0.2), {Rotation = CatOpen and 0 or -90}):Play()
            end)

            local CategoryFunctions = {}

            function CategoryFunctions:AddSubCategory(SubCatName)
                local SubButton = CreateInstance("TextButton", {
                    Parent = SubCatContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, Scale(24)),
                    FontFace = Config.Font,
                    Text = " " .. SubCatName,
                    TextSize = Scale(11),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false
                }, {TextColor3 = "TextMain"})

                CreateInstance("UICorner", {Parent = SubButton, CornerRadius = UDim.new(0, Scale(3))})

                local ActiveBorder = CreateInstance("Frame", {
                    Parent = SubButton,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, Scale(2), 1, 0),
                    Visible = false
                }, {BackgroundColor3 = "Accent"})

                local SubFunctions = {}
                local AssociatedSections = {}
                local SubState = {bIsActive = false, oButton = SubButton, oActiveBorder = ActiveBorder}
                table.insert(TabSubCategories, SubState)

                table.insert(Library.DynamicUpdates, function()
                    if SubState.bIsActive then
                        SubButton.TextColor3 = Config.Colors.TextLight
                        SubButton.BackgroundTransparency = 0.9
                        SubButton.BackgroundColor3 = Color3.new(1,1,1)
                        ActiveBorder.Visible = true
                    else
                        SubButton.TextColor3 = Config.Colors.TextMain
                        SubButton.BackgroundTransparency = 1
                        ActiveBorder.Visible = false
                    end
                end)

                local function SelectSubCategory(NoFade)
                    Library:ClosePopups()
                    ActiveSubAction = SelectSubCategory
                    CurrentActiveSections = AssociatedSections

                    for _, State in TabSubCategories do
                        State.bIsActive = false
                        TweenService:Create(State.oButton, CreateTween(0.2), {
                            BackgroundTransparency = 1,
                            TextColor3 = Config.Colors.TextMain
                        }):Play()
                        State.oActiveBorder.Visible = false
                    end

                    SubState.bIsActive = true
                    TweenService:Create(SubButton, CreateTween(0.2), {
                        BackgroundTransparency = 0.9,
                        BackgroundColor3 = Color3.new(1,1,1),
                        TextColor3 = Config.Colors.TextLight
                    }):Play()
                    ActiveBorder.Visible = true

                    if not NoFade then
                        task.spawn(function()
                            ContentFadeOverlay.Visible = true
                            local OutTween = TweenService:Create(ContentFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 0})
                            OutTween:Play()
                            OutTween.Completed:Wait()

                            if CurrentActiveSections == AssociatedSections then
                                for _, Child in SectionContainer:GetChildren() do
                                    if Child:IsA("Frame") then
                                        Child.Visible = false
                                    end
                                end
                                for _, Section in AssociatedSections do
                                    Section.Visible = true
                                end
                                local InTween = TweenService:Create(ContentFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 1})
                                InTween:Play()
                                InTween.Completed:Wait()
                                if CurrentActiveSections == AssociatedSections then
                                    ContentFadeOverlay.Visible = false
                                end
                            end
                        end)
                    else
                        ContentFadeOverlay.Visible = false
                        for _, Child in SectionContainer:GetChildren() do
                            if Child:IsA("Frame") then
                                Child.Visible = false
                            end
                        end
                        for _, Section in AssociatedSections do
                            Section.Visible = true
                        end
                    end
                end

                SubButton.MouseButton1Click:Connect(function() SelectSubCategory(false) end)

                if TabFirstSubCategory then
                    ActiveSubAction = SelectSubCategory
                    TabFirstSubCategory = false
                    if IsThisTabActive then
                        SelectSubCategory(true)
                    end
                end

                function SubFunctions:AddSection(SectionName)
                    local SectionFrame = CreateInstance("Frame", {
                        Parent = SectionContainer,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Visible = false,
                        BorderSizePixel = 0
                    }, {BackgroundColor3 = "SectionBg"})

                    CreateInstance("UICorner", {Parent = SectionFrame, CornerRadius = UDim.new(0, Scale(5))})
                    CreateInstance("UIStroke", {Parent = SectionFrame, Thickness = 1}, {Color = "Border"})
                    table.insert(AssociatedSections, SectionFrame)

                    if SubState.bIsActive then
                        SectionFrame.Visible = true
                    end

                    -- Viewport cleanup on section hide
                    SectionFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                        if not SectionFrame.Visible then
                            -- Pause expensive operations when hidden
                            for _, child in ipairs(SectionFrame:GetDescendants()) do
                                if child:IsA("ViewportFrame") then
                                    child.Visible = false
                                end
                            end
                        else
                            for _, child in ipairs(SectionFrame:GetDescendants()) do
                                if child:IsA("ViewportFrame") then
                                    child.Visible = true
                                end
                            end
                        end
                    end)

                    local HeaderContainer = CreateInstance("Frame", {
                        Parent = SectionFrame,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, Scale(28)),
                        BorderSizePixel = 0
                    })

                    local HeaderBtn = CreateInstance("TextButton", {
                        Parent = HeaderContainer,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        Text = " " .. SectionName,
                        FontFace = Config.Font,
                        TextSize = Scale(11),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false
                    }, {TextColor3 = "TextMain"})

                    local SecIcon = CreateInstance("ImageLabel", {
                        Parent = HeaderBtn,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, Scale(14), 0, Scale(14)),
                        Position = UDim2.new(1, Scale(-20), 0.5, Scale(-7)),
                        Image = Config.ChevronImage,
                        Rotation = 0
                    }, {ImageColor3 = "TextMain"})

                    CreateInstance("Frame", {
                        Parent = SectionFrame,
                        BorderSizePixel = 0,
                        Position = UDim2.new(0,0,0,Scale(28)),
                        Size = UDim2.new(1, 0, 0, 1)
                    }, {BackgroundColor3 = "Separator"})

                    local ElementsContainer = CreateInstance("Frame", {
                        Parent = SectionFrame,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 0, 0, Scale(32)),
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        ClipsDescendants = false
                    })

                    CreateInstance("UIListLayout", {Parent = ElementsContainer, Padding = UDim.new(0, Scale(6))})
                    CreateInstance("UIPadding", {
                        Parent = SectionFrame,
                        PaddingBottom = UDim.new(0, Scale(8)),
                        PaddingLeft = UDim.new(0, Scale(8)),
                        PaddingRight = UDim.new(0, Scale(8))
                    })

                    local SecOpen = true
                    HeaderBtn.MouseButton1Click:Connect(function()
                        SecOpen = not SecOpen
                        ElementsContainer.Visible = SecOpen
                        TweenService:Create(SecIcon, CreateTween(0.2), {Rotation = SecOpen and 0 or -90}):Play()
                    end)

                    local SectionFunctions = {}
                    local SearchBox = nil

                    -- AddCustomContainer method
                    function SectionFunctions:AddCustomContainer(Properties)
                        local Container = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = Properties.BackgroundTransparency or 1,
                            Size = Properties.Size or UDim2.new(1, 0, 0, 200),
                            AutomaticSize = Properties.AutomaticSize or Enum.AutomaticSize.None,
                            BorderSizePixel = 0
                        })

                        if Properties.Border then
                            CreateInstance("UIStroke", {
                                Parent = Container,
                                Thickness = Properties.Border.Thickness or 1,
                                Color = Properties.Border.Color or Config.Colors.Border
                            })
                        end

                        if Properties.CornerRadius then
                            CreateInstance("UICorner", {
                                Parent = Container,
                                CornerRadius = UDim.new(0, Properties.CornerRadius)
                            })
                        end

                        table.insert(Library.CustomContainers, Container)
                        return Container
                    end

                    -- BUTTON - Compact
                    function SectionFunctions:Button(Props)
                        local ButtonFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(26))
                        })

                        CreateInstance("UIListLayout", {
                            Parent = ButtonFrame,
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            Padding = UDim.new(0, Scale(4))
                        })

                        local ButtonsInGroup = {}
                        local ButtonFunctions = {}

                        local function AddButton(BtnProps)
                            local Btn = CreateInstance("TextButton", {
                                Parent = ButtonFrame,
                                BorderSizePixel = 0,
                                FontFace = Config.Font,
                                Text = BtnProps.Title,
                                TextSize = Scale(11),
                                AutoButtonColor = false
                            }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextMain"})

                            CreateInstance("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, Scale(4))})
                            local Stroke = CreateInstance("UIStroke", {Parent = Btn, Thickness = 1}, {Color = "Border"})

                            Btn.MouseEnter:Connect(function()
                                TweenService:Create(Btn, CreateTween(0.15), {TextColor3 = Config.Colors.TextLight}):Play()
                                TweenService:Create(Stroke, CreateTween(0.15), {Color = Config.Colors.Accent}):Play()
                            end)

                            Btn.MouseLeave:Connect(function()
                                TweenService:Create(Btn, CreateTween(0.15), {TextColor3 = Config.Colors.TextMain}):Play()
                                TweenService:Create(Stroke, CreateTween(0.15), {Color = Config.Colors.Border}):Play()
                            end)

                            Btn.MouseButton1Click:Connect(function()
                                local ClickTween = TweenService:Create(Btn, CreateTween(0.1), {BackgroundColor3 = Config.Colors.SectionBg})
                                ClickTween:Play()
                                ClickTween.Completed:Wait()
                                TweenService:Create(Btn, CreateTween(0.1), {BackgroundColor3 = Config.Colors.ElementBg}):Play()
                                if BtnProps.Callback then
                                    BtnProps.Callback()
                                end
                            end)

                            table.insert(ButtonsInGroup, Btn)

                            local TotalPadding = (#ButtonsInGroup - 1) * Scale(4)
                            local Offset = - (TotalPadding / #ButtonsInGroup)

                            for _, B in ButtonsInGroup do
                                B.Size = UDim2.new(1 / #ButtonsInGroup, Offset, 1, 0)
                            end

                            if BtnProps.Flag then
                                Library.Flags[BtnProps.Flag] = {
                                    SetValue = function(_, Val) Btn.Text = tostring(Val) end,
                                    GetValue = function() return Btn.Text end
                                }
                            end

                            return ButtonFunctions
                        end

                        function ButtonFunctions:Button(NewProps)
                            return AddButton(NewProps)
                        end

                        function ButtonFunctions:SetValue(Val)
                            ButtonsInGroup[1].Text = tostring(Val)
                        end

                        function ButtonFunctions:GetValue()
                            return ButtonsInGroup[1].Text
                        end

                        return AddButton(Props)
                    end

                    -- LABEL - Compact
                    function SectionFunctions:Label(Props)
                        local LabelFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(18))
                        })

                        local Title = CreateInstance("TextLabel", {
                            Parent = LabelFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 1, 0)
                        }, {TextColor3 = "TextMain"})

                        local LabelFunctions = {}
                        function LabelFunctions:SetValue(Val) Title.Text = tostring(Val) end
                        function LabelFunctions:GetValue() return Title.Text end

                        if Props.Flag then Library.Flags[Props.Flag] = LabelFunctions end
                        return LabelFunctions
                    end

                    -- TEXT INPUT - Compact
                    function SectionFunctions:Input(Props)
                        local InputFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(38))
                        })

                        CreateInstance("TextLabel", {
                            Parent = InputFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title or "Input",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextMain"})

                        local BoxContainer = CreateInstance("Frame", {
                            Parent = InputFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(16)),
                            Size = UDim2.new(1, 0, 0, Scale(22))
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = BoxContainer, CornerRadius = UDim.new(0, Scale(4))})
                        local BoxStroke = CreateInstance("UIStroke", {Parent = BoxContainer, Thickness = 1}, {Color = "Border"})

                        local TextBox = CreateInstance("TextBox", {
                            Parent = BoxContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, Scale(-10), 1, 0),
                            Position = UDim2.new(0, Scale(5), 0, 0),
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            Text = Props.Default or "",
                            PlaceholderText = Props.Placeholder or "Enter text...",
                            ClearTextOnFocus = false
                        }, {TextColor3 = "TextLight", PlaceholderColor3 = "TextMain"})

                        TextBox.Focused:Connect(function()
                            TweenService:Create(BoxStroke, CreateTween(0.2), {Color = Config.Colors.Accent}):Play()
                        end)

                        TextBox.FocusLost:Connect(function(EnterPressed)
                            TweenService:Create(BoxStroke, CreateTween(0.2), {Color = Config.Colors.Border}):Play()
                            if Props.Callback then
                                Props.Callback(TextBox.Text, EnterPressed)
                            end
                        end)

                        local InputFunctions = {}
                        function InputFunctions:SetValue(Val)
                            TextBox.Text = tostring(Val)
                            if Props.Callback then
                                Props.Callback(TextBox.Text, false)
                            end
                        end
                        function InputFunctions:GetValue() return TextBox.Text end

                        if Props.Flag then Library.Flags[Props.Flag] = InputFunctions end
                        return InputFunctions
                    end

                    -- DROPDOWN - Compact
                    function SectionFunctions:Dropdown(Props)
                        local DropdownFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            ClipsDescendants = false
                        })

                        CreateInstance("UIListLayout", {
                            Parent = DropdownFrame,
                            FillDirection = Enum.FillDirection.Vertical,
                            Padding = UDim.new(0, Scale(2))
                        })

                        CreateInstance("TextLabel", {
                            Parent = DropdownFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title or "Dropdown",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextMain"})

                        local DropdownBtn = CreateInstance("TextButton", {
                            Parent = DropdownFrame,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, Scale(22)),
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            Text = " " .. (Props.Default or "Select..."),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextLight"})

                        CreateInstance("UICorner", {Parent = DropdownBtn, CornerRadius = UDim.new(0, Scale(4))})
                        local BtnStroke = CreateInstance("UIStroke", {Parent = DropdownBtn, Thickness = 1}, {Color = "Border"})

                        local Arrow = CreateInstance("ImageLabel", {
                            Parent = DropdownBtn,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(0, Scale(14), 0, Scale(14)),
                            Position = UDim2.new(1, Scale(-20), 0.5, Scale(-7)),
                            Image = Config.ChevronImage,
                            Rotation = 0
                        }, {ImageColor3 = "TextMain"})

                        local MenuOpen = false
                        local SelectedOption = Props.Default
                        local Options = Props.Options or {}

                        local OptionFrame = CreateInstance("Frame", {
                            Parent = DropdownFrame,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, 0),
                            Visible = false,
                            ZIndex = 100
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = OptionFrame, CornerRadius = UDim.new(0, Scale(4))})
                        CreateInstance("UIStroke", {Parent = OptionFrame, Thickness = 1}, {Color = "Border"})

                        local OptionScroll = CreateInstance("ScrollingFrame", {
                            Parent = OptionFrame,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, Scale(-4), 1, Scale(-4)),
                            Position = UDim2.new(0, Scale(2), 0, Scale(2)),
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            ScrollBarThickness = 2,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            ZIndex = 101
                        })

                        local OptionList = CreateInstance("UIListLayout", {
                            Parent = OptionScroll,
                            Padding = UDim.new(0, Scale(2))
                        })

                        local function CloseMenu()
                            MenuOpen = false
                            TweenService:Create(Arrow, CreateTween(0.2), {Rotation = 0}):Play()
                            TweenService:Create(OptionFrame, CreateTween(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                            task.wait(0.2)
                            OptionFrame.Visible = false
                            Library.ActivePopup = nil
                        end

                        local function OpenMenu()
                            Library:ClosePopups()
                            MenuOpen = true
                            OptionFrame.Visible = true
                            TweenService:Create(Arrow, CreateTween(0.2), {Rotation = 180}):Play()

                            local MaxHeight = math.min(#Options * Scale(24) + Scale(4), Scale(120))
                            TweenService:Create(OptionFrame, CreateTween(0.2), {Size = UDim2.new(1, 0, 0, MaxHeight)}):Play()

                            Library.ActivePopup = {Element = OptionFrame, Close = CloseMenu}
                        end

                        DropdownBtn.MouseButton1Click:Connect(function()
                            if MenuOpen then CloseMenu() else OpenMenu() end
                        end)

                        local function SelectOption(Option)
                            SelectedOption = Option
                            DropdownBtn.Text = " " .. Option
                            if Props.Callback then Props.Callback(Option) end
                            CloseMenu()
                        end

                        local OptionButtons = {}

                        local function BuildOptions()
                            for _, Btn in ipairs(OptionButtons) do
                                Btn:Destroy()
                            end
                            table.clear(OptionButtons)

                            for _, Option in ipairs(Options) do
                                local Btn = CreateInstance("TextButton", {
                                    Parent = OptionScroll,
                                    BorderSizePixel = 0,
                                    Size = UDim2.new(1, 0, 0, Scale(22)),
                                    FontFace = Config.Font,
                                    TextSize = Scale(11),
                                    Text = " " .. Option,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                    AutoButtonColor = false,
                                    ZIndex = 102
                                }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextMain"})

                                Btn.MouseEnter:Connect(function()
                                    TweenService:Create(Btn, CreateTween(0.1), {BackgroundColor3 = Config.Colors.PanelBg}):Play()
                                end)
                                Btn.MouseLeave:Connect(function()
                                    TweenService:Create(Btn, CreateTween(0.1), {BackgroundColor3 = Config.Colors.ElementBg}):Play()
                                end)
                                Btn.MouseButton1Click:Connect(function() SelectOption(Option) end)

                                table.insert(OptionButtons, Btn)
                            end
                        end

                        BuildOptions()

                        DropdownBtn.MouseEnter:Connect(function()
                            TweenService:Create(BtnStroke, CreateTween(0.2), {Color = Config.Colors.Accent}):Play()
                        end)
                        DropdownBtn.MouseLeave:Connect(function()
                            TweenService:Create(BtnStroke, CreateTween(0.2), {Color = Config.Colors.Border}):Play()
                        end)

                        local DropdownFunctions = {}
                        function DropdownFunctions:SetValue(Val) SelectOption(Val) end
                        function DropdownFunctions:GetValue() return SelectedOption end
                        function DropdownFunctions:SetOptions(NewOptions)
                            Options = NewOptions
                            BuildOptions()
                        end

                        if Props.Flag then Library.Flags[Props.Flag] = DropdownFunctions end
                        return DropdownFunctions
                    end

                    -- PROGRESS BAR - Compact
                    function SectionFunctions:ProgressBar(Props)
                        local BarFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(30))
                        })

                        local Title = CreateInstance("TextLabel", {
                            Parent = BarFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title or "Progress",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextMain"})

                        local PercentLabel = CreateInstance("TextLabel", {
                            Parent = BarFrame,
                            BackgroundTransparency = 1,
                            Text = "0%",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextLight"})

                        local BarBg = CreateInstance("Frame", {
                            Parent = BarFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(18)),
                            Size = UDim2.new(1, 0, 0, Scale(6))
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = BarBg, CornerRadius = UDim.new(0, Scale(3))})

                        local BarFill = CreateInstance("Frame", {
                            Parent = BarBg,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 0, 1, 0)
                        }, {BackgroundColor3 = "Accent"})

                        CreateInstance("UICorner", {Parent = BarFill, CornerRadius = UDim.new(0, Scale(3))})

                        local ProgressFunctions = {}
                        function ProgressFunctions:SetValue(Percent)
                            local Clamped = math.clamp(Percent, 0, 100)
                            TweenService:Create(BarFill, CreateTween(0.3), {Size = UDim2.new(Clamped / 100, 0, 1, 0)}):Play()
                            PercentLabel.Text = math.floor(Clamped) .. "%"
                        end
                        function ProgressFunctions:GetValue()
                            return BarFill.Size.X.Scale * 100
                        end

                        if Props.Default then ProgressFunctions:SetValue(Props.Default) end
                        if Props.Flag then Library.Flags[Props.Flag] = ProgressFunctions end
                        return ProgressFunctions
                    end

                    -- TOGGLE - Compact
                    function SectionFunctions:Toggle(Props)
                        local ToggleFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(20))
                        })

                        local Checkbox = CreateInstance("TextButton", {
                            Parent = ToggleFrame,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, Scale(14), 0, Scale(14)),
                            Position = UDim2.new(0, 0, 0.5, Scale(-7)),
                            Text = "",
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = Checkbox, CornerRadius = UDim.new(0, Scale(3))})
                        local CheckStroke = CreateInstance("UIStroke", {Parent = Checkbox, Color = Color3.fromRGB(50,50,50), Thickness = 1})

                        local Title = CreateInstance("TextLabel", {
                            Parent = ToggleFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Position = UDim2.new(0, Scale(20), 0, 0),
                            Size = UDim2.new(1, Scale(-20), 1, 0)
                        }, {TextColor3 = "TextMain"})

                        local Toggled = Props.Default or false

                        local function UpdateState(ForcedVal)
                            if ForcedVal ~= nil then Toggled = ForcedVal end
                            if Toggled then
                                TweenService:Create(Checkbox, CreateTween(0.15), {BackgroundColor3 = Config.Colors.Accent}):Play()
                                CheckStroke.Color = Config.Colors.Accent
                                TweenService:Create(Title, CreateTween(0.15), {TextColor3 = Config.Colors.TextLight}):Play()
                            else
                                TweenService:Create(Checkbox, CreateTween(0.15), {BackgroundColor3 = Config.Colors.ElementBg}):Play()
                                CheckStroke.Color = Color3.fromRGB(50,50,50)
                                TweenService:Create(Title, CreateTween(0.15), {TextColor3 = Config.Colors.TextMain}):Play()
                            end
                            if Props.Callback then Props.Callback(Toggled) end
                        end

                        UpdateState()
                        table.insert(Library.DynamicUpdates, function() UpdateState(Toggled) end)

                        Checkbox.MouseButton1Click:Connect(function()
                            Toggled = not Toggled
                            UpdateState()
                        end)

                        local ToggleFunctions = {}
                        function ToggleFunctions:SetValue(Val) UpdateState(Val) end
                        function ToggleFunctions:GetValue() return Toggled end

                        if Props.Flag then Library.Flags[Props.Flag] = ToggleFunctions end
                        return ToggleFunctions
                    end

                    -- SLIDER - Compact
                    function SectionFunctions:Slider(Props)
                        local SliderFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(38))
                        })

                        CreateInstance("TextLabel", {
                            Parent = SliderFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextMain"})

                        local ValueLabel = CreateInstance("TextLabel", {
                            Parent = SliderFrame,
                            BackgroundTransparency = 1,
                            Text = "",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Size = UDim2.new(1, 0, 0, Scale(16))
                        }, {TextColor3 = "TextLight"})

                        local SliderBg = CreateInstance("TextButton", {
                            Parent = SliderFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(20)),
                            Size = UDim2.new(1, 0, 0, Scale(4)),
                            Text = "",
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = SliderBg, CornerRadius = UDim.new(0, Scale(2))})

                        local SliderFill = CreateInstance("Frame", {
                            Parent = SliderBg,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 0, 1, 0)
                        }, {BackgroundColor3 = "Accent"})

                        CreateInstance("UICorner", {Parent = SliderFill, CornerRadius = UDim.new(0, Scale(2))})

                        local SliderFunctions = {}
                        local Decimals = Props.Decimal or 0
                        local Mult = 10 ^ Decimals
                        local Format = "%." .. Decimals .. "f"
                        local Prefix = Props.Prefix or ""
                        local Suffix = Props.Suffix or ""

                        local ZeroValue = Props.ZeroValue or Props.Min
                        local CurrentValue = Props.Default or ZeroValue
                        local ZeroScale = (ZeroValue - Props.Min) / (Props.Max - Props.Min)

                        ValueLabel.Text = Prefix .. string.format(Format, CurrentValue) .. Suffix

                        SliderBg.InputBegan:Connect(function(Input)
                            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                                local function Update(InputVec)
                                    local Pos = math.clamp((InputVec.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                                    local Raw = (Pos * (Props.Max - Props.Min)) + Props.Min
                                    local Val = math.floor(Raw * Mult + 0.5) / Mult
                                    SliderFunctions:SetValue(Val)
                                end
                                Update(Input.Position)
                                local MoveCon = UserInputService.InputChanged:Connect(function(Move)
                                    if Move.UserInputType == Enum.UserInputType.MouseMovement or Move.UserInputType == Enum.UserInputType.Touch then
                                        Update(Move.Position)
                                    end
                                end)
                                local EndCon; EndCon = UserInputService.InputEnded:Connect(function(Ended)
                                    if Ended.UserInputType == Enum.UserInputType.MouseButton1 or Ended.UserInputType == Enum.UserInputType.Touch then
                                        MoveCon:Disconnect()
                                        EndCon:Disconnect()
                                    end
                                end)
                            end
                        end)

                        function SliderFunctions:SetValue(Val)
                            CurrentValue = math.clamp(math.floor(Val * Mult + 0.5) / Mult, Props.Min, Props.Max)
                            local Pos = (CurrentValue - Props.Min) / (Props.Max - Props.Min)
                            local StartScale = math.min(ZeroScale, Pos)
                            local FillSize = math.abs(Pos - ZeroScale)
                            TweenService:Create(SliderFill, CreateTween(0.08), {
                                Position = UDim2.new(StartScale, 0, 0, 0),
                                Size = UDim2.new(FillSize, 0, 1, 0)
                            }):Play()
                            ValueLabel.Text = Prefix .. string.format(Format, CurrentValue) .. Suffix
                            if Props.Callback then Props.Callback(CurrentValue) end
                        end

                        function SliderFunctions:GetValue() return CurrentValue end

                        local StartPercent = (CurrentValue - Props.Min) / (Props.Max - Props.Min)
                        local InitStart = math.min(ZeroScale, StartPercent)
                        local InitSize = math.abs(StartPercent - ZeroScale)
                        SliderFill.Position = UDim2.new(InitStart, 0, 0, 0)
                        SliderFill.Size = UDim2.new(InitSize, 0, 1, 0)

                        if Props.Flag then Library.Flags[Props.Flag] = SliderFunctions end
                        return SliderFunctions
                    end

                    -- ENHANCED GRID - With Search, ViewportFrame Support, and Virtual Scrolling
                    function SectionFunctions:Grid(Props)
                        return self:SearchableGrid(Props)
                    end

                    -- SearchableGrid - Built-in search functionality
                    function SectionFunctions:SearchableGrid(Props)
                        local GridItems = Props.Items or {}
                        local Selected = {}
                        local Favorites = {}
                        local MultiSelect = Props.Multi ~= false
                        local MinColumns = Props.MinColumns or 4
                        local MaxColumns = Props.MaxColumns or 8
                        local MinCellWidth = Props.MinCellWidth or Scale(140)
                        local CellHeight = Props.CellHeight or Scale(70)
                        local SearchFilter = ""
                        local ShowBorders = Props.ShowBorders ~= false
                        local OnSelect = Props.Callback
                        local Searchable = Props.Searchable ~= false
                        local RenderType = Props.RenderType or "ImageLabel" -- "ImageLabel" | "ViewportFrame" | "Custom"
                        local OnRender = Props.OnRender
                        local VirtualScroll = Props.VirtualScroll ~= false and #GridItems > 20 -- Enable for large lists
                        local SearchPlaceholder = Props.SearchPlaceholder or "🔍 Search..."
                        local OnSearch = Props.OnSearch
                        local SelectionNotify = Props.SelectionNotify ~= false

                        local function NotifyOnce(Message, Type)
                            local Key = tostring(Message)
                            if Library.NotificationQueue[Key] then return end
                            Library.NotificationQueue[Key] = true
                            Library:Notify(Message, 1.2, Type)
                            task.delay(1.2, function()
                                Library.NotificationQueue[Key] = nil
                            end)
                        end

                        -- Search Box
                        if Searchable then
                            HeaderBtn.Text = " " .. SectionName .. " "

                            SearchBox = CreateInstance("TextBox", {
                                Parent = HeaderBtn,
                                BackgroundTransparency = 0,
                                Size = UDim2.new(0, Scale(120), 0, Scale(20)),
                                Position = UDim2.new(1, Scale(-150), 0.5, Scale(-10)),
                                FontFace = Config.Font,
                                TextSize = Scale(10),
                                Text = "",
                                PlaceholderText = SearchPlaceholder,
                                ClearTextOnFocus = false,
                                ZIndex = 10
                            }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextLight", PlaceholderColor3 = "TextMain"})

                            CreateInstance("UICorner", {Parent = SearchBox, CornerRadius = UDim.new(0, Scale(4))})
                            local SearchStroke = CreateInstance("UIStroke", {Parent = SearchBox, Thickness = 1}, {Color = "Border"})

                            SearchBox.Focused:Connect(function()
                                TweenService:Create(SearchStroke, CreateTween(0.2), {Color = Config.Colors.Accent}):Play()
                            end)
                            SearchBox.FocusLost:Connect(function()
                                TweenService:Create(SearchStroke, CreateTween(0.2), {Color = Config.Colors.Border}):Play()
                            end)

                            SearchBox.Focused:Connect(function()
                                HeaderBtn.Active = false
                            end)
                            SearchBox.FocusLost:Connect(function()
                                HeaderBtn.Active = true
                            end)
                        end

                        local GridFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BorderSizePixel = 0,
                            Visible = true,
                            ClipsDescendants = false
                        })

                        local GridContainer = CreateInstance("Frame", {
                            Parent = GridFrame,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, 0),
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BorderSizePixel = 0
                        })

                        local GridLayout = CreateInstance("UIGridLayout", {
                            Parent = GridContainer,
                            CellPadding = UDim2.new(0, Scale(6), 0, Scale(6)),
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Left,
                            VerticalAlignment = Enum.VerticalAlignment.Top,
                            SortOrder = Enum.SortOrder.LayoutOrder
                        })

                        local EmptyState = CreateInstance("TextLabel", {
                            Parent = GridContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(80)),
                            FontFace = Config.Font,
                            TextSize = Scale(12),
                            Text = "No items found",
                            TextColor3 = Config.Colors.TextMain,
                            Visible = false
                        })

                        local GridFunctions = {}
                        local CellButtons = {}
                        local VisibleCells = {} -- For virtual scrolling

                        local function CalculateCellSize()
                            local ContainerWidth = GridContainer.AbsoluteSize.X - Scale(10)
                            if ContainerWidth <= 0 then ContainerWidth = Scale(600) end

                            local Calculated = math.floor(ContainerWidth / (MinCellWidth + Scale(6)))
                            local Columns = math.clamp(Calculated, MinColumns, MaxColumns)

                            local CellWidth = math.floor((ContainerWidth - ((Columns - 1) * Scale(6))) / Columns)
                            return CellWidth, CellHeight, Columns
                        end

                        local function FilterItems()
                            local Filtered = {}
                            local FilterText = SearchFilter or ""
                            for _, Item in ipairs(GridItems) do
                                local matches = false
                                if FilterText == "" then
                                    matches = true
                                elseif OnSearch then
                                    matches = OnSearch(FilterText, Item)
                                else
                                    matches = Item.Name and Item.Name:lower():find(FilterText, 1, true)
                                end

                                if matches then
                                    table.insert(Filtered, Item)
                                end
                            end
                            return Filtered
                        end

                        local function ToggleFavorite(Item, StarIcon)
                            local IsFav = not (Favorites[Item.Name] == true)
                            Favorites[Item.Name] = IsFav
                            if IsFav then
                                TweenService:Create(StarIcon, CreateTween(0.2), {TextColor3 = Config.Colors.Warning}):Play()
                                StarIcon.Text = "★"
                            else
                                TweenService:Create(StarIcon, CreateTween(0.2), {TextColor3 = Config.Colors.TextMain}):Play()
                                StarIcon.Text = "☆"
                            end

                            if Props.Flag and Library.Flags[Props.Flag] then
                                Library.Flags[Props.Flag].Favorites = Favorites
                            end
                        end

                        local function ApplySelectionVisualState(CellBtn, IsSelected)
                            if not CellBtn or not CellBtn.Frame then return end

                            local backgroundTransparency = IsSelected and 0.02 or 0.18
                            local backgroundColor = IsSelected and Config.Colors.SectionBg or Config.Colors.ElementBg
                            local strokeColor = IsSelected and Config.Colors.Accent or Config.Colors.Border

                            TweenService:Create(CellBtn.Frame, CreateTween(0.15), {
                                BackgroundTransparency = backgroundTransparency,
                                BackgroundColor3 = backgroundColor
                            }):Play()

                            if CellBtn.Stroke then
                                TweenService:Create(CellBtn.Stroke, CreateTween(0.15), {
                                    Color = strokeColor
                                }):Play()
                            end

                            if CellBtn.Checkmark then
                                CellBtn.Checkmark.Visible = IsSelected
                            end
                        end

                        local function UpdateSelection(Item, IsSelected, CellBtn, Silent)
                            if IsSelected then
                                if not MultiSelect then
                                    for _, sel in ipairs(Selected) do
                                        if sel ~= Item then
                                            local idx = table.find(Selected, sel)
                                            if idx then table.remove(Selected, idx) end
                                        end
                                    end
                                    for _, Btn in ipairs(CellButtons) do
                                        if Btn.Item ~= Item then
                                            ApplySelectionVisualState(Btn, false)
                                        end
                                    end
                                end

                                if not table.find(Selected, Item) then
                                    table.insert(Selected, Item)
                                end

                                ApplySelectionVisualState(CellBtn, true)

                                if SelectionNotify then
                                    NotifyOnce("Selected: " .. (Item.Name or "Item"), "Success")
                                end
                            else
                                local idx = table.find(Selected, Item)
                                if idx then table.remove(Selected, idx) end

                                ApplySelectionVisualState(CellBtn, false)

                                if SelectionNotify then
                                    NotifyOnce("Deselected: " .. (Item.Name or "Item"), "Info")
                                end
                            end

                            if not Silent and OnSelect then OnSelect(Selected, Item, IsSelected) end

                            if Props.Flag and Library.Flags[Props.Flag] then
                                Library.Flags[Props.Flag].Value = Selected
                            end
                        end

                        local function CreateCell(Item, Index)
                            local CellWidth, CellHeight = CalculateCellSize()

                            local CellBtn = CreateInstance("TextButton", {
                                Parent = GridContainer,
                                BackgroundTransparency = 0.18,
                                BorderSizePixel = 0,
                                LayoutOrder = Index,
                                AutoButtonColor = false,
                                Text = "",
                                Visible = true,
                                Name = "Cell_" .. (Item.Name or tostring(Index))
                            }, {BackgroundColor3 = "ElementBg"})

                            CreateInstance("UICorner", {Parent = CellBtn, CornerRadius = UDim.new(0, Scale(6))})

                            local Stroke
                            if ShowBorders then
                                Stroke = CreateInstance("UIStroke", {
                                    Parent = CellBtn,
                                    Thickness = 1,
                                    Color = Config.Colors.Border
                                })
                            end

                            local Checkmark = CreateInstance("TextLabel", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, Scale(20), 0, Scale(20)),
                                Position = UDim2.new(1, Scale(-10), 0, Scale(6)),
                                AnchorPoint = Vector2.new(1, 0),
                                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                                Text = "✓",
                                TextSize = Scale(16),
                                TextColor3 = Config.Colors.Accent,
                                Visible = false,
                                ZIndex = 5
                            })

                            local StarBtn = CreateInstance("TextButton", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, Scale(20), 0, Scale(20)),
                                Position = UDim2.new(0, Scale(6), 0, Scale(6)),
                                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                                Text = Favorites[Item.Name] and "★" or "☆",
                                TextSize = Scale(14),
                                TextColor3 = Favorites[Item.Name] and Config.Colors.Warning or Config.Colors.TextMain,
                                ZIndex = 6,
                                AutoButtonColor = false
                            })

                            StarBtn.MouseButton1Click:Connect(function()
                                ToggleFavorite(Item, StarBtn)
                            end)

                            -- Render content based on type
                            local ContentContainer = CreateInstance("Frame", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0.9, 0, 0.5, 0),
                                Position = UDim2.new(0.05, 0, 0.12, 0),
                                BorderSizePixel = 0
                            })

                            if RenderType == "ViewportFrame" and OnRender then
                                -- Custom ViewportFrame rendering
                                local Viewport = OnRender(Item, ContentContainer)
                                if Viewport then
                                    Viewport.Parent = ContentContainer
                                    Viewport.Size = UDim2.new(1, 0, 1, 0)
                                    Viewport.BackgroundTransparency = 1

                                    -- Cache for cleanup
                                    Library.ViewportCache[CellBtn] = Viewport
                                end
                            elseif RenderType == "Custom" and OnRender then
                                -- Fully custom rendering
                                OnRender(Item, CellBtn, ContentContainer)
                            else
                                -- Default ImageLabel
                                if Item.Image then
                                    local ImgLabel = CreateInstance("ImageLabel", {
                                        Parent = ContentContainer,
                                        BackgroundTransparency = 1,
                                        Size = UDim2.new(1, 0, 1, 0),
                                        Image = Item.Image,
                                        ScaleType = Enum.ScaleType.Fit
                                    })
                                end
                            end

                            local NameLabel = CreateInstance("TextLabel", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, Scale(-12), 0, Scale(18)),
                                Position = UDim2.new(0, Scale(6), 1, Scale(-22)),
                                FontFace = Config.Font,
                                TextSize = Scale(10),
                                Text = Item.Name or "Item",
                                TextXAlignment = Enum.TextXAlignment.Center,
                                TextWrapped = true,
                                TextColor3 = Config.Colors.TextLight
                            })

                            CellBtn.MouseEnter:Connect(function()
                                if not table.find(Selected, Item) then
                                    TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.08}):Play()
                                    if Stroke then TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Accent}):Play() end
                                end
                            end)

                            CellBtn.MouseLeave:Connect(function()
                                if not table.find(Selected, Item) then
                                    TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.18}):Play()
                                    if Stroke then TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Border}):Play() end
                                end
                            end)

                            CellBtn.MouseButton1Click:Connect(function()
                                local CurrentlySelected = table.find(Selected, Item) ~= nil
                                UpdateSelection(Item, not CurrentlySelected, {
                                    Frame = CellBtn,
                                    Stroke = Stroke,
                                    Item = Item,
                                    Checkmark = Checkmark,
                                    Star = StarBtn
                                })
                            end)

                            local CellData = {
                                Frame = CellBtn,
                                Stroke = Stroke,
                                Item = Item,
                                Checkmark = Checkmark,
                                Star = StarBtn,
                                Index = Index
                            }
                            table.insert(CellButtons, CellData)

                            if table.find(Selected, Item) then
                                task.defer(function()
                                    if CellBtn and CellBtn.Parent then
                                        ApplySelectionVisualState(CellData, true)
                                    end
                                end)
                            end

                            if Item.Default or (Props.Default and (Props.Default == Item.Name or (type(Props.Default) == "table" and table.find(Props.Default, Item.Name)))) then
                                task.defer(function()
                                    UpdateSelection(Item, true, CellData)
                                end)
                            end

                            return CellData
                        end

                        local ScrollFrame = GridFrame.Parent
                        local UpdateVisibleCells

                        local function RefreshGrid()
                            -- Clear existing
                            for _, Cell in ipairs(CellButtons) do
                                if Cell.Frame then
                                    -- Cleanup ViewportFrames
                                    if Library.ViewportCache[Cell.Frame] then
                                        Library.ViewportCache[Cell.Frame] = nil
                                    end
                                    Cell.Frame:Destroy()
                                end
                            end
                            table.clear(CellButtons)
                            table.clear(VisibleCells)

                            local Filtered = FilterItems()
                            EmptyState.Visible = (#Filtered == 0)

                            if #Filtered == 0 then return end

                            -- Create cells
                            for Index, Item in ipairs(Filtered) do
                                CreateCell(Item, Index)
                            end

                            local CellWidth, CellHeight = CalculateCellSize()
                            GridLayout.CellSize = UDim2.new(0, CellWidth, 0, CellHeight)

                            -- Update virtual scroll if enabled
                            if VirtualScroll then
                                UpdateVisibleCells()
                            end
                        end

                        -- Virtual Scrolling
                        UpdateVisibleCells = function()
                            if not ScrollFrame or not ScrollFrame:IsA("ScrollingFrame") then return end

                            local scrollPos = ScrollFrame.CanvasPosition.Y
                            local frameHeight = ScrollFrame.AbsoluteSize.Y
                            local buffer = 150 -- pixels buffer

                            for _, CellData in ipairs(CellButtons) do
                                local cell = CellData.Frame
                                if cell and cell.Parent then
                                    local cellY = cell.AbsolutePosition.Y - GridContainer.AbsolutePosition.Y
                                    local isVisible = cellY >= scrollPos - buffer and cellY <= scrollPos + frameHeight + buffer

                                    -- Toggle visibility of expensive elements
                                    for _, child in ipairs(cell:GetDescendants()) do
                                        if child:IsA("ViewportFrame") then
                                            child.Visible = isVisible
                                        end
                                    end
                                end
                            end
                        end

                        if VirtualScroll and ScrollFrame and ScrollFrame:IsA("ScrollingFrame") then
                            ScrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(UpdateVisibleCells)
                        end

                        -- Search connection (moved here after RefreshGrid is defined)
                        if Searchable and SearchBox then
                            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                                SearchFilter = (SearchBox.Text or ""):lower()
                                RefreshGrid()
                            end)
                        end

                        task.defer(function()
                            RefreshGrid()
                        end)

                        GridContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                            local CellWidth, CellHeight = CalculateCellSize()
                            GridLayout.CellSize = UDim2.new(0, CellWidth, 0, CellHeight)
                        end)

                        -- Grid Functions
                        function GridFunctions:SetItems(NewItems)
                            GridItems = NewItems
                            RefreshGrid()
                        end

                        function GridFunctions:SetSelected(Items, Silent)
                            if type(Items) ~= "table" then Items = {Items} end
                            for _, Cell in ipairs(CellButtons) do
                                if table.find(Selected, Cell.Item) then
                                    UpdateSelection(Cell.Item, false, Cell, true)
                                else
                                    ApplySelectionVisualState(Cell, false)
                                end
                            end
                            table.clear(Selected)
                            for _, Name in ipairs(Items) do
                                for _, Cell in ipairs(CellButtons) do
                                    if Cell.Item.Name == Name or Cell.Item == Name then
                                        if not table.find(Selected, Cell.Item) then
                                            table.insert(Selected, Cell.Item)
                                        end
                                        ApplySelectionVisualState(Cell, true)
                                        if not Silent and OnSelect then
                                            OnSelect(Selected, Cell.Item, true)
                                        end
                                        break
                                    end
                                end
                            end
                            if Props.Flag and Library.Flags[Props.Flag] then
                                Library.Flags[Props.Flag].Value = Selected
                            end
                        end

                        function GridFunctions:GetSelected()
                            local result = {}
                            for _, item in ipairs(Selected) do
                                table.insert(result, item)
                            end
                            return result
                        end

                        function GridFunctions:ClearSelection()
                            for _, Cell in ipairs(CellButtons) do
                                UpdateSelection(Cell.Item, false, Cell, true)
                            end
                        end

                        function GridFunctions:GetFavorites()
                            local favs = {}
                            for name, isFav in pairs(Favorites) do
                                if isFav then table.insert(favs, name) end
                            end
                            return favs
                        end

                        function GridFunctions:SetSearchVisible(Visible)
                            if SearchBox then
                                SearchBox.Visible = Visible
                            end
                        end

                        function GridFunctions:SetValue(Val)
                            if type(Val) == "table" then
                                GridFunctions:SetSelected(Val)
                            else
                                GridFunctions:SetSelected({Val})
                            end
                        end

                        function GridFunctions:GetValue()
                            return GridFunctions:GetSelected()
                        end

                        function GridFunctions:Refresh()
                            RefreshGrid()
                        end

                        -- Config serialization support
                        local GridFlagData = {
                            SetValue = GridFunctions.SetValue,
                            GetValue = GridFunctions.GetValue,
                            Value = Selected,
                            Favorites = Favorites,
                            GetFavorites = GridFunctions.GetFavorites,
                            Type = "Grid",
                            Serialize = function(val)
                                -- Serialize selected items to names
                                local serialized = {}
                                for _, item in ipairs(val) do
                                    if type(item) == "table" and item.Name then
                                        table.insert(serialized, item.Name)
                                    elseif type(item) == "string" then
                                        table.insert(serialized, item)
                                    end
                                end
                                return {Selected = serialized, Favorites = Favorites}
                            end,
                            Deserialize = function(data)
                                if type(data) == "table" then
                                    return data.Selected or {}
                                end
                                return {}
                            end
                        }

                        if Props.Flag then
                            Library.Flags[Props.Flag] = GridFlagData
                        end

                        return GridFunctions
                    end

                    return SectionFunctions
                end
                return SubFunctions
            end
            return CategoryFunctions
        end
        return TabFunctions
    end
    return WindowFunctions
end

-- Additional Utility Functions
function Library:Destroy()
    if Library.MainFrame and Library.MainFrame.Parent then
        Library.MainFrame.Parent:Destroy()
    end
    -- Cleanup viewport cache
    for _, viewport in pairs(Library.ViewportCache) do
        if viewport and viewport.Parent then
            viewport:Destroy()
        end
    end
    table.clear(Library.ViewportCache)
end

function Library:Show()
    if Library.MainFrame then
        Library.WindowVisible = true
        Library.MainFrame.Visible = true
        TweenService:Create(Library.MainFrame, CreateTween(0.3), {GroupTransparency = 0}):Play()
        local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
        if Stroke then
            TweenService:Create(Stroke, CreateTween(0.3), {Transparency = 0}):Play()
        end
    end
end

function Library:Hide()
    if Library.MainFrame then
        local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
        if Stroke then
            TweenService:Create(Stroke, CreateTween(0.3), {Transparency = 1}):Play()
        end
        TweenService:Create(Library.MainFrame, CreateTween(0.3), {GroupTransparency = 1}):Play()
        task.delay(0.3, function()
            Library.MainFrame.Visible = false
            Library.WindowVisible = false
        end)
    end
end

function Library:CreateModal(Title, Content, Options)
    Options = Options or {}
    local Modal = CreateInstance("Frame", {
        Parent = Library.MainFrame,
        Size = UDim2.new(0, Scale(400), 0, Scale(300)),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 15000
    }, {BackgroundColor3 = "PanelBg"})

    CreateInstance("UICorner", {Parent = Modal, CornerRadius = UDim.new(0, Scale(8))})
    CreateInstance("UIStroke", {Parent = Modal, Thickness = 1}, {Color = "Accent"})

    local Backdrop = CreateInstance("Frame", {
        Parent = Library.MainFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 14999
    })

    -- Modal Header
    local Header = CreateInstance("Frame", {
        Parent = Modal,
        Size = UDim2.new(1, 0, 0, Scale(40)),
        BackgroundTransparency = 0,
        BorderSizePixel = 0
    }, {BackgroundColor3 = "MainBg"})

    CreateInstance("UICorner", {Parent = Header, CornerRadius = UDim.new(0, Scale(8))})

    -- Fix corner for bottom
    local BottomFix = CreateInstance("Frame", {
        Parent = Header,
        Position = UDim2.new(0, 0, 1, Scale(-8)),
        Size = UDim2.new(1, 0, 0, Scale(8)),
        BorderSizePixel = 0
    }, {BackgroundColor3 = "MainBg"})

    CreateInstance("TextLabel", {
        Parent = Header,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, Scale(-40), 1, 0),
        Position = UDim2.new(0, Scale(16), 0, 0),
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
        Text = Title or "Modal",
        TextSize = Scale(14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Colors.TextLight
    })

    -- Close button
    local CloseBtn = CreateInstance("TextButton", {
        Parent = Header,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, Scale(28), 0, Scale(28)),
        Position = UDim2.new(1, Scale(-34), 0, Scale(6)),
        Text = "X",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
        TextSize = Scale(14),
        TextColor3 = Config.Colors.TextMain
    })

    local ContentContainer = CreateInstance("Frame", {
        Parent = Modal,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, Scale(40)),
        Size = UDim2.new(1, 0, 1, Scale(-40))
    })

    local function CloseModal()
        TweenService:Create(Modal, CreateTween(0.2), {GroupTransparency = 1}):Play()
        TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
        task.wait(0.2)
        Modal:Destroy()
        Backdrop:Destroy()
    end

    CloseBtn.MouseButton1Click:Connect(CloseModal)
    Backdrop.MouseButton1Click:Connect(CloseModal)

    return {
        Frame = Modal,
        Content = ContentContainer,
        Close = CloseModal
    }
end

return Library
