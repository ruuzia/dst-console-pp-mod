
--[[---- CONSOLE -----------
self.consoletext = Text(BODYTEXTFONT, 20, "CONSOLE TEXT")
self.consoletext:SetVAlign(ANCHOR_BOTTOM)
self.consoletext:SetHAlign(ANCHOR_LEFT)
self.consoletext:SetVAnchor(ANCHOR_MIDDLE)
self.consoletext:SetHAnchor(ANCHOR_MIDDLE)
self.consoletext:SetScaleMode(SCALEMODE_PROPORTIONAL)

self.consoletext:SetRegionSize(900, 406)
self.consoletext:SetPosition(0,0,0)
self.consoletext:Hide()

TheFrontEnd.consoletext = ScrollableList(
    self.list_widgets,  -- items
    175,                -- listwidth
    280,                -- listheight
    20,                 -- itemheight
    0,                  -- itempadding
    nil,                -- updatefn
    nil,                -- widgetstoupdate
    nil,                -- widgetXOffset
    nil,                -- always_show_static
    nil,                -- starting_offset
    15,                 -- yInit
    nil,                -- bar_width_scale_factor
    nil,                -- bar_height_scale_factor
    "GOLD"              -- scrollbar_style
)
-----------------]]

TheFrontEnd.consoletext:SetPosition(-100, 100, 0)
