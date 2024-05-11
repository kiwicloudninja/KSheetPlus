--- === KSheetPlus ===
---
--- Keybindings cheatsheet for current application
---

local obj={}
obj.__index = obj

-- Metadata
obj.name = "KSheetPlus"
obj.version = "1.0"
obj.author = "Davo <davo@kiwicloudninja.com>"
obj.homepage = "https://github.com/kiwicloudninja/KSheetPlus"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Workaround for "Dictation" menuitem
hs.application.menuGlyphs[148]="fn fn"

obj.commandEnum = {
    cmd = '⌘',
    shift = '⇧',
    alt = '⌥',
    ctrl = '⌃',
}

obj.theme = 'default'
obj.position = 'top'

function fileExists(name)
    local f = io.open(name, "r")
    return f ~= nil and io.close(f)
 end

local function positionSubMenu()
    local positions = {
        "top",
        "right",
        "centre",
        "bottom",
        "left"
    }
    local position_menu = {}
    for i, position in pairs(positions) do
        table.insert(position_menu, {
            title = (position:gsub("^%l", string.upper)),
            fn = function() obj:setPosition(position) end,
            checked = obj.position == position,
            disabled = obj.position == position,
            shortcut = position:sub(1,1)
        })
    end

    return position_menu
end

local function themeSubMenu()
    local theme_path = hs.spoons.resourcePath('themes/')
    local file = io.open(theme_path .. "themes", "r");
    if file == nil then
        return
    end
    local themes = {}
    for line in file:lines() do
        if line ~= "" and fileExists(theme_path .. line .. "/style.css") then
            table.insert(themes, line);
        end
    end
    file:close()
    local theme_menu = {}
    for i, theme in pairs(themes) do
        table.insert(theme_menu, {
            title = (theme:gsub("^%l", string.upper)),
            fn = function() obj:setTheme(theme) end,
            checked = obj.theme == theme,
            disabled = obj.theme == theme,
        })
    end

    return theme_menu
end

local function setMenuItems()
    local items = {
        { title = "Theme",  menu=themeSubMenu(), shortcut='t' },
        { title = "Position", menu=positionSubMenu(), shortcut='p' }
      }
    return items
end

local function addMenu()
    obj.menu = hs.menubar.new(true)
    obj.menu:setTitle("⌘K")
    obj.menu:setMenu(setMenuItems())
end

--- Method
--- Initialize the spoon
function obj:init()
    addMenu()
    self.sheetView = hs.webview.new({x=0, y=0, w=0, h=0})
    self.sheetView:alpha(0.90)
    self.sheetView:windowTitle("CheatSheets")
    self.sheetView:windowStyle("utility")
    self.sheetView:allowGestures(true)
    self.sheetView:allowNewWindows(false)
    self.sheetView:level(hs.drawing.windowLevels.tornOffMenu)
    self:setPosition("top")
end

function obj:setTheme(theme_name)
    self.theme = theme_name
    self:show()
    self.menu:setMenu(setMenuItems())
end

function obj:setPosition(position)
    ---TODO: Update menu checkboxes. Fix up bottom y.
    self.position = position
    local cscreen = hs.screen.mainScreen()
    local cres = cscreen:fullFrame()
    local x_centered = cres.x+(cres.w*.5)-512
    local y_centered = cres.y+(cres.h*.5)-(cres.h*.25)
    local width = 220
    local height = 240

    ---Default position is top
    local win_pos = {
        x = x_centered,
        y = cres.y+10,
        w = 1024,
        h = height
    }

    ---Adjust y for bottom
    if position == "bottom" then
        win_pos.y = cres.h - 60 - height
    end
    --Adjust y,h for left, centre, right
    if position ~= "top" and position ~= "bottom" then
        win_pos.y = y_centered
        win_pos.h = cres.h*.5
    end
    ---Adjust w,x for left & right
    if position == "left" or position == "right" then
        win_pos.w = width
        if position == "left" then
            win_pos.x = 0
        else
            win_pos.x = cres.w - width
        end
    end
    self.sheetView:frame(win_pos)
    self:show()
    self.menu:setMenu(setMenuItems())
end

local function processMenuItems(menustru)
    local menu = ""
        for pos,val in pairs(menustru) do
            if type(val) == "table" then
                -- TODO: Remove menubar items with no shortcuts in them
                if val.AXRole == "AXMenuBarItem" and type(val.AXChildren) == "table" then
                    menu = menu .. "<ul class='col col" .. pos .. "'>"
                    menu = menu .. "<li class='title'><strong>" .. val.AXTitle .. "</strong></li>"
                    menu = menu .. processMenuItems(val.AXChildren[1])
                    menu = menu .. "</ul>"
                elseif val.AXRole == "AXMenuItem" and not val.AXChildren then
                    if not (val.AXMenuItemCmdChar == '' and val.AXMenuItemCmdGlyph == '') then
                        local CmdModifiers = ''
                        for key, value in pairs(val.AXMenuItemCmdModifiers) do
                            CmdModifiers = CmdModifiers .. obj.commandEnum[value]
                        end
                        local CmdChar = val.AXMenuItemCmdChar
                        local CmdGlyph = hs.application.menuGlyphs[val.AXMenuItemCmdGlyph] or ''
                        local CmdKeys = CmdChar .. CmdGlyph
                        menu = menu .. "<li><div class='cmdModifiers'>" .. CmdModifiers .. " " .. CmdKeys .. "</div><div class='cmdtext'>" .. " " .. val.AXTitle .. "</div></li>"
                    end
                elseif val.AXRole == "AXMenuItem" and type(val.AXChildren) == "table" then
                    menu = menu .. processMenuItems(val.AXChildren[1])
                end
            end
        end
    return menu
end

local function loadCSS()
    local css_path = hs.spoons.resourcePath('themes/' .. obj.theme .. '/style.css')
    local css_file = io.open(css_path, "r")
    if css_file == nil then
        hs.dialog.alert(200, 200, nil, "No style sheet", "Couldn't load theme stylesheet", "OK")
        return ''
    end
    local css = css_file:read("*a")
    css_file:close()
    if obj.position == "left" or obj.position == "right" then
        css = css .. ".content > .col { width:90%; }"
    end
    return css
end

local function generateHtml(application)
    local app_title = application:title()
    local menuitems_tree = application:getMenuItems()
    local allmenuitems = processMenuItems(menuitems_tree)
    local theme_css = loadCSS()

    local html = [[
        <!DOCTYPE html>
        <html>
            <head>
            <style type="text/css">]] .. theme_css .. [[</style>
            </head>
            <body>
                <header>
                <div class="title"><strong>]] .. app_title .. [[</strong></div>
                <hr />
                </header>
                <div class="content maincontent">]] .. allmenuitems .. [[</div>
                <br>
                <footer>
                    <hr />
                    <div class="content" >
                        <div class="col">
                            original by <a href="https://github.com/dharmapoudel" target="_parent">dharma poudel</a>
                        </div>
                    </div>
                </footer>
            </body>
        </html>
        ]]

    return html
end

--- KSheetPlus:show()
--- Method
--- Show current application's keybindings in a view.
function obj:show()
    local capp = hs.application.frontmostApplication()
    local webcontent = generateHtml(capp)
    self.sheetView:html(webcontent)
    self.sheetView:show()
end

--- KSheetPlus:hide()
--- Method
--- Hide the cheatsheet view.
function obj:hide()
    self.sheetView:hide()
end

--- KSheetPlus:toggle()
--- Method
--- Alternatively show/hide the cheatsheet view.
function obj:toggle()
  if self.sheetView and self.sheetView:hswindow() and self.sheetView:hswindow():isVisible() then
    self:hide()
  else
    self:show()
  end
end

--- KSheetPlus:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for KSheetPlus
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * show - Show the keybinding view
---   * hide - Hide the keybinding view
---   * toggle - Show if hidden, hide if shown
function obj:bindHotkeys(mapping)
  local actions = {
    toggle = hs.fnutils.partial(self.toggle, self),
    show = hs.fnutils.partial(self.show, self),
    hide = hs.fnutils.partial(self.hide, self)
  }
  hs.spoons.bindHotkeysToSpec(actions, mapping)
end

return obj
