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
Library.TooltipFrame = nil
Library.ConfigProfiles = {}
Library.ScrollLocks = {}
Library.NotificationSettings = {
    Position = "top_center",
    Width = 320
}
Library.ConfigRules = {
    SaveDefaults = true,
    Include = nil,
    Exclude = nil,
    Defaults = {}
}

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
    local Inst
    local OkCreate, Created = pcall(Instance.new, Class)
    if OkCreate then
        Inst = Created
    elseif Class == "CanvasGroup" then
        Inst = Instance.new("Frame")
    else
        error(Created)
    end

    for Key, Value in Properties do
        local OkAssign, Err = pcall(function()
            Inst[Key] = Value
        end)
        if not OkAssign and Key ~= "GroupTransparency" then
            error(Err)
        end
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

local function ApplyNotificationContainerLayout()
    local Container = Library.NotificationContainer
    if not Container then
        return
    end

    local Settings = Library.NotificationSettings or {}
    local Position = tostring(Settings.Position or "top_center")
    local Width = math.max(220, math.floor(tonumber(Settings.Width) or 320))
    local Layout = Container:FindFirstChildOfClass("UIListLayout")

    Container.Size = UDim2.new(0, Width, 0, 0)
    Container.AutomaticSize = Enum.AutomaticSize.Y

    if Position == "bottom_right" then
        Container.AnchorPoint = Vector2.new(1, 1)
        Container.Position = UDim2.new(1, -Scale(14), 1, -Scale(14))
        if Layout then
            Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        end
    elseif Position == "top_right" then
        Container.AnchorPoint = Vector2.new(1, 0)
        Container.Position = UDim2.new(1, -Scale(14), 0, Scale(14))
        if Layout then
            Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        end
    else
        Container.AnchorPoint = Vector2.new(0.5, 0)
        Container.Position = UDim2.new(0.5, 0, 0, Scale(14))
        if Layout then
            Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        end
    end
end

local function SupportsGroupTransparency(GuiObject)
    if not GuiObject then
        return false
    end

    return pcall(function()
        local _ = GuiObject.GroupTransparency
        return _
    end)
end

local function PlayGroupTransparencyTween(GuiObject, Time, Target)
    if not SupportsGroupTransparency(GuiObject) then
        return nil
    end

    local Tween = TweenService:Create(GuiObject, CreateTween(Time), {GroupTransparency = Target})
    Tween:Play()
    return Tween
end

local function GetConfigBaseName(Name)
    local BaseName = tostring(Name or Library.ConfigName or "SeraphConfig")
    return BaseName:gsub("%.json$", "")
end

local function GetConfigFilePath(Name)
    return GetConfigBaseName(Name) .. ".json"
end

local function CreateTooltipFrame()
    if Library.TooltipFrame and Library.TooltipFrame.Parent then
        return Library.TooltipFrame
    end

    local Tooltip = CreateInstance("TextLabel", {
        Parent = Library.MainFrame and Library.MainFrame.Parent or nil,
        BackgroundTransparency = 0,
        AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false,
        AnchorPoint = Vector2.new(0, 1),
        ZIndex = 20000,
        FontFace = Config.Font,
        TextSize = Scale(10),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, {BackgroundColor3 = "PanelBg", TextColor3 = "TextLight"})

    CreateInstance("UICorner", {Parent = Tooltip, CornerRadius = UDim.new(0, Scale(4))})
    CreateInstance("UIStroke", {Parent = Tooltip, Thickness = 1}, {Color = "Border"})
    CreateInstance("UIPadding", {
        Parent = Tooltip,
        PaddingTop = UDim.new(0, Scale(6)),
        PaddingBottom = UDim.new(0, Scale(6)),
        PaddingLeft = UDim.new(0, Scale(8)),
        PaddingRight = UDim.new(0, Scale(8))
    })

    Library.TooltipFrame = Tooltip
    return Tooltip
end

local function ShowTooltip(Text)
    if not Text or Text == "" or not Library.MainFrame or not Library.MainFrame.Parent then
        return
    end

    local Tooltip = CreateTooltipFrame()
    Tooltip.Parent = Library.MainFrame.Parent
    Tooltip.Text = tostring(Text)
    Tooltip.Size = UDim2.fromOffset(0, 0)
    Tooltip.Visible = true

    local MousePos = UserInputService:GetMouseLocation()
    local MaxWidth = math.max(Scale(140), math.floor(Library.MainFrame.AbsoluteSize.X * 0.4))
    Tooltip.Size = UDim2.fromOffset(MaxWidth, 0)

    local AbsoluteSize = Tooltip.AbsoluteSize
    local X = MousePos.X + Scale(12)
    local Y = MousePos.Y - Scale(8)
    local ScreenSize = Library.MainFrame.Parent.AbsoluteSize

    if X + AbsoluteSize.X > ScreenSize.X - Scale(8) then
        X = ScreenSize.X - AbsoluteSize.X - Scale(8)
    end
    if Y - AbsoluteSize.Y < Scale(8) then
        Y = MousePos.Y + AbsoluteSize.Y
        Tooltip.AnchorPoint = Vector2.new(0, 0)
    else
        Tooltip.AnchorPoint = Vector2.new(0, 1)
    end

    Tooltip.Position = UDim2.fromOffset(X, Y)
end

local function HideTooltip()
    if Library.TooltipFrame then
        Library.TooltipFrame.Visible = false
    end
end

local function ApplyTextOptions(TextObject, Options)
    if not TextObject or not Options then
        return
    end

    if Options.Wrap ~= nil then
        TextObject.TextWrapped = Options.Wrap
    end
    if Options.Truncate then
        TextObject.TextTruncate = Options.Truncate
    end
    if Options.RichText ~= nil then
        TextObject.RichText = Options.RichText
    end
    if Options.XAlignment then
        TextObject.TextXAlignment = Options.XAlignment
    end
    if Options.YAlignment then
        TextObject.TextYAlignment = Options.YAlignment
    end
    if Options.Monospace then
        TextObject.FontFace = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    end
    if Options.CopyOnClick and TextObject:IsA("GuiButton") then
        TextObject.MouseButton1Click:Connect(function()
            if setclipboard then
                pcall(setclipboard, TextObject.Text)
                Library:Notify("Copied to clipboard", 1.4, "Success")
            end
        end)
    end
end

local function SetScrollLocked(ScrollFrame, Locked)
    if not ScrollFrame then
        return
    end
    ScrollFrame.ScrollingEnabled = not Locked
end

local function RegisterPopup(PopupData)
    Library:ClosePopups()
    Library.ActivePopup = PopupData
    if PopupData and PopupData.ScrollLock then
        SetScrollLocked(PopupData.ScrollLock, true)
    end
end

local function SetGuiInteractable(Gui, Enabled)
    if not Gui then
        return
    end

    if Gui:IsA("GuiButton") then
        Gui.Active = Enabled
        Gui.AutoButtonColor = false
    elseif Gui:IsA("TextBox") then
        Gui.Active = Enabled
        Gui.TextEditable = Enabled
    else
        Gui.Active = Enabled
    end
end

local function StopTween(TweenState, Key)
    local ActiveTween = TweenState[Key]
    if ActiveTween then
        pcall(function()
            ActiveTween:Cancel()
        end)
        TweenState[Key] = nil
    end
end

local function PlayTrackedTween(TweenState, Key, GuiObject, Time, Properties, Style, Direction)
    if not GuiObject or not Properties then
        return
    end

    StopTween(TweenState, Key)

    local Tween = TweenService:Create(GuiObject, CreateTween(Time, Style, Direction), Properties)
    TweenState[Key] = Tween
    Tween.Completed:Connect(function()
        if TweenState[Key] == Tween then
            TweenState[Key] = nil
        end
    end)
    Tween:Play()
    return Tween
end

local function CreateInteractiveFeedback(Options)
    local State = {
        Hovered = false,
        Pressed = false,
        Focused = false,
        Disabled = false
    }
    local Targets = Options.Targets or {}
    local Interactive = Options.Interactive or {}
    local TweenState = {}
    local Connections = {}

    local function ApplyVisual(Name, Immediate)
        local Visual = Options[Name] or Options.Default or {}
        for Key, Target in pairs(Targets) do
            local Props = Visual[Key]
            if Props and Target.Object then
                if Immediate then
                    StopTween(TweenState, Key)
                    for Property, Value in pairs(Props) do
                        Target.Object[Property] = Value
                    end
                else
                    PlayTrackedTween(
                        TweenState,
                        Key,
                        Target.Object,
                        Target.Time or 0.12,
                        Props,
                        Target.Style,
                        Target.Direction
                    )
                end
            end
        end
    end

    local function ResolveVisualState()
        if State.Disabled and Options.Disabled then
            return "Disabled"
        end
        if State.Pressed and Options.Pressed then
            return "Pressed"
        end
        if State.Focused and Options.Focused then
            return "Focused"
        end
        if State.Hovered and Options.Hover then
            return "Hover"
        end
        return "Default"
    end

    local function Refresh(Immediate)
        ApplyVisual(ResolveVisualState(), Immediate)
    end

    for _, Gui in ipairs(Interactive) do
        if Gui then
            if Gui.MouseEnter then
                table.insert(Connections, Gui.MouseEnter:Connect(function()
                    if State.Disabled then
                        return
                    end
                    State.Hovered = true
                    Refresh()
                end))
            end

            if Gui.MouseLeave then
                table.insert(Connections, Gui.MouseLeave:Connect(function()
                    State.Hovered = false
                    State.Pressed = false
                    Refresh()
                end))
            end

            if Gui.InputBegan then
                table.insert(Connections, Gui.InputBegan:Connect(function(Input)
                    if State.Disabled then
                        return
                    end
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        State.Pressed = true
                        Refresh()
                    end
                end))
            end

            if Gui.InputEnded then
                table.insert(Connections, Gui.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        State.Pressed = false
                        Refresh()
                    end
                end))
            end
        end
    end

    Refresh(true)

    return {
        SetDisabled = function(_, Disabled)
            State.Disabled = Disabled and true or false
            if State.Disabled then
                State.Hovered = false
                State.Pressed = false
            end
            Refresh()
        end,
        SetFocused = function(_, Focused)
            State.Focused = Focused and true or false
            Refresh()
        end,
        Refresh = function(_, Immediate)
            Refresh(Immediate)
        end,
        Destroy = function()
            for _, Connection in ipairs(Connections) do
                pcall(function()
                    Connection:Disconnect()
                end)
            end
            for Key in pairs(TweenState) do
                StopTween(TweenState, Key)
            end
        end
    }
end

local function AttachControlStateApi(Control, Options)
    local Root = Options.Root
    local Interactive = Options.Interactive or {}
    local TextTargets = Options.TextTargets or {}
    local TooltipTargets = Options.TooltipTargets or Interactive
    local ManualDisabled = false
    local Loading = false
    local TooltipText = Options.Tooltip
    local LoadingText = Options.LoadingText or "Loading..."
    local OriginalText = {}
    local Destroyed = false
    local Cleanup = Options.Cleanup or {}

    if Root and #TooltipTargets == 0 then
        TooltipTargets = {Root}
    end

    local function ApplyState()
        local Blocked = ManualDisabled or Loading
        if Options.SetDisabledState then
            Options.SetDisabledState(Blocked, ManualDisabled, Loading)
        end
        for _, Gui in ipairs(Interactive) do
            SetGuiInteractable(Gui, not Blocked)
        end
    end

                        local function BindTooltip()
        for _, Target in ipairs(TooltipTargets) do
            if Target and Target.Parent then
                if Target.MouseEnter then
                    Target.MouseEnter:Connect(function()
                        if TooltipText and TooltipText ~= "" then
                            ShowTooltip(TooltipText)
                        end
                    end)
                end
                if Target.MouseLeave then
                    Target.MouseLeave:Connect(HideTooltip)
                end
                if Target.InputChanged then
                    Target.InputChanged:Connect(function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseMovement and TooltipText and TooltipText ~= "" then
                            ShowTooltip(TooltipText)
                        end
                    end)
                end
            end
        end
    end

    function Control:SetVisible(Visible)
        if Root then
            Root.Visible = Visible
        end
    end

    function Control:GetVisible()
        return Root and Root.Visible or false
    end

    function Control:SetDisabled(Disabled)
        ManualDisabled = Disabled and true or false
        ApplyState()
    end

    function Control:IsDisabled()
        return ManualDisabled or Loading
    end

    function Control:SetTooltip(Text)
        TooltipText = Text
    end

    function Control:GetTooltip()
        return TooltipText
    end

    function Control:SetLoading(IsLoading, OverrideText)
        local WasLoading = Loading
        Loading = IsLoading and true or false
        for _, Target in ipairs(TextTargets) do
            if Target and Target.Parent then
                if Loading then
                    if not WasLoading then
                        OriginalText[Target] = Target.Text
                    end
                    Target.Text = OverrideText or LoadingText
                elseif WasLoading and OriginalText[Target] ~= nil then
                    Target.Text = OriginalText[Target]
                end
            end
        end
        ApplyState()
    end

    function Control:IsLoading()
        return Loading
    end

    function Control:Destroy()
        if Destroyed then
            return
        end
        Destroyed = true
        HideTooltip()
        for _, Item in ipairs(Cleanup) do
            if typeof(Item) == "RBXScriptConnection" then
                pcall(function() Item:Disconnect() end)
            elseif type(Item) == "function" then
                pcall(Item)
            elseif type(Item) == "table" and Item.Destroy then
                pcall(function() Item:Destroy() end)
            end
        end
        if Options.OnDestroy then
            pcall(Options.OnDestroy)
        end
        if Root and Root.Parent then
            Root:Destroy()
        end
    end

    BindTooltip()
    ApplyState()
    return Control
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
    if type(Name) == "table" then
        Library.ConfigName = GetConfigBaseName(Name.Name or Library.ConfigName)
        Library:ConfigurePersistence(Name)
    else
        Library.ConfigName = GetConfigBaseName(Name)
    end
end

function Library:ConfigurePersistence(Options)
    Options = Options or {}
    Library.ConfigRules.SaveDefaults = Options.SaveDefaults ~= false
    Library.ConfigRules.Include = Options.Include
    Library.ConfigRules.Exclude = Options.Exclude
    Library.ConfigRules.Defaults = Options.Defaults or Library.ConfigRules.Defaults or {}
end

function Library:GetConfigProfiles()
    local Profiles = {}
    local Seen = {}

    local function AddProfile(Name)
        local CleanName = GetConfigBaseName(Name)
        if CleanName ~= "" and not Seen[CleanName] then
            Seen[CleanName] = true
            table.insert(Profiles, CleanName)
        end
    end

    AddProfile(Library.ConfigName)

    if listfiles then
        local Success, Files = pcall(function()
            return listfiles(".")
        end)

        if Success and type(Files) == "table" then
            for _, Path in ipairs(Files) do
                local FileName = tostring(Path):match("[^/\\]+$") or tostring(Path)
                local BaseName = FileName:match("^(.*)%.json$")
                if BaseName then
                    AddProfile(BaseName)
                end
            end
        end
    end

    table.sort(Profiles)
    Library.ConfigProfiles = Profiles
    return Profiles
end

function Library:SaveConfig(NameOrSilent, MaybeSilent)
    if not Library.ConfigEnabled then return end

    local ProfileName = nil
    local Silent = false
    if type(NameOrSilent) == "boolean" then
        Silent = NameOrSilent
    else
        ProfileName = NameOrSilent
        Silent = MaybeSilent and true or false
    end

    if ProfileName then
        Library.ConfigName = GetConfigBaseName(ProfileName)
    end

    local Data = {}
    for Flag, Func in pairs(Library.Flags) do
        local Included = true
        if Library.ConfigRules.Include then
            Included = table.find(Library.ConfigRules.Include, Flag) ~= nil
        end
        if Included and Library.ConfigRules.Exclude then
            Included = table.find(Library.ConfigRules.Exclude, Flag) == nil
        end
        if Func.IncludeInConfig == false then
            Included = false
        end

        if Included and Func.GetValue then
            local Success, Value = pcall(function() return Func:GetValue() end)
            if Success then
                local DefaultValue = Func.DefaultValue
                if DefaultValue == nil then
                    DefaultValue = Library.ConfigRules.Defaults[Flag]
                end
                if not Library.ConfigRules.SaveDefaults and DefaultValue ~= nil and Value == DefaultValue then
                    continue
                end
                if Func.Serialize then
                    Data[Flag] = Func.Serialize(Value)
                else
                    Data[Flag] = Value
                end
            end
        end
    end

    local Encoded = HttpService:JSONEncode(Data)
    writefile(GetConfigFilePath(Library.ConfigName), Encoded)
    if not Silent then
        Library:Notify("Configuration saved: " .. Library.ConfigName, 2, "Success")
    end
end

function Library:LoadConfig(NameOrSilent, MaybeSilent)
    if not Library.ConfigEnabled then return end

    local ProfileName = nil
    local Silent = false
    if type(NameOrSilent) == "boolean" then
        Silent = NameOrSilent
    else
        ProfileName = NameOrSilent
        Silent = MaybeSilent and true or false
    end

    if ProfileName then
        Library.ConfigName = GetConfigBaseName(ProfileName)
    end

    if isfile(GetConfigFilePath(Library.ConfigName)) then
        local Success, Decoded = pcall(function()
            return HttpService:JSONDecode(readfile(GetConfigFilePath(Library.ConfigName)))
        end)

        if Success and Decoded then
            for Flag, DefaultValue in pairs(Library.ConfigRules.Defaults) do
                if Decoded[Flag] == nil and Library.Flags[Flag] and Library.Flags[Flag].SetValue then
                    pcall(function() Library.Flags[Flag]:SetValue(DefaultValue) end)
                end
            end
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
                Library:Notify("Configuration loaded: " .. Library.ConfigName, 2, "Success")
            end
        end
    elseif not Silent then
        Library:Notify("Missing config: " .. Library.ConfigName, 2, "Warning")
    end
end

function Library:DeleteConfig(Name, Silent)
    if not Library.ConfigEnabled then
        return
    end

    local ProfileName = GetConfigBaseName(Name)
    local Path = GetConfigFilePath(ProfileName)
    if isfile(Path) then
        delfile(Path)
        if not Silent then
            Library:Notify("Configuration deleted: " .. ProfileName, 2, "Success")
        end
    elseif not Silent then
        Library:Notify("Missing config: " .. ProfileName, 2, "Warning")
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
            PlayGroupTransparencyTween(Dialog, 0.2, 1)
            TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
            task.wait(0.2)
            Dialog:Destroy()
            Backdrop:Destroy()
            if Library.ActivePopup and Library.ActivePopup.Element == Dialog then
                Library.ActivePopup = nil
            end
            if Callback then Callback(BtnData.Result) end
        end)
    end

    RegisterPopup({
        Element = Dialog,
        Ignore = {Dialog},
        Close = function()
            PlayGroupTransparencyTween(Dialog, 0.2, 1)
            TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
            task.wait(0.2)
            if Dialog.Parent then Dialog:Destroy() end
            if Backdrop.Parent then Backdrop:Destroy() end
        end
    })

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
            Size = UDim2.new(0, Scale(320), 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
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

        ApplyNotificationContainerLayout()
    end

    local function dismissNotification(notificationGui)
        if not notificationGui or notificationGui:GetAttribute("Closing") then return end
        notificationGui:SetAttribute("Closing", true)
        notificationGui.ClipsDescendants = true

        local stroke = notificationGui:FindFirstChildOfClass("UIStroke")
        local accentBar = notificationGui:FindFirstChildOfClass("Frame")

        local outTween = TweenService:Create(notificationGui, CreateTween(0.2), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        if stroke then
            TweenService:Create(stroke, CreateTween(0.2), {Transparency = 1}):Play()
        end
        if accentBar then
            TweenService:Create(accentBar, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
        end
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
        Visible = false,
        ClipsDescendants = true
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
        if Library.ActivePopup.ScrollLock then
            SetScrollLocked(Library.ActivePopup.ScrollLock, false)
        end
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

function Library:SetNotificationOptions(Options)
    Options = Options or {}
    if Options.Position then
        Library.NotificationSettings.Position = tostring(Options.Position)
    end
    if Options.Width then
        Library.NotificationSettings.Width = tonumber(Options.Width) or Library.NotificationSettings.Width
    end
    ApplyNotificationContainerLayout()
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
            PlayGroupTransparencyTween(Library.MainFrame, 0.2, 0)
            local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
            if Stroke then
                TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 0}):Play()
            end
        else
            local Tween = PlayGroupTransparencyTween(Library.MainFrame, 0.2, 1)
            local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
            if Stroke then
                TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 1}):Play()
            end
            task.spawn(function()
                if Tween then
                    Tween.Completed:Wait()
                else
                    task.wait(0.2)
                end
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
        Size = UDim2.new(1, 0, 0, Scale(46)),
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
            Position = UDim2.new(0, Scale(16), 0, Scale(4)),
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
        Position = UDim2.new(1, Scale(-72), 0, Scale(9)),
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
        Position = UDim2.new(1, Scale(-38), 0, Scale(9)),
        Text = "X",
        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextSize = Scale(14),
        AutoButtonColor = false
    }, {TextColor3 = "TextMain"})

    CreateInstance("UICorner", {Parent = CloseButton, CornerRadius = UDim.new(0, Scale(5))})

    local Body = CreateInstance("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, Scale(46)),
        Size = UDim2.new(1, 0, 1, Scale(-46)),
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
        local Tween = PlayGroupTransparencyTween(MainFrame, 0.3, 1)
        local StrokeTween = TweenService:Create(MainStroke, CreateTween(0.3), {Transparency = 1})
        StrokeTween:Play()
        if Tween then
            Tween.Completed:Wait()
        else
            task.wait(0.3)
        end
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
        Size = UDim2.new(0, Scale(132), 1, Scale(-20))
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
        Position = UDim2.new(0, Scale(152), 0, Scale(10)),
        Size = UDim2.new(1, Scale(-167), 1, Scale(-20))
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
    local TabObjects = {}

    function WindowFunctions:AddTab(IconAsset)
        local RequestedIcon = Config.FallbackTabIcon
        local FallbackLabel = ""
        if type(IconAsset) == "string" then
            RequestedIcon = IconAsset ~= "" and IconAsset or Config.FallbackTabIcon
        elseif type(IconAsset) == "table" then
            local FirstIcon = IconAsset.Icon or IconAsset[1]
            if type(FirstIcon) == "string" and FirstIcon ~= "" then
                RequestedIcon = FirstIcon
            end
            local RequestedLabel = IconAsset.Label or IconAsset[2]
            if type(RequestedLabel) == "string" then
                FallbackLabel = RequestedLabel
            end
        end

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
            Image = RequestedIcon
        }, {ImageColor3 = "TextMain"})

        local FallbackText = CreateInstance("TextLabel", {
            Parent = TabButton,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            Text = FallbackLabel,
            TextSize = Scale(12),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center
        }, {TextColor3 = "TextMain"})

        -- Fallback handling for tab icons
        local function showTextFallback()
            if FallbackLabel ~= "" then
                IconImg.Visible = false
                FallbackText.Visible = true
            end
        end

        local function checkIcon()
            if IconImg.Image ~= Config.FallbackTabIcon and IconImg.IsLoaded and IconImg.ImageRectSize == Vector2.zero then
                showTextFallback()
            end
        end
        
        checkIcon()
        IconImg:GetPropertyChangedSignal("IsLoaded"):Connect(checkIcon)        
        task.delay(1, function()
            if IconImg.Parent and (not IconImg.IsLoaded or IconImg.ImageRectSize == Vector2.zero) then
                showTextFallback()
            end
        end)

        table.insert(AllTabs, TabButton)

        local TabFunctions = {}
        local Categories = {}
        local TabSubCategories = {}
        local IsThisTabActive = FirstTab
        local TabFirstSubCategory = true
        local ActiveSubAction = nil
        local CategoryObjects = {}

        table.insert(Library.DynamicUpdates, function()
            if IsThisTabActive then
                IconImg.ImageColor3 = Config.Colors.TextLight
                FallbackText.TextColor3 = Config.Colors.TextLight
                TabButton.BackgroundTransparency = 0.9
            else
                IconImg.ImageColor3 = Config.Colors.TextMain
                FallbackText.TextColor3 = Config.Colors.TextMain
                TabButton.BackgroundTransparency = 1
            end
        end)

        local function ActivateTab()
            if IsAnimatingTab then return end
            Library:ClosePopups()
            for _, TabObject in ipairs(TabObjects) do
                TabObject.IsActive = false
            end
            IsThisTabActive = true

            for _, Btn in ipairs(AllTabs) do
                if Btn:IsA("ImageButton") then
                    TweenService:Create(Btn, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
                    local InnerIcon = Btn:FindFirstChild("ImageLabel")
                    if InnerIcon then
                        TweenService:Create(InnerIcon, CreateTween(0.2), {ImageColor3 = Config.Colors.TextMain}):Play()
                    end
                    local InnerText = Btn:FindFirstChild("TextLabel")
                    if InnerText then
                        TweenService:Create(InnerText, CreateTween(0.2), {TextColor3 = Config.Colors.TextMain}):Play()
                    end
                end
            end

            TweenService:Create(TabButton, CreateTween(0.2), {BackgroundTransparency = 0.9}):Play()
            TweenService:Create(IconImg, CreateTween(0.2), {ImageColor3 = Config.Colors.TextLight}):Play()
            TweenService:Create(FallbackText, CreateTween(0.2), {TextColor3 = Config.Colors.TextLight}):Play()

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

        function TabFunctions:Select()
            ActivateTab()
        end

        function TabFunctions:IsSelected()
            return IsThisTabActive
        end

        function TabFunctions:GetCategories()
            return CategoryObjects
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
            local SubCategoryObjects = {}
            table.insert(CategoryObjects, CategoryFunctions)

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
                SubFunctions._state = SubState
                SubFunctions._sections = AssociatedSections
                table.insert(SubCategoryObjects, SubFunctions)

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
                    if not IsThisTabActive then
                        ActivateTab()
                    end
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

                function SubFunctions:Select(NoFade)
                    SelectSubCategory(NoFade == true)
                end

                function SubFunctions:IsSelected()
                    return SubState.bIsActive
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
                    SectionFunctions._frame = SectionFrame
                    SectionFunctions._expanded = true

                    local function SetExpanded(Expanded)
                        SecOpen = Expanded and true or false
                        SectionFunctions._expanded = SecOpen
                        ElementsContainer.Visible = SecOpen
                        TweenService:Create(SecIcon, CreateTween(0.2), {Rotation = SecOpen and 0 or -90}):Play()
                    end

                    function SectionFunctions:Expand()
                        SetExpanded(true)
                    end

                    function SectionFunctions:Collapse()
                        SetExpanded(false)
                    end

                    function SectionFunctions:ToggleExpanded()
                        SetExpanded(not SecOpen)
                    end

                    function SectionFunctions:IsExpanded()
                        return SecOpen
                    end

                    function SectionFunctions:Description(Props)
                        local Text = Props
                        local Options = {}
                        if type(Props) == "table" then
                            Text = Props.Text or Props.Title or Props.Description or ""
                            Options = Props
                        end

                        local DescriptionFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BorderSizePixel = 0
                        })

                        local DescriptionLabel = CreateInstance("TextLabel", {
                            Parent = DescriptionFrame,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            TextWrapped = true,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            Text = tostring(Text or "")
                        }, {TextColor3 = "TextMain"})
                        ApplyTextOptions(DescriptionLabel, Options)

                        local DescriptionFunctions = {}
                        function DescriptionFunctions:SetValue(Value)
                            DescriptionLabel.Text = tostring(Value or "")
                        end
                        function DescriptionFunctions:GetValue()
                            return DescriptionLabel.Text
                        end

                        AttachControlStateApi(DescriptionFunctions, {
                            Root = DescriptionFrame,
                            TextTargets = {DescriptionLabel},
                            Tooltip = Options.Tooltip
                        })

                        return DescriptionFunctions
                    end

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

                    function SectionFunctions:Row(Props)
                        Props = Props or {}
                        local RowFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = Props.BackgroundTransparency or 1,
                            Size = Props.Size or UDim2.new(1, 0, 0, Props.Height or Scale(26)),
                            AutomaticSize = Props.AutomaticSize or Enum.AutomaticSize.None,
                            BorderSizePixel = 0
                        })

                        if Props.BackgroundColor then
                            RowFrame.BackgroundColor3 = Props.BackgroundColor
                        end

                        if Props.CornerRadius then
                            CreateInstance("UICorner", {Parent = RowFrame, CornerRadius = UDim.new(0, Props.CornerRadius)})
                        end

                        if Props.Border then
                            CreateInstance("UIStroke", {
                                Parent = RowFrame,
                                Thickness = Props.Border.Thickness or 1,
                                Color = Props.Border.Color or Config.Colors.Border
                            })
                        end

                        CreateInstance("UIListLayout", {
                            Parent = RowFrame,
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Props.VerticalAlignment or Enum.VerticalAlignment.Center,
                            HorizontalAlignment = Props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
                            Padding = UDim.new(0, Props.Padding or Scale(6))
                        })

                        if Props.PaddingX or Props.PaddingY then
                            CreateInstance("UIPadding", {
                                Parent = RowFrame,
                                PaddingTop = UDim.new(0, Props.PaddingY or 0),
                                PaddingBottom = UDim.new(0, Props.PaddingY or 0),
                                PaddingLeft = UDim.new(0, Props.PaddingX or 0),
                                PaddingRight = UDim.new(0, Props.PaddingX or 0)
                            })
                        end

                        local RowFunctions = {}

                        function RowFunctions:GetContainer()
                            return RowFrame
                        end

                        function RowFunctions:Add(ItemProps)
                            ItemProps = ItemProps or {}
                            local Item = CreateInstance(ItemProps.ClassName or "Frame", {
                                Parent = RowFrame,
                                BackgroundTransparency = ItemProps.BackgroundTransparency or 1,
                                Size = ItemProps.Size or UDim2.new(0, ItemProps.Width or Scale(80), 1, 0),
                                AutomaticSize = ItemProps.AutomaticSize or Enum.AutomaticSize.None,
                                BorderSizePixel = 0
                            })

                            if ItemProps.BackgroundColor then
                                Item.BackgroundColor3 = ItemProps.BackgroundColor
                            end

                            if ItemProps.Text and (Item:IsA("TextLabel") or Item:IsA("TextButton") or Item:IsA("TextBox")) then
                                Item.Text = ItemProps.Text
                            end

                            return Item
                        end

                        function RowFunctions:AddSpacer(Width)
                            return CreateInstance("Frame", {
                                Parent = RowFrame,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, Width or Scale(8), 1, 0),
                                BorderSizePixel = 0
                            })
                        end

                        function RowFunctions:SetVisible(Visible)
                            RowFrame.Visible = Visible
                        end

                        AttachControlStateApi(RowFunctions, {
                            Root = RowFrame,
                            Tooltip = Props.Tooltip
                        })
                        return RowFunctions
                    end

                    function SectionFunctions:Columns(Props)
                        Props = Props or {}
                        local Count = math.max(1, Props.Count or 2)
                        local ColumnsFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Props.Height or Scale(120)),
                            AutomaticSize = Props.AutomaticSize or Enum.AutomaticSize.None,
                            BorderSizePixel = 0
                        })

                        CreateInstance("UIListLayout", {
                            Parent = ColumnsFrame,
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, Props.Padding or Scale(8))
                        })

                        local ColumnFrames = {}
                        local WidthOffset = -(((Count - 1) * (Props.Padding or Scale(8))) / Count)
                        for Index = 1, Count do
                            local Column = CreateInstance("Frame", {
                                Parent = ColumnsFrame,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1 / Count, WidthOffset, 1, 0),
                                AutomaticSize = Enum.AutomaticSize.Y,
                                BorderSizePixel = 0
                            })
                            CreateInstance("UIListLayout", {
                                Parent = Column,
                                Padding = UDim.new(0, Props.ColumnPadding or Scale(6))
                            })
                            table.insert(ColumnFrames, Column)
                        end

                        local ColumnFunctions = {}

                        function ColumnFunctions:GetColumn(Index)
                            return ColumnFrames[Index]
                        end

                        function ColumnFunctions:AddToColumn(Index, Properties)
                            local Target = ColumnFrames[Index]
                            if not Target then
                                return nil
                            end

                            Properties = Properties or {}
                            local Container = CreateInstance("Frame", {
                                Parent = Target,
                                BackgroundTransparency = Properties.BackgroundTransparency or 1,
                                Size = Properties.Size or UDim2.new(1, 0, 0, Properties.Height or Scale(24)),
                                AutomaticSize = Properties.AutomaticSize or Enum.AutomaticSize.None,
                                BorderSizePixel = 0
                            })

                            if Properties.BackgroundColor then
                                Container.BackgroundColor3 = Properties.BackgroundColor
                            end

                            if Properties.CornerRadius then
                                CreateInstance("UICorner", {Parent = Container, CornerRadius = UDim.new(0, Properties.CornerRadius)})
                            end

                            if Properties.Border then
                                CreateInstance("UIStroke", {
                                    Parent = Container,
                                    Thickness = Properties.Border.Thickness or 1,
                                    Color = Properties.Border.Color or Config.Colors.Border
                                })
                            end

                            return Container
                        end

                        AttachControlStateApi(ColumnFunctions, {
                            Root = ColumnsFrame,
                            Tooltip = Props.Tooltip
                        })
                        return ColumnFunctions
                    end

                    function SectionFunctions:Stat(Props)
                        Props = Props or {}
                        local StatFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BorderSizePixel = 0,
                            Size = Props.Size or UDim2.new(1, 0, 0, Props.Height or Scale(44))
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = StatFrame, CornerRadius = UDim.new(0, Scale(5))})
                        CreateInstance("UIStroke", {Parent = StatFrame, Thickness = 1}, {Color = "Border"})
                        CreateInstance("UIPadding", {
                            Parent = StatFrame,
                            PaddingTop = UDim.new(0, Scale(6)),
                            PaddingBottom = UDim.new(0, Scale(6)),
                            PaddingLeft = UDim.new(0, Scale(8)),
                            PaddingRight = UDim.new(0, Scale(8))
                        })

                        local Row = CreateInstance("Frame", {
                            Parent = StatFrame,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 1, 0),
                            BorderSizePixel = 0
                        })

                        CreateInstance("UIListLayout", {
                            Parent = Row,
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            Padding = UDim.new(0, Scale(8))
                        })

                        if Props.Icon then
                            CreateInstance("ImageLabel", {
                                Parent = Row,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, Scale(18), 0, Scale(18)),
                                Image = Props.Icon
                            }, {ImageColor3 = "TextLight"})
                        end

                        local TextWrap = CreateInstance("Frame", {
                            Parent = Row,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, Props.RightText and Scale(-60) or 0, 1, 0),
                            BorderSizePixel = 0
                        })

                        local TitleLabel = CreateInstance("TextLabel", {
                            Parent = TextWrap,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(14)),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            Text = Props.Title or "Stat"
                        }, {TextColor3 = "TextMain"})

                        local ValueLabel = CreateInstance("TextLabel", {
                            Parent = TextWrap,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(14)),
                            Size = UDim2.new(1, 0, 0, Scale(18)),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
                            TextSize = Scale(13),
                            Text = tostring(Props.Value or "0")
                        }, {TextColor3 = "TextLight"})

                        local RightLabel = nil
                        if Props.RightText then
                            RightLabel = CreateInstance("TextLabel", {
                                Parent = Row,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, Scale(56), 1, 0),
                                FontFace = Config.Font,
                                TextSize = Scale(10),
                                TextXAlignment = Enum.TextXAlignment.Right,
                                Text = Props.RightText
                            }, {TextColor3 = "TextMain"})
                        end

                        local StatFunctions = {}
                        function StatFunctions:SetValue(Value)
                            ValueLabel.Text = tostring(Value)
                        end
                        function StatFunctions:GetValue()
                            return ValueLabel.Text
                        end
                        function StatFunctions:SetTitle(Value)
                            TitleLabel.Text = tostring(Value)
                        end
                        function StatFunctions:SetRightText(Value)
                            if RightLabel then
                                RightLabel.Text = tostring(Value)
                            end
                        end

                        AttachControlStateApi(StatFunctions, {
                            Root = StatFrame,
                            TextTargets = {ValueLabel},
                            Tooltip = Props.Tooltip
                        })

                        if Props.Flag then
                            Library.Flags[Props.Flag] = StatFunctions
                        end
                        return StatFunctions
                    end

                    function SectionFunctions:List(Props)
                        Props = Props or {}
                        local Items = Props.Items or {}
                        local SelectedIndex = nil
                        local RowHeight = Props.RowHeight or Scale(34)

                        local ListFrame = CreateInstance("Frame", {
                            Parent = Props.Parent or ElementsContainer,
                            BackgroundTransparency = 1,
                            Position = Props.Position or UDim2.new(0, 0, 0, 0),
                            Size = UDim2.new(1, 0, 0, Props.Height or Scale(160)),
                            BorderSizePixel = 0
                        })

                        if Props.Title then
                            local TitleLabel = CreateInstance("TextLabel", {
                                Parent = ListFrame,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, Scale(16)),
                                FontFace = Config.Font,
                                TextSize = Scale(11),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Text = Props.Title
                            }, {TextColor3 = "TextMain"})
                            TitleLabel.Name = "ListTitle"
                        end

                        local ListScroll = CreateInstance("ScrollingFrame", {
                            Parent = ListFrame,
                            BackgroundTransparency = 0,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Props.Title and Scale(18) or 0),
                            Size = UDim2.new(1, 0, 1, Props.Title and Scale(-18) or 0),
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            ScrollBarThickness = 2,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y
                        }, {BackgroundColor3 = "ElementBg", ScrollBarImageColor3 = "Border"})

                        CreateInstance("UICorner", {Parent = ListScroll, CornerRadius = UDim.new(0, Scale(5))})
                        CreateInstance("UIStroke", {Parent = ListScroll, Thickness = 1}, {Color = "Border"})

                        local ListContent = CreateInstance("Frame", {
                            Parent = ListScroll,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, Scale(-4), 0, 0),
                            Position = UDim2.new(0, Scale(2), 0, Scale(2)),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BorderSizePixel = 0
                        })

                        CreateInstance("UIListLayout", {
                            Parent = ListContent,
                            Padding = UDim.new(0, Scale(4))
                        })

                        local EmptyLabel = CreateInstance("TextLabel", {
                            Parent = ListContent,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(24)),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            Text = Props.EmptyText or "No items",
                            Visible = false
                        }, {TextColor3 = "TextMain"})

                        local RowRefs = {}
                        local ListFunctions = {}

                        local function GetItemTitle(Item)
                            if type(Item) == "table" then
                                return tostring(Item.Title or Item.Name or Item.Value or "Item")
                            end
                            return tostring(Item)
                        end

                        local function GetItemDescription(Item)
                            if type(Item) == "table" then
                                return tostring(Item.Description or "")
                            end
                            return ""
                        end

                        local function GetItemRight(Item)
                            if type(Item) == "table" then
                                return tostring(Item.RightText or Item.Right or "")
                            end
                            return ""
                        end

                        local function ApplySelection()
                            for Index, Row in ipairs(RowRefs) do
                                local IsSelected = Index == SelectedIndex
                                TweenService:Create(Row.Button, CreateTween(0.15), {
                                    BackgroundColor3 = IsSelected and Config.Colors.SectionBg or Config.Colors.ElementBg
                                }):Play()
                                TweenService:Create(Row.Stroke, CreateTween(0.15), {
                                    Color = IsSelected and Config.Colors.Accent or Config.Colors.Border
                                }):Play()
                            end
                        end

                        local function Rebuild()
                            for _, Row in ipairs(RowRefs) do
                                Row.Button:Destroy()
                            end
                            table.clear(RowRefs)

                            EmptyLabel.Visible = #Items == 0
                            if #Items == 0 then
                                return
                            end

                            for Index, Item in ipairs(Items) do
                                local Button = CreateInstance("TextButton", {
                                    Parent = ListContent,
                                    BorderSizePixel = 0,
                                    Size = UDim2.new(1, 0, 0, RowHeight),
                                    AutoButtonColor = false,
                                    Text = ""
                                }, {BackgroundColor3 = "ElementBg"})

                                CreateInstance("UICorner", {Parent = Button, CornerRadius = UDim.new(0, Scale(4))})
                                local Stroke = CreateInstance("UIStroke", {Parent = Button, Thickness = 1}, {Color = "Border"})

                                local TitleLabel = CreateInstance("TextLabel", {
                                    Parent = Button,
                                    BackgroundTransparency = 1,
                                    Position = UDim2.new(0, Scale(8), 0, Scale(5)),
                                    Size = UDim2.new(1, Scale(-72), 0, Scale(12)),
                                    FontFace = Config.Font,
                                    TextSize = Scale(11),
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                    Text = GetItemTitle(Item)
                                }, {TextColor3 = "TextLight"})

                                local DescriptionLabel = CreateInstance("TextLabel", {
                                    Parent = Button,
                                    BackgroundTransparency = 1,
                                    Position = UDim2.new(0, Scale(8), 0, Scale(18)),
                                    Size = UDim2.new(1, Scale(-72), 0, Scale(11)),
                                    FontFace = Config.Font,
                                    TextSize = Scale(9),
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                    Text = GetItemDescription(Item),
                                    Visible = GetItemDescription(Item) ~= ""
                                }, {TextColor3 = "TextMain"})

                                local RightLabel = CreateInstance("TextLabel", {
                                    Parent = Button,
                                    BackgroundTransparency = 1,
                                    Position = UDim2.new(1, Scale(-64), 0, 0),
                                    Size = UDim2.new(0, Scale(56), 1, 0),
                                    FontFace = Config.Font,
                                    TextSize = Scale(10),
                                    TextXAlignment = Enum.TextXAlignment.Right,
                                    Text = GetItemRight(Item)
                                }, {TextColor3 = "TextMain"})
                                ApplyTextOptions(TitleLabel, Props)
                                ApplyTextOptions(DescriptionLabel, Props)
                                ApplyTextOptions(RightLabel, Props)

                                Button.MouseEnter:Connect(function()
                                    if SelectedIndex ~= Index then
                                        TweenService:Create(Stroke, CreateTween(0.15), {Color = Config.Colors.Accent}):Play()
                                    end
                                end)
                                Button.MouseLeave:Connect(function()
                                    if SelectedIndex ~= Index then
                                        TweenService:Create(Stroke, CreateTween(0.15), {Color = Config.Colors.Border}):Play()
                                    end
                                end)
                                Button.MouseButton1Click:Connect(function()
                                    SelectedIndex = Index
                                    ApplySelection()
                                    if Props.Callback then
                                        Props.Callback(Item, Index)
                                    end
                                end)

                                table.insert(RowRefs, {
                                    Button = Button,
                                    Stroke = Stroke,
                                    Item = Item,
                                    Title = TitleLabel,
                                    Description = DescriptionLabel,
                                    Right = RightLabel
                                })
                            end

                            ApplySelection()
                        end

                        function ListFunctions:SetItems(NewItems)
                            Items = NewItems or {}
                            if SelectedIndex and SelectedIndex > #Items then
                                SelectedIndex = nil
                            end
                            Rebuild()
                        end

                        function ListFunctions:AddItem(Item)
                            table.insert(Items, Item)
                            Rebuild()
                        end

                        function ListFunctions:Clear()
                            Items = {}
                            SelectedIndex = nil
                            Rebuild()
                        end

                        function ListFunctions:SetValue(Index)
                            SelectedIndex = Index
                            ApplySelection()
                        end

                        function ListFunctions:GetValue()
                            return SelectedIndex and Items[SelectedIndex] or nil
                        end

                        function ListFunctions:GetItems()
                            return Items
                        end
                        ListFunctions.IncludeInConfig = Props.IncludeInConfig == true

                        Rebuild()

                        AttachControlStateApi(ListFunctions, {
                            Root = ListFrame,
                            Interactive = {ListScroll},
                            Tooltip = Props.Tooltip
                        })

                        if Props.Flag then
                            Library.Flags[Props.Flag] = ListFunctions
                        end
                        return ListFunctions
                    end

                    function SectionFunctions:Keybind(Props)
                        Props = Props or {}
                        local Binding = Props.Default
                        local Listening = false

                        local KeybindFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(24))
                        })

                        local Title = CreateInstance("TextLabel", {
                            Parent = KeybindFrame,
                            BackgroundTransparency = 1,
                            Text = Props.Title or "Keybind",
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, Scale(-82), 1, 0)
                        }, {TextColor3 = "TextMain"})

                        local BindButton = CreateInstance("TextButton", {
                            Parent = KeybindFrame,
                            BorderSizePixel = 0,
                            AnchorPoint = Vector2.new(1, 0),
                            Position = UDim2.new(1, 0, 0, 0),
                            Size = UDim2.new(0, Scale(76), 1, 0),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            AutoButtonColor = false,
                            Text = GetBindText(Binding)
                        }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextLight"})

                        CreateInstance("UICorner", {Parent = BindButton, CornerRadius = UDim.new(0, Scale(4))})
                        local BindStroke = CreateInstance("UIStroke", {Parent = BindButton, Thickness = 1}, {Color = "Border"})
                        ApplyTextOptions(Title, Props)
                        ApplyTextOptions(BindButton, Props)

                        local CaptureConnection

                        local function StopListening(NewBind)
                            Listening = false
                            TweenService:Create(BindStroke, CreateTween(0.15), {Color = Config.Colors.Border}):Play()
                            if CaptureConnection then
                                CaptureConnection:Disconnect()
                                CaptureConnection = nil
                            end
                            if NewBind ~= nil then
                                Binding = NewBind
                                BindButton.Text = GetBindText(Binding)
                                if Props.Callback then
                                    Props.Callback(Binding)
                                end
                            else
                                BindButton.Text = GetBindText(Binding)
                            end
                        end

                        BindButton.MouseButton1Click:Connect(function()
                            if Listening then
                                StopListening(nil)
                                return
                            end

                            Listening = true
                            BindButton.Text = "Press..."
                            TweenService:Create(BindStroke, CreateTween(0.15), {Color = Config.Colors.Accent}):Play()

                            CaptureConnection = UserInputService.InputBegan:Connect(function(Input, Processed)
                                if Processed then
                                    return
                                end
                                if Input.KeyCode == Enum.KeyCode.Escape then
                                    StopListening(nil)
                                    return
                                end
                                if Input.UserInputType == Enum.UserInputType.Keyboard then
                                    StopListening(Input.KeyCode)
                                elseif Input.UserInputType == Enum.UserInputType.MouseButton1
                                    or Input.UserInputType == Enum.UserInputType.MouseButton2
                                    or Input.UserInputType == Enum.UserInputType.MouseButton3 then
                                    StopListening(Input.UserInputType)
                                end
                            end)
                        end)

                        local KeybindFunctions = {}
                        function KeybindFunctions:SetValue(Value)
                            Binding = Value
                            BindButton.Text = GetBindText(Binding)
                        end
                        function KeybindFunctions:GetValue()
                            return Binding
                        end
                        function KeybindFunctions:Clear()
                            KeybindFunctions:SetValue(nil)
                            if Props.Callback then
                                Props.Callback(nil)
                            end
                        end
                        KeybindFunctions.DefaultValue = Props.Default
                        KeybindFunctions.IncludeInConfig = Props.IncludeInConfig ~= false

                        AttachControlStateApi(KeybindFunctions, {
                            Root = KeybindFrame,
                            Interactive = {BindButton},
                            TextTargets = {BindButton},
                            Tooltip = Props.Tooltip,
                            Cleanup = {
                                function()
                                    if CaptureConnection then
                                        CaptureConnection:Disconnect()
                                        CaptureConnection = nil
                                    end
                                end
                            },
                            SetDisabledState = function(Disabled)
                                if Disabled and Listening then
                                    StopListening(nil)
                                end
                            end
                        })

                        if Props.Flag then
                            Library.Flags[Props.Flag] = KeybindFunctions
                        end
                        return KeybindFunctions
                    end

                    function SectionFunctions:Table(Props)
                        Props = Props or {}
                        local Columns = Props.Columns or {}
                        local Rows = Props.Rows or {}
                        local RowHeight = Props.RowHeight or Scale(24)
                        local TableState = "ready"
                        local StateMessage = ""
                        local SortColumn = nil
                        local SortDirection = "asc"

                        local TableFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Props.Height or Scale(180)),
                            BorderSizePixel = 0
                        })

                        if Props.Title then
                            local TitleLabel = CreateInstance("TextLabel", {
                                Parent = TableFrame,
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, Scale(16)),
                                FontFace = Config.Font,
                                TextSize = Scale(11),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Text = Props.Title
                            }, {TextColor3 = "TextMain"})
                            ApplyTextOptions(TitleLabel, Props)
                        end

                        local HeaderFrame = CreateInstance("Frame", {
                            Parent = TableFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Props.Title and Scale(18) or 0),
                            Size = UDim2.new(1, 0, 0, Scale(22))
                        }, {BackgroundColor3 = "ElementBg"})
                        CreateInstance("UICorner", {Parent = HeaderFrame, CornerRadius = UDim.new(0, Scale(4))})
                        CreateInstance("UIStroke", {Parent = HeaderFrame, Thickness = 1}, {Color = "Border"})

                        local HeaderLayout = CreateInstance("UIListLayout", {
                            Parent = HeaderFrame,
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, Scale(4))
                        })

                        local HeaderPadding = CreateInstance("UIPadding", {
                            Parent = HeaderFrame,
                            PaddingLeft = UDim.new(0, Scale(8)),
                            PaddingRight = UDim.new(0, Scale(8))
                        })

                        local BodyScroll = CreateInstance("ScrollingFrame", {
                            Parent = TableFrame,
                            BackgroundTransparency = 0,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, (Props.Title and Scale(18) or 0) + Scale(26)),
                            Size = UDim2.new(1, 0, 1, -((Props.Title and Scale(18) or 0) + Scale(26))),
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            ScrollBarThickness = 2
                        }, {BackgroundColor3 = "ElementBg", ScrollBarImageColor3 = "Border"})
                        CreateInstance("UICorner", {Parent = BodyScroll, CornerRadius = UDim.new(0, Scale(4))})
                        CreateInstance("UIStroke", {Parent = BodyScroll, Thickness = 1}, {Color = "Border"})

                        local BodyContent = CreateInstance("Frame", {
                            Parent = BodyScroll,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, Scale(2), 0, Scale(2)),
                            Size = UDim2.new(1, Scale(-4), 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BorderSizePixel = 0
                        })
                        CreateInstance("UIListLayout", {Parent = BodyContent, Padding = UDim.new(0, Scale(4))})

                        local StateLabel = CreateInstance("TextLabel", {
                            Parent = BodyScroll,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, Scale(-12), 0, Scale(24)),
                            Position = UDim2.new(0, Scale(6), 0, Scale(8)),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = "",
                            Visible = false
                        }, {TextColor3 = "TextMain"})

                        local RebuildRows
                        local function BuildColumns(Target, TextColorKey, IsHeader)
                            local TotalWeight = 0
                            for _, Column in ipairs(Columns) do
                                TotalWeight += Column.Width or 1
                            end
                            local Padding = math.max(0, (#Columns - 1) * Scale(4))
                            local WidthOffset = -Padding

                            for _, Column in ipairs(Columns) do
                                local HeaderParent = Target
                                local Label
                                if IsHeader then
                                    HeaderParent = CreateInstance("TextButton", {
                                        Parent = Target,
                                        BackgroundTransparency = 1,
                                        AutoButtonColor = false,
                                        Text = "",
                                        Size = UDim2.new((Column.Width or 1) / math.max(1, TotalWeight), WidthOffset / math.max(1, #Columns), 1, 0)
                                    })
                                    Label = CreateInstance("TextLabel", {
                                        Parent = HeaderParent,
                                        BackgroundTransparency = 1,
                                        Size = UDim2.new(1, 0, 1, 0),
                                        FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
                                        TextSize = Scale(10),
                                        TextXAlignment = Column.Alignment or Enum.TextXAlignment.Left,
                                        Text = tostring(Column.Title or Column.Key or "")
                                    }, {TextColor3 = TextColorKey})
                                    HeaderParent.MouseButton1Click:Connect(function()
                                        if SortColumn == Column.Key then
                                            SortDirection = SortDirection == "asc" and "desc" or "asc"
                                        else
                                            SortColumn = Column.Key
                                            SortDirection = "asc"
                                        end
                                        RebuildRows()
                                    end)
                                else
                                    Label = CreateInstance("TextLabel", {
                                        Parent = HeaderParent,
                                        BackgroundTransparency = 1,
                                        Size = UDim2.new((Column.Width or 1) / math.max(1, TotalWeight), WidthOffset / math.max(1, #Columns), 1, 0),
                                        FontFace = Config.Font,
                                        TextSize = Scale(9),
                                        TextXAlignment = Column.Alignment or Enum.TextXAlignment.Left,
                                        Text = tostring(Column.Title or Column.Key or "")
                                    }, {TextColor3 = TextColorKey})
                                end
                                Label.TextTruncate = Enum.TextTruncate.AtEnd
                                ApplyTextOptions(Label, Column)
                            end
                        end

                        local function GetSortedRows()
                            local SortedRows = table.clone(Rows)
                            if not SortColumn then
                                return SortedRows
                            end
                            table.sort(SortedRows, function(A, B)
                                local AV = type(A) == "table" and A[SortColumn] or nil
                                local BV = type(B) == "table" and B[SortColumn] or nil
                                if tonumber(AV) and tonumber(BV) then
                                    AV = tonumber(AV)
                                    BV = tonumber(BV)
                                else
                                    AV = tostring(AV or "")
                                    BV = tostring(BV or "")
                                end
                                if SortDirection == "desc" then
                                    return AV > BV
                                end
                                return AV < BV
                            end)
                            return SortedRows
                        end

                        RebuildRows = function()
                            for _, Child in ipairs(BodyContent:GetChildren()) do
                                if Child:IsA("Frame") then
                                    Child:Destroy()
                                end
                            end

                            if TableState ~= "ready" then
                                BodyContent.Visible = false
                                StateLabel.Visible = true
                                if TableState == "loading" then
                                    StateLabel.Text = StateMessage ~= "" and StateMessage or "Loading..."
                                elseif TableState == "error" then
                                    StateLabel.Text = StateMessage ~= "" and StateMessage or "Something went wrong"
                                else
                                    StateLabel.Text = StateMessage ~= "" and StateMessage or "No rows"
                                end
                                return
                            end

                            BodyContent.Visible = true
                            StateLabel.Visible = false

                            local SortedRows = GetSortedRows()
                            if #SortedRows == 0 then
                                BodyContent.Visible = false
                                StateLabel.Visible = true
                                StateLabel.Text = Props.EmptyText or "No rows"
                                return
                            end

                            for _, Row in ipairs(SortedRows) do
                                local RowFrame = CreateInstance("Frame", {
                                    Parent = BodyContent,
                                    BorderSizePixel = 0,
                                    Size = UDim2.new(1, 0, 0, RowHeight)
                                }, {BackgroundColor3 = "PanelBg"})
                                CreateInstance("UICorner", {Parent = RowFrame, CornerRadius = UDim.new(0, Scale(4))})
                                CreateInstance("UIStroke", {Parent = RowFrame, Thickness = 1}, {Color = "Border"})
                                CreateInstance("UIListLayout", {
                                    Parent = RowFrame,
                                    FillDirection = Enum.FillDirection.Horizontal,
                                    Padding = UDim.new(0, Scale(4))
                                })
                                CreateInstance("UIPadding", {
                                    Parent = RowFrame,
                                    PaddingLeft = UDim.new(0, Scale(8)),
                                    PaddingRight = UDim.new(0, Scale(8))
                                })

                                local TotalWeight = 0
                                for _, Column in ipairs(Columns) do
                                    TotalWeight += Column.Width or 1
                                end
                                local Padding = math.max(0, (#Columns - 1) * Scale(4))
                                local WidthOffset = -Padding

                                for _, Column in ipairs(Columns) do
                                    local Value = ""
                                    if type(Row) == "table" then
                                        Value = Row[Column.Key] or Row[Column.Title] or ""
                                    end
                                    local Label = CreateInstance("TextLabel", {
                                        Parent = RowFrame,
                                        BackgroundTransparency = 1,
                                        Size = UDim2.new((Column.Width or 1) / math.max(1, TotalWeight), WidthOffset / math.max(1, #Columns), 1, 0),
                                        FontFace = Config.Font,
                                        TextSize = Scale(9),
                                        TextXAlignment = Column.Alignment or Enum.TextXAlignment.Left,
                                        Text = tostring(Value)
                                    }, {TextColor3 = "TextLight"})
                                    Label.TextTruncate = Enum.TextTruncate.AtEnd
                                    ApplyTextOptions(Label, Column)
                                end
                            end
                        end

                        BuildColumns(HeaderFrame, "TextMain", true)
                        RebuildRows()

                        local TableFunctions = {}
                        function TableFunctions:SetRows(NewRows)
                            Rows = NewRows or {}
                            TableState = "ready"
                            RebuildRows()
                        end
                        function TableFunctions:AddRow(Row)
                            table.insert(Rows, Row)
                            TableState = "ready"
                            RebuildRows()
                        end
                        function TableFunctions:Clear()
                            Rows = {}
                            RebuildRows()
                        end
                        function TableFunctions:SetState(State, Message)
                            TableState = State or "ready"
                            StateMessage = tostring(Message or "")
                            RebuildRows()
                        end
                        function TableFunctions:SortBy(ColumnKey, Direction)
                            SortColumn = ColumnKey
                            SortDirection = Direction or "asc"
                            RebuildRows()
                        end
                        function TableFunctions:GetValue()
                            return Rows
                        end
                        TableFunctions.IncludeInConfig = Props.IncludeInConfig == true

                        AttachControlStateApi(TableFunctions, {
                            Root = TableFrame,
                            Interactive = {BodyScroll},
                            Tooltip = Props.Tooltip
                        })

                        if Props.Flag then
                            Library.Flags[Props.Flag] = TableFunctions
                        end
                        return TableFunctions
                    end

                    function SectionFunctions:ConfigManager(Props)
                        Props = Props or {}
                        local ManagerFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(176)),
                            BorderSizePixel = 0
                        })

                        local Header = CreateInstance("TextLabel", {
                            Parent = ManagerFrame,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(16)),
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = Props.Title or "Config Manager"
                        }, {TextColor3 = "TextMain"})

                        local InputContainer = CreateInstance("Frame", {
                            Parent = ManagerFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(20)),
                            Size = UDim2.new(1, 0, 0, Scale(24))
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = InputContainer, CornerRadius = UDim.new(0, Scale(4))})
                        CreateInstance("UIStroke", {Parent = InputContainer, Thickness = 1}, {Color = "Border"})

                        local ProfileInput = CreateInstance("TextBox", {
                            Parent = InputContainer,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, Scale(8), 0, 0),
                            Size = UDim2.new(1, Scale(-16), 1, 0),
                            FontFace = Config.Font,
                            TextSize = Scale(11),
                            ClearTextOnFocus = false,
                            PlaceholderText = "Profile name",
                            Text = Library.ConfigName
                        }, {TextColor3 = "TextLight", PlaceholderColor3 = "TextMain"})

                        local Actions = CreateInstance("Frame", {
                            Parent = ManagerFrame,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(50)),
                            Size = UDim2.new(1, 0, 0, Scale(26)),
                            BorderSizePixel = 0
                        })

                        CreateInstance("UIListLayout", {
                            Parent = Actions,
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, Scale(6))
                        })

                        local ProfilesLabel = CreateInstance("TextLabel", {
                            Parent = ManagerFrame,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(82)),
                            Size = UDim2.new(1, 0, 0, Scale(14)),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = ""
                        }, {TextColor3 = "TextMain"})

                        local ActiveLabel = CreateInstance("TextLabel", {
                            Parent = ManagerFrame,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(100)),
                            Size = UDim2.new(1, 0, 0, Scale(14)),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = ""
                        }, {TextColor3 = "TextLight"})

                        local ListWidget = SectionFunctions:List({
                            Parent = ManagerFrame,
                            Position = UDim2.new(0, 0, 0, Scale(116)),
                            Title = nil,
                            Height = Scale(58),
                            EmptyText = "No saved profiles",
                            Items = {},
                            Callback = function(Item)
                                ProfileInput.Text = tostring(Item)
                            end
                        })

                        local function GetSelectedProfile()
                            local Raw = ProfileInput.Text ~= "" and ProfileInput.Text or Library.ConfigName
                            return GetConfigBaseName(Raw)
                        end

                        local function RefreshProfiles()
                            local Profiles = Library:GetConfigProfiles()
                            ProfilesLabel.Text = "Profiles: " .. (#Profiles > 0 and table.concat(Profiles, ", ") or "None")
                            ActiveLabel.Text = "Active: " .. Library.ConfigName
                            ListWidget:SetItems(Profiles)
                        end

                        local function CreateActionButton(Text, Callback)
                            local Button = CreateInstance("TextButton", {
                                Parent = Actions,
                                BorderSizePixel = 0,
                                Size = UDim2.new(0.25, Scale(-5), 1, 0),
                                FontFace = Config.Font,
                                TextSize = Scale(10),
                                Text = Text,
                                AutoButtonColor = false
                            }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextLight"})
                            CreateInstance("UICorner", {Parent = Button, CornerRadius = UDim.new(0, Scale(4))})
                            local Stroke = CreateInstance("UIStroke", {Parent = Button, Thickness = 1}, {Color = "Border"})
                            CreateInteractiveFeedback({
                                Interactive = {Button},
                                Targets = {
                                    Surface = {Object = Button, Time = 0.1},
                                    Stroke = {Object = Stroke, Time = 0.1},
                                    Text = {Object = Button, Time = 0.1}
                                },
                                Default = {
                                    Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Border, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                },
                                Hover = {
                                    Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                },
                                Pressed = {
                                    Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                }
                            })
                            Button.MouseButton1Click:Connect(Callback)
                            return Button
                        end

                        local Buttons = {
                            CreateActionButton("Save", function()
                                local Profile = GetSelectedProfile()
                                Library:SaveConfig(Profile)
                                RefreshProfiles()
                            end),
                            CreateActionButton("Load", function()
                                local Profile = GetSelectedProfile()
                                Library:LoadConfig(Profile)
                                RefreshProfiles()
                            end),
                            CreateActionButton("Delete", function()
                                local Profile = GetSelectedProfile()
                                Library:DeleteConfig(Profile)
                                RefreshProfiles()
                            end),
                            CreateActionButton("Refresh", RefreshProfiles)
                        }

                        RefreshProfiles()

                        local ManagerFunctions = {}
                        function ManagerFunctions:GetValue()
                            return GetSelectedProfile()
                        end
                        function ManagerFunctions:SetValue(Value)
                            ProfileInput.Text = GetConfigBaseName(Value)
                        end
                        function ManagerFunctions:Refresh()
                            RefreshProfiles()
                        end
                        ManagerFunctions.IncludeInConfig = false

                        AttachControlStateApi(ManagerFunctions, {
                            Root = ManagerFrame,
                            Interactive = {ProfileInput, Buttons[1], Buttons[2], Buttons[3], Buttons[4]},
                            TextTargets = {Buttons[1], Buttons[2], Buttons[3], Buttons[4]},
                            Tooltip = Props.Tooltip
                        })

                        if Props.Flag then
                            Library.Flags[Props.Flag] = ManagerFunctions
                        end
                        return ManagerFunctions
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
                            local Feedback = CreateInteractiveFeedback({
                                Interactive = {Btn},
                                Targets = {
                                    Surface = {Object = Btn, Time = 0.12},
                                    Stroke = {Object = Stroke, Time = 0.12},
                                    Text = {Object = Btn, Time = 0.12}
                                },
                                Default = {
                                    Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Border, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0}
                                },
                                Hover = {
                                    Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                },
                                Pressed = {
                                    Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                    Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                },
                                Disabled = {
                                    Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0.18},
                                    Stroke = {Color = Config.Colors.Border, Transparency = 0.35},
                                    Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0.35}
                                }
                            })

                            Btn.MouseButton1Click:Connect(function()
                                if BtnProps.Callback then
                                    BtnProps.Callback()
                                end
                            end)

                            table.insert(ButtonsInGroup, Btn)
                            table.insert(ButtonFunctions, Feedback)

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

                        local Result = AddButton(Props)

                        AttachControlStateApi(ButtonFunctions, {
                            Root = ButtonFrame,
                            Interactive = ButtonsInGroup,
                            TextTargets = ButtonsInGroup,
                            Tooltip = Props.Tooltip,
                            SetDisabledState = function(Disabled)
                                for _, Feedback in ipairs(ButtonFunctions) do
                                    if type(Feedback) == "table" and Feedback.SetDisabled then
                                        Feedback:SetDisabled(Disabled)
                                    end
                                end
                            end
                        })

                        return Result
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
                        ApplyTextOptions(Title, Props)

                        AttachControlStateApi(LabelFunctions, {
                            Root = LabelFrame,
                            TextTargets = {Title},
                            Tooltip = Props.Tooltip
                        })

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
                            Size = UDim2.new(1, 0, 0, Scale(22)),
                            ClipsDescendants = true
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
                            ClearTextOnFocus = false,
                            ClipsDescendants = true,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd
                        }, {TextColor3 = "TextLight", PlaceholderColor3 = "TextMain"})
                        ApplyTextOptions(TextBox, Props)
                        local InputFeedback = CreateInteractiveFeedback({
                            Interactive = {TextBox},
                            Targets = {
                                Surface = {Object = BoxContainer, Time = 0.12},
                                Stroke = {Object = BoxStroke, Time = 0.12}
                            },
                            Default = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0}
                            },
                            Hover = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0}
                            },
                            Focused = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0}
                            },
                            Disabled = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0.12},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0.35}
                            }
                        })

                        TextBox.Focused:Connect(function()
                            InputFeedback:SetFocused(true)
                            if Props.OnFocusExpand then
                                TextBox.TextTruncate = Enum.TextTruncate.None
                            end
                        end)

                        TextBox.FocusLost:Connect(function(EnterPressed)
                            InputFeedback:SetFocused(false)
                            if Props.OnFocusExpand and Props.Truncate then
                                TextBox.TextTruncate = Props.Truncate
                            end
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
                        InputFunctions.DefaultValue = Props.Default or ""
                        InputFunctions.IncludeInConfig = Props.IncludeInConfig ~= false

                        AttachControlStateApi(InputFunctions, {
                            Root = InputFrame,
                            Interactive = {TextBox},
                            TextTargets = {TextBox},
                            Tooltip = Props.Tooltip,
                            Cleanup = {InputFeedback},
                            SetDisabledState = function(Disabled)
                                InputFeedback:SetDisabled(Disabled)
                            end
                        })

                        if Props.Flag then Library.Flags[Props.Flag] = InputFunctions end
                        return InputFunctions
                    end

                    -- DROPDOWN - Compact
                    function SectionFunctions:Dropdown(Props)
                        local TitleHeight = (Props.Title and Props.Title ~= "") and Scale(18) or 0
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
                        ApplyTextOptions(DropdownBtn, Props)

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
                        local DropdownFeedback = CreateInteractiveFeedback({
                            Interactive = {DropdownBtn},
                            Targets = {
                                Surface = {Object = DropdownBtn, Time = 0.12},
                                Stroke = {Object = BtnStroke, Time = 0.12},
                                Text = {Object = DropdownBtn, Time = 0.12},
                                Icon = {Object = Arrow, Time = 0.12}
                            },
                            Default = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0},
                                Icon = {ImageColor3 = Config.Colors.TextMain, ImageTransparency = 0}
                            },
                            Hover = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0},
                                Icon = {ImageColor3 = Config.Colors.TextLight, ImageTransparency = 0}
                            },
                            Focused = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0},
                                Icon = {ImageColor3 = Config.Colors.TextLight, ImageTransparency = 0}
                            },
                            Pressed = {
                                Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0},
                                Icon = {ImageColor3 = Config.Colors.TextLight, ImageTransparency = 0}
                            },
                            Disabled = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0.14},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0.35},
                                Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0.35},
                                Icon = {ImageColor3 = Config.Colors.TextMain, ImageTransparency = 0.35}
                            }
                        })

                        local MenuOpen = false
                        local SelectedOption = Props.Default
                        local Options = Props.Options or {}

                        local OptionFrame = CreateInstance("Frame", {
                            Parent = DropdownFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, TitleHeight + Scale(20)),
                            Size = UDim2.new(1, 0, 0, 0),
                            Visible = false,
                            ClipsDescendants = true,
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
                            Active = true,
                            ScrollingDirection = Enum.ScrollingDirection.Y,
                            ScrollingEnabled = true,
                            ZIndex = 101
                        })

                        local OptionList = CreateInstance("UIListLayout", {
                            Parent = OptionScroll,
                            Padding = UDim.new(0, Scale(2))
                        })

                        local function CloseMenu()
                            MenuOpen = false
                            DropdownFeedback:SetFocused(false)
                            TweenService:Create(Arrow, CreateTween(0.2), {Rotation = 0}):Play()
                            TweenService:Create(OptionFrame, CreateTween(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                            task.wait(0.2)
                            OptionFrame.Visible = false
                            Library.ActivePopup = nil
                        end

                        local function OpenMenu()
                            Library:ClosePopups()
                            MenuOpen = true
                            DropdownFeedback:SetFocused(true)
                            OptionFrame.Visible = true
                            OptionFrame.Position = UDim2.new(0, 0, 0, TitleHeight + DropdownBtn.AbsoluteSize.Y + Scale(2))
                            TweenService:Create(Arrow, CreateTween(0.2), {Rotation = 180}):Play()

                            local MaxHeight = math.min(#Options * Scale(24) + Scale(4), Scale(120))
                            TweenService:Create(OptionFrame, CreateTween(0.2), {Size = UDim2.new(1, 0, 0, MaxHeight)}):Play()

                            RegisterPopup({
                                Element = OptionFrame,
                                Ignore = {DropdownBtn},
                                Close = CloseMenu,
                                ScrollLock = SectionContainer
                            })
                        end

                        OptionScroll.MouseEnter:Connect(function()
                            if MenuOpen then
                                SetScrollLocked(SectionContainer, true)
                            end
                        end)

                        OptionScroll.MouseLeave:Connect(function()
                            if not Library.ActivePopup or Library.ActivePopup.Element ~= OptionFrame then
                                SetScrollLocked(SectionContainer, false)
                            end
                        end)

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
                                CreateInteractiveFeedback({
                                    Interactive = {Btn},
                                    Targets = {
                                        Surface = {Object = Btn, Time = 0.08},
                                        Text = {Object = Btn, Time = 0.08}
                                    },
                                    Default = {
                                        Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                        Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0}
                                    },
                                    Hover = {
                                        Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                        Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                    },
                                    Pressed = {
                                        Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                        Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                                    }
                                })
                                Btn.MouseButton1Click:Connect(function() SelectOption(Option) end)

                                table.insert(OptionButtons, Btn)
                            end
                        end

                        BuildOptions()

                        local DropdownFunctions = {}
                        function DropdownFunctions:SetValue(Val) SelectOption(Val) end
                        function DropdownFunctions:GetValue() return SelectedOption end
                        function DropdownFunctions:SetOptions(NewOptions)
                            Options = NewOptions
                            BuildOptions()
                        end
                        DropdownFunctions.DefaultValue = Props.Default
                        DropdownFunctions.IncludeInConfig = Props.IncludeInConfig ~= false

                        AttachControlStateApi(DropdownFunctions, {
                            Root = DropdownFrame,
                            Interactive = {DropdownBtn},
                            TextTargets = {DropdownBtn},
                            Tooltip = Props.Tooltip,
                            Cleanup = {DropdownFeedback},
                            SetDisabledState = function(Disabled)
                                if Disabled and MenuOpen then
                                    CloseMenu()
                                end
                                DropdownFeedback:SetDisabled(Disabled)
                            end
                        })

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
                        local BarStroke = CreateInstance("UIStroke", {Parent = BarBg, Thickness = 1}, {Color = "Border"})

                        local BarFill = CreateInstance("Frame", {
                            Parent = BarBg,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 0, 1, 0)
                        }, {BackgroundColor3 = "Accent"})

                        CreateInstance("UICorner", {Parent = BarFill, CornerRadius = UDim.new(0, Scale(3))})

                        local ProgressFunctions = {}
                        function ProgressFunctions:SetValue(Percent)
                            local Clamped = math.clamp(Percent, 0, 100)
                            TweenService:Create(BarFill, CreateTween(0.18), {Size = UDim2.new(Clamped / 100, 0, 1, 0)}):Play()
                            TweenService:Create(BarStroke, CreateTween(0.18), {
                                Color = Clamped > 0 and Config.Colors.Accent or Config.Colors.Border
                            }):Play()
                            PercentLabel.Text = math.floor(Clamped) .. "%"
                        end
                        function ProgressFunctions:GetValue()
                            return BarFill.Size.X.Scale * 100
                        end
                        ApplyTextOptions(PercentLabel, Props)

                        AttachControlStateApi(ProgressFunctions, {
                            Root = BarFrame,
                            TextTargets = {PercentLabel},
                            Tooltip = Props.Tooltip
                        })

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
                        local ToggleFeedback = CreateInteractiveFeedback({
                            Interactive = {Checkbox},
                            Targets = {
                                Surface = {Object = Checkbox, Time = 0.1},
                                Stroke = {Object = CheckStroke, Time = 0.1},
                                Text = {Object = Title, Time = 0.1}
                            },
                            Default = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                Stroke = {Color = Color3.fromRGB(50, 50, 50), Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0}
                            },
                            Hover = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                            },
                            Focused = {
                                Surface = {BackgroundColor3 = Config.Colors.Accent, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                            },
                            Pressed = {
                                Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0},
                                Text = {TextColor3 = Config.Colors.TextLight, TextTransparency = 0}
                            },
                            Disabled = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0.18},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0.35},
                                Text = {TextColor3 = Config.Colors.TextMain, TextTransparency = 0.35}
                            }
                        })

                        local function UpdateState(ForcedVal)
                            if ForcedVal ~= nil then Toggled = ForcedVal end
                            ToggleFeedback:SetFocused(Toggled)
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
                        ToggleFunctions.DefaultValue = Props.Default or false
                        ToggleFunctions.IncludeInConfig = Props.IncludeInConfig ~= false
                        ApplyTextOptions(Title, Props)

                        AttachControlStateApi(ToggleFunctions, {
                            Root = ToggleFrame,
                            Interactive = {Checkbox},
                            TextTargets = {Title},
                            Tooltip = Props.Tooltip,
                            Cleanup = {ToggleFeedback},
                            SetDisabledState = function(Disabled)
                                ToggleFeedback:SetDisabled(Disabled)
                            end
                        })

                        if Props.Flag then Library.Flags[Props.Flag] = ToggleFunctions end
                        return ToggleFunctions
                    end

                    -- SLIDER - Compact
                    function SectionFunctions:Slider(Props)
                        local Step = tonumber(Props.Step)
                        if Step and Step <= 0 then
                            Step = nil
                        end

                        local function CountDecimals(Value)
                            local Text = string.format("%.10f", tonumber(Value) or 0)
                            local Trimmed = Text:gsub("0+$", "")
                            local DecimalsText = Trimmed:match("%.(%d+)")
                            return DecimalsText and #DecimalsText or 0
                        end

                        local Decimals = Props.Decimal
                        if Decimals == nil then
                            Decimals = Step and CountDecimals(Step) or 0
                        end

                        local Mult = 10 ^ Decimals
                        local Format = "%." .. Decimals .. "f"
                        local Prefix = Props.Prefix or ""
                        local Suffix = Props.Suffix or ""
                        local ZeroValue = Props.ZeroValue or Props.Min
                        local Range = Props.Max - Props.Min
                        local ZeroScale = Range ~= 0 and ((ZeroValue - Props.Min) / Range) or 0

                        local Presets = type(Props.Presets) == "table" and Props.Presets or nil
                        local HasPresets = Presets and #Presets > 0
                        local SliderFrameHeight = HasPresets and Scale(64) or Scale(38)

                        local SliderFrame = CreateInstance("Frame", {
                            Parent = ElementsContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, SliderFrameHeight)
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
                        ApplyTextOptions(ValueLabel, Props)

                        local SliderBg = CreateInstance("TextButton", {
                            Parent = SliderFrame,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(20)),
                            Size = UDim2.new(1, 0, 0, Scale(4)),
                            Text = "",
                            AutoButtonColor = false
                        }, {BackgroundColor3 = "ElementBg"})

                        CreateInstance("UICorner", {Parent = SliderBg, CornerRadius = UDim.new(0, Scale(2))})
                        local SliderStroke = CreateInstance("UIStroke", {Parent = SliderBg, Thickness = 1}, {Color = "Border"})

                        local SliderHitbox = CreateInstance("TextButton", {
                            Parent = SliderFrame,
                            BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            Position = UDim2.new(0, 0, 0, Scale(14)),
                            Size = UDim2.new(1, 0, 0, Scale(16)),
                            Text = "",
                            AutoButtonColor = false,
                            ZIndex = SliderBg.ZIndex + 2
                        })

                        local SliderFill = CreateInstance("Frame", {
                            Parent = SliderBg,
                            BorderSizePixel = 0,
                            Size = UDim2.new(0, 0, 1, 0)
                        }, {BackgroundColor3 = "Accent"})

                        CreateInstance("UICorner", {Parent = SliderFill, CornerRadius = UDim.new(0, Scale(2))})

                        local ShowStops = Props.ShowStops
                        if ShowStops == nil then
                            ShowStops = Step ~= nil
                        end

                        if ShowStops and Step and Range > 0 then
                            local StopCount = math.floor((Range / Step) + 0.5)
                            if StopCount >= 1 and StopCount <= 24 then
                                local StopContainer = CreateInstance("Frame", {
                                    Parent = SliderBg,
                                    BackgroundTransparency = 1,
                                    BorderSizePixel = 0,
                                    Size = UDim2.new(1, 0, 1, 0),
                                    Active = false,
                                    ZIndex = SliderBg.ZIndex + 1
                                })

                                for Index = 0, StopCount do
                                    local PositionScale = StopCount > 0 and (Index / StopCount) or 0
                                    CreateInstance("Frame", {
                                        Parent = StopContainer,
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundColor3 = Config.Colors.Border,
                                        BackgroundTransparency = 0.35,
                                        BorderSizePixel = 0,
                                        Position = UDim2.new(PositionScale, 0, 0.5, 0),
                                        Size = UDim2.new(0, 1, 0, Scale(8)),
                                        ZIndex = StopContainer.ZIndex
                                    })
                                end
                            end
                        end

                        local SliderFunctions = {}
                        local CurrentValue
                        local PresetButtons = {}
                        local InteractiveTargets = {SliderBg, SliderHitbox}
                        local SliderFeedback = CreateInteractiveFeedback({
                            Interactive = InteractiveTargets,
                            Targets = {
                                Surface = {Object = SliderBg, Time = 0.08},
                                Stroke = {Object = SliderStroke, Time = 0.08}
                            },
                            Default = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0.15}
                            },
                            Hover = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0}
                            },
                            Focused = {
                                Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0}
                            },
                            Pressed = {
                                Surface = {BackgroundColor3 = Config.Colors.SectionBg, BackgroundTransparency = 0},
                                Stroke = {Color = Config.Colors.Accent, Transparency = 0}
                            },
                            Disabled = {
                                Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0.12},
                                Stroke = {Color = Config.Colors.Border, Transparency = 0.45}
                            }
                        })

                        local function SnapValue(Val)
                            local Numeric = tonumber(Val) or ZeroValue
                            local Clamped = math.clamp(Numeric, Props.Min, Props.Max)
                            if Step then
                                local Relative = (Clamped - Props.Min) / Step
                                Clamped = Props.Min + (math.floor(Relative + 0.5) * Step)
                                Clamped = math.clamp(Clamped, Props.Min, Props.Max)
                            end
                            return math.floor(Clamped * Mult + 0.5) / Mult
                        end

                        local function FormatValue(Value)
                            return Prefix .. string.format(Format, Value) .. Suffix
                        end

                        local function UpdatePresetVisuals()
                            if #PresetButtons == 0 then
                                return
                            end

                            local MatchTolerance = Step and math.max(Step / 2, 1 / Mult) or (0.5 / Mult)
                            for _, PresetButton in ipairs(PresetButtons) do
                                local IsActive = math.abs(PresetButton.Value - CurrentValue) <= MatchTolerance
                                TweenService:Create(PresetButton.Button, CreateTween(0.12), {
                                    BackgroundColor3 = IsActive and Config.Colors.Accent or Config.Colors.ElementBg,
                                    BackgroundTransparency = IsActive and 0.1 or 0,
                                    TextColor3 = IsActive and Config.Colors.TextLight or Config.Colors.TextMain
                                }):Play()
                                if PresetButton.Stroke then
                                    TweenService:Create(PresetButton.Stroke, CreateTween(0.12), {
                                        Color = IsActive and Config.Colors.Accent or Config.Colors.Border,
                                        Transparency = IsActive and 0 or 0.2
                                    }):Play()
                                end
                            end
                        end

                        CurrentValue = SnapValue(Props.Default or ZeroValue)

                        ValueLabel.Text = FormatValue(CurrentValue)

                        SliderHitbox.InputBegan:Connect(function(Input)
                            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                                SliderFeedback:SetFocused(true)
                                local function Update(InputVec)
                                    local Pos = math.clamp((InputVec.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                                    local Raw = (Pos * Range) + Props.Min
                                    SliderFunctions:SetValue(Raw)
                                end
                                Update(Input.Position)
                                local MoveCon = UserInputService.InputChanged:Connect(function(Move)
                                    if Move.UserInputType == Enum.UserInputType.MouseMovement or Move.UserInputType == Enum.UserInputType.Touch then
                                        Update(Move.Position)
                                    end
                                end)
                                local EndCon; EndCon = UserInputService.InputEnded:Connect(function(Ended)
                                    if Ended.UserInputType == Enum.UserInputType.MouseButton1 or Ended.UserInputType == Enum.UserInputType.Touch then
                                        SliderFeedback:SetFocused(false)
                                        MoveCon:Disconnect()
                                        EndCon:Disconnect()
                                    end
                                end)
                            end
                        end)

                        if HasPresets then
                            local PresetRow = CreateInstance("Frame", {
                                Parent = SliderFrame,
                                BackgroundTransparency = 1,
                                BorderSizePixel = 0,
                                Position = UDim2.new(0, 0, 0, Scale(30)),
                                Size = UDim2.new(1, 0, 0, Scale(24))
                            })

                            CreateInstance("UIListLayout", {
                                Parent = PresetRow,
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                                Padding = UDim.new(0, Scale(6))
                            })

                            local function NormalizePreset(Preset)
                                if type(Preset) == "table" then
                                    local Value = tonumber(Preset.Value or Preset[2] or Preset[1])
                                    if Value == nil then
                                        return nil
                                    end
                                    local Label = Preset.Label
                                    if Label == nil or Label == "" then
                                        Label = FormatValue(SnapValue(Value))
                                    end
                                    return Label, Value
                                end

                                local Value = tonumber(Preset)
                                if Value == nil then
                                    return nil
                                end
                                return FormatValue(SnapValue(Value)), Value
                            end

                            for _, Preset in ipairs(Presets) do
                                local LabelText, PresetValue = NormalizePreset(Preset)
                                if LabelText and PresetValue ~= nil then
                                    local PresetButton = CreateInstance("TextButton", {
                                        Parent = PresetRow,
                                        AutomaticSize = Enum.AutomaticSize.X,
                                        BackgroundTransparency = 0,
                                        BorderSizePixel = 0,
                                        Size = UDim2.new(0, 0, 0, Scale(20)),
                                        Text = tostring(LabelText),
                                        FontFace = Config.Font,
                                        TextSize = Scale(10),
                                        AutoButtonColor = false
                                    }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextMain"})

                                    CreateInstance("UICorner", {Parent = PresetButton, CornerRadius = UDim.new(0, Scale(10))})
                                    local PresetStroke = CreateInstance("UIStroke", {Parent = PresetButton, Thickness = 1}, {Color = "Border"})
                                    CreateInstance("UIPadding", {
                                        Parent = PresetButton,
                                        PaddingLeft = UDim.new(0, Scale(8)),
                                        PaddingRight = UDim.new(0, Scale(8))
                                    })

                                    PresetButton.MouseButton1Click:Connect(function()
                                        SliderFunctions:SetValue(PresetValue)
                                    end)

                                    table.insert(InteractiveTargets, PresetButton)
                                    table.insert(PresetButtons, {
                                        Button = PresetButton,
                                        Stroke = PresetStroke,
                                        Value = SnapValue(PresetValue)
                                    })
                                end
                            end
                        end

                        function SliderFunctions:SetValue(Val)
                            CurrentValue = SnapValue(Val)
                            local Pos = Range ~= 0 and ((CurrentValue - Props.Min) / Range) or 0
                            local StartScale = math.min(ZeroScale, Pos)
                            local FillSize = math.abs(Pos - ZeroScale)
                            TweenService:Create(SliderFill, CreateTween(0.06), {
                                Position = UDim2.new(StartScale, 0, 0, 0),
                                Size = UDim2.new(FillSize, 0, 1, 0)
                            }):Play()
                            ValueLabel.Text = FormatValue(CurrentValue)
                            UpdatePresetVisuals()
                            if Props.Callback then Props.Callback(CurrentValue) end
                        end

                        function SliderFunctions:GetValue() return CurrentValue end
                        SliderFunctions.DefaultValue = Props.Default or ZeroValue
                        SliderFunctions.IncludeInConfig = Props.IncludeInConfig ~= false

                        local StartPercent = Range ~= 0 and ((CurrentValue - Props.Min) / Range) or 0
                        local InitStart = math.min(ZeroScale, StartPercent)
                        local InitSize = math.abs(StartPercent - ZeroScale)
                        SliderFill.Position = UDim2.new(InitStart, 0, 0, 0)
                        SliderFill.Size = UDim2.new(InitSize, 0, 1, 0)
                        UpdatePresetVisuals()

                        AttachControlStateApi(SliderFunctions, {
                            Root = SliderFrame,
                            Interactive = InteractiveTargets,
                            TextTargets = {ValueLabel},
                            Tooltip = Props.Tooltip,
                            Cleanup = {SliderFeedback},
                            SetDisabledState = function(Disabled)
                                SliderFeedback:SetDisabled(Disabled)
                            end
                        })

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
                        local SelectedKeys = {}
                        local Favorites = {}
                        local MultiSelect = Props.Multi ~= false
                        local PreferredColumns = Props.Columns or Props.PreferredColumns or Props.MinColumns or 4
                        local MaxColumns = Props.MaxColumns or PreferredColumns
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
                        local GridPadding = Scale(6)

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
                            local SearchFeedback = CreateInteractiveFeedback({
                                Interactive = {SearchBox},
                                Targets = {
                                    Surface = {Object = SearchBox, Time = 0.12},
                                    Stroke = {Object = SearchStroke, Time = 0.12}
                                },
                                Default = {
                                    Surface = {BackgroundColor3 = Config.Colors.ElementBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Border, Transparency = 0}
                                },
                                Hover = {
                                    Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Border, Transparency = 0}
                                },
                                Focused = {
                                    Surface = {BackgroundColor3 = Config.Colors.PanelBg, BackgroundTransparency = 0},
                                    Stroke = {Color = Config.Colors.Accent, Transparency = 0}
                                }
                            })

                            SearchBox.Focused:Connect(function()
                                SearchFeedback:SetFocused(true)
                            end)
                            SearchBox.FocusLost:Connect(function()
                                SearchFeedback:SetFocused(false)
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
                            CellPadding = UDim2.new(0, GridPadding, 0, GridPadding),
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Left,
                            VerticalAlignment = Enum.VerticalAlignment.Top,
                            SortOrder = Enum.SortOrder.LayoutOrder
                        })

                        local EmptyState = CreateInstance("Frame", {
                            Parent = GridContainer,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(80)),
                            Visible = false,
                            BorderSizePixel = 0
                        })

                        local EmptyIcon = CreateInstance("TextLabel", {
                            Parent = EmptyState,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, Scale(26)),
                            FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
                            TextSize = Scale(18),
                            Text = Props.EmptyIcon or "⊘",
                            TextColor3 = Config.Colors.TextMain
                        })

                        local EmptyTitle = CreateInstance("TextLabel", {
                            Parent = EmptyState,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(24)),
                            Size = UDim2.new(1, 0, 0, Scale(18)),
                            FontFace = Config.Font,
                            TextSize = Scale(12),
                            Text = Props.EmptyTitle or "No items found",
                            TextColor3 = Config.Colors.TextLight
                        })

                        local EmptyDescription = CreateInstance("TextLabel", {
                            Parent = EmptyState,
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, Scale(42)),
                            Size = UDim2.new(1, 0, 0, Scale(32)),
                            FontFace = Config.Font,
                            TextSize = Scale(10),
                            TextWrapped = true,
                            Text = Props.EmptyDescription or "Adjust your search or try a different category.",
                            TextColor3 = Config.Colors.TextMain
                        })

                        if Props.EmptyHint and Props.EmptyHint ~= "" then
                            EmptyDescription.Text = EmptyDescription.Text .. "\n" .. tostring(Props.EmptyHint)
                        end

                        local GridFunctions = {}
                        local CellButtons = {}
                        local VisibleCells = {} -- For virtual scrolling

                        local function GetItemKey(Item)
                            if type(Item) == "table" then
                                return tostring(Item.Name or Item.Id or Item.Value or "")
                            end
                            return tostring(Item)
                        end

                        local function SyncSelectedList()
                            table.clear(Selected)
                            for _, Item in ipairs(GridItems) do
                                if SelectedKeys[GetItemKey(Item)] then
                                    table.insert(Selected, Item)
                                end
                            end
                        end

                        local function CalculateCellSize(ItemCount)
                            local ContainerWidth = math.floor(GridContainer.AbsoluteSize.X + 0.5)
                            if ContainerWidth <= 0 then
                                ContainerWidth = Scale(600)
                            end

                            local VisibleCount = math.max(1, ItemCount or #GridItems)
                            local Columns = math.min(math.max(1, PreferredColumns), math.max(1, VisibleCount), math.max(1, MaxColumns))
                            while Columns > 1 do
                                local TotalPadding = (Columns - 1) * GridPadding
                                local CandidateWidth = (ContainerWidth - TotalPadding) / Columns
                                if CandidateWidth >= MinCellWidth then
                                    break
                                end
                                Columns -= 1
                            end

                            Columns = math.max(1, Columns)
                            local TotalPadding = (Columns - 1) * GridPadding
                            local CellWidth = math.max(1, math.floor(((ContainerWidth - TotalPadding) / Columns) + 0.5))
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

                            if CellBtn.Feedback then
                                CellBtn.Feedback:SetFocused(IsSelected)
                            end

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
                            local ItemKey = GetItemKey(Item)
                            if IsSelected then
                                if not MultiSelect then
                                    table.clear(SelectedKeys)
                                    for _, Btn in ipairs(CellButtons) do
                                        if Btn.Item ~= Item then
                                            ApplySelectionVisualState(Btn, false)
                                        end
                                    end
                                end

                                SelectedKeys[ItemKey] = true
                                SyncSelectedList()

                                ApplySelectionVisualState(CellBtn, true)

                                if SelectionNotify and not Silent then
                                    NotifyOnce("Selected: " .. (Item.Name or "Item"), "Success")
                                end
                            else
                                SelectedKeys[ItemKey] = nil
                                SyncSelectedList()

                                ApplySelectionVisualState(CellBtn, false)

                                if SelectionNotify and not Silent then
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
                            local CellFeedback = CreateInteractiveFeedback({
                                Interactive = {CellBtn},
                                Targets = {
                                    Surface = {Object = CellBtn, Time = 0.1},
                                    Stroke = Stroke and {Object = Stroke, Time = 0.1} or nil
                                },
                                Default = {
                                    Surface = {
                                        BackgroundColor3 = Config.Colors.ElementBg,
                                        BackgroundTransparency = 0.18
                                    },
                                    Stroke = Stroke and {
                                        Color = Config.Colors.Border,
                                        Transparency = 0
                                    } or nil
                                },
                                Hover = {
                                    Surface = {
                                        BackgroundColor3 = Config.Colors.ElementBg,
                                        BackgroundTransparency = 0.08
                                    },
                                    Stroke = Stroke and {
                                        Color = Config.Colors.Accent,
                                        Transparency = 0
                                    } or nil
                                },
                                Focused = {
                                    Surface = {
                                        BackgroundColor3 = Config.Colors.SectionBg,
                                        BackgroundTransparency = 0.02
                                    },
                                    Stroke = Stroke and {
                                        Color = Config.Colors.Accent,
                                        Transparency = 0
                                    } or nil
                                },
                                Pressed = {
                                    Surface = {
                                        BackgroundColor3 = Config.Colors.SectionBg,
                                        BackgroundTransparency = 0
                                    },
                                    Stroke = Stroke and {
                                        Color = Config.Colors.Accent,
                                        Transparency = 0
                                    } or nil
                                }
                            })

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

                            CellBtn.MouseButton1Click:Connect(function()
                                local CurrentlySelected = table.find(Selected, Item) ~= nil
                                UpdateSelection(Item, not CurrentlySelected, {
                                    Frame = CellBtn,
                                    Feedback = CellFeedback,
                                    Stroke = Stroke,
                                    Item = Item,
                                    Checkmark = Checkmark,
                                    Star = StarBtn
                                })
                            end)

                            local CellData = {
                                Frame = CellBtn,
                                Feedback = CellFeedback,
                                Stroke = Stroke,
                                Item = Item,
                                Checkmark = Checkmark,
                                Star = StarBtn,
                                Index = Index
                            }
                            table.insert(CellButtons, CellData)

                            if SelectedKeys[GetItemKey(Item)] then
                                task.defer(function()
                                    if CellBtn and CellBtn.Parent then
                                        ApplySelectionVisualState(CellData, true)
                                    end
                                end)
                            end

                            if Item.Default or (Props.Default and (Props.Default == Item.Name or (type(Props.Default) == "table" and table.find(Props.Default, Item.Name)))) then
                                task.defer(function()
                                    UpdateSelection(Item, true, CellData, true)
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

                            local CellWidth, CellHeight = CalculateCellSize(#Filtered)
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
                            local CellWidth, CellHeight = CalculateCellSize(#FilterItems())
                            GridLayout.CellSize = UDim2.new(0, CellWidth, 0, CellHeight)
                        end)

                        -- Grid Functions
                        function GridFunctions:SetItems(NewItems)
                            GridItems = NewItems
                            SyncSelectedList()
                            RefreshGrid()
                        end

                        function GridFunctions:SetSelected(Items, Silent)
                            if type(Items) ~= "table" then Items = {Items} end
                            table.clear(SelectedKeys)

                            if not MultiSelect and #Items > 0 then
                                local First = Items[1]
                                Items = {First}
                            end

                            for _, Entry in ipairs(Items) do
                                local EntryKey = GetItemKey(Entry)
                                if EntryKey ~= "" then
                                    SelectedKeys[EntryKey] = true
                                end
                            end

                            SyncSelectedList()

                            for _, Cell in ipairs(CellButtons) do
                                ApplySelectionVisualState(Cell, SelectedKeys[GetItemKey(Cell.Item)] == true)
                            end

                            if not Silent and OnSelect then
                                for _, Item in ipairs(Selected) do
                                    OnSelect(Selected, Item, true)
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
                            table.clear(SelectedKeys)
                            table.clear(Selected)
                            for _, Cell in ipairs(CellButtons) do
                                ApplySelectionVisualState(Cell, false)
                            end
                            if Props.Flag and Library.Flags[Props.Flag] then
                                Library.Flags[Props.Flag].Value = Selected
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
                            if type(Val) == "table" and Val.Selected ~= nil then
                                Favorites = type(Val.Favorites) == "table" and Val.Favorites or Favorites
                                GridFunctions:SetSelected(Val.Selected, true)
                                RefreshGrid()
                            elseif type(Val) == "table" then
                                GridFunctions:SetSelected(Val, true)
                            else
                                GridFunctions:SetSelected({Val}, true)
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
                                    return {
                                        Selected = data.Selected or {},
                                        Favorites = data.Favorites or {}
                                    }
                                end
                                return {
                                    Selected = {},
                                    Favorites = {}
                                }
                            end
                        }

                        if Props.Flag then
                            Library.Flags[Props.Flag] = GridFlagData
                        end

                        AttachControlStateApi(GridFunctions, {
                            Root = GridFrame,
                            Interactive = SearchBox and {SearchBox} or {},
                            TextTargets = {EmptyTitle, EmptyDescription},
                            Tooltip = Props.Tooltip
                        })

                        return GridFunctions
                    end

                    return SectionFunctions
                end
                return SubFunctions
            end
            function CategoryFunctions:GetSubCategories()
                return SubCategoryObjects
            end
            return CategoryFunctions
        end
        table.insert(TabObjects, {Api = TabFunctions, IsActive = IsThisTabActive})
        return TabFunctions
    end
    function WindowFunctions:GetTabs()
        local Result = {}
        for _, TabObject in ipairs(TabObjects) do
            table.insert(Result, TabObject.Api)
        end
        return Result
    end

    function WindowFunctions:SelectTab(TabOrIndex)
        if type(TabOrIndex) == "number" then
            local Target = TabObjects[TabOrIndex]
            if Target and Target.Api and Target.Api.Select then
                Target.Api:Select()
            end
        elseif type(TabOrIndex) == "table" and TabOrIndex.Select then
            TabOrIndex:Select()
        end
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
        PlayGroupTransparencyTween(Library.MainFrame, 0.3, 0)
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
        PlayGroupTransparencyTween(Library.MainFrame, 0.3, 1)
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
        PlayGroupTransparencyTween(Modal, 0.2, 1)
        TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
        task.wait(0.2)
        Modal:Destroy()
        Backdrop:Destroy()
        if Library.ActivePopup and Library.ActivePopup.Element == Modal then
            Library.ActivePopup = nil
        end
    end

    CloseBtn.MouseButton1Click:Connect(CloseModal)
    Backdrop.MouseButton1Click:Connect(CloseModal)

    RegisterPopup({
        Element = Modal,
        Ignore = {Modal},
        Close = CloseModal
    })

    return {
        Frame = Modal,
        Content = ContentContainer,
        Close = CloseModal
    }
end

return Library
