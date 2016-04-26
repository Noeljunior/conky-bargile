--[[
    Yet another conky-lua theme, this one includes some kind of an engine
    Copyright (C) 2016  Tiago Levita

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>
--]]

defaultfile = "/etc/conky/conky-bargile.lua.default"
homefile = os.getenv("HOME") .. "/.config/conky/conky-bargile.lua"

--==============================================================================
--====================================================================
--==================================================================== MAIN LOOP
--====================================================================
--==============================================================================

function conky_bargile()
    if isready ~= true then
        if conky_window == nil --or isready < 5
                    or conky_window.width == 0
                    or conky_window.height == 0
                    then
            --isready = isready + 1
            return
        end
        --print('Initializing...')
        isready = true

        -- init cairo
        cs = cairo_xlib_surface_create(conky_window.display,
            conky_window.drawable, conky_window.visual, conky_window.width,
            conky_window.height)
        cr = cairo_create(cs)

        -- one time init
        robjects = {}

        updateinterval = 1.0

        -- call init function
        if type(bargile_init) == "function" then
            bargile_init()
        end

    end
    if firsttimerender == nil then
        firsttimerender = true
        conky_set_update_interval(updateinterval)
        --return
    end

    -- call loop function
    if type(bargile_loop) == "function" then
        if bargile_loop() == true then return end
    end

    -- update and draw all objects
    for i, ro in pairs(robjects) do
        ro:udraw()
    end
end


--==============================================================================
--======================================================================
--====================================================================== RENGINE
--======================================================================
--==============================================================================

--========================================================
--================================================ HELPERS
--========================================================

--------------------------------------------
--                   general purpose helpers
--------------------------------------------

function bgh_bold() return CAIRO_FONT_WEIGHT_BOLD end

function bgh_prescake(bytes)
    -- returns a staired scale
    return bytes
end

function bgh_rad(degree)
    return degree * (math.pi/180.0)
end

function bgh_rgbablend(c1, c2, p)
    local ip = 1 - p
    return { c1[1] * ip + c2[1] * p, c1[2] * ip + c2[2] * p, c1[3] * ip + c2[3] * p, c1[4] * ip + c2[4] * p }
end

function bgh_fstring(s, ...)
    return string.format(s, ...)
end

function bgh_log(n)
    return math.log(n + 1)
end

function bgh_htb(str)
    if str == nil then str = "" end
    num = tonumber(string.match(str, "%d+[%.]?%d+"))
    if num == nil then return 0 end
    if     (string.find(str, 'E'))   then num = num * 1024 ^ 6
    elseif (string.find(str, 'P'))   then num = num * 1024 ^ 5
    elseif (string.find(str, 'T'))   then num = num * 1024 ^ 4
    elseif (string.find(str, 'G'))   then num = num * 1024 ^ 3
    elseif (string.find(str, 'M'))   then num = num * 1024 ^ 2
    elseif (string.find(str, 'K'))   then num = num * 1024
    end
    return num
end

function bgh_rgba_to_r_g_b_a(colour)
    return {((colour[1] / 0x10000) % 0x100) / 255.,
            ((colour[1] / 0x100) % 0x100) / 255.,
            (colour[1] % 0x100) / 255.,
            colour[2]}
end

function bgh_hexa_rgba(colour, alpha)
    if type(colour) ~= "table" then colour = {colour} end
    alpha = colour[2] or alpha
    if alpha ~= nil then
        return ((colour[1] / 0x10000) % 0x100) / 255.,
               ((colour[1] / 0x100) % 0x100) / 255.,
                (colour[1] % 0x100) / 255.,
                alpha
    else
        return ((colour[1] / 0x10000) % 0x100) / 255.,
               ((colour[1] / 0x100) % 0x100) / 255.,
                (colour[1] % 0x100) / 255.
    end
end

function bgh_tmerge(t1, t2)
    for i, val in pairs(t2) do
        table.insert(t1, val)
    end
end

function bgh_inlist(e, t)
    local ret = false
    for i, val in pairs(t) do
        if val == e then
            ret = true
            break
        end
    end
    return ret
end

function bgh_torender(ros)
    if robjects == nil then robjects = {} end
    bgh_tmerge(robjects, ros)
end

function bgh_conky(cmd)
    return conky_parse('${' .. cmd .. '}')
end

function bgh_exec(cmd)
    local f = io.popen(cmd, 'r')
    local s = f:read("*a")
    f:close()
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', '\n')
    return s
end

function bgh_nicstate(nic)
    local checkcmd = 'NIC="' .. nic .. '"; ' .. [[ state=$(ip addr show dev $NIC 2>/dev/null | grep -Eo "state (UP)?(DOWN)?(UNKNOWN)?" | grep -Eo "(UP)?(DOWN)?(UNKNOWN)?")
        if [ "$state" == "UP" ] || [ "$state" == "UNKNOWN" ]; then
            IP=$(ip addr show dev $NIC 2>/dev/null | grep "brd" | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
            echo "UP $IP"
            exit 0 
        fi
        echo "DOWN" ]]

    local resstr = bgh_exec(checkcmd)
    local res = {}
    for word in resstr:gmatch("%S+") do table.insert(res, word) end
    return res[1], res[2]
end

function bgh_copytable(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

function bgh_tprint(table, rec)
    if rec == nil then rec = 0 end
    --if type(table) == "table" then
        for i, val in pairs(table) do
            io.write(string.rep("   ", rec))
            if type(val) == "table" then
                print("[" .. i .. "] {")
                bgh_tprint(val, rec + 1)
                print("}")
            else
                print("[" .. i .. "] = " .. val)
            end
        end
    --else
    --    print(table)
    --end
end

--------------------------------------------
--                     autodetectors helpers
--------------------------------------------

function bgh_nothreads()
    return tonumber(bgh_exec("nproc"))
end

function bgh_cpus(nothreads)
    cpus = {}
    for i = 1, nothreads, 1 do
        table.insert(cpus, i)
    end
    return cpus
end

function bgh_lmsensors(grep)
    if grep == nil then
        grep = "grep 'Core [0-9]*:' | cut -d: -f1"
    end
    local lmsensors = bgh_exec("sensors | " .. grep)

    local sensors = {}
    for sense in lmsensors:gmatch("[^\n]+") do
        table.insert(sensors, sense)
    end
    return sensors
end

function bgh_lmsense(grep)
    return "sensors | grep '".. grep .. "' | cut -d+ -f2 | cut -d. -f1"
end

function bgh_hddtemp_disks(cmd)
    cmd = cmd or "nc localhost 7634"
    local hddtemps = bgh_exec(cmd)
    hddtemps = string.gsub(hddtemps, "||", "|\n|")
    local disks = {}
    local names = {}
    for hddtemp in hddtemps:gmatch("[^\n]+") do
        local ht = hddtemp:split("|")
        table.insert(disks, ht[1])
        table.insert(names, ht[1]:sub(ht[1]:find("/[^/]*$") + 1))
    end
    return disks, names
end

function bgh_hddtemps(cmd)
    cmd = cmd or "nc localhost 7634"
    local hddtemps = bgh_conky("exec " .. cmd)
    hddtemps = string.gsub(hddtemps, "||", "|\n|")
    local temps = {}
    for hddtemp in hddtemps:gmatch("[^\n]+") do
        local ht = hddtemp:split("|")
        local t = tonumber(ht[3])
        if t ~= nil then
            temps[ht[1]] = ht[3]
        end
    end
    return temps
end

function bgh_filesystems(grep, devname)
    grep = grep or "grep /dev/sd | grep ext"

    grep = " | " .. grep

    local mounts = bgh_exec("cat /proc/mounts" .. grep)

    local disks = {}
    local dnames = {}
    local parts = {}

    for amount in mounts:gmatch("[^\n]+") do
        local mount = amount:split(" ")
        local alreadythere = false
        for i, val in pairs(parts) do
            if val == mount[1] then
                alreadythere = true
                break
            end
        end
        if alreadythere == false then
            table.insert(parts, mount[1])

            table.insert(disks, mount[2])
            if devname ~= nil then
                table.insert(dnames, mount[1])
            else
                table.insert(dnames, mount[2])
            end
        end
    end

    return disks, dnames
end

function bgh_nics(ignore, force)
    ignore = ignore or {"lo"}
    force = force or {"ppp0"}

    local nics = {}
    local autonics = bgh_exec("ip link show | grep '^[0-9]*: [a-zA-Z0-9]*:' | cut -d' ' -f2 | cut -d: -f1")

    -- remove the ignores
    for nic in autonics:gmatch("[^\n]+") do
        if not bgh_inlist(nic, ignore) then
            table.insert(nics, nic)
        end
    end

    -- add the forces
    for i, val in pairs(force) do
        if not bgh_inlist(val, nics) then
            table.insert(nics, val)
        end
    end

    return nics
end

--------------------------------------------
--                            render helpers
--------------------------------------------
function bgh_init(fdef, fuser)
    --dofile()
    if bgh_fileexists(fuser) then
        print("Loading user's home config file...")
        dofile(fuser)
    elseif bgh_fileexists(fdef) then
        print("Loading default config file...")
        dofile(fdef)
    else
        print("Couldn't load a config file.")
    end
    -- load cairo
    require 'cairo'
end

function bgh_fileexists(fname)
    local f = io.open(fname, "r")
    if f ~= nil then io.close(f) return true else return false end
end

--------------------------------------------
--                  overrides of the std lib
--------------------------------------------
function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

--========================================================
--========================================= RENDER OBJECTS
--========================================================

--------------------------------------------
--                                     OPLOT
--------------------------------------------
-- Plot values in time...

bgh_oplot = {}
bgh_oplot.__index = bgh_oplot
function bgh_oplot:new (lengh, vmax, width, height, posx, posy, patfill, patline, patbg, hinv, vinv, vertical)
    local newobj = {}
    setmetatable(newobj, bgh_oplot)


    newobj.width  = width   or 200
    newobj.height = height  or 50
    newobj.posx   = posx    or 10
    newobj.posy   = posy    or 10
    newobj.length = length or newobj.width

    -- colours
    if patfill ~= nil then
        newobj.patfill = cairo_pattern_create_linear(0, 0, 0, 50)
        for i, val in pairs(patfill) do
            cairo_pattern_add_color_stop_rgba(newobj.patfill, unpack(val))
        end
    end
    if patline ~= nil then
        newobj.patline = cairo_pattern_create_linear(0, 0, 0, 50)
        for i, val in pairs(patline) do
            cairo_pattern_add_color_stop_rgba(newobj.patline, unpack(val))
        end
    end
    if patbg ~= nil then
        newobj.patbg = cairo_pattern_create_linear(0, 0, 0, 50)
        for i, val in pairs(patbg) do
            cairo_pattern_add_color_stop_rgba(newobj.patbg, unpack(val))
        end
    end

    -- autoscale
    if vmax ~= nil then
        if tonumber(vmax) ~= nil then
            newobj.vmax = tonumber(vmax)
        elseif type(vmax) == "table" then
            newobj.vmax = vmax
        end
    end


    -- values
    newobj.values = {}
    for i = 1, newobj.length, 1 do
        newobj.values[i] = 0
    end

    -- avg
    newobj.avg = 0

    -- step
    newobj.step = newobj.width / (newobj.length - 1)

    -- orientation & position
    newobj.hinv = {}
    if hinv ~= nil then
        newobj.hinv.t = newobj.width + newobj.posx
        newobj.hinv.s = -1
    else
        newobj.hinv.t = 0 + newobj.posx
        newobj.hinv.s = 1
    end

    newobj.vinv = {}
    if vinv ~= nil then
        newobj.vinv.t = 0 + newobj.posy
        newobj.vinv.s = 1
    else
        newobj.vinv.t = newobj.height + newobj.posy
        newobj.vinv.s = -1
    end

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    return newobj
end

function bgh_oplot:addval(val)
    if (tonumber(val) == nil) then return end
    val = tonumber(val)

    last = table.remove(self.values)
    table.insert(self.values, 1, val)

    -- compute the scale
    local vmax = 0
    if self.vmax ~= nil then
        vmax = self.vmax
    else
        for i, val in pairs(self.values) do vmax = val > vmax and val or vmax end
    end
    if vmax <= 0 then vmax = 1 end
    self.scaley = self.height / bgh_prescake(vmax)

    -- update avg
    self.avg = self.avg + val / #self.values - last / #self.values
end

function bgh_oplot:udraw()
    if self._drawme ~= nil and self._drawme() ~= true then
        -- do not draw this time
        return
    end

    self:addval(self._upfunc(unpack(self._upparams)))
    self:draw()
end

function bgh_oplot:getavg()
    return self.avg
end

function bgh_oplot:draw()
    -- positioning
    cairo_save(cr)
    cairo_rectangle(cr, self.posx, self.posy, self.width, self.height)
    cairo_clip(cr)
    --cairo_new_path(cr)

    -- background
    if self.patbg ~= nil then
        cairo_rectangle(cr, self.posx, self.posy, self.width, self.height)
        cairo_set_source(cr, self.patbg);
        cairo_set_line_width (cr, 0);
        cairo_fill(cr)
    end

    cairo_translate(cr, self.hinv.t, self.vinv.t)
    cairo_scale(    cr, self.hinv.s, self.vinv.s)

    -- plot fill
    if self.patfill ~= nil then
        cairo_move_to(cr, 0, 0)
        for i = 1, #self.values, 1 do
            cairo_line_to(cr, self.step * (i - 1), self.values[i] * self.scaley)
        end
        cairo_line_to(cr, self.step * (#self.values - 1), 0)
        cairo_close_path(cr)

        cairo_set_source(cr, self.patfill);
        cairo_set_line_width (cr, 0);
        cairo_fill(cr)
    end

    -- plot line
    if self.patline ~= nil then
        cairo_move_to(cr, 0, self.values[1] * self.scaley)
        for i = 2, #self.values, 1 do
            cairo_line_to(cr, self.step * (i - 1), self.values[i] * self.scaley)
        end

        cairo_set_source(cr, self.patline);
        cairo_set_line_width (cr, 1);
        cairo_stroke(cr)
    end

    cairo_restore(cr)
end

--------------------------------------------
--                                     OLINE
--------------------------------------------
-- A line gauge

bgh_oline = {}
bgh_oline.__index = bgh_oline
function bgh_oline:new(vmin, vmax, posx, posy, width, height, lwidth, colors, hinv)
    local newobj = {}
    setmetatable(newobj, bgh_oline)

    newobj.vmin   = vmin    or 0
    newobj.vmax   = vmax    or 100
    newobj.posx   = posx    or 10
    newobj.posy   = posy    or 10
    newobj.width  = width   or 300
    newobj.height = height  or 50
    newobj.lwidth = lwidth  or 0.5
    --newobj.color  = color   or {1, 0, 0, 1}

    -- colours
    if colors ~= nil then
        newobj.colors = cairo_pattern_create_linear(0, 0, 0, 50)
        for i, val in pairs(colors) do
            cairo_pattern_add_color_stop_rgba(newobj.colors, unpack(val))
        end
    end

    -- orientation & position
    newobj.hinv = {}
    if hinv ~= nil then
        newobj.hinv.t = 0 + newobj.posx
        newobj.hinv.s = 1
    else
        newobj.hinv.t = newobj.height + newobj.posy
        newobj.hinv.s = -1
    end

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    newobj:setval(newobj.vmin)

    return newobj
end

function bgh_oline:setval(val)
    if (tonumber(val) == nil) then return end
    val = tonumber(val)

    if val < self.vmin then val = self.vmin end
    if val > self.vmax then val = self.vmax end

    local perc = val / (self.vmax - self.vmin)

    self.pval = self.vmin + self.height * perc
end

function bgh_oline:udraw()
    if self._drawme ~= nil and self._drawme() ~= true then
        -- do not draw this time
        return
    end

    self:setval(self._upfunc(unpack(self._upparams)))
    self:draw()
end

function bgh_oline:draw()
    cairo_save(cr)
    cairo_rectangle(cr, self.posx, self.posy, self.width, self.height)
    cairo_clip(cr)

    cairo_translate(cr, self.posx, self.hinv.t)
    cairo_scale(    cr, 1,         self.hinv.s)


    cairo_move_to(cr, 0, self.pval)
    cairo_line_to(cr, self.width, self.pval)
    cairo_set_source(cr, self.colors);
    cairo_set_line_width(cr, self.lwidth);
    cairo_stroke(cr)


    cairo_restore(cr)
end

--------------------------------------------
--                                     OTEXT
--------------------------------------------
-- A text

bgh_otext = {}
bgh_otext.__index = bgh_otext
function bgh_otext:new(text, posx, posy, anchor, font, fcolor)
    local newobj = {}
    setmetatable(newobj, bgh_otext)


    newobj.text    = text     or ""
    newobj.posx    = posx     or 0
    newobj.posy    = posy     or 0
    newobj.anchor  = anchor   or ""
    newobj.fcolor  = fcolor   or {1, 1, 1, 1}

    newobj.font      = font   or {}
    newobj.font.size = newobj.font.size or 10
    newobj.font.face = newobj.font.face or "monospace"
    newobj.font.weight = newobj.font.weight or CAIRO_FONT_WEIGHT_NORMAL
    -- text extents
    newobj.te = cairo_text_extents_t:create()

    -- anchor
    newobj.ax, newobj.ay = newobj.anchor:sub(1,1), newobj.anchor:sub(2,2)
    if newobj.ax == nil then ax = "" end
    if newobj.ay == nil then ay = "" end

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    return newobj
end

function bgh_otext:settxt(text)
    if (text == nil) then return end
    self.text = text
end

function bgh_otext:udraw()
    if self._drawme ~= nil and self._drawme() ~= true then
        -- do not draw this time
        return
    end

    self:settxt(self._upfunc(unpack(self._upparams)))
    self:draw()
end

function bgh_otext:getsize()
    cairo_save(cr)

    cairo_select_font_face(cr, self.font.face, CAIRO_FONT_SLANT_NORMAL, self.font.weight)
    cairo_set_font_size(cr, self.font.size)
    cairo_set_source_rgba(cr, unpack(self.fcolor))

    -- compute outter box of the text (extents)
    local ex, ey = 0, 0
    cairo_text_extents(cr, self.text, self.te)

    if     self.ax == "c" then ex = -(self.te.width/2 + self.te.x_bearing)
    elseif self.ax == "r" then ex = -(self.te.width   + self.te.x_bearing)
    else                       ex = 0 end

    if     self.ay == "c" then ey = -(self.te.height/2 + self.te.y_bearing)
    elseif self.ay == "t" then ey = -(self.te.height   + self.te.y_bearing)
    else                       ey = 0 end

    cairo_restore(cr)

    return self.te.width, self.te.height
end

function bgh_otext:draw()
    cairo_save(cr)

    cairo_select_font_face(cr, self.font.face, CAIRO_FONT_SLANT_NORMAL, self.font.weight)
    cairo_set_font_size(cr, self.font.size)
    cairo_set_source_rgba(cr, unpack(self.fcolor))

    -- compute outter box of the text (extents)
    local ex, ey = 0, 0
    cairo_text_extents(cr, self.text, self.te)

    if     self.ax == "c" then ex = -(self.te.width/2 + self.te.x_bearing)
    elseif self.ax == "r" then ex = -(self.te.width   + self.te.x_bearing)
    else                       ex = 0 end

    if     self.ay == "c" then ey = -(self.te.height/2 + self.te.y_bearing)
    elseif self.ay == "t" then ey = -(self.te.height   + self.te.y_bearing)
    else                       ey = 0 end

    cairo_move_to(cr, self.posx + ex, self.posy + ey)
    cairo_show_text(cr, self.text)
    cairo_stroke(cr)

    cairo_restore(cr)
end



--------------------------------------------
--                                    OGAUGE
--------------------------------------------
-- A bar gauge

bgh_ogauge = {}
bgh_ogauge.__index = bgh_ogauge
function bgh_ogauge:newarc(vmin, vmax, posx, posy, radius, angles, anglef, width, widthtip, colorbg, colorfg, colorstip, colorstxt, txtfont, reverse)
    local newobj = {}
    setmetatable(newobj, bgh_ogauge)

    newobj.toarc     = true

    newobj.vmin      = vmin       or 0
    newobj.vmax      = vmax       or 100
    newobj.posx      = posx       or 100
    newobj.posy      = posy       or 300
    newobj.radius    = radius     or 50
    newobj.angles    = angles     or bgh_rad(90)
    newobj.anglef    = anglef     or bgh_rad(90+180)

    newobj.width     = width      or 5.0
    newobj.widthtip  = widthtip   or bgh_rad(5)
    newobj.colorbg   = colorbg    or {1, 1, 1, 0.2}
    newobj.colorfg   = colorfg    or {1, 1, 1, 0.6}
    newobj.colorstip = colorstip  or {{0, 1, 0, 0.6}, {1, 0, 0, 0.6}}
    newobj.colorstxt = colorstxt  or {{0, 1, 1, 0.6}, {1, 1, 0, 0.6}}
    newobj.reverse   = reverse

    newobj.font      = txtfont    or {}
    newobj.font.size = newobj.font.size or 8
    newobj.font.face = newobj.font.face or "sans-serif"
    newobj.font.weight = newobj.font.weight or CAIRO_FONT_WEIGHT_NORMAL
    -- text extents
    newobj.te = cairo_text_extents_t:create()

    -- pre computes
    if newobj.reverse == nil or newobj.reverse == false then
        newobj.cairoarc = cairo_arc
    else
        newobj.cairoarc = cairo_arc_negative
        newobj.angles = -newobj.angles
        newobj.anglef = -newobj.anglef
    end

    newobj.angled    = newobj.anglef - newobj.angles

    newobj.widthtip = newobj.widthtip / 2

    newobj.percmin = newobj.widthtip * 1 / newobj.angled
    newobj.percmax = 1 - newobj.percmin

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    newobj:setvaltxt(0, "")

    return newobj
end

function bgh_ogauge:newline(vmin, vmax, posx, posy, posfx, posfy, width, widthtip, colorbg, colorfg, colorstip, colorstxt, txtfont, reverse)
    local newobj = {}
    setmetatable(newobj, bgh_ogauge)

    newobj.toarc   = false

    newobj.vmin      = vmin       or 0
    newobj.vmax      = vmax       or 100
    newobj.posx      = posx       or 125
    newobj.posy      = posy       or 550
    newobj.posfx     = posfx      or 225
    newobj.posfy     = posfy      or 450

    newobj.width     = width      or 5.0
    newobj.widthtip  = widthtip   or 5
    newobj.colorbg   = colorbg    --or {1, 1, 1, 0.2}
    newobj.colorfg   = colorfg    --or {1, 1, 1, 0.6}
    newobj.colorstip = colorstip  --or {{0, 1, 0, 0.6}, {1, 0, 0, 0.6}}
    newobj.colorstxt = colorstxt  --or {{0, 1, 1, 0.6}, {1, 1, 0, 0.6}}
    newobj.reverse   = reverse

    newobj.font      = txtfont    or {}
    newobj.font.size = newobj.font.size or 8
    newobj.font.face = newobj.font.face or "sans-serif"
    newobj.font.weight = newobj.font.weight or CAIRO_FONT_WEIGHT_NORMAL
    -- text extents
    newobj.te = cairo_text_extents_t:create()

    -- pre computes
    if reverse == nil or reverse == false then
        local t1, t2 = newobj.posfx, newobj.posfy
        newobj.posfx, newobj.posfy = newobj.posx, newobj.posy
        newobj.posx, newobj.posy = t1, t2
    end
    newobj.vectordx  = newobj.posfx - newobj.posx
    newobj.vectordy  = newobj.posfy - newobj.posy

    newobj.widthtip = newobj.widthtip / 2

    local d = math.sqrt(newobj.vectordx^2 + newobj.vectordy^2)
    newobj.widthtipx = (newobj.vectordx / d) * newobj.widthtip
    newobj.widthtipy = (newobj.vectordy / d) * newobj.widthtip

    newobj.percmin = newobj.widthtip * 1 / d
    newobj.percmax = 1 - newobj.percmin

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    newobj:setvaltxt(newobj.vmin, "")

    return newobj
end

function bgh_ogauge:setvaltxt(val, text)
    if (tonumber(val) == nil) then return end
    val = tonumber(val)

    self.text = text or ""

    --print("gauge:setvaltxt", val, text)
    if val < self.vmin then val = self.vmin end
    if val > self.vmax then val = self.vmax end

    self.percent = val / (self.vmax - self.vmin)


    if self.toarc then
        self.pval = self.angles + self.angled * self.percent
        if self.percent < self.percmin then
            self.pval = self.angles + self.widthtip
        end
        if self.percent > self.percmax then
            self.pval = self.angles + self.angled - self.widthtip
        end
    else
        self.pvalx = self.vectordx * self.percent
        self.pvaly = self.vectordy * self.percent
        if self.percent < self.percmin then
            self.pvalx = self.vectordx * self.percmin
            self.pvaly = self.vectordy * self.percmin
        end
        if self.percent > self.percmax then
            self.pvalx = self.vectordx * self.percmax
            self.pvaly = self.vectordy * self.percmax
        end
    end

    -- colors blend
    if self.colorstip == nil then
    elseif #self.colorstip == 2 then
        self.colortip = bgh_rgbablend(self.colorstip[1], self.colorstip[2], self.percent)
    else
        self.colortip = self.colorstip[1]
    end

    if self.colorstxt == nil then
    elseif #self.colorstxt == 2 then
        self.colortxt = bgh_rgbablend(self.colorstxt[1], self.colorstxt[2], self.percent)
    else
        self.colortxt = self.colorstxt[1]
    end

end

function bgh_ogauge:udraw()
    if self._drawme ~= nil and self._drawme() ~= true then
        -- do not draw this time
        return
    end

    self:setvaltxt(self._upfunc(unpack(self._upparams)))
    self:draw()
end

function bgh_ogauge:draw()
    cairo_save(cr)
    cairo_translate(cr, self.posx, self.posy)

    -- background
    if self.colorbg ~= nil then
        if self.toarc then
            self.cairoarc(cr, 0, 0, self.radius, self.angles, self.anglef)
        else
            cairo_move_to(cr, 0, 0)
            cairo_line_to(cr, self.vectordx, self.vectordy)
        end
        cairo_set_source_rgba(cr, unpack(self.colorbg))
        cairo_set_line_width(cr, self.width)
        cairo_stroke(cr)
    end

    -- foreground
    if self.colorfg ~= nil then
        if self.toarc then
            self.cairoarc(cr, 0, 0, self.radius, self.angles, self.pval - self.widthtip)
        else
            cairo_move_to(cr, 0, 0)
            cairo_line_to(cr, self.pvalx - self.widthtipx, self.pvaly - self.widthtipy)
        end
        cairo_set_source_rgba(cr, unpack(self.colorfg))
        cairo_set_line_width(cr, self.width)
        cairo_stroke(cr)
    end

    -- tip
    if self.colortip ~= nil then
        if self.toarc then
            self.cairoarc(cr, 0, 0, self.radius, self.pval - self.widthtip, self.pval + self.widthtip)
        else
            cairo_move_to(cr, self.pvalx - self.widthtipx, self.pvaly - self.widthtipy)
            cairo_line_to(cr, self.pvalx + self.widthtipx, self.pvaly + self.widthtipy)
        end
        cairo_set_source_rgba(cr, unpack(self.colortip))
        cairo_set_line_width(cr, self.width)
        cairo_stroke(cr)
    end

    -- text
    if self.colortxt ~= nil then
        cairo_select_font_face(cr, self.font.face, CAIRO_FONT_SLANT_NORMAL, self.font.weight)
        cairo_set_font_size(cr, self.font.size)
        cairo_set_source_rgba(cr, unpack(self.colortxt))

        -- compute outter box of the text (extents)
        local ex, ey = 0, 0
        cairo_text_extents(cr, self.text, self.te)

        if self.toarc then
            ex = self.radius * math.cos(self.pval) - (self.te.width/2 + self.te.x_bearing)
            ey = self.radius * math.sin(self.pval) - (self.te.height/2 + self.te.y_bearing)
        else
            ex = self.pvalx - (self.te.width/2 + self.te.x_bearing)
            ey = self.pvaly - (self.te.height/2 + self.te.y_bearing)
        end

        cairo_move_to(cr, ex, ey)
        cairo_show_text(cr, self.text)
        cairo_stroke(cr)
    end
    cairo_restore(cr)
end

--========================================================
--================================= RENDER OBJECTS HELPERS
--========================================================

--------------------------------------------
--                                  SYNCPLOT
--------------------------------------------
-- A bgh_oplot two-container that syncs the
--  scale btween both to the bigger one

bgh_syncplot = {}
bgh_syncplot.__index = bgh_syncplot
function bgh_syncplot:new (roplota, roplotb)
    local newobj = {}
    setmetatable(newobj, bgh_syncplot)

    newobj.roplota = roplota
    newobj.roplotb = roplotb

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    return newobj
end

function bgh_syncplot:udraw()
    self.roplota:addval(self.roplota._upfunc(unpack(self.roplota._upparams)))
    self.roplotb:addval(self.roplotb._upfunc(unpack(self.roplotb._upparams)))

    -- sync the max/scaley value
    local max = self.roplota.scaley
    if self.roplotb.scaley < self.roplota.scaley then
        max = self.roplotb.scaley
    end
    self.roplota.scaley = max
    self.roplotb.scaley = max

    self.roplota:draw()
    self.roplotb:draw()
end

--------------------------------------------
--                                 GROUPLIST
--------------------------------------------
-- A render object container render, or not,
--  the content in a list format.

bgh_grouplist = {}
bgh_grouplist.__index = bgh_grouplist
function bgh_grouplist:new (incx, incy)
    local newobj = {}
    setmetatable(newobj, bgh_grouplist)

    newobj.incx = incx
    newobj.incy = incy

    -- list of plots
    newobj.groups = {}

    -- auto draw function/params
    newobj._upfunc = function() return nil end
    newobj._upparams = {}

    return newobj
end

function bgh_grouplist:addgroup(plot)
    table.insert(self.groups, plot)
end

function bgh_grouplist:udraw()
    cairo_save(cr)
    cairo_translate(cr, -self.incx, -self.incy)
    for i, group in pairs(self.groups) do
        if group._drawme ~= nil and group._drawme() == true then
            cairo_translate(cr, self.incx, self.incy)
            for j, ro in pairs(group) do
                if type(ro) == "table" then
                    ro:udraw()
                end
            end
        end

    end
    cairo_restore(cr)
end

--------------------------------------------
--                                     DUMMY
--------------------------------------------
-- A dummy render object that executes a
--  function tick() every drawing

bgh_dummy = {}
bgh_dummy.__index = bgh_dummy
function bgh_dummy:new()
    local newobj = {}
    setmetatable(newobj, bgh_dummy)

    -- auto draw function/params
    newobj._upfunc = function() return nil end

    newobj._upparams = {}
    return newobj
end


function bgh_dummy:udraw()
    if self.tick ~= nil then
        self:tick()
    end
end


--========================================================
--============================================= INIT STUFF
--========================================================
bgh_init(defaultfile, homefile)
-- EOF

