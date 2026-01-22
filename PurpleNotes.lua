-- PurpleNotes - simple notepad with a draggable, resizable frame.
PurpleNotesDB = PurpleNotesDB or {}

local frame = CreateFrame("Frame", "PurpleNotesFrame", UIParent, "BackdropTemplate")
frame:SetSize(400, 300)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Resizing
frame:SetResizable(true)
frame:SetResizeBounds(200, 150)

-- Background
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
})
frame:SetBackdropColor(0, 0, 0, 0.75)

-- Close button
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Edit box
local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetFontObject(ChatFontNormal)
editBox:SetAutoFocus(false)
editBox:SetTextInsets(5, 5, 5, 5)
editBox:SetTextColor(0.8, 0.4, 1) -- purple
scrollFrame:SetScrollChild(editBox)

-- Resize handle (bottom-right)
local resizeButton = CreateFrame("Button", nil, frame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function()
    frame:StartSizing("BOTTOMRIGHT")
end)

resizeButton:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
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

frame:SetScript("OnSizeChanged", function()
    UpdateLayout()
end)

-- Load saved state (text + optional size/pos)
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

    editBox:SetText(PurpleNotesDB.text or "")
    UpdateLayout()
end

-- Save size/pos when moving/resizing stops
local function SaveFrameState()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    PurpleNotesDB.point = point
    PurpleNotesDB.relativePoint = relativePoint
    PurpleNotesDB.xOfs = xOfs
    PurpleNotesDB.yOfs = yOfs

    PurpleNotesDB.w = frame:GetWidth()
    PurpleNotesDB.h = frame:GetHeight()
end

-- Hook drag stop to save position
frame:HookScript("OnDragStop", function()
    SaveFrameState()
end)

-- Also save after sizing ends
resizeButton:HookScript("OnMouseUp", function()
    SaveFrameState()
end)

-- Save notes continuously
editBox:SetScript("OnTextChanged", function(self)
    PurpleNotesDB.text = self:GetText()
    scrollFrame:UpdateScrollChildRect()
end)

-- Slash commands
SLASH_PURPLENOTES1 = "/pn"
SLASH_PURPLENOTES2 = "/purplenotes"
SlashCmdList["PURPLENOTES"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        editBox:SetFocus()
    end
end

-- Initialize once player is in game
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    ApplySavedState()
    frame:Hide()
end)
