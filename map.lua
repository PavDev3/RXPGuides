local addonName, addon = ...

local _G = _G

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
addon.activeWaypoints = {}
addon.linePoints = {}

local MapPinPool = {}
local MapLinePool = {}
local worldMapFramePool, miniMapFramePool, lineMapFramePool

addon.arrowFrame = CreateFrame("Frame", "RXPG_ARROW", UIParent)
local af = addon.arrowFrame

function addon.arrowFrame:UpdateVisuals()
    self.texture:SetTexture(addon.GetTexture(
        "rxp_navigation_arrow-1"))
end


addon.enabledFrames["arrowFrame"] = af
af.IsFeatureEnabled = function ()
    return not addon.settings.profile.disableArrow and (addon.hideArrow ~= nil and not addon.hideArrow)
end

--local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
af:SetMovable(true)
af:EnableMouse(1)
af:SetClampedToScreen(true)
af:SetSize(32, 32)
af.texture = af:CreateTexture()
af.texture:SetAllPoints()
-- af.texture:SetScale(0.5)
af.text = af:CreateFontString(nil, "OVERLAY")
af.text:SetJustifyH("CENTER")
af.text:SetJustifyV("MIDDLE")
af.text:SetPoint("TOP", af, "BOTTOM", 0, -5)
af.orientation = 0
af.distance = 0
af.lowerbound = math.pi / 64 -- angle in radians
af.upperbound = 2 * math.pi - af.lowerbound

af:SetPoint("TOP")
af:Hide()

af:SetScript("OnMouseDown", function(self, button)
    if not addon.settings.profile.lockFrames and af:GetAlpha() ~= 0 then af:StartMoving() end
end)
af:SetScript("OnMouseUp", function(self, button)
    self:StopMovingOrSizing()
    addon.settings:SaveFramePositions()
end)

function addon.SetupArrow()
    af.text:SetFont(addon.font, 9,"OUTLINE")
    af.texture:SetTexture(addon.GetTexture("rxp_navigation_arrow-1"))
    af.text:SetTextColor(unpack(addon.activeTheme.textColor))

    addon.arrowFrame:SetScript("OnUpdate", addon.UpdateArrow)
end

function addon.UpdateArrow(self)

    if addon.settings.profile.disableArrow or not self then return end
    local element = self.element
    if element then
        local x, y, instance = HBD:GetPlayerWorldPosition()
        local angle, dist = HBD:GetWorldVector(instance, x, y, element.wx,
                                               element.wy)
        local facing = GetPlayerFacing()

        if not (dist and facing) then
            if af.alpha ~= 0 then
                af.alpha = 0
                af:SetAlpha(0)
            end
            return
        elseif af.alpha ~= 1 then
            af.alpha = 1
            af:SetAlpha(1)
        end

        local orientation = angle - facing
        local diff = math.abs(orientation - self.orientation)
        dist = math.floor(dist)

        if diff > self.lowerbound and diff < self.upperbound or self.forceUpdate then
            self.orientation = orientation
            self.texture:SetRotation(orientation)
            self.forceUpdate = false
        end

        if dist ~= self.distance then
            self.distance = dist
            local step = element.step
            local title = step and (step.title or step.index and ("Step "..step.index))
            if element.title then
                for RXP_ in string.gmatch(element.title, "RXP_[A-Z]+_") do
                    element.title = element.title:gsub(RXP_, addon.guideTextColors[RXP_] or
                                                 addon.guideTextColors.default["error"])
                end
                --self.text:SetText(string.format("%s\n(%dyd)",element.title, dist))
                self.text:SetText(string.format("%s\n(%dyd)",element.title, dist))
            elseif title then
                for RXP_ in string.gmatch(title, "RXP_[A-Z]+_") do
                    title = title:gsub(RXP_, addon.guideTextColors[RXP_] or addon.guideTextColors.default["error"])
                end
                self.text:SetText(string.format("%s\n(%dyd)", title, dist))
            else
                self.text:SetText(string.format("(%dyd)", dist))
            end
        end
    end

end

local function PinOnEnter(self)
    if self:IsForbidden() or _G.GameTooltip:IsForbidden() then
        return
    end
    local pin = self.activeObject
    local showTooltip
    if self.lineData then
        showTooltip = pin.step and pin.step.showTooltip and pin.step.elements
        if addon.settings.profile.debug then
            local line = self.lineData
            self:SetAlpha(0.5)
            print("Line start point:", line.sX, ",", line.sY)
            print("Line end point:", line.fX, ",", line.fY)
        end
        if showTooltip then
            local element = self.lineData.element
            for line in lineMapFramePool:EnumerateActive() do
                if line.lineData.element == element then
                    line:SetAlpha(0.3)
                end
            end
        end
    end

    _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
    _G.GameTooltip:ClearLines()
    local lines = 0
    local lastStep

    for _, element in pairs(pin.elements or showTooltip or {}) do
        local parent = element.parent
        local text
        local step = element.step
        local icon = step.icon or ""
        local debug = ""
        if addon.settings.profile.debug then
            debug = format("%.3f,%.3f:",element.x or 0, element.y or 0)
        end
        icon = icon:gsub("(|T.-):%d+:%d+:","%1:0:0:")
        if parent and not parent.hideTooltip then
            text = parent.mapTooltip or parent.tooltipText or parent.text or ""
            local title = step.mapTooltip or step.title or step.index and ("Step " .. step.index) or step.tip and "Tip"
            if title and title ~= lastStep then
                _G.GameTooltip:AddLine(icon..title,unpack(addon.colors.mapPins))
                lastStep = title
            end
            _G.GameTooltip:AddLine(debug..text)
            lines = lines + 1
        elseif not parent and not element.hideTooltip then
            text = element.mapTooltip or element.tooltipText or step.text or ""
            local title = step.mapTooltip or step.title or step.index and ("Step " .. step.index) or step.tip and "Tip"
            if title and step ~= lastStep then
                _G.GameTooltip:AddLine(icon..title,unpack(addon.colors.mapPins))
                lastStep = title
            end
            _G.GameTooltip:AddLine(debug..text)
            lines = lines + 1
        end
    end

    _G.GameTooltip:SetShown(lines > 0)
end

local function PinOnLeave(self)
    if self:IsForbidden() or _G.GameTooltip:IsForbidden() then
        return
    end
    local lineData = self.lineData
    if lineData then
        local element = lineData.element
        for line in lineMapFramePool:EnumerateActive() do
            if line.lineData.element == element then
                self:SetAlpha(line.lineData.lineAlpha or 1)
            end
        end
        addon.UpdateMap()
    end
    _G.GameTooltip:Hide()
end

-- The Frame Pool that will manage pins on the world and mini map
-- You must use a frame pool to aquire and release pin frames,
-- otherwise the pins will not be properly removed from the map.
local CreateFramePool
if _G.CreateSecureFramePool then
    local ObjectPoolBaseMixin = {};
    local function Reserve(pool, capacity)
        pool.capacity = capacity or math.huge;

        if pool.capacity ~= math.huge then
            for index = 1, pool.capacity do
                pool:Acquire();
            end
            pool:ReleaseAll();
        end
    end

    local function GetObjectIsInvalidMsg(object, poolCollection)
        return string.format("Attempted to release inactive object '%s'", tostring(object));
    end

    function ObjectPoolBaseMixin:Acquire()
        if self:GetNumActive() == self.capacity then
            return nil, false;
        end

        local object = self:PopInactiveObject();
        local new = object == nil;
        if new then
            object = self:CallCreate();

            --[[
            While pools don't necessarily need to only contain tables, support for other types
            has not been tested, and therefore isn't allowed until we can justify a use for them.
            ]]--
            assert(type(object) == "table");

            --[[
            The reset function will error if forbidden actions are attempted insecurely,
            particularly in scenarios involving forbidden and protected frames. If an error
            is thrown, it will do so before we make any further modifications to this pool.

            Note this does create a potential for a dangling frame or region, but that is less of a
            concern than mutating the pool.
            ]]--
            self:CallReset(object, new);
        end

        self:AddObject(object);
        return object, new;
    end

    function ObjectPoolBaseMixin:Release(object, canFailToFindObject)
        local active = self:IsActive(object);

        --[[
        If Release() is called on a pool directly from external code, then we expect
        an assert if the object is not found. However, if it was called from a pool
        collection, the object not being active is expected as the pool collection iterates
        all the pools until it is found. A separate assert in pool collections accounts for
        the case where the object was not found in any pool.
        ]]--
        if not canFailToFindObject then
            assertsafe(active, GetObjectIsInvalidMsg, object, self);
        end

        if active then
            --[[
            The reset function will error if forbidden actions are attempted insecurely,
            particularly in scenarios involving forbidden and protected frames. If an error
            is thrown, it will do so before we make any further modifications to this pool.
            ]]--
            self:CallReset(object);

            self:ReclaimObject(object);
        end

        return active;
    end

    function ObjectPoolBaseMixin:Dump()
        for index, object in self:EnumerateActive() do
            print(tostring(object));
        end
    end
    local ObjectPoolMixin = CreateFromMixins(ObjectPoolBaseMixin);

    function ObjectPoolMixin:Init(createFunc, resetFunc, capacity)
        self.createFunc = createFunc;
        self.resetFunc = resetFunc;
        self.activeObjects = {};
        self.inactiveObjects = {};
        self.activeObjectCount = 0;

        Reserve(self, capacity);
    end

    function ObjectPoolMixin:CallReset(object, new)
        self.resetFunc(self, object, new);
    end

    function ObjectPoolMixin:CallCreate()
        -- The pool argument 'self' is passed only for addons already reliant on it.
        return self.createFunc(self);
    end

    function ObjectPoolMixin:PopInactiveObject()
        return tremove(self.inactiveObjects);
    end

    function ObjectPoolMixin:AddObject(object)
        local dummy = true;
        self.activeObjects[object] = dummy;
        self.activeObjectCount = self.activeObjectCount + 1;
    end

    function ObjectPoolMixin:ReclaimObject(object)
        tinsert(self.inactiveObjects, object);
        self.activeObjects[object] = nil;
        self.activeObjectCount = self.activeObjectCount - 1;
    end

    function ObjectPoolMixin:ReleaseAll()
        for object in pairs(self.activeObjects) do
            self:Release(object);
        end
    end

    function ObjectPoolMixin:EnumerateActive()
        return pairs(self.activeObjects);
    end

    function ObjectPoolMixin:GetNextActive(current)
        return next(self.activeObjects, current);
    end

    function ObjectPoolMixin:IsActive(object)
        return self.activeObjects[object] ~= nil;
    end

    function ObjectPoolMixin:GetNumActive()
        return self.activeObjectCount;
    end
    CreateFramePool = function(ref)
        local framePool = CreateFromMixins(ObjectPoolMixin)
        framePool:Init(ref.creationFunc, ref.resetterFunc)
        return framePool
    end
else
    CreateFramePool = function(ref)
        local framePool = _G.CreateFramePool()
        framePool.creationFunc = ref.creationFunc
        framePool.resetterFunc = ref.resetterFunc
        return framePool
    end
end

MapPinPool.create = function()
    local framePool = CreateFramePool(MapPinPool)

    return framePool
end

-- Create the Frame with the Frame Pool.
--
-- Because you cannot pass the pin data to the Frame Pool when acquiring a frame,
-- the frame is given a "render" function that can be used to bind the corect data
-- to the frame

MapPinPool.creationFunc = function(framePool)
    local f = CreateFrame("Button", nil, UIParent,
                          BackdropTemplateMixin and "BackdropTemplate")

    -- Styling
    f:SetBackdrop({
        bgFile = addon.GetTexture("white_circle"),
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    f:SetWidth(0)
    f:SetHeight(0)
    f:EnableMouse()
    f:SetMouseClickEnabled(false)
    f:Hide()
    -- Active Step Indicator (A Target Icon)
    f.inner = CreateFrame("Button", nil, f,
                          BackdropTemplateMixin and "BackdropTemplate")
    f.inner:SetBackdrop({
        bgFile = addon.GetTexture("map_active_step_target_icon"),
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    f.inner:SetPoint("CENTER", 0, 0)
    --f.inner:EnableMouse()

    -- Text
    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.text:SetTextColor(unpack(addon.colors.mapPins))
    f.text:SetFont(addon.font, 14, "OUTLINE")

    -- Renders the Pin with Step Information
    f.render = function(self, pin, isMiniMapPin)
        local element = pin.elements[1]
        local step = element.step or pin.step
        local icon = step.icon and step.icon:match("(|T.-:%d.*|t)")
        local label = icon or element.label or step.index or "*"
        self.activeObject = pin

        local r = self.text:GetTextColor()
        if r ~= addon.colors.mapPins[1] then
            self.text:SetTextColor(unpack(addon.colors.mapPins))
        end

        if #pin.elements > 1 and not icon then
            self.text:SetText(label .. "+")
        else
            self.text:SetText(label)
        end

        self.text:Show()
        if addon.settings.profile.mapCircle and not isMiniMapPin and not icon then
            local size = math.max(self.text:GetWidth(), self.text:GetHeight()) + 8
            self.inner:Show()
            if step.active then
                self:SetAlpha(1)
                self:SetWidth(size + 3)
                self:SetHeight(size + 3)
                self:SetBackdropColor(0.0, 0.0, 0.0,
                                   addon.settings.profile.worldMapPinBackgroundOpacity)
                self.inner:SetBackdropColor(1, 1, 1, 1)
                self.inner:SetWidth(size + 3)
                self.inner:SetHeight(size + 3)

                self.text:SetFont(addon.font, 14, "OUTLINE")
            else
                self:SetBackdropColor(0.1, 0.1, 0.1,
                                   addon.settings.profile.worldMapPinBackgroundOpacity)
                self:SetWidth(size)
                self:SetHeight(size)

                self.inner:SetBackdropColor(0, 0, 0, 0)

                self.text:SetFont(addon.font, 9, "OUTLINE")
            end
            self.inner:SetPoint("CENTER", self, 0, 0)
            self.inner:SetWidth(size)
            self.inner:SetHeight(size)
            self.text:SetPoint("CENTER", self, 0, 0)
            self:SetScale(addon.settings.profile.worldMapPinScale)
            self:SetAlpha(pin.opacity)
        else
            --print('s3',GetTime())
            self.inner:Hide()

            if icon then
                self:SetBackdropColor(0, 0, 0, 0)
                self.text:SetFont(addon.font, 16, "OUTLINE")
                local x,y = icon:match("|T.-:(%d+):?(%d*)")
                x,y = tonumber(x), tonumber(y)
                x = x > 0 and x or 16
                y = y or 16
                self:SetSize(x,y)
                self.text:SetPoint("CENTER", self, 1, 0)
            elseif step.active and not isMiniMapPin then
                self:SetBackdropColor(0.0, 0.0, 0.0,
                                   addon.settings.profile.worldMapPinBackgroundOpacity)

                self.text:SetFont(addon.font, 14, "OUTLINE")
                self:SetWidth(self.text:GetStringWidth() + 3)
                self:SetHeight(self.text:GetStringHeight() + 5)
                self.text:SetPoint("CENTER", self, 1, 0)
            else
                local bgAlpha = isMiniMapPin and 0 or
                                    addon.settings.profile.worldMapPinBackgroundOpacity
                self:SetBackdropColor(0.1, 0.1, 0.1, bgAlpha)

                self.text:SetFont(addon.font, 9, "OUTLINE")
                self:SetWidth(self.text:GetStringWidth() + 3)
                self:SetHeight(self.text:GetStringHeight() + 5)
                self.text:SetPoint("CENTER", self, 1, 0)
            end

            self:SetScale(addon.settings.profile.worldMapPinScale)
            self:SetAlpha(pin.opacity)
        end

        -- Mouse Handlers
        self:SetScript("OnEnter", PinOnEnter)

        self:SetScript("OnLeave", PinOnLeave)

    end

    return f
end

-- Hides and disables the Frame when it is released
MapPinPool.resetterFunc = function(framePool, frame)
    frame:SetHeight(0)
    frame:SetWidth(0)
    frame:Hide()
    frame:EnableMouse(0)
    frame.currentPin = nil
end



MapLinePool.create = function()
    local framePool = CreateFramePool(MapLinePool)
    return framePool
end

-- Create the Frame with the Frame Pool.
--
-- Because you cannot pass the pin data to the Frame Pool when acquiring a frame,
-- the frame is given a "render" function that can be used to bind the corect data
-- to the frame
MapLinePool.creationFunc = function(framePool)
    local f = CreateFrame("Button", nil, _G.WorldMapFrame:GetCanvas());
    f.line = f.line or f:CreateLine();
    local border = f.border or f:CreateLine();
    border:SetColorTexture(0, 0, 0, 1);
    f.border = border

    f.render = function(self, coords)
        if coords.lineAlpha == 0 then
            self:Hide()
            return
        end
        f.activeObject = self
        local thickness = coords.linethickness or 2
        local alpha = coords.lineAlpha or 1
        self:SetAlpha(alpha)
        local canvas = _G.WorldMapFrame:GetCanvas()
        local width = canvas:GetWidth()
        local height = canvas:GetHeight()

        -- print(width,height)
        local sX, fX, sY, fY = coords.sX * width / 100, coords.fX * width / 100,
                               coords.sY * height / -100,
                               coords.fY * height / -100

        local lineWidth = abs(sX - fX) + thickness * 4
        local lineHeight = abs(sY - fY) + thickness * 4
        self:SetWidth(lineWidth);
        self:SetHeight(lineHeight);

        local xAnchor = max(sX, fX) - thickness * 2 - lineWidth / 2
        local yAnchor = min(sY, fY) + thickness * 2 + lineHeight / 2

        local line = self.line
        line:SetDrawLayer("OVERLAY", -5)
        line:SetStartPoint("TOPLEFT", sX - xAnchor, sY - yAnchor)
        line:SetEndPoint("TOPLEFT", fX - xAnchor, fY - yAnchor)
        line:SetColorTexture(unpack(addon.colors.mapPins))
        --line:SetTexture('interface/buttons/white8x8')
        line:SetThickness(thickness);

        local lborder = self.border
        lborder:SetDrawLayer("OVERLAY", -6)
        lborder:SetStartPoint("TOPLEFT", sX - xAnchor, sY - yAnchor)
        lborder:SetEndPoint("TOPLEFT", fX - xAnchor, fY - yAnchor)
        lborder:SetThickness(thickness + 2);
        lborder:SetAlpha(0.5)

        self:SetParent(canvas)
        self:SetFrameStrata(canvas:GetFrameStrata())
        self:SetFrameLevel(2010)
        --self:SetFrameStrata("FULLSCREEN_DIALOG")
        -- self:SetFrameLevel(3000)
        self:SetPoint("TOPLEFT", canvas, "TOPLEFT", xAnchor, yAnchor)
        self:EnableMouse(true)
        -- self:Show()

        f:SetScript("OnEnter",PinOnEnter)

        f:SetScript("OnLeave", PinOnLeave)
        --local _,_,px,py = line:GetStartPoint()
        --print('ok',coords.sX,coords.sY,';',coords.fX,coords.fY,'+',_G.WorldMapFrame:GetMapID())
        --print(width,height)

    end

    return f
end

-- Hides and disables the Frame when it is released
MapLinePool.resetterFunc = function(framePool, frame)
    frame:SetHeight(0)
    frame:SetWidth(0)
    frame:Hide()
    frame:EnableMouse(0)
    frame.step = nil
    frame.zone = nil
    frame.lineData = nil
    frame.activeObject = nil
end

worldMapFramePool = MapPinPool.create()
miniMapFramePool = MapPinPool.create()
lineMapFramePool = MapLinePool.create()

-- Calculates if a given element is close to any other provided pins
local function elementIsCloseToOtherPins(element, pins, isMiniMapPin)
    local overlap = addon.settings.profile.distanceBetweenPins or 1
    local pinDistanceMod, pinMaxDistance = 0, 0
    if isMiniMapPin then
        pinMaxDistance = 25
    else
        pinDistanceMod = 5e-5 * overlap ^ 2
        pinMaxDistance = 60 * overlap
    end
    for i, pin in ipairs(pins) do
        for j, pinElement in ipairs(pin.elements) do
            if not (pinElement.hidePin or element.hidePin) then
                local relativeDist, dist, dx, dy
                if element.instance == pinElement.instance then
                    dist, dx, dy = HBD:GetWorldDistance(pinElement.instance,
                                                        pinElement.wx,
                                                        pinElement.wy,
                                                        element.wx, element.wy)
                end
                if not isMiniMapPin then
                    local zx, zy = HBD:GetZoneSize(pin.zone)
                    if dx ~= nil and zx ~= nil then
                        relativeDist = (dx / zx) ^ 2 + (dy / zy) ^ 2
                    end
                    if (relativeDist and relativeDist < pinDistanceMod) or
                        (dist and dist < pinMaxDistance) then
                        return true, pin
                    end
                elseif dist and dist < pinMaxDistance then
                    return true, pin
                end

            end
        end
    end

    return false
end

local lsh = bit.lshift
local function GetPinHash(x,y,instance,element,step)
    local n = step and step.index or 0
    return ((instance + n) % 256) + lsh(math.floor(x*128),8) +
            lsh(math.floor(y*1024),15) + lsh((element % 128),25)
end
-- Creates a list of Pin data structures.
--
-- All of the filtering and combining of steps and elements by proximity
-- is done in this step up front. Then the pins are rendered as WoW Frames
-- using the MapPinPool.
local function generatePins(steps, numPins, startingIndex, isMiniMap)
    local pins = {}

    if addon.currentGuide.empty then return pins end
    local numActivePins = 0
    local numSteps = #steps
    local activeSteps = addon.RXPFrame.activeSteps

    local numActive = 0

    local function GetNumPins(step)
        if step then
            for _, element in pairs(step.elements) do
                if element.zone and element.wx and not element.hidePin then
                    numActive = numActive + 1
                end
            end
        end
    end

    for _, step in pairs(activeSteps) do GetNumPins(step) end

    for i = RXPCData.currentStep + 1, RXPCData.currentStep + numPins do
        local step = addon.currentGuide.steps[i]
        GetNumPins(step)
        if step and step.centerPins then
            numActive = numActive + #step.centerPins
        end
    end

    if numPins < numActive then numPins = numActive end

    -- Loop through the steps until we create the number of pins a user
    -- configures or until we reach the end of the current guide.

    local function ProcessMapPin(step,ignoreCounter)
        if not step then return end
        -- Loop through the elements in each step. Again, we check if we
        -- already created enough pins, then we check if the element
        -- should be included on the map.
        --
        -- If it should be, we calculate whether the element is close to
        -- other pins. If it is, we add the element to a previous pin.
        --
        -- If it is far enough away, we add a new pin to the map.
        local j = 1;
        local n = 0;
        local nCenter = step.centerPins and #step.centerPins or 0
        --print('cp',#step.centerPins)
        local nElements = #step.elements
        while (numActivePins < numPins or j <= nCenter or ignoreCounter) and j <= nElements + nCenter do
            local element
            if j > nCenter then
                element = step.elements[j-nCenter]
            else
                element = step.centerPins[j]
                --print('c1',element.x,element.y)
            end

            local skipWp = not(element.zone and element.x)
            if not element.wpHash and not skipWp then
                element.wpHash = GetPinHash(element.x,element.y,element.zone,n,step)
                n = n + 1
            end
            if not isMiniMap and step.active and not skipWp then
                local wpList = RXPCData.completedWaypoints[step.index or "tip"] or {}
                skipWp = wpList[element.wpHash] or element.skip
                wpList[element.wpHash] = skipWp
                RXPCData.completedWaypoints[element.step.index or "tip"] = wpList
            end

            if element.text and not element.label and not element.textOnly then
                element.label = tostring(step.index or "*")
            end

            if not skipWp and
                (not (element.parent and
                    (element.parent.completed or element.parent.skip)) and
                    not element.skip) then
                if not element.hidePin then
                    local closeToOtherPin, otherPin =
                        elementIsCloseToOtherPins(element, pins, isMiniMap)
                    if closeToOtherPin and not element.hidePin then
                        table.insert(otherPin.elements, element)
                    else
                        local pinalpha = 0
                        if isMiniMap then
                            pinalpha = 0.8
                        elseif element.step and element.step.active then
                            pinalpha = 1
                        else
                            pinalpha = math.max(0.4, 1 - (#pins * 0.05))
                        end
                        table.insert(pins, {
                            elements = {element},
                            opacity = pinalpha,
                            instance = element.instance,
                            wx = element.wx,
                            wy = element.wy,
                            zone = element.zone,
                            parent = element.parent,
                            wpHash = element.wpHash,
                        })
                    end
                end
                if not isMiniMap then
                    table.insert(addon.activeWaypoints, element)
                end
                if not element.hidePin then
                    numActivePins = numActivePins + 1
                end
            end

            j = j + 1
        end
    end

    for _, step in pairs(activeSteps) do ProcessMapPin(step) end

    if not isMiniMap then
        local currentStep = steps[RXPCData.currentStep]
        if (currentStep and not currentStep.active) then
            ProcessMapPin(currentStep)
        end
        local i = 0;
        while numActivePins < numPins and (startingIndex + i < numSteps) do
            i = i + 1
            local step = steps[startingIndex + i]
            ProcessMapPin(step)
        end

        addon:ProcessGeneratedSteps(ProcessMapPin,true)
    end

    return pins
end

local function generateLines(steps, numPins, startingIndex, isMiniMap)
    local pins = {}
    if addon.currentGuide.empty then return pins end
    local numActivePins = 0
    local numSteps = #steps
    local activeSteps = addon.RXPFrame.activeSteps

    local numActive = 0

    local function GetNumPins(step)
        if step then
            for _, element in pairs(step.elements) do
                if element.zone and (element.segments) then
                    numActive = numActive + 1
                end
            end
        end
    end

    for _, step in pairs(activeSteps) do GetNumPins(step) end

    for i = RXPCData.currentStep + 1, RXPCData.currentStep + numPins do
        GetNumPins(addon.currentGuide.steps[i])
    end

    numPins = math.max(numPins, numActive)
    -- Loop through the steps until we create the number of pins a user
    -- configures or until we reach the end of the current guide.

    local function ProcessLine(step,ignoreCounter)
        if not step then return end
        step.centerPins = {}
        local function InsertLine(element, sX, sY, fX, fY, lineAlpha)
            local thickness = tonumber(element.step and step.linethickness)
            table.insert(pins, {
                element = element,
                zone = element.zone,
                sX = sX,
                sY = sY,
                fX = fX,
                fY = fY,
                lineAlpha = lineAlpha,
                linethickness = thickness or element.thickness --or 3
            })
        end

        local centerX, centerY, nEdges = 0,0,0
        local j = 1
        local n = 0

        local function AddPoint(x,y,element,flags,...)
            local wx, wy, instance =
                HBD:GetWorldCoordinatesFromZone(x/100, y/100,
                                                element.zone)
            local point = {
                x = x,
                y = y,
                wx = wx,
                wy = wy,
                instance = instance,
                zone = element.zone,
                anchor = element,
                range = element.range,
                generated = flags,
                step = step,
                parent = element.parent,
                mapTooltip = element.mapTooltip,
            }
            point.wpHash = GetPinHash(x,y,element.zone,n,step)
            n = n + 1
            local tableList = {...}
            for _,tbl in pairs(tableList) do
                table.insert(tbl, point)
            end
        end

        while (numActivePins < numPins or ignoreCounter) and j <= #step.elements do
            local element = step.elements[j]
            local flags = element.bigLoop and 3 or 1
            local nPoints = element.segments and
                                math.floor(#element.segments / 2)
            local nSegments = element.segments and #element.segments
            if element.zone and nPoints and
                (not (element.parent and
                    (element.parent.completed or element.parent.skip)) and
                    not element.skip) then
                for i = 1, nPoints * 2, 2 do
                    local sX = (element.segments[i])
                    local sY = (element.segments[i + 1])
                    local fX,fY
                    if element.connectPoints then
                        fX = (element.segments[(i + 1) % nSegments + 1])
                        fY = (element.segments[(i + 2) % nSegments + 1])
                    else
                        fX = element.segments[i + 2]
                        fY = element.segments[i + 3]
                    end

                    if sX and sY and fX and fY then
                        if sX < 0 and sY < 0 then
                            -- Dashed line if start x/y coordinates are negative
                            sX, sY, fX, fY = math.abs(sX), math.abs(sY),
                                             math.abs(fX), math.abs(fY)
                            centerX = centerX + sX
                            centerY = centerY + sY
                            nEdges = nEdges + 1
                            -- local distMod = 1.75
                            local length = math.sqrt(
                                               (fX - sX) ^ 2 + (fY - sY) ^ 2) *
                                               1.75
                            if length > 1 then
                                local nSegments = math.floor(length)
                                local xinc = (fX - sX) / length
                                local yinc = (fY - sY) / length
                                local xpos, ypos = sX, sY

                                for k = 1, nSegments do
                                    local endx = xpos + xinc
                                    local endy = ypos + yinc
                                    local alpha = bit.band(k, 0x1)
                                    if alpha > 0 then
                                        InsertLine(element, xpos, ypos, endx,
                                                   endy, alpha)
                                    end
                                    xpos = endx
                                    ypos = endy
                                end
                            end
                        else
                            sX, sY, fX, fY = math.abs(sX), math.abs(sY),
                                             math.abs(fX), math.abs(fY)
                            centerX = centerX + sX
                            centerY = centerY + sY
                            nEdges = nEdges + 1
                            InsertLine(element, sX, sY, fX, fY, element.lineAlpha or 1)
                        end
                        if element.showArrow and step.active then
                            AddPoint(sX,sY,element,flags,addon.linePoints,addon.activeWaypoints)
                        end
                    end
                end
                if element.drawCenterPoint and step.active and centerX ~= 0 and centerY then
                    centerX = centerX/nEdges
                    centerY = centerY/nEdges
                    AddPoint(centerX,centerY,element,flags,step.centerPins)
                end
            end

            j = j + 1
        end
    end

    for _, step in pairs(activeSteps) do ProcessLine(step) end

    if not isMiniMap then
        local currentStep = steps[RXPCData.currentStep]
        if not (currentStep and currentStep.active) then
            ProcessLine(currentStep)
        end
        local i = 0;
        while numActivePins < numPins and (startingIndex + i < numSteps) do
            i = i + 1
            local step = steps[startingIndex + i]
            ProcessLine(step)
        end

        addon:ProcessGeneratedSteps(ProcessLine,true)

    end

    return pins
end

-- Generate pins using the current guide's steps, then add the pins to the world map
local function addWorldMapPins()
    -- Calculate which pins should be on the world map
    local pins = generatePins(addon.currentGuide.steps, addon.settings.profile.numMapPins,
                              RXPCData.currentStep, false)

    -- Convert each "pin" data structure into a WoW frame. Then add that frame to the world map
    if IsInInstance() then return end
    for i = #pins, 1, -1 do
        local pin = pins[i]
        if not pin.hidePin then
            local element = pin.elements[1]
            local worldMapFrame = worldMapFramePool:Acquire()
            worldMapFrame:render(pin, false)
            local map = element.step and element.step.map and (addon.GetMapId(element.step.map) or tonumber(element.step.map))
            local x,y
            --if pin.generated then print('f',element.generated) end
            if map then
                x,y = HBD:GetZoneCoordinatesFromWorld(element.wx, element.wy, map)
            else
                x = element.x/100
                y = element.y/100
                map = element.zone
            end
            HBDPins:AddWorldMapIconMap(addon, worldMapFrame, map, x, y,
                                       _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT)
        end
    end
end

local function addWorldMapLines()
    local lineData = generateLines(addon.currentGuide.steps, addon.settings.profile.numMapPins,
                                   RXPCData.currentStep, false)

    if #lineData > 0 then
        local canvas = _G.WorldMapFrame:GetCanvas()
        local width = canvas:GetWidth()
        local height = canvas:GetHeight()

        if width == 0 or height == 0 then
            WorldMapFrame:Show()
            WorldMapFrame:Hide()
        end
    end

    for i = #lineData, 1, -1 do
        local line = lineData[i]
        local element = line.element
        local step = element.step
        local lineFrame = lineMapFramePool:Acquire()
        lineFrame.lineData = line
        lineFrame.step = step
        lineFrame.zone = element.zone
        lineFrame:render(line, false)
    end
end

-- Generate pins using only the active steps, then add the pins to the Mini Map
local function addMiniMapPins(pins)
    if addon.settings.profile.hideMiniMapPins then return end
    -- Calculate which pins should be on the mini map
    local pins = generatePins(addon.currentGuide.steps, addon.settings.profile.numMapPins,
                              RXPCData.currentStep, true)

    -- Convert each "pin" data structure into a WoW frame. Then add that frame to the mini map
    if IsInInstance() then return end
    for i = #pins, 1, -1 do
        local pin = pins[i]
        local element = pin.elements[1]
        if element and element.x then
            local miniMapFrame = miniMapFramePool:Acquire()
            miniMapFrame:render(pin, true)
            HBDPins:AddMinimapIconMap(addon, miniMapFrame, element.zone,
                                      element.x / 100, element.y / 100, true, true)
        end
    end
end

local corpseWP = {title = "Corpse", generated = 1, wpHash = 0}
-- Updates the arrow

local function updateArrow()

    local lowPrioWPs
    local loop = {}
    local function ProcessWaypoint(element, lowPrio, isComplete)
        if element.lowPrio and not lowPrio then
            table.insert(lowPrioWPs, element)
            return
        end
        local step = element.step
        if step.loop then
            loop[step] = true
        end
        local generated = element.generated or 0
        if (bit.band(generated,0x1) == 0x1) or (element.arrow and element.step.active and
            not (element.parent and
                (element.parent.completed or element.parent.skip)) and
            not (element.text and (element.completed or isComplete) and
                not isComplete)) then
            af:SetShown(not addon.settings.profile.disableArrow and not addon.hideArrow and addon.settings.profile.showEnabled)
            af.dist = 0
            af.orientation = 0
            af.element = element
            af.forceUpdate = true
            return true
        end
    end

    if UnitIsGhost("player") and --Meet at the grave and the follow-up quest:
        not (addon.QuestAutoAccept(3912) or addon.QuestAutoAccept(3913)) then
        local skip
        for i,element in pairs(addon.activeWaypoints) do
            skip = skip or (element.step and element.step.ignorecorpse) or (not element.textOnly and addon.currentGuide.name == "41-43 Badlands")
        end
        local zone = HBD:GetPlayerZone()
        local corpse
        if type(zone) == "number" then
            corpse = C_DeathInfo.GetCorpseMapPosition(zone)
        end
        if not skip and corpse and corpse.x then
            corpseWP.wx, corpseWP.wy, corpseWP.instance =
                             HBD:GetWorldCoordinatesFromZone(corpse.x,corpse.y,zone)
            ProcessWaypoint(corpseWP)
            return
        end
    end

    local function SetArrowWP()
        lowPrioWPs = {}
        for i, element in ipairs(addon.activeWaypoints) do
            if ProcessWaypoint(element) then
                return true
            end
        end

        for i, element in ipairs(lowPrioWPs) do
            if ProcessWaypoint(element, true) then
                return true
            end
        end
    end

    if SetArrowWP() then
        return
    end

    for step in pairs(loop) do
        for _,element in ipairs(step.elements) do
            if element.arrow and element.wpHash ~= element.wpHash and element.textOnly then
                element.skip = false
                RXPCData.completedWaypoints[step.index or "tip"][element.wpHash] = false
            end
        end
    end

    if SetArrowWP() then
        return
    end

    af:Hide()
end

function addon.ResetArrowPosition()
    addon.settings.profile.disableArrow = false
    if not addon.settings.profile.showEnabled then
        addon.settings.ToggleActive()
    end
    af:ClearAllPoints()
    af:SetPoint("CENTER", 0, 200)
    updateArrow()
end

-- Removes all pins from the map and mini map and resets all data structrures
local currentPoint
local lastPoint

local function resetMap()
    addon.activeWaypoints = {}
    addon.linePoints = {}
    addon.updateMap = false
    HBDPins:RemoveAllMinimapIcons(addon)
    HBDPins:RemoveAllWorldMapIcons(addon)
    worldMapFramePool:ReleaseAll()
    miniMapFramePool:ReleaseAll()
    lineMapFramePool:ReleaseAll()
end

local lastMap
function addon.UpdateMap(resetPins)
    if resetPins then
        if addon.currentGuide == nil then return end
        lastMap = nil
        resetMap()
        addWorldMapLines()
        addWorldMapPins()
        addMiniMapPins()
        updateArrow()
        addon.DisplayLines(true)
    else
        addon.updateMap = true
        --[[if GetTime() - gt > 10 then
            error('ok')
        end]]
    end
end

local closestPoint
local maxDist = math.huge
local function DisplayLines(self)
    local currentMap = _G.WorldMapFrame:GetMapID()
    if lastMap ~= currentMap or self then
        for line in lineMapFramePool:EnumerateActive() do
            local shown = line.step and line.step.active and line.zone ==
                _G.WorldMapFrame:GetMapID() and line.lineData.lineAlpha > 0
            line:SetShown(shown)
            --print('c',shown,line.zone)
        end
    end
    lastMap = currentMap
end
addon.DisplayLines = DisplayLines

hooksecurefunc(_G.WorldMapFrame, "OnMapChanged", DisplayLines);

local scale = 0
if _G.WorldMapFrame.OnCanvasScaleChanged then
    hooksecurefunc(_G.WorldMapFrame, "OnCanvasScaleChanged", function()
        local mapScale = _G.WorldMapFrame:GetCanvasScale()
        if mapScale ~= scale then
            addon.UpdateMap()
        end
        scale = mapScale
    end)
end

function addon.UpdateGotoSteps()
    local hideArrow = false
    local forceArrowUpdate = UnitIsGhost("player") == (af.element ~= corpseWP)
    DisplayLines()
    if #addon.activeWaypoints == 0 and not forceArrowUpdate then
        af:Hide()
        return
    end
    local function CheckLoop(element,step)
        --local step = element.step
        if step.loop and not element.skip and element.radius then
            local hasValidWPs
            element.skip = true
            for _,wp in pairs(step.elements) do
                if wp.arrow and not wp.skip and wp.textOnly then
                    hasValidWPs = true
                    --print(step.index,wp.wpHash)
                end
            end
            --A = step
            --print('ok1',hasValidWPs)
            if not hasValidWPs then
                --print('noValidWPs',step.index)
                for _,wp in pairs(step.elements) do
                    if wp.arrow and wp.wpHash ~= element.wpHash and wp.textOnly then
                        wp.skip = false
                        RXPCData.completedWaypoints[step.index or "tip"][wp.wpHash] = false
                    end
                end
                forceArrowUpdate = true
            end
        end
    end
    local minDist
    --local zone = C_Map.GetBestMapForUnit("player")
    local x, y, instance = HBD:GetPlayerWorldPosition()
    if af.element and af.element.instance ~= instance and instance ~= -1 then hideArrow = true end
    for i, element in ipairs(addon.activeWaypoints) do
        local step = element.step
        if step and step.active then

            if (element.radius or element.dynamic) and element.arrow and
                not (element.parent and
                    (element.parent.completed or element.parent.skip) and
                    not element.parent.textOnly) and not element.skip then
                local _, dist = HBD:GetWorldVector(instance, x, y, element.wx,
                                                   element.wy)
                if dist then

                    if element.dynamic then
                        if minDist and dist > minDist then
                            element.lowPrio = true
                        else
                            minDist = dist
                            if closestPoint then
                                closestPoint.lowPrio = true
                            end
                            if closestPoint ~= element then
                                forceArrowUpdate = true
                            end
                            element.lowPrio = false
                            closestPoint = element
                        end
                    end
                    if element.radius then
                        if dist <= element.radius then
                            if element.persistent and not element.skip then
                                element.skip = true
                                addon.UpdateMap()
                            elseif not (element.textOnly and element.hidePin and
                                         element.wpHash ~= af.element.wpHash and not element.generated) then
                                CheckLoop(element,step)
                                element.skip = true
                                addon.UpdateMap()
                                if not element.textOnly then
                                    addon.SetElementComplete(element.frame)
                                end
                                if element.timer then
                                    addon.StartTimer(element.timer,element.timerText)
                                end
                            end
                        elseif element.persistent and element.skip then
                            element.skip = false
                            RXPCData.completedWaypoints[step.index or "tip"][element.wpHash] = false
                            addon.UpdateMap()
                        end
                    end
                end
            end
            --
        end
    end

    if addon.hideArrow ~= hideArrow then
        addon.hideArrow = hideArrow
        forceArrowUpdate = true
    end

    minDist = nil
    local anchorPoint = currentPoint
    local linePoints = addon.linePoints
    local nPoints = 0
    local reset
    for i, element in ipairs(linePoints) do
        local radius = element.anchor.range
        if radius and not element.anchor.pointCount then
            nPoints = nPoints + 1
            local _, dist = HBD:GetWorldVector(instance, x, y, element.wx,
                                               element.wy)
            element.dist = dist
            if dist then
                if dist <= radius then
                    currentPoint = i
                    if anchorPoint ~= i then
                        lastPoint = anchorPoint
                    end
                end
                if not lastPoint then
                    if minDist and dist > minDist then
                        element.lowPrio = true
                    else
                        minDist = dist
                        if closestPoint then
                            closestPoint.lowPrio = true
                        end
                        if closestPoint ~= element then
                            forceArrowUpdate = true
                        end
                        element.lowPrio = false
                        closestPoint = element
                    end
                end
            end
            if currentPoint == i then element.lowPrio = true end
        elseif element.wpHash == af.element.wpHash and radius and element.anchor.pointCount then
            local _, dist = HBD:GetWorldVector(instance, x, y, element.wx,
                                               element.wy)
            if dist and dist <= radius then
                if not element.lowPrio then
                    element.anchor.pointCount = element.anchor.pointCount + 1
                    element.lowPrio = true
                    forceArrowUpdate = true
                    --print('ok',element.anchor.pointCount,linePoints)
                    if element.anchor.pointCount >= #linePoints then
                        element.anchor.pointCount = 0
                        reset = element
                        --print('reset')
                    end
                end
            end
        end
    end

    if reset then
        --print('reset-ok')
        for _, element in ipairs(linePoints) do
            if element ~= reset then
                element.lowPrio = false
            else
                element.anchor.pointCount = element.lowPrio and 1 or 0
            end
        end
    elseif currentPoint and nPoints > 0 then
        nPoints = #linePoints
        local nextPoint = currentPoint % nPoints + 1
        local prevPoint = (currentPoint - 2) % nPoints + 1
        local nextElement = linePoints[nextPoint]
        local prevElement = linePoints[prevPoint]
        local nextDist = nextElement.dist or 0
        local prevDist = prevElement.dist or 0
        local isNextCloser = nextDist <= prevDist and lastPoint ~= nextPoint or
                                 lastPoint == prevPoint

        nextElement.lowPrio = not isNextCloser
        prevElement.lowPrio = isNextCloser

        local pointUpdate = currentPoint ~= anchorPoint
        -- print(isNextCloser,lastPoint,currentPoint)
        if pointUpdate then forceArrowUpdate = true end
        if isNextCloser then
            if pointUpdate then
                maxDist = math.max(nextDist * 1.3, 1000)
            elseif nextDist > maxDist then
                currentPoint = nil
                lastPoint = nil
                maxDist = math.huge
                forceArrowUpdate = true
            end
        else
            if pointUpdate then
                maxDist = math.max(prevDist * 1.3, 1000)
            elseif prevDist > maxDist then
                currentPoint = nil
                lastPoint = nil
                maxDist = math.huge
                forceArrowUpdate = true
            end
        end

        for i, element in ipairs(linePoints) do
            if i ~= nextPoint and i ~= prevPoint then
                element.lowPrio = true
            end
        end

    end

    if forceArrowUpdate then updateArrow() end
end

local function GetMapCoefficients(p1x,p1y,p1xb,p1yb,p2x,p2y,p2xb,p2yb)
    local c11 = (p1xb-p2xb)/(p1x-p2x)
    local c31 = p1xb-p1x*c11
    local c22 = (p1yb-p2yb)/(p1y-p2y)
    local c32 = p1yb-p1y*c22
    return {c11,c31,c22,c32}
end

local p1 = {
    ["y"] = 25,
    ["x"] = 25,
    ["yb"] = 43.7789069363158,
    ["xb"] = 39.02232393772481,
}
local p2 = 	{
    ["y"] = 75,
    ["x"] = 75,
    ["yb"] = 82.47040384981797,
    ["xb"] = 77.70637435364208,
}


addon.classicToWrathSW = GetMapCoefficients(p1.x,p1.y,p1.xb,p1.yb,p2.x,p2.y,p2.xb,p2.yb)
addon.wrathToClassicSW = GetMapCoefficients(p1.xb,p1.yb,p1.x,p1.y,p2.xb,p2.yb,p2.x,p2.y)

p1 = {
    ["x"] = 81.51690,
    ["y"] = 59.23138,
    ["xb"] = 75.75077,
    ["yb"] = 53.32378,
}
p2 = {
    ["x"] = 48.12616,
    ["y"] = 21.96377,
    ["xb"] = 43.67876,
    ["yb"] = 17.52954,
}

addon.classicToWrathEPL = GetMapCoefficients(p1.x,p1.y,p1.xb,p1.yb,p2.x,p2.y,p2.xb,p2.yb)
addon.wrathToClassicEPL = GetMapCoefficients(p1.xb,p1.yb,p1.x,p1.y,p2.xb,p2.yb,p2.x,p2.y)


addon.mID = {}
function addon.GetMapId(zone)
    local z = tonumber(zone)
    if z then
        addon.mID[z] = true
        --print(1,z)
    end
    return addon.mapId[zone]
end

function addon.GetMapInfo(zone,x,y)
    x = tonumber(x)
    y = tonumber(y)
    if not (x and y and zone) then
        return
    elseif zone == "StormwindClassic" then
        if addon.gameVersion > 30000 then
            local c = addon.classicToWrathSW
            x = x*c[1]+c[2]
            y = y*c[3]+c[4]
        end
        return addon.GetMapId("Stormwind City"),x,y
    elseif zone == "EPLClassic" then
        if addon.gameVersion > 30000 then
            local c = addon.classicToWrathEPL
            x = x*c[1]+c[2]
            y = y*c[3]+c[4]
        end
        return addon.GetMapId("Eastern Plaguelands"),x,y
    elseif zone == "StormwindNew" then
        if addon.gameVersion < 30000 then
            local c = addon.wrathToClassicSW
            x = x*c[1]+c[2]
            y = y*c[3]+c[4]
        end
        return addon.GetMapId("Stormwind City"),x,y
    elseif zone == "EPLNew" then
        if addon.gameVersion < 30000 then
            local c = addon.wrathToClassicEPL
            x = x*c[1]+c[2]
            y = y*c[3]+c[4]
        end
        return addon.GetMapId("Eastern Plaguelands"),x,y
    else
        return addon.GetMapId(zone) or tonumber(zone),x,y
    end
end

addon.mapId["StormwindClassic"] = addon.mapId["Stormwind City"]
addon.mapId["StormwindNew"] = addon.mapId["Stormwind City"]
addon.mapId["EPLClassic"] = addon.mapId["Eastern Plaguelands"]
addon.mapId["EPLNew"] = addon.mapId["Eastern Plaguelands"]
