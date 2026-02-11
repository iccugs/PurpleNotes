-- PurpleNotes v0.3
-- Simple notepad with a draggable, resizable frame.

PurpleNotesDB = PurpleNotesDB or {}

-- Migrate old single-note format to multi-note format
if PurpleNotesDB.text and not PurpleNotesDB.notes then
    PurpleNotesDB.notes = {{text = PurpleNotesDB.text}}
    PurpleNotesDB.text = nil
end

PurpleNotesDB.notes = PurpleNotesDB.notes or {{text = ""}}
PurpleNotesDB.currentNote = PurpleNotesDB.currentNote or 1

local currentNoteIndex = PurpleNotesDB.currentNote

local frame = CreateFrame("Frame", "PurpleNotesFrame", UIParent, "BackdropTemplate")
frame:SetSize(400, 300)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)

-- Resizing
frame:SetResizable(true)
frame:SetResizeBounds(200, 150)

-- Background
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
frame:SetBackdropColor(0, 0, 0, 0.75)

-- Title bar (darker than background)
local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
titleBar:SetHeight(30)
titleBar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
titleBar:SetBackdropColor(0, 0, 0, 0.9)
titleBar:EnableMouse(true)

-- Safer title-bar dragging (prevents drag starting from child widgets like the title EditBox)
frame.isMoving = false
frame.isSizing = false

-- Menu button (almost black)
local menuButton = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
menuButton:SetSize(20, 20)
menuButton:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 5, -5)
menuButton:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
menuButton:SetBackdropColor(0, 0, 0, 0.95)

-- Menu dropdown
local menuDropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
menuDropdown:SetSize(150, 100)
menuDropdown:SetPoint("TOPLEFT", menuButton, "BOTTOMLEFT", 0, -2)
menuDropdown:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3},
})
menuDropdown:SetBackdropColor(0, 0, 0, 1.0)
menuDropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
menuDropdown:SetFrameStrata("DIALOG")
menuDropdown:Hide()

-- Menu items
local menuItems = {"Select Note", "Close Menu", "Exit"}
local menuButtons = {}

-- Forward declaration - SwitchToNote will be defined later after editBox is created
local SwitchToNote
local SaveFrameState
local pendingDeleteIndex = nil

-- Submenu for note selection
local noteSubmenu = CreateFrame("Frame", nil, menuDropdown, "BackdropTemplate")
noteSubmenu:SetSize(160, 200)
noteSubmenu:SetPoint("TOPLEFT", menuDropdown, "TOPRIGHT", -2, 0)
noteSubmenu:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3},
})
noteSubmenu:SetBackdropColor(0, 0, 0, 1.0)
noteSubmenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
noteSubmenu:SetFrameStrata("DIALOG")
noteSubmenu:SetFrameLevel(menuDropdown:GetFrameLevel() + 1)
noteSubmenu:EnableMouse(true)
noteSubmenu:Hide()

local noteSubmenuButtons = {}
local noteSubmenuPinned = false

local function UpdateNoteSubmenu()
    -- Hide existing rows
    for _, btn in ipairs(noteSubmenuButtons) do
        btn:Hide()
    end

    if not PurpleNotesDB.notes then return end

    local yOffset = -5

    for i = 1, #PurpleNotesDB.notes do
        local btn = noteSubmenuButtons[i]

        if not btn then
            btn = CreateFrame("Button", nil, noteSubmenu)
            btn:SetSize(150, 25)
            btn:EnableMouse(true)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 5, 0)
            text:SetPoint("RIGHT", btn, "RIGHT", -26, 0) -- space for delete icon
            text:SetTextColor(0.7, 0.7, 0.7, 1)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            btn.text = text

            -- Delete button
            local del = CreateFrame("Button", nil, btn)
            del:SetSize(16, 16)
            del:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
            del:SetPropagateMouseClicks(false)

            local delTex = del:CreateTexture(nil, "ARTWORK")
            delTex:SetAllPoints()
            delTex:SetTexture("Interface\\Buttons\\UI-StopButton")
            delTex:SetVertexColor(1, 0, 0, 1) -- make it red
            del.delTex = delTex

            del:SetScript("OnEnter", function(self)
                if btn.text then btn.text:SetTextColor(1, 1, 1, 1) end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Delete note", 1, 1, 1, 1)
                GameTooltip:Show()
            end)

            del:SetScript("OnLeave", function()
                if btn.text then btn.text:SetTextColor(0.7, 0.7, 0.7, 1) end
                GameTooltip:Hide()
            end)

            del:SetScript("OnClick", function(self)
                local deleteIndex = self.noteIndex
                if not deleteIndex then return end

                -- Keep your existing "only note" warning as-is (no confirmation needed here)
                if #PurpleNotesDB.notes <= 1 then
                    UIErrorsFrame:AddMessage("You must keep at least one note.", 1, 0.2, 0.2)
                    return
                end

                pendingDeleteIndex = deleteIndex
                StaticPopup_Show("PURPLENOTES_DELETE_NOTE_CONFIRM")
            end)

            btn.deleteButton = del

            -- Row hover + click (uses self.noteIndex, not i)
            btn:SetScript("OnEnter", function(self)
                if self.text then self.text:SetTextColor(1, 1, 1, 1) end
                if self.fullTitle then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.fullTitle, 1, 1, 1, 1)
                    if GameTooltipTextLeft1 then
                        GameTooltipTextLeft1:SetWordWrap(true)
                    end
                    GameTooltip:Show()
                end
            end)

            btn:SetScript("OnLeave", function(self)
                if self.text then self.text:SetTextColor(0.7, 0.7, 0.7, 1) end
                GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", function(self)
                local idx = self.noteIndex
                if not idx then return end
                SwitchToNote(idx)
                noteSubmenu:Hide()
                noteSubmenuPinned = false
                menuDropdown:Hide()
            end)

            noteSubmenuButtons[i] = btn
        end

        -- Always update per-refresh state
        btn.noteIndex = i
        btn.deleteButton.noteIndex = i

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", noteSubmenu, "TOPLEFT", 5, yOffset)

        local noteData = PurpleNotesDB.notes[i]
        local fullTitle = (noteData and noteData.title and noteData.title ~= "") and noteData.title or ("Note " .. i)

        local displayText = fullTitle
        if displayText:len() > 15 then
            displayText = displayText:sub(1, 15) .. "..."
        end

        btn.fullTitle = fullTitle
        btn.text:SetText(displayText)

        btn:Show()
        yOffset = yOffset - 27
    end

    noteSubmenu:SetHeight(math.max(40, #PurpleNotesDB.notes * 27 + 10))
end

for i, itemText in ipairs(menuItems) do
    local item = CreateFrame("Button", nil, menuDropdown)
    item:SetSize(140, 25)
    item:SetPoint("TOPLEFT", menuDropdown, "TOPLEFT", 5, -5 - (i-1) * 27)
    item:EnableMouse(true)
    
    local text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", item, "LEFT", 5, 0)
    text:SetText(itemText)
    text:SetTextColor(0.7, 0.7, 0.7, 1)
    
    item:SetScript("OnEnter", function()
        text:SetTextColor(1, 1, 1, 1)
        if i == 1 and not noteSubmenuPinned then
            UpdateNoteSubmenu()
            noteSubmenu:Show()
        end
    end)
    item:SetScript("OnLeave", function()
        text:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    item:SetScript("OnClick", function()
        if i == 1 then
            -- Toggle pinned state for "Select Note"
            noteSubmenuPinned = not noteSubmenuPinned
            if noteSubmenuPinned then
                UpdateNoteSubmenu()
                noteSubmenu:Show()
            else
                noteSubmenu:Hide()
            end
        elseif i == 2 then
            -- Close Menu
            menuDropdown:Hide()
            noteSubmenu:Hide()
            noteSubmenuPinned = false
        elseif i == 3 then
            -- Exit - hide the entire frame
            menuDropdown:Hide()
            noteSubmenu:Hide()
            noteSubmenuPinned = false
            frame:Hide()
        end
    end)
    
    menuButtons[i] = item
end

-- Hide submenu when leaving dropdown or submenu area
menuDropdown:SetScript("OnUpdate", function(self)
    if noteSubmenu:IsShown() and not noteSubmenuPinned then
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        x = x / scale
        y = y / scale
        
        local menuLeft, menuBottom, menuWidth, menuHeight = self:GetRect()
        local subLeft, subBottom, subWidth, subHeight = noteSubmenu:GetRect()
        
        local inMenu = x >= menuLeft and x <= (menuLeft + menuWidth) and y >= menuBottom and y <= (menuBottom + menuHeight)
        local inSubmenu = subLeft and x >= subLeft and x <= (subLeft + subWidth) and y >= subBottom and y <= (subBottom + subHeight)
        
        -- Check if hovering over "Select Note" menu item specifically
        local selectNoteButton = menuButtons[1]
        local btnLeft, btnBottom, btnWidth, btnHeight = selectNoteButton:GetRect()
        local onSelectNote = btnLeft and x >= btnLeft and x <= (btnLeft + btnWidth) and y >= btnBottom and y <= (btnBottom + btnHeight)
        
        if not onSelectNote and not inSubmenu then
            noteSubmenu:Hide()
        end
    end
end)

-- Menu button functionality
menuButton:SetScript("OnClick", function()
    if menuDropdown:IsShown() then
        menuDropdown:Hide()
    else
        menuDropdown:Show()
    end
end)

menuButton:SetScript("OnEnter", function()
    menuButton:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
end)

menuButton:SetScript("OnLeave", function()
    menuButton:SetBackdropColor(0, 0, 0, 0.95)
end)

-- Left arrow button
local leftArrow = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
leftArrow:SetSize(20, 20)
leftArrow:SetPoint("LEFT", menuButton, "RIGHT", 3, 0)
leftArrow:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
leftArrow:SetBackdropColor(0.15, 0.15, 0.15, 0.95)

local leftArrowText = leftArrow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
leftArrowText:SetPoint("CENTER", 0, 0)
leftArrowText:SetText("<")
leftArrowText:SetTextColor(0.3, 0.3, 0.3, 1)

leftArrow:SetScript("OnEnter", function()
    leftArrowText:SetTextColor(0.7, 0.7, 0.7, 1)
end)

leftArrow:SetScript("OnLeave", function()
    leftArrowText:SetTextColor(0.3, 0.3, 0.3, 1)
end)

-- Right arrow button
local rightArrow = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
rightArrow:SetSize(20, 20)
rightArrow:SetPoint("LEFT", leftArrow, "RIGHT", 2, 0)
rightArrow:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
rightArrow:SetBackdropColor(0.15, 0.15, 0.15, 0.95)

local rightArrowText = rightArrow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
rightArrowText:SetPoint("CENTER", 0, 0)
rightArrowText:SetText(">")
rightArrowText:SetTextColor(0.3, 0.3, 0.3, 1)

rightArrow:SetScript("OnEnter", function()
    rightArrowText:SetTextColor(0.7, 0.7, 0.7, 1)
end)

rightArrow:SetScript("OnLeave", function()
    rightArrowText:SetTextColor(0.3, 0.3, 0.3, 1)
end)

-- Title/Name EditBox (centered in title bar)
local titleEditBox = CreateFrame("EditBox", nil, titleBar, "BackdropTemplate")
titleEditBox:SetHeight(20)
titleEditBox:SetPoint("LEFT", rightArrow, "RIGHT", 50, 0)
titleEditBox:SetPoint("RIGHT", titleBar, "RIGHT", -80, 0)
titleEditBox:SetFontObject(GameFontNormal)
titleEditBox:SetAutoFocus(false)
titleEditBox:SetTextInsets(8, 8, 0, 0)
titleEditBox:SetTextColor(0.7, 0.7, 0.7, 1)
titleEditBox:SetJustifyH("CENTER")
titleEditBox:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
titleEditBox:SetBackdropColor(0, 0, 0, 0.7)

titleEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

titleEditBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

titleEditBox:SetScript("OnEditFocusGained", function(self)
    -- Always reload full title from database when clicked
    local noteData = PurpleNotesDB.notes[currentNoteIndex]
    if noteData and noteData.title and noteData.title ~= "" then
        self:SetText(noteData.title)
        self:SetTextColor(0.7, 0.7, 0.7, 1)
    else
        self:SetText("")
    end
end)

titleEditBox:SetScript("OnEditFocusLost", function(self)
    local text = self:GetText():trim()
    if PurpleNotesDB.notes[currentNoteIndex] then
        if text == "" then
            PurpleNotesDB.notes[currentNoteIndex].title = nil
            -- Set placeholder
            self:SetText("Note " .. currentNoteIndex)
            self:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            PurpleNotesDB.notes[currentNoteIndex].title = text
            self:SetTextColor(0.7, 0.7, 0.7, 1)
        end
    end
end)

titleEditBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and PurpleNotesDB.notes[currentNoteIndex] then
        local text = self:GetText():trim()
        if text ~= "" then
            PurpleNotesDB.notes[currentNoteIndex].title = text
            self:SetTextColor(0.7, 0.7, 0.7, 1)
        end
    end
end)

-- Set up titleBar dragging after all child widgets are defined
local function IsInteractiveChild(focus)
    return focus == titleEditBox
        or focus == menuButton
        or focus == leftArrow
        or focus == rightArrow
end

titleBar:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end

    local foci = GetMouseFoci()
    local focus = (foci and foci[1]) or nil

    if focus ~= self and focus and IsInteractiveChild(focus) then
        return -- clicked a child control; do not start moving
    end

    -- If we were sizing (or anything weird), hard-stop first
    frame:StopMovingOrSizing()
    frame.isSizing = false

    frame:StartMoving()
    frame.isMoving = true
end)

titleBar:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then return end
    if frame.isMoving then
        frame:StopMovingOrSizing()
        frame.isMoving = false
        SaveFrameState()
    end
end)

-- Close menu when clicking outside
local menuCloser = CreateFrame("Frame")
menuCloser:SetScript("OnUpdate", function(self)
    if not menuDropdown:IsShown() then return end
    
    if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
        self.wasMouseDown = false
        return
    end
    
    if self.wasMouseDown then return end
    self.wasMouseDown = true
    
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x = x / scale
    y = y / scale
    
    local menuLeft, menuBottom, menuWidth, menuHeight = menuDropdown:GetRect()
    local inMenu = menuLeft and x >= menuLeft and x <= (menuLeft + menuWidth) and y >= menuBottom and y <= (menuBottom + menuHeight)
    
    local inSubmenu = false
    if noteSubmenu:IsShown() then
        local subLeft, subBottom, subWidth, subHeight = noteSubmenu:GetRect()
        inSubmenu = subLeft and x >= subLeft and x <= (subLeft + subWidth) and y >= subBottom and y <= (subBottom + subHeight)
    end
    
    local btnLeft, btnBottom, btnWidth, btnHeight = menuButton:GetRect()
    local inButton = btnLeft and x >= btnLeft and x <= (btnLeft + btnWidth) and y >= btnBottom and y <= (btnBottom + btnHeight)
    
    if not inMenu and not inSubmenu and not inButton then
        menuDropdown:Hide()
        noteSubmenu:Hide()
        noteSubmenuPinned = false
    end
end)

-- Close button
local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
close:SetScript("OnClick", function()
    frame:Hide()
end)

-- Scroll frame (adjusted for title bar)
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Edit box
local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetFontObject(ChatFontNormal)
editBox:SetAutoFocus(false)
editBox:SetTextInsets(5, 5, 5, 5)
editBox:SetTextColor(0.8, 0.4, 1) -- purple
scrollFrame:SetScrollChild(editBox)

-- Function to switch notes
SwitchToNote = function(index, skipSave)
    -- Save current note text and title before switching (unless told not to)
    if not skipSave and PurpleNotesDB.notes[currentNoteIndex] then
        PurpleNotesDB.notes[currentNoteIndex].text = editBox:GetText()
        local titleText = titleEditBox:GetText():trim()
        if titleText ~= "" and titleText ~= ("Note " .. currentNoteIndex) then
            PurpleNotesDB.notes[currentNoteIndex].title = titleText
        end
    end
    
    -- Switch to new note
    currentNoteIndex = index
    PurpleNotesDB.currentNote = index
    
    -- Load new note text
    local noteData = PurpleNotesDB.notes[currentNoteIndex]
    if noteData then
        editBox:SetText(noteData.text or "")
        
        -- Load title or set placeholder
        if noteData.title and noteData.title ~= "" then
            titleEditBox:SetText(noteData.title)
            titleEditBox:SetTextColor(0.7, 0.7, 0.7, 1)
        else
            titleEditBox:SetText("Note " .. currentNoteIndex)
            titleEditBox:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    else
        PurpleNotesDB.notes[currentNoteIndex] = {text = ""}
        editBox:SetText("")
        titleEditBox:SetText("Note " .. currentNoteIndex)
        titleEditBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end
    
    editBox:SetCursorPosition(0)
    scrollFrame:UpdateScrollChildRect()
end

-- Arrow button click handlers
leftArrow:SetScript("OnClick", function()
    if not PurpleNotesDB.notes then
        PurpleNotesDB.notes = {{text = ""}}
    end
    if currentNoteIndex > 1 then
        SwitchToNote(currentNoteIndex - 1)
    end
end)

rightArrow:SetScript("OnClick", function()
    if not PurpleNotesDB.notes then
        PurpleNotesDB.notes = {{text = ""}}
    end

    local atEnd = (currentNoteIndex >= #PurpleNotesDB.notes)

    -- If there's already a next note, always allow moving to it
    if not atEnd then
        SwitchToNote(currentNoteIndex + 1)
        return
    end

    -- Only block if we're at the end AND the current note is blank (prevents creating empty new notes)
    local currentText = editBox:GetText()
    if currentText and currentText:trim() == "" then
        return
    end

    -- Create new note and advance
    table.insert(PurpleNotesDB.notes, {text = ""})
    SwitchToNote(currentNoteIndex + 1)
end)

-- Resize handle (bottom-right)
local resizeButton = CreateFrame("Button", nil, frame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function()
    -- Clicking the grip often causes EditBoxes to lose focus first; that can trip move/anchor state.
    titleEditBox:ClearFocus()
    editBox:ClearFocus()

    -- Hard stop any pending move/sizing before starting a new sizing op (prevents the "snap")
    frame:StopMovingOrSizing()
    frame.isMoving = false

    frame:StartSizing("BOTTOMRIGHT")
    frame.isSizing = true
end)

resizeButton:SetScript("OnMouseUp", function()
    if frame.isSizing then
        frame:StopMovingOrSizing()
        frame.isSizing = false
        SaveFrameState()
    end
end)

-- Optional polish: show resize grip only on hover
resizeButton:SetAlpha(0)
frame:SetScript("OnEnter", function() resizeButton:SetAlpha(1) end)
frame:SetScript("OnLeave", function() resizeButton:SetAlpha(0) end)

-- Keep edit box width in sync with frame size
local function UpdateLayout()
    local w = frame:GetWidth()
    editBox:SetWidth(math.max(50, w - 60))
    scrollFrame:UpdateScrollChildRect()
end

local function RefreshTitleVisibility()
    -- Don't fight the user while they are actively typing
    if titleEditBox:HasFocus() then return end

    -- Force the EditBox to reset its horizontal scroll/cursor view
    local txt = titleEditBox:GetText() or ""
    titleEditBox:SetCursorPosition(0)

    -- Some clients only update the scroll when cursor/text changes,
    -- so "poke" the text (no-op visually) to refresh the display.
    titleEditBox:SetText(txt)
    titleEditBox:SetCursorPosition(0)
end

frame:SetScript("OnSizeChanged", function()
    UpdateLayout()
    RefreshTitleVisibility()
end)

-- Load saved state (size/pos only - note text is loaded earlier)
local function ApplySavedState()
    if PurpleNotesDB.w and PurpleNotesDB.h then
        frame:SetSize(PurpleNotesDB.w, PurpleNotesDB.h)
    end

    if PurpleNotesDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(
            PurpleNotesDB.point,
            UIParent,
            PurpleNotesDB.relativePoint or PurpleNotesDB.point,
            PurpleNotesDB.xOfs or 0,
            PurpleNotesDB.yOfs or 0
        )
    end

    UpdateLayout()
end

-- Save size/pos when moving/resizing stops
SaveFrameState = function()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    PurpleNotesDB.point = point
    PurpleNotesDB.relativePoint = relativePoint
    PurpleNotesDB.xOfs = xOfs
    PurpleNotesDB.yOfs = yOfs

    PurpleNotesDB.w = frame:GetWidth()
    PurpleNotesDB.h = frame:GetHeight()
end

-- Note: SaveFrameState() is now called directly in titleBar OnMouseUp and resizeButton OnMouseUp

-- Save notes continuously
editBox:SetScript("OnTextChanged", function(self)
    if PurpleNotesDB.notes and PurpleNotesDB.notes[currentNoteIndex] then
        PurpleNotesDB.notes[currentNoteIndex].text = self:GetText()
    end
    scrollFrame:UpdateScrollChildRect()
end)

-- Slash commands
SLASH_PURPLENOTES1 = "/pn"
SLASH_PURPLENOTES2 = "/purplenotes"
SlashCmdList["PURPLENOTES"] = function(msg)
    local command = msg:lower():trim()
    
    if command == "reset" then
        StaticPopup_Show("PURPLENOTES_RESET_CONFIRM")
    else
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
            editBox:SetFocus()
        end
    end
end

StaticPopupDialogs["PURPLENOTES_DELETE_NOTE_CONFIRM"] = {
    text = "Delete this note?\n\n|cffff0000This cannot be undone.|r",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        local deleteIndex = pendingDeleteIndex
        pendingDeleteIndex = nil
        if not deleteIndex then return end

        -- Keep your existing rule: must keep at least one note
        if #PurpleNotesDB.notes <= 1 then
            UIErrorsFrame:AddMessage("You must keep at least one note.", 1, 0.2, 0.2)
            return
        end

        local deletingCurrent = (deleteIndex == currentNoteIndex)

        -- Decide which note should become active AFTER deletion
        local newIndex = currentNoteIndex
        if deletingCurrent then
            if deleteIndex > 1 then
                newIndex = deleteIndex - 1      -- prefer previous
            else
                newIndex = 1                    -- after removal, old #2 becomes #1
            end
        else
            -- If we delete something before the current note, current shifts left by 1
            if currentNoteIndex > deleteIndex then
                newIndex = currentNoteIndex - 1
            else
                newIndex = currentNoteIndex
            end
        end

        table.remove(PurpleNotesDB.notes, deleteIndex)

        -- Clamp newIndex to valid range
        if newIndex > #PurpleNotesDB.notes then
            newIndex = #PurpleNotesDB.notes
        end
        if newIndex < 1 then newIndex = 1 end

        PurpleNotesDB.currentNote = newIndex

        -- If we deleted the active note, load the chosen neighbor WITHOUT saving the deleted note
        if deletingCurrent then
            SwitchToNote(newIndex, true)
        else
            -- Just update the indices (no need to reload text)
            currentNoteIndex = newIndex
            PurpleNotesDB.currentNote = newIndex
        end

        UpdateNoteSubmenu()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Reset confirmation popup
StaticPopupDialogs["PURPLENOTES_RESET_CONFIRM"] = {
    text = "Are you sure you want to reset PurpleNotes?\n\n|cffff0000This will delete all notes, reset position and size, and cannot be undone.|r",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        -- Clear all data
        PurpleNotesDB = {
            notes = {{text = ""}},
            currentNote = 1
        }
        currentNoteIndex = 1
        
        -- Reset frame position and size
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
        frame:SetSize(400, 300)
        
        -- Clear and reload
        editBox:SetText("")
        print("|cff8040ffPurpleNotes:|r All data has been reset.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Initialize once player is in game
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    -- Ensure currentNoteIndex is in sync with saved data
    currentNoteIndex = PurpleNotesDB.currentNote or 1
    
    -- Load the current note's text and title
    local noteData = PurpleNotesDB.notes[currentNoteIndex]
    if noteData then
        editBox:SetText(noteData.text or "")
        
        -- Load title or set placeholder
        if noteData.title and noteData.title ~= "" then
            titleEditBox:SetText(noteData.title)
            titleEditBox:SetTextColor(0.7, 0.7, 0.7, 1)
        else
            titleEditBox:SetText("Note " .. currentNoteIndex)
            titleEditBox:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    else
        editBox:SetText("")
        titleEditBox:SetText("Note " .. currentNoteIndex)
        titleEditBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end
    
    ApplySavedState()
    frame:Hide()
end)
