--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
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
    TextSize = 13, 
    ChevronImage = "rbxassetid://10709790948", 
    PickerCursor = "rbxassetid://10709798174",
    CloseIcon = "rbxassetid://10709790948"
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

-- Notification System
function Library:Notify(Message, Duration, Type)
    Type = Type or "Info"
    Duration = Duration or 3
    
    local NotificationGui = CreateInstance("Frame", {
        Name = "Notification",
        Parent = Library.MainFrame and Library.MainFrame.Parent or game.CoreGui,
        Size = UDim2.new(0, 300, 0, 60),
        Position = UDim2.new(0.5, 0, 0, 100),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 5000,
        Visible = false
    }, {BackgroundColor3 = "PanelBg"})
    
    CreateInstance("UICorner", {Parent = NotificationGui, CornerRadius = UDim.new(0, 6)})
    CreateInstance("UIStroke", {Parent = NotificationGui, Thickness = 1}, {Color = "Border"})
    
    local ColorMap = {
        Info = "Accent",
        Success = "Success",
        Error = "Error",
        Warning = "Warning"
    }
    
    CreateInstance("Frame", {
        Parent = NotificationGui,
        Size = UDim2.new(0, 4, 1, 0),
        BorderSizePixel = 0
    }, {BackgroundColor3 = ColorMap[Type] or "Accent"})
    
    CreateInstance("TextLabel", {
        Parent = NotificationGui,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        FontFace = Config.Font,
        TextSize = 12,
        Text = Message,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true
    }, {TextColor3 = "TextLight"})
    
    table.insert(Library.Notifications, NotificationGui)
    
    NotificationGui.Visible = true
    local InTween = TweenService:Create(NotificationGui, CreateTween(0.3), {Position = UDim2.new(0.5, 0, 0, 20)})
    InTween:Play()
    
    task.delay(Duration, function()
        local OutTween = TweenService:Create(NotificationGui, CreateTween(0.3), {Position = UDim2.new(0.5, 0, 0, -100), BackgroundTransparency = 1})
        OutTween:Play()
        OutTween.Completed:Wait()
        NotificationGui:Destroy()
        local idx = table.find(Library.Notifications, NotificationGui)
        if idx then table.remove(Library.Notifications, idx) end
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

function Library:SetWindowKeybind(KeyCode)
    Library.WindowKeybind = KeyCode
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

-- Main Window Function
function Library:Window(TitleOrIcon)
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
        Size = UDim2.new(0.9, 0, 0.9, 0),
        GroupTransparency = 0
    }, {BackgroundColor3 = "PanelBg"})
    
    local SizeConstraint = CreateInstance("UISizeConstraint", {Parent = MainFrame, MaxSize = Vector2.new(900, 650), MinSize = Vector2.new(400, 300)})
    Library.MainFrame = MainFrame
    CreateInstance("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 8)})
    local MainStroke = CreateInstance("UIStroke", {Parent = MainFrame, Thickness = 1, Name = "UIStroke"}, {Color = "MainBg"})

    -- Top Bar
    local TopBar = CreateInstance("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 48)
    }, {BackgroundColor3 = "MainBg"})
    
    MakeDraggable(TopBar, MainFrame)
    
    -- Title/Icon
    if tostring(TitleOrIcon):find("rbxassetid") then
        CreateInstance("ImageLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 32, 0, 32),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 15, 0.5, 0),
            Image = TitleOrIcon,
            ScaleType = Enum.ScaleType.Fit
        }, {ImageColor3 = "Accent"})
    else
        CreateInstance("TextLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 20, 0, 0),
            Size = UDim2.new(0, 200, 1, 0),
            FontFace = Config.Font,
            Text = tostring(TitleOrIcon or "Library"),
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left
        }, {TextColor3 = "Accent"})
    end
    
    -- MINIMIZE BUTTON
    local MinimizeButton = CreateInstance("TextButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -87, 0, 6),
        Text = "−",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextSize = 24,
        AutoButtonColor = false
    }, {TextColor3 = "TextMain"})
    
    CreateInstance("UICorner", {Parent = MinimizeButton, CornerRadius = UDim.new(0, 6)})
    
    -- CLOSE BUTTON
    local CloseButton = CreateInstance("TextButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -46, 0, 6),
        Text = "X",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextSize = 18,
        AutoButtonColor = false
    }, {TextColor3 = "TextMain"})
    
    CreateInstance("UICorner", {Parent = CloseButton, CornerRadius = UDim.new(0, 6)})
    
    -- Body
    local Body = CreateInstance("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 1, -48),
        Name = "Body"
    })
    
    -- Function to clamp window position to screen bounds
    local function ClampWindowPosition()
        local viewportSize = workspace.CurrentCamera.ViewportSize
        local size = MainFrame.AbsoluteSize
        local pos = MainFrame.Position
        
        local minX = size.X / 2
        local maxX = viewportSize.X - size.X / 2
        local minY = size.Y / 2
        local maxY = viewportSize.Y - size.Y / 2
        
        local newX = math.clamp(pos.X.Offset, minX - (viewportSize.X * pos.X.Scale), maxX - (viewportSize.X * pos.X.Scale))
        local newY = math.clamp(pos.Y.Offset, minY - (viewportSize.Y * pos.Y.Scale), maxY - (viewportSize.Y * pos.Y.Scale))
        
        if newX ~= pos.X.Offset or newY ~= pos.Y.Offset then
            MainFrame.Position = UDim2.new(pos.X.Scale, newX, pos.Y.Scale, newY)
        end
    end
    
    -- Minimize functionality
    local IsMinimized = false
    local PreMinimizeSize = nil
    
    MinimizeButton.MouseEnter:Connect(function()
        TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.ElementBg, TextColor3 = Config.Colors.TextLight}):Play()
    end)
    
    MinimizeButton.MouseLeave:Connect(function()
        TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
    end)
    
    MinimizeButton.MouseButton1Click:Connect(function()
        IsMinimized = not IsMinimized
        if IsMinimized then
            PreMinimizeSize = MainFrame.Size
            SizeConstraint.MinSize = Vector2.new(400, 48)
            Body.Visible = false
            
            local minimizedHeight = 48
            TweenService:Create(MainFrame, CreateTween(0.2), {Size = UDim2.new(PreMinimizeSize.X.Scale, PreMinimizeSize.X.Offset, 0, minimizedHeight)}):Play()
            
            MinimizeButton.Text = "+"
        else
            Body.Visible = true
            TweenService:Create(MainFrame, CreateTween(0.2), {Size = PreMinimizeSize or UDim2.new(0.9, 0, 0.9, 0)}):Play()
            
            task.delay(0.2, function()
                SizeConstraint.MinSize = Vector2.new(400, 300)
            end)
            
            task.delay(0.25, function()
                ClampWindowPosition()
            end)
            
            MinimizeButton.Text = "−"
        end
    end)
    
    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.Error, TextColor3 = Color3.fromRGB(255,255,255)}):Play()
    end)
    
    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        local Tween = TweenService:Create(MainFrame, CreateTween(0.3), {GroupTransparency = 1})
        local StrokeTween = TweenService:Create(MainStroke, CreateTween(0.3), {Transparency = 1})
        Tween:Play()
        StrokeTween:Play()
        Tween.Completed:Wait()
        MainFrame.Visible = false
        Library.WindowVisible = false
        MainStroke.Transparency = 0
    end)

    -- Tab Container
    local TabContainer = CreateInstance("Frame", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 120, 0, 0),
        Size = UDim2.new(1, -200, 1, 0)
    })
    
    CreateInstance("UIListLayout", {
        Parent = TabContainer,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 5)
    })

    -- Sidebar
    local SidebarArea = CreateInstance("Frame", {
        Parent = Body,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 15, 0, 15),
        Size = UDim2.new(0, 150, 1, -30)
    })
    
    CreateInstance("TextLabel", {
        Parent = SidebarArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        FontFace = Config.Font,
        Text = "CATEGORIES",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, {TextColor3 = "TextMain"})
    
    local SidebarList = CreateInstance("ScrollingFrame", {
        Parent = SidebarArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 25),
        Size = UDim2.new(1, 0, 1, -25),
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    
    CreateInstance("UIListLayout", {Parent = SidebarList, Padding = UDim.new(0, 10)})

    -- Content Area
    local ContentArea = CreateInstance("Frame", {
        Parent = Body,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 175, 0, 15),
        Size = UDim2.new(1, -190, 1, -30)
    })
    
    CreateInstance("TextLabel", {
        Parent = ContentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        FontFace = Config.Font,
        Text = "FEATURES",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, {TextColor3 = "TextMain"})
    
    local SectionContainer = CreateInstance("ScrollingFrame", {
        Parent = ContentArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 25),
        Size = UDim2.new(1, 0, 1, -25),
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, {ScrollBarImageColor3 = "Border"})
    
    CreateInstance("UIListLayout", {Parent = SectionContainer, Padding = UDim.new(0, 10)})

    -- Fade Overlays
    local ContentFadeOverlay = CreateInstance("Frame", {
        Parent = ContentArea,
        Name = "ContentFadeOverlay",
        Size = UDim2.new(1, 0, 1, -25),
        Position = UDim2.new(0, 0, 0, 25),
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

    function WindowFunctions:AddTab(IconAsset)
        local TabButton = CreateInstance("ImageButton", {
            Parent = TabContainer,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 32, 0, 32),
            Image = "",
            AutoButtonColor = false
        }, {BackgroundColor3 = "PanelBg"})
        
        CreateInstance("UICorner", {Parent = TabButton, CornerRadius = UDim.new(0, 6)})
        
        local IconImg = CreateInstance("ImageLabel", {
            Parent = TabButton,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Image = IconAsset[1] or "rbxassetid://10734962600"
        }, {ImageColor3 = "TextMain"})

        local TabFunctions = {}
        local Categories = {} 
        local TabSubCategories = {} 
        local IsThisTabActive = FirstTab
        local TabFirstSubCategory = true
        local ActiveSubAction = nil 

        table.insert(Library.DynamicUpdates, function() 
            if IsThisTabActive then 
                IconImg.ImageColor3 = Config.Colors.TextLight 
            else 
                IconImg.ImageColor3 = Config.Colors.TextMain 
            end 
        end)

        local function ActivateTab()
            if IsAnimatingTab then return end
            Library:ClosePopups()
            
            for _, Btn in TabContainer:GetChildren() do 
                if Btn:IsA("ImageButton") then 
                    TweenService:Create(Btn, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
                    local InnerIcon = Btn:FindFirstChild("ImageLabel")
                    if InnerIcon then 
                        TweenService:Create(InnerIcon, CreateTween(0.2), {ImageColor3 = Config.Colors.TextMain}):Play() 
                    end
                end 
            end
            
            TweenService:Create(TabButton, CreateTween(0.2), {BackgroundTransparency = 1}):Play() 
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
        end

        function TabFunctions:AddCategory(CatName)
            local CategoryFrame = CreateInstance("Frame", {
                Parent = SidebarList,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = IsThisTabActive,
                BorderSizePixel = 0
            }, {BackgroundColor3 = "SectionBg"})
            
            CreateInstance("UICorner", {Parent = CategoryFrame, CornerRadius = UDim.new(0, 6)})
            CreateInstance("UIStroke", {Parent = CategoryFrame, Thickness = 1}, {Color = "Border"})
            table.insert(Categories, CategoryFrame)

            local CatHeader = CreateInstance("TextButton", {
                Parent = CategoryFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                FontFace = Config.Font,
                Text = "  " .. CatName,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false
            }, {TextColor3 = "TextLight"})
            
            local CatIcon = CreateInstance("ImageLabel", {
                Parent = CatHeader,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -22, 0.5, -8),
                Image = Config.ChevronImage,
                Rotation = 0
            }, {ImageColor3 = "TextMain"})
            
            local SubCatContainer = CreateInstance("Frame", {
                Parent = CategoryFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 32),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                ClipsDescendants = true,
                Visible = true
            })
            
            CreateInstance("UIListLayout", {Parent = SubCatContainer, Padding = UDim.new(0, 2)})
            CreateInstance("UIPadding", {
                Parent = SubCatContainer,
                PaddingBottom = UDim.new(0, 6),
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
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
                    Size = UDim2.new(1, 0, 0, 28),
                    FontFace = Config.Font,
                    Text = "  " .. SubCatName,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false
                }, {TextColor3 = "TextMain"})
                
                CreateInstance("UICorner", {Parent = SubButton, CornerRadius = UDim.new(0, 4)})
                
                local ActiveBorder = CreateInstance("Frame", {
                    Parent = SubButton,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 3, 1, 0),
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
                    
                    CreateInstance("UICorner", {Parent = SectionFrame, CornerRadius = UDim.new(0, 6)})
                    CreateInstance("UIStroke", {Parent = SectionFrame, Thickness = 1}, {Color = "Border"})
                    table.insert(AssociatedSections, SectionFrame)
                    
                    if SubState.bIsActive then 
                        SectionFrame.Visible = true 
                    end

                    local HeaderBtn = CreateInstance("TextButton", {
                        Parent = SectionFrame,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 32),
                        Text = "  " .. SectionName,
                        FontFace = Config.Font,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false
                    }, {TextColor3 = "TextMain"})
                    
                    local SecIcon = CreateInstance("ImageLabel", {
                        Parent = HeaderBtn,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 16, 0, 16),
                        Position = UDim2.new(1, -22, 0.5, -8),
                        Image = Config.ChevronImage,
                        Rotation = 0
                    }, {ImageColor3 = "TextMain"}) 
                    
                    CreateInstance("Frame", {
                        Parent = SectionFrame,
                        BorderSizePixel = 0,
                        Position = UDim2.new(0,0,0,32),
                        Size = UDim2.new(1, 0, 0, 1)
                    }, {BackgroundColor3 = "Separator"})

                    local ElementsContainer = CreateInstance("Frame", {
                        Parent = SectionFrame,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 0, 0, 37),
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        ClipsDescendants = false
                    })
                    
                    CreateInstance("UIListLayout", {Parent = ElementsContainer, Padding = UDim.new(0, 8)})
                    CreateInstance("UIPadding", {
                        Parent = SectionFrame,
                        PaddingBottom = UDim.new(0, 10),
                        PaddingLeft = UDim.new(0, 10),
                        PaddingRight = UDim.new(0, 10)
                    })

                    local SecOpen = true
                    HeaderBtn.MouseButton1Click:Connect(function() 
                        SecOpen = not SecOpen
                        ElementsContainer.Visible = SecOpen
                        TweenService:Create(SecIcon, CreateTween(0.2), {Rotation = SecOpen and 0 or -90}):Play() 
                    end)

                    local SectionFunctions = {}

                    -- BUTTON
                    function SectionFunctions:Button(Props)
                        local ButtonFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 30)
                        })
                        
                        CreateInstance("UIListLayout", {
                            Parent = ButtonFrame,
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            Padding = UDim.new(0, 5)
                        })
                        
                        local ButtonsInGroup = {}
                        local ButtonFunctions = {}

                        local function AddButton(BtnProps)
                            local Btn = CreateInstance("TextButton", {
                                Parent = ButtonFrame,
                                BorderSizePixel = 0,
                                FontFace = Config.Font,
                                Text = BtnProps.Title,
                                TextSize = 12,
                                AutoButtonColor = false
                            }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextMain"})
                            
                            CreateInstance("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 5)})
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

                            local TotalPadding = (#ButtonsInGroup - 1) * 5
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

                    -- LABEL
                    function SectionFunctions:Label(Props)
                        local LabelFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 22)
                        })
                        
                        local Title = CreateInstance("TextLabel", {
                            Parent = LabelFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 1, 0)
                        }, {TextColor3 = "TextMain"})

                        local LabelFunctions = {}
                        function LabelFunctions:SetValue(Val) Title.Text = tostring(Val) end
                        function LabelFunctions:GetValue() return Title.Text end
                        
                        if Props.Flag then Library.Flags[Props.Flag] = LabelFunctions end
                        return LabelFunctions
                    end

                    -- TOGGLE
                    function SectionFunctions:Toggle(Props)
                        local ToggleFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 24)
                        })
                        
                        local Checkbox = CreateInstance("TextButton", {
                            Parent = ToggleFrame,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 16, 0, 16),
                            Position = UDim2.new(0, 0, 0.5, -8),
                            Text = "",
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg"})
                        
                        CreateInstance("UICorner", {Parent = Checkbox, CornerRadius = UDim.new(0, 4)})
                        local CheckStroke = CreateInstance("UIStroke", {Parent = Checkbox, Color = Color3.fromRGB(50,50,50), Thickness = 1})
                        
                        local Title = CreateInstance("TextLabel", {
                            Parent = ToggleFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Position = UDim2.new(0, 24, 0, 0),
                            Size = UDim2.new(1, -24, 1, 0)
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

                    -- SLIDER
                    function SectionFunctions:Slider(Props)
                        local SliderFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 45)
                        })
                        
                        CreateInstance("TextLabel", {
                            Parent = SliderFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title,
                            FontFace = Config.Font,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, 18)
                        }, {TextColor3 = "TextMain"})
                        
                        local ValueLabel = CreateInstance("TextLabel", {
                            Parent = SliderFrame,
                            BackgroundTransparency = 1,
                            Text = "",
                            FontFace = Config.Font,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Size = UDim2.new(1, 0, 0, 18)
                        }, {TextColor3 = "TextLight"})
                        
                        local SliderBg = CreateInstance("TextButton", {
                            Parent = SliderFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, 23),
                            Size = UDim2.new(1, 0, 0, 5),
                            Text = "",
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg"})
                        
                        CreateInstance("UICorner", {Parent = SliderBg, CornerRadius = UDim.new(0, 3)})
                        
                        local SliderFill = CreateInstance("Frame", {
                            Parent = SliderBg,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 0, 1, 0)
                        }, {BackgroundColor3 = "Accent"})
                        
                        CreateInstance("UICorner", {Parent = SliderFill, CornerRadius = UDim.new(0, 3)})

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

                    -- GRID (FIXED VISIBILITY & RENDERING)
                    function SectionFunctions:Grid(Props)
                        local GridItems = Props.Items or {}
                        local Selected = {}
                        local MultiSelect = Props.Multi or false
                        local CellSize = Props.CellSize or 80
                        local Padding = Props.Padding or 8
                        local GridHeight = Props.Height or 200
                        local OnSelect = Props.Callback

                        -- Container for the grid with fixed height
                        local GridFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, GridHeight),
                            BorderSizePixel = 0,
                            Visible = true,
                            ClipsDescendants = false
                        })
                        
                        -- Scrolling frame to hold cells
                        local ScrollFrame = CreateInstance("ScrollingFrame", {
                            Parent = GridFrame,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 1, 0),
                            Position = UDim2.new(0, 0, 0, 0),
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            ScrollBarThickness = 4,
                            ScrollingDirection = Enum.ScrollingDirection.Y,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            Visible = true,
                            BorderSizePixel = 0
                        }, {ScrollBarImageColor3 = "Accent"})
                        
                        local GridLayout = CreateInstance("UIGridLayout", {
                            Parent = ScrollFrame,
                            CellSize = UDim2.new(0, CellSize, 0, CellSize),
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Left,
                            VerticalAlignment = Enum.VerticalAlignment.Top,
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            Padding = UDim.new(0, Padding, 0, Padding)
                        })

                        local GridFunctions = {}
                        local CellButtons = {}

                        -- FIX: Force canvas update with better calculation
                        local function UpdateCanvasSize()
                            if not GridLayout then return end
                            local contentSize = GridLayout.AbsoluteContentSize
                            local newHeight = contentSize.Y + (Padding * 2)
                            if newHeight < 0 then newHeight = 0 end
                            ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, newHeight)
                        end
                        
                        -- Wait for layout to compute then update
                        local function ForceUpdate()
                            task.wait()
                            if GridLayout and GridLayout.Parent then
                                UpdateCanvasSize()
                            end
                        end
                        
                        GridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)

                        local function UpdateSelection(Item, IsSelected, CellBtn)
                            if IsSelected then
                                if not MultiSelect then
                                    -- Deselect all others
                                    local toRemove = {}
                                    for _, sel in ipairs(Selected) do
                                        if sel ~= Item then
                                            table.insert(toRemove, sel)
                                        end
                                    end
                                    for _, rem in ipairs(toRemove) do
                                        local idx = table.find(Selected, rem)
                                        if idx then table.remove(Selected, idx) end
                                    end
                                    
                                    -- Update visual state for all other cells
                                    for _, Btn in ipairs(CellButtons) do
                                        if Btn.Item ~= Item then
                                            TweenService:Create(Btn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.3}):Play()
                                            TweenService:Create(Btn.Stroke, CreateTween(0.15), {Color = Config.Colors.Border}):Play()
                                            if Btn.Checkmark then
                                                Btn.Checkmark.Visible = false
                                            end
                                        end
                                    end
                                end
                                if not table.find(Selected, Item) then
                                    table.insert(Selected, Item)
                                end
                                -- Selected visual state
                                TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.1}):Play()
                                TweenService:Create(CellBtn.Stroke, CreateTween(0.15), {Color = Config.Colors.Accent}):Play()
                                TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundColor3 = Config.Colors.Accent}):Play()
                                if CellBtn.Checkmark then
                                    CellBtn.Checkmark.Visible = true
                                end
                            else
                                local idx = table.find(Selected, Item)
                                if idx then table.remove(Selected, idx) end
                                -- Deselected visual state
                                TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.3}):Play()
                                TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundColor3 = Config.Colors.ElementBg}):Play()
                                TweenService:Create(CellBtn.Stroke, CreateTween(0.15), {Color = Config.Colors.Border}):Play()
                                if CellBtn.Checkmark then
                                    CellBtn.Checkmark.Visible = false
                                end
                            end
                            if OnSelect then OnSelect(Selected, Item, IsSelected) end
                        end

                        local function CreateCell(Item, Index)
                            local CellBtn = CreateInstance("TextButton", {
                                Parent = ScrollFrame,
                                BackgroundTransparency = 0.3, -- REDUCED from 0.85
                                BorderSizePixel = 0,
                                LayoutOrder = Index,
                                AutoButtonColor = false,
                                Text = "",
                                Visible = true,
                                Size = UDim2.new(0, CellSize, 0, CellSize)
                            }, {BackgroundColor3 = "ElementBg"})
                            
                            CreateInstance("UICorner", {Parent = CellBtn, CornerRadius = UDim.new(0, 8)})
                            
                            -- Visible border
                            local Stroke = CreateInstance("UIStroke", {
                                Parent = CellBtn, 
                                Thickness = 1.5,
                                Color = Config.Colors.Border
                            })
                            
                            -- Selection indicator (checkmark)
                            local Checkmark = CreateInstance("TextLabel", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, 20, 0, 20),
                                Position = UDim2.new(1, -10, 0, -5),
                                AnchorPoint = Vector2.new(1, 0),
                                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                                Text = "✓",
                                TextSize = 16,
                                TextColor3 = Config.Colors.TextLight,
                                Visible = false,
                                ZIndex = 5
                            })
                            
                            -- Image container
                            local ImgContainer = CreateInstance("Frame", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0.7, 0, 0.6, 0),
                                Position = UDim2.new(0.15, 0, 0.1, 0),
                                BorderSizePixel = 0
                            })
                            
                            if Item.Image then
                                local ImgLabel = CreateInstance("ImageLabel", {
                                    Parent = ImgContainer,
                                    BackgroundTransparency = 1,
                                    Size = UDim2.new(1, 0, 1, 0),
                                    Position = UDim2.new(0, 0, 0, 0),
                                    Image = Item.Image,
                                    ScaleType = Enum.ScaleType.Fit
                                })
                            else
                                -- Placeholder icon/text when no image
                                local Placeholder = CreateInstance("TextLabel", {
                                    Parent = ImgContainer,
                                    BackgroundTransparency = 1,
                                    Size = UDim2.new(1, 0, 1, 0),
                                    FontFace = Config.Font,
                                    Text = "📦",
                                    TextSize = 32,
                                    TextColor3 = Config.Colors.TextMain
                                })
                            end
                            
                            -- Name label at bottom
                            local NameLabel = CreateInstance("TextLabel", {
                                Parent = CellBtn,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, -8, 0, 20),
                                Position = UDim2.new(0, 4, 1, -24),
                                FontFace = Config.Font,
                                TextSize = 11,
                                Text = Item.Name or "Item",
                                TextXAlignment = Enum.TextXAlignment.Center,
                                TextWrapped = true,
                                TextColor3 = Config.Colors.TextLight
                            })
                            
                            -- Hover effects
                            CellBtn.MouseEnter:Connect(function()
                                if not table.find(Selected, Item) then
                                    TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.15}):Play()
                                    TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Accent}):Play()
                                end
                            end)
                            
                            CellBtn.MouseLeave:Connect(function()
                                if not table.find(Selected, Item) then
                                    TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.3}):Play()
                                    TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Border}):Play()
                                end
                            end)
                            
                            CellBtn.MouseButton1Click:Connect(function()
                                local CurrentlySelected = table.find(Selected, Item) ~= nil
                                UpdateSelection(Item, not CurrentlySelected, {
                                    Frame = CellBtn, 
                                    Stroke = Stroke, 
                                    Item = Item,
                                    Checkmark = Checkmark
                                })
                            end)
                            
                            local CellData = {
                                Frame = CellBtn,
                                Stroke = Stroke,
                                Item = Item,
                                Checkmark = Checkmark
                            }
                            table.insert(CellButtons, CellData)
                            
                            -- Apply default selection
                            if Item.Default or (Props.Default and (Props.Default == Item.Name or (type(Props.Default) == "table" and table.find(Props.Default, Item.Name)))) then
                                task.defer(function() 
                                    UpdateSelection(Item, true, CellData) 
                                end)
                            end
                            
                            return CellData
                        end

                        -- Build grid
                        for Index, Item in ipairs(GridItems) do
                            CreateCell(Item, Index)
                        end
                        
                        -- Force layout update after creation
                        task.defer(function()
                            UpdateCanvasSize()
                            task.wait(0.1)
                            UpdateCanvasSize()
                        end)

                        function GridFunctions:SetItems(NewItems)
                            for _, Cell in ipairs(CellButtons) do
                                Cell.Frame:Destroy()
                            end
                            table.clear(CellButtons)
                            table.clear(Selected)
                            
                            GridItems = NewItems
                            for Index, Item in ipairs(GridItems) do
                                CreateCell(Item, Index)
                            end
                            UpdateCanvasSize()
                        end
                        
                        function GridFunctions:SetSelected(Items)
                            if type(Items) ~= "table" then Items = {Items} end
                            for _, Cell in ipairs(CellButtons) do
                                UpdateSelection(Cell.Item, false, Cell)
                            end
                            for _, Name in ipairs(Items) do
                                for _, Cell in ipairs(CellButtons) do
                                    if Cell.Item.Name == Name then
                                        UpdateSelection(Cell.Item, true, Cell)
                                        break
                                    end
                                end
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
                                UpdateSelection(Cell.Item, false, Cell)
                            end
                        end
                        
                        function GridFunctions:SetValue(Val)
                            GridFunctions:SetSelected(Val)
                        end
                        
                        function GridFunctions:GetValue()
                            return GridFunctions:GetSelected()
                        end

                        -- Theme update support
                        table.insert(Library.DynamicUpdates, function()
                            for _, Cell in ipairs(CellButtons) do
                                if table.find(Selected, Cell.Item) then
                                    Cell.Stroke.Color = Config.Colors.Accent
                                    Cell.Frame.BackgroundColor3 = Config.Colors.Accent
                                else
                                    Cell.Stroke.Color = Config.Colors.Border
                                    Cell.Frame.BackgroundColor3 = Config.Colors.ElementBg
                                end
                            end
                        end)
                        
                        if Props.Flag then 
                            Library.Flags[Props.Flag] = GridFunctions 
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

return Library
