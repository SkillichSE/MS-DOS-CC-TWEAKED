-- MS-DOS 6.22

local VERSION_STR = "MS-DOS Version 6.22"
local BOOT_TITLE  = "MS-DOS 6.22"

local currentDir = "C:\\"
local env = {
    PATH    = "C:\\DOS;C:\\",
    PROMPT  = "$p$g",
    COMSPEC = "C:\\COMMAND.COM",
    TEMP    = "C:\\TEMP",
    TMP     = "C:\\TEMP",
}
local function setColor(fg, bg)
    if term.isColor() then
        if fg then term.setTextColor(fg) end
        if bg then term.setBackgroundColor(bg) end
    end
end
local function resetColor() setColor(colors.white, colors.black) end
local function dosToCC(path)
    if path == nil then return "/" end
    path = path:gsub("^[A-Za-z]:[/\\]+", "/")
    path = path:gsub("\\", "/")
    path = path:gsub("/+", "/")
    if path == "" then path = "/" end
    return path
end

local function ccToDos(path)
    if path == "/" or path == "" then return "C:\\" end
    path = path:gsub("/", "\\")
    if path:sub(1,1) == "\\" then return "C:" .. path end
    return "C:\\" .. path
end

local function getCurrentCC() return dosToCC(currentDir) end

local function resolvePath(arg)
    if arg == nil or arg == "" then return getCurrentCC() end
    if arg:match("^[A-Za-z]:[/\\]") or arg:match("^[A-Za-z]:$") then
        return dosToCC(arg)
    end
    if arg:sub(1,1) == "/" then return arg end
    arg = arg:gsub("\\", "/")
    local base = getCurrentCC()
    local parts = {}
    for p in base:gmatch("[^/]+") do table.insert(parts, p) end
    for seg in arg:gmatch("[^/]+") do
        if seg == ".." then
            if #parts > 0 then table.remove(parts) end
        elseif seg ~= "." then
            table.insert(parts, seg)
        end
    end
    if #parts == 0 then return "/" end
    return "/" .. table.concat(parts, "/")
end

local function getDriveLetter() return "C" end

local DOW = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"}
local MON = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

local function getDateTime()
    local day  = os.day()
    local time = os.time()
    local h    = math.floor(time) % 24
    local m    = math.floor((time - math.floor(time)) * 60)
    local s    = math.floor(((time - math.floor(time)) * 60 - m) * 60)
    local d    = (day - 1) % 28 + 1
    local dow  = DOW[((day - 1) % 7) + 1]
    local ampm = "a"
    local h12  = h
    if h >= 12 then ampm = "p" end
    if h12 == 0 then h12 = 12 elseif h12 > 12 then h12 = h12 - 12 end
    local dateStr = string.format("01-%02d-1994", d)
    local timeStr = string.format("%02d:%02d:%02d.%02d%s", h12, m, s, 0, ampm)
    return dateStr, timeStr, dow
end

local function renderPrompt()
    local prompt = env.PROMPT or "$p$g"
    local date, time, dow = getDateTime()
    local result = prompt
        :gsub("%$p", currentDir)
        :gsub("%$P", currentDir)
        :gsub("%$g", ">")
        :gsub("%$G", ">")
        :gsub("%$l", "<")
        :gsub("%$L", "<")
        :gsub("%$b", "|")
        :gsub("%$B", "|")
        :gsub("%$n", getDriveLetter())
        :gsub("%$N", getDriveLetter())
        :gsub("%$d", dow .. " " .. date)
        :gsub("%$D", dow .. " " .. date)
        :gsub("%$t", time)
        :gsub("%$T", time)
        :gsub("%$v", VERSION_STR)
        :gsub("%$V", VERSION_STR)
        :gsub("%$_", "\n")
        :gsub("%$%$", "$")
        :gsub("%$e", "\27")
        :gsub("%$h", "\8")
        :gsub("%$q", "=")
        :gsub("%$Q", "=")
    return result
end

local function morePager(lines)
    local _, h = term.getSize()
    local pageH = h - 1
    local i = 1
    while i <= #lines do
        print(lines[i])
        i = i + 1
        if i <= #lines and (i - 1) % pageH == 0 then
            setColor(colors.black, colors.white)
            io.write("-- More --")
            resetColor()
            local ev, key = os.pullEvent("key")
            io.write("\r          \r")
            if key == keys.q then break end
        end
    end
end

local commands = {}

commands["cls"] = function(args)
    term.clear()
    term.setCursorPos(1, 1)
end

commands["ver"] = function(args)
    print()
    print(VERSION_STR)
    print()
end

commands["echo"] = function(args, rawLine)
    if rawLine then
        local rest = rawLine:match("^[Ee][Cc][Hh][Oo](.*)")
        if rest then
            if rest:match("^[%.%(%)!%+%-%,;=@#%$%%^&%*]") then
                print("")
                return
            end
        end
    end
    if #args == 0 then
        print("ECHO is on.")
    elseif args[1]:lower() == "on" then
        print("ECHO is on.")
    elseif args[1]:lower() == "off" then
    else
        print(table.concat(args, " "))
    end
end

commands["date"] = function(args)
    local date, _, dow = getDateTime()
    print("Current date is " .. dow .. " " .. date)
    io.write("Enter new date (mm-dd-yy): ")
    io.read()
end

commands["time"] = function(args)
    local _, time = getDateTime()
    print("Current time is " .. time)
    io.write("Enter new time: ")
    io.read()
end

commands["vol"] = function(args)
    print()
    print(" Volume in drive C is VOLUME1")
    print(" Volume Serial Number is 1994-0101")
    print()
end

commands["dir"] = function(args)
    local target = getCurrentCC()
    local wideMode = false
    local pauseMode = false
    local showHidden = false
    for _, a in ipairs(args) do
        local al = a:lower()
        if al == "/w" then wideMode = true
        elseif al == "/p" then pauseMode = true
        elseif al == "/a" or al == "/a:h" then showHidden = true
        elseif a:sub(1,1) ~= "/" then target = resolvePath(a)
        end
    end

    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("File Not Found")
        resetColor()
        return
    end
    if not fs.isDir(target) then
        setColor(colors.red, colors.black)
        print("File not found")
        resetColor()
        return
    end

    local dosTarget = ccToDos(target)
    local outLines = {}
    table.insert(outLines, "")
    table.insert(outLines, " Volume in drive C is VOLUME1")
    table.insert(outLines, " Volume Serial Number is 1994-0101")
    table.insert(outLines, " Directory of " .. dosTarget)
    table.insert(outLines, "")

    local files = fs.list(target)
    table.sort(files, function(a,b) return a:lower() < b:lower() end)

    local fileCount, dirCount, totalBytes = 0, 0, 0
    local date = getDateTime()

    local function fmtDate(d)
        return d or "01-01-94"
    end
    local curDate = (function()
        local dd = os.day()
        local d = (dd - 1) % 28 + 1
        return string.format("01-%02d-94", d)
    end)()
    local curTime12 = (function()
        local t = os.time()
        local h = math.floor(t) % 24
        local m2 = math.floor((t - math.floor(t)) * 60)
        local ampm = h >= 12 and "p" or "a"
        if h > 12 then h = h - 12 elseif h == 0 then h = 12 end
        return string.format("%2d:%02d%s", h, m2, ampm)
    end)()

    if not wideMode then
        table.insert(outLines, string.format("%-8s %-3s      <DIR>  %s  %s", ".", "", curDate, curTime12))
        table.insert(outLines, string.format("%-8s %-3s      <DIR>  %s  %s", "..", "", curDate, curTime12))
    end
    dirCount = dirCount + 2

    if wideMode then
        local row = {}
        for _, name in ipairs(files) do
            local fullPath = fs.combine(target, name)
            local isDir = fs.isDir(fullPath)
            local entry = isDir and ("[" .. name:upper() .. "]") or name:upper()
            table.insert(row, string.format("%-15s", entry))
            if #row == 5 then
                table.insert(outLines, table.concat(row))
                row = {}
            end
            if isDir then dirCount = dirCount + 1 else fileCount = fileCount + 1 end
        end
        if #row > 0 then table.insert(outLines, table.concat(row)) end
    else
        for _, name in ipairs(files) do
            local fullPath = fs.combine(target, name)
            local isDir = fs.isDir(fullPath)
            if isDir then
                dirCount = dirCount + 1
                local namePart = name:upper()
                table.insert(outLines, string.format("%-8s %-3s      <DIR>  %s  %s",
                    namePart, "", curDate, curTime12))
            else
                fileCount = fileCount + 1
                local size = fs.getSize(fullPath)
                totalBytes = totalBytes + size
                local base, ext = name:match("^(.+)%.([^%.]+)$")
                if not base then base = name; ext = "" end
                table.insert(outLines, string.format("%-8s %-3s %9d  %s  %s",
                    base:upper():sub(1,8), ext:upper():sub(1,3),
                    size, curDate, curTime12))
            end
        end
    end

    table.insert(outLines, "")
    table.insert(outLines, string.format("%9d file(s)   %12d bytes", fileCount, totalBytes))
    table.insert(outLines, string.format("%9d dir(s)    %12d bytes free", dirCount, 1044480))
    table.insert(outLines, "")

    if pauseMode then
        morePager(outLines)
    else
        for _, l in ipairs(outLines) do print(l) end
    end
end

commands["cd"] = function(args)
    if #args == 0 then
        print(currentDir)
        return
    end
    local target = args[1]
    if target:match("^[A-Za-z]:$") then
        print(currentDir)
        return
    end
    local resolved = resolvePath(target)
    if not fs.exists(resolved) then
        setColor(colors.red, colors.black)
        print("The system cannot find the path specified.")
        resetColor()
    elseif not fs.isDir(resolved) then
        setColor(colors.red, colors.black)
        print("The directory name is invalid.")
        resetColor()
    else
        currentDir = ccToDos(resolved)
    end
end
commands["chdir"] = commands["cd"]

commands["md"] = function(args)
    if #args == 0 then
        print("The syntax of the command is incorrect.")
        return
    end
    local target = resolvePath(args[1])
    if fs.exists(target) then
        setColor(colors.red, colors.black)
        print("A subdirectory or file " .. args[1]:upper() .. " already exists.")
        resetColor()
    else
        fs.makeDir(target)
    end
end
commands["mkdir"] = commands["md"]

commands["rd"] = function(args)
    if #args == 0 then
        print("The syntax of the command is incorrect.")
        return
    end
    local target = resolvePath(args[1])
    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("The system cannot find the path specified.")
        resetColor()
    elseif not fs.isDir(target) then
        setColor(colors.red, colors.black)
        print("The directory name is invalid.")
        resetColor()
    elseif #fs.list(target) > 0 then
        setColor(colors.red, colors.black)
        print("The directory is not empty.")
        resetColor()
    else
        fs.delete(target)
    end
end
commands["rmdir"] = commands["rd"]

commands["del"] = function(args)
    if #args == 0 then
        print("Required parameter missing.")
        return
    end
    local target = resolvePath(args[1])
    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("File not found")
        resetColor()
    elseif fs.isDir(target) then
        io.write("All files in directory will be deleted! Are you sure (Y/N)?")
        local ans = io.read()
        if ans and ans:upper() == "Y" then
            local function deleteAll(path)
                for _, f in ipairs(fs.list(path)) do
                    local full = fs.combine(path, f)
                    if fs.isDir(full) then deleteAll(full) end
                    fs.delete(full)
                end
            end
            deleteAll(target)
        end
    else
        fs.delete(target)
    end
end
commands["erase"] = commands["del"]

commands["type"] = function(args)
    if #args == 0 then
        print("Required parameter missing.")
        return
    end
    local target = resolvePath(args[1])
    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("File not found - " .. args[1]:upper())
        resetColor()
        return
    end
    if fs.isDir(target) then
        setColor(colors.red, colors.black)
        print("Access denied.")
        resetColor()
        return
    end
    local f = fs.open(target, "r")
    if f then
        local content = f.readAll()
        f.close()
        io.write(content)
        if content:sub(-1) ~= "\n" then print() end
    end
end

commands["copy"] = function(args)
    if #args == 0 then
        print("The syntax of the command is incorrect.")
        return
    end

    if args[1] and args[1]:lower() == "con" and args[2] then
        local dst = resolvePath(args[2])
        local lines2 = {}
        print("(Type content, press Ctrl+Z / F6 then Enter to finish)")
        while true do
            local line = io.read()
            if line == nil or line == "\26" or line:upper() == "^Z" then break end
            table.insert(lines2, line)
        end
        local f = fs.open(dst, "w")
        f.write(table.concat(lines2, "\n"))
        f.close()
        print("        1 file(s) copied.")
        return
    end

    local dst = nil
    local srcs = {}
    for i, a in ipairs(args) do
        if a:sub(1,1) == "/" then
        elseif i == #args and #args > 1 then
            dst = resolvePath(a)
        else
            for src in (a .. "+"):gmatch("([^+]+)%+") do
                table.insert(srcs, src)
            end
        end
    end

    if #srcs == 0 or dst == nil then
        print("The syntax of the command is incorrect.")
        return
    end

    if #srcs == 1 then
        local src = resolvePath(srcs[1])
        if not fs.exists(src) then
            setColor(colors.red, colors.black)
            print("File not found - " .. srcs[1]:upper())
            resetColor()
            return
        end
        if fs.exists(dst) and fs.isDir(dst) then
            dst = fs.combine(dst, fs.getName(src))
        end
        fs.copy(src, dst)
        print("        1 file(s) copied.")
    else
        local buf = {}
        local count = 0
        for _, name in ipairs(srcs) do
            local p = resolvePath(name)
            if fs.exists(p) and not fs.isDir(p) then
                local f = fs.open(p, "r")
                table.insert(buf, f.readAll())
                f.close()
                count = count + 1
            else
                setColor(colors.red, colors.black)
                print("File not found - " .. name:upper())
                resetColor()
            end
        end
        local out = fs.open(dst, "w")
        out.write(table.concat(buf, ""))
        out.close()
        print(string.format("        %d file(s) copied.", count))
    end
end

commands["xcopy"] = function(args)
    if #args < 2 then
        print("The syntax of the command is incorrect.")
        return
    end
    local src = resolvePath(args[1])
    local dst = resolvePath(args[2])
    local subDirs = false
    local count = 0
    for i = 3, #args do
        if args[i]:lower() == "/s" or args[i]:lower() == "/e" then subDirs = true end
    end

    if not fs.exists(src) then
        setColor(colors.red, colors.black)
        print("File not found - " .. args[1]:upper())
        resetColor()
        return
    end

    local function xcopyDir(from, to)
        if not fs.exists(to) then fs.makeDir(to) end
        for _, name in ipairs(fs.list(from)) do
            local fp = fs.combine(from, name)
            local tp = fs.combine(to, name)
            if fs.isDir(fp) and subDirs then
                xcopyDir(fp, tp)
            elseif not fs.isDir(fp) then
                print(ccToDos(fp))
                fs.copy(fp, tp)
                count = count + 1
            end
        end
    end

    if fs.isDir(src) then
        xcopyDir(src, dst)
    else
        if fs.exists(dst) and fs.isDir(dst) then
            dst = fs.combine(dst, fs.getName(src))
        end
        print(ccToDos(src))
        fs.copy(src, dst)
        count = 1
    end
    print(string.format("%d File(s) copied", count))
end

commands["ren"] = function(args)
    if #args < 2 then
        print("The syntax of the command is incorrect.")
        return
    end
    local src = resolvePath(args[1])
    local dst = fs.combine(fs.getDir(src), args[2])
    if not fs.exists(src) then
        setColor(colors.red, colors.black)
        print("File not found - " .. args[1]:upper())
        resetColor()
        return
    end
    if fs.exists(dst) then
        setColor(colors.red, colors.black)
        print("Duplicate file name or file not found")
        resetColor()
        return
    end
    fs.move(src, dst)
end
commands["rename"] = commands["ren"]

commands["move"] = function(args)
    if #args < 2 then
        print("The syntax of the command is incorrect.")
        return
    end
    local src = resolvePath(args[1])
    local dst = resolvePath(args[2])
    if not fs.exists(src) then
        setColor(colors.red, colors.black)
        print("File not found - " .. args[1]:upper())
        resetColor()
        return
    end
    if fs.exists(dst) and fs.isDir(dst) then
        dst = fs.combine(dst, fs.getName(src))
    end
    fs.move(src, dst)
    print(ccToDos(src) .. " => " .. ccToDos(dst))
    print("        1 file(s) moved.")
end

commands["set"] = function(args)
    if #args == 0 then
        local ks = {}
        for k in pairs(env) do table.insert(ks, k) end
        table.sort(ks)
        for _, k in ipairs(ks) do print(k .. "=" .. env[k]) end
        return
    end
    local line = table.concat(args, " ")
    local key, val = line:match("^([%w_]+)=(.*)$")
    if key then
        key = key:upper()
        if val == "" then
            env[key] = nil
        else
            env[key] = val
        end
    else
        local k = line:upper()
        if env[k] then
            print(k .. "=" .. env[k])
        else
            print("Environment variable " .. k .. " not defined")
        end
    end
end

commands["path"] = function(args)
    if #args == 0 then
        if env.PATH then
            print("PATH=" .. env.PATH)
        else
            print("No Path")
        end
    else
        env.PATH = table.concat(args, " ")
    end
end

commands["prompt"] = function(args)
    if #args == 0 then
        env.PROMPT = "$p$g"
    else
        env.PROMPT = table.concat(args, " ")
    end
end

commands["attrib"] = function(args)
    local setR, clearR, setH, clearH, setA, clearA = false,false,false,false,false,false
    local paths2 = {}
    for _, a in ipairs(args) do
        local al = a:lower()
        if al == "+r" then setR=true elseif al == "-r" then clearR=true
        elseif al == "+h" then setH=true elseif al == "-h" then clearH=true
        elseif al == "+a" then setA=true elseif al == "-a" then clearA=true
        elseif a:sub(1,1) ~= "/" then table.insert(paths2, a)
        end
    end
    local noSwitches = not(setR or clearR or setH or clearH or setA or clearA)
    local target = #paths2 > 0 and resolvePath(paths2[1]) or getCurrentCC()

    if fs.isDir(target) and (noSwitches) then
        for _, name in ipairs(fs.list(target)) do
            local fp = fs.combine(target, name)
            local attr = fs.isReadOnly(fp) and "R" or " "
            print(string.format("  %s         %s", attr, ccToDos(fp)))
        end
    elseif fs.exists(target) then
        if noSwitches then
            local attr = fs.isReadOnly(target) and "R" or " "
            print(string.format("  %s         %s", attr, ccToDos(target)))
        else
            print("Attribute change not supported on this drive.")
        end
    else
        setColor(colors.red, colors.black)
        print("File not found - " .. ccToDos(target))
        resetColor()
    end
end

commands["format"] = function(args)
    print()
    print("Insert new diskette for drive C:")
    print("and press ENTER when ready...")
    io.read()
    setColor(colors.yellow, colors.black)
    print("Format failed.")
    print("The disk is write-protected.")
    resetColor()
end

commands["mem"] = function(args)
    print()
    local sep = string.rep("-", 16) .. "  " .. string.rep("-", 7) ..
                "  " .. string.rep("-", 8) .. "  " .. string.rep("-", 7)
    local fmt = "%-16s %7dK  %8dK  %7dK"
    print("Memory Type          Total       Used       Free")
    print(sep)
    print(string.format(fmt, "Conventional",    640,   48,  592))
    print(string.format(fmt, "Upper",           155,   99,   56))
    print(string.format(fmt, "Extended (XMS)", 3072, 2048, 1024))
    print(sep)
    print(string.format(fmt, "Total memory",   3867, 2195, 1672))
    print()
    print("Total under 1 MB  795K (814080 bytes)")
    print()
end

commands["chkdsk"] = function(args)
    print()
    print("Volume VOLUME1     created 01-01-1994 12:00a")
    print("Volume Serial Number is 1994-0101")
    print()
    print("     1,048,576 bytes total disk space")
    print("        49,152 bytes in 3 hidden files")
    print("        32,768 bytes in 5 directories")
    print("       245,760 bytes in 47 user files")
    print("       720,896 bytes available on disk")
    print()
    print("         4,096 bytes in each allocation unit")
    print("           256 total allocation units on disk")
    print("           176 available allocation units on disk")
    print()
    print("       655,360 total bytes memory")
    print("       604,784 bytes free")
    print()
end

commands["more"] = function(args)
    if #args == 0 then
        print("Reads output from standard input and displays it one screen at a time.")
        return
    end
    local target = resolvePath(args[1])
    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("File not found - " .. args[1]:upper())
        resetColor()
        return
    end
    local f = fs.open(target, "r")
    local content = f.readAll()
    f.close()
    local ls = {}
    for l in (content .. "\n"):gmatch("([^\n]*)\n") do table.insert(ls, l) end
    morePager(ls)
end

commands["sort"] = function(args)
    local target = nil
    local reverse = false
    for _, a in ipairs(args) do
        if a:lower() == "/r" then reverse = true
        elseif a:sub(1,1) ~= "/" then target = resolvePath(a)
        end
    end
    if not target then
        print("SORT: incorrect parameters.")
        return
    end
    if not fs.exists(target) then
        setColor(colors.red, colors.black)
        print("File not found - " .. target)
        resetColor()
        return
    end
    local f = fs.open(target, "r")
    local content = f.readAll()
    f.close()
    local ls = {}
    for l in (content .. "\n"):gmatch("([^\n]*)\n") do table.insert(ls, l) end
    table.sort(ls, function(a,b)
        return reverse and (a > b) or (a < b)
    end)
    for _, l in ipairs(ls) do print(l) end
end

local function printTree(path, prefix)
    prefix = prefix or ""
    if not fs.isDir(path) then return end
    local items = fs.list(path)
    table.sort(items)
    for i, name in ipairs(items) do
        local fullPath = fs.combine(path, name)
        local isLast = (i == #items)
        local connector  = isLast and "\\---" or "+---"
        local childPfx   = isLast and "    " or "|   "
        if fs.isDir(fullPath) then
            setColor(colors.cyan, colors.black)
            print(prefix .. connector .. name:upper())
            resetColor()
            printTree(fullPath, prefix .. childPfx)
        end
    end
end

commands["tree"] = function(args)
    local target = args[1] and resolvePath(args[1]) or getCurrentCC()
    if not fs.exists(target) or not fs.isDir(target) then
        setColor(colors.red, colors.black)
        print("Invalid path - " .. ccToDos(target))
        resetColor()
        return
    end
    print("Folder PATH listing for volume VOLUME1")
    print("Volume serial number is 1994-0101")
    setColor(colors.cyan, colors.black)
    print(ccToDos(target))
    resetColor()
    printTree(target)
    print()
end

commands["find"] = function(args)
    local flags = { v=false, c=false, n=false, i=false }
    local needle = nil
    local files2 = {}
    local i = 1
    while i <= #args do
        local a = args[i]
        local al = a:lower()
        if al == "/v" then flags.v = true
        elseif al == "/c" then flags.c = true
        elseif al == "/n" then flags.n = true
        elseif al == "/i" then flags.i = true
        elseif a:sub(1,1) == '"' then
            local q = a
            while q:sub(-1) ~= '"' and i < #args do
                i = i + 1; q = q .. " " .. args[i]
            end
            needle = q:gsub('^"', ''):gsub('"$', '')
        elseif a:sub(1,1) == "/" then
        else
            table.insert(files2, a)
        end
        i = i + 1
    end

    if needle == nil or #files2 == 0 then
        print("FIND: Parameter format not correct.")
        return
    end

    for _, fname in ipairs(files2) do
        local fpath = resolvePath(fname)
        if not fs.exists(fpath) then
            setColor(colors.red, colors.black)
            print("FIND: File not found - " .. fname:upper())
            resetColor()
        else
            print("---------- " .. fname:upper())
            local f = fs.open(fpath, "r")
            local count = 0
            local lineNum = 0
            local line = f.readLine()
            while line do
                lineNum = lineNum + 1
                local haystack = flags.i and line:lower() or line
                local ndl      = flags.i and needle:lower() or needle
                local found    = haystack:find(ndl, 1, true)
                local show     = flags.v and not found or (not flags.v and found)
                if show then
                    count = count + 1
                    if not flags.c then
                        if flags.n then
                            print(string.format("[%d]%s", lineNum, line))
                        else
                            print(line)
                        end
                    end
                end
                line = f.readLine()
            end
            f.close()
            if flags.c then
                print(string.format("---------- %s: %d", fname:upper(), count))
            end
        end
    end
end

commands["pause"] = function(args)
    print("Press any key to continue . . .")
    os.pullEvent("key")
end

local _pause = commands["pause"]

commands["verify"] = function(args)
    if #args == 0 then
        print("VERIFY is off")
    end
end

commands["label"] = function(args)
    print("Volume in drive C is VOLUME1")
    io.write("Volume label (11 characters, ENTER for none)? ")
    io.read()
end

commands["edit"] = function(args)
    local filename = args[1]
    local filepath = filename and resolvePath(filename) or nil
    local lines = {}

    if filepath and fs.exists(filepath) and not fs.isDir(filepath) then
        local f = fs.open(filepath, "r")
        local content = f.readAll()
        f.close()
        for line in (content .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
        if #lines == 0 then lines = {""} end
    else
        lines = {""}
    end

    term.clear()
    term.setCursorPos(1, 1)
    local w, h = term.getSize()

    local function drawUI()
        setColor(colors.black, colors.cyan)
        term.setCursorPos(1, 1)
        local title = "  MS-DOS Editor - " .. (filename and filename:upper() or "Untitled")
        term.write((title .. string.rep(" ", w)):sub(1, w))
        setColor(colors.black, colors.white)
        term.setCursorPos(1, h)
        local hint = "  F1=Save  F2=Exit  Arrows=Move  Home/End  Del  Ins"
        term.write((hint .. string.rep(" ", w)):sub(1, w))
        resetColor()
    end

    local curLine  = 1
    local curCol   = 1
    local scrollTop= 1
    local scrollLeft=0
    local contentH = h - 2
    local lineNumW = 5
    local insertMode = true

    local function clampCol()
        local maxCol = #lines[curLine] + 1
        if curCol > maxCol then curCol = maxCol end
        if curCol < 1 then curCol = 1 end
    end

    local function renderEditor()
        local visW = w - lineNumW
        drawUI()
        for row = 1, contentH do
            local lineIdx = scrollTop + row - 1
            term.setCursorPos(1, row + 1)
            term.clearLine()
            setColor(colors.cyan, colors.black)
            term.write(string.format("%4d ", lineIdx))
            setColor(colors.white, colors.black)
            if lines[lineIdx] then
                local seg = lines[lineIdx]:sub(scrollLeft + 1, scrollLeft + visW)
                term.write(seg)
            end
        end
        if curCol - 1 < scrollLeft then
            scrollLeft = math.max(0, curCol - 1)
        elseif curCol - 1 >= scrollLeft + (w - lineNumW) then
            scrollLeft = curCol - (w - lineNumW)
        end
        local cy = curLine - scrollTop + 2
        local cx = lineNumW + (curCol - 1 - scrollLeft) + 1
        if cx < lineNumW + 1 then cx = lineNumW + 1 end
        if cx > w then cx = w end
        term.setCursorPos(cx, cy)
        setColor(colors.black, colors.white)
        local modeStr = insertMode and "INS" or "OVR"
        term.setCursorPos(w - 3, h)
        term.write(modeStr)
        resetColor()
        term.setCursorPos(cx, cy)
    end

    renderEditor()

    local running = true
    while running do
        clampCol()
        do
            local visW = w - lineNumW
            if curCol - 1 < scrollLeft then
                scrollLeft = math.max(0, curCol - 1)
            elseif curCol - 1 >= scrollLeft + visW then
                scrollLeft = curCol - visW
            end
            local cy2 = curLine - scrollTop + 2
            local cx2 = lineNumW + (curCol - 1 - scrollLeft) + 1
            if cx2 < lineNumW+1 then cx2 = lineNumW+1 end
            if cx2 > w then cx2 = w end
            term.setCursorPos(cx2, cy2)
        end

        local event, p1 = os.pullEvent()

        if event == "key" then
            local key = p1
            if key == keys.down then
                if curLine < #lines then
                    curLine = curLine + 1
                    if curLine - scrollTop >= contentH then scrollTop = scrollTop + 1 end
                    clampCol()
                    renderEditor()
                end
            elseif key == keys.up then
                if curLine > 1 then
                    curLine = curLine - 1
                    if curLine < scrollTop then scrollTop = scrollTop - 1 end
                    clampCol()
                    renderEditor()
                end
            elseif key == keys.right then
                if curCol <= #lines[curLine] then
                    curCol = curCol + 1
                elseif curLine < #lines then
                    curLine = curLine + 1; curCol = 1
                    if curLine - scrollTop >= contentH then scrollTop = scrollTop + 1 end
                end
                renderEditor()
            elseif key == keys.left then
                if curCol > 1 then
                    curCol = curCol - 1
                elseif curLine > 1 then
                    curLine = curLine - 1
                    curCol = #lines[curLine] + 1
                    if curLine < scrollTop then scrollTop = scrollTop - 1 end
                end
                renderEditor()
            elseif key == keys.home then
                curCol = 1; renderEditor()
            elseif key == keys["end"] then
                curCol = #lines[curLine] + 1; renderEditor()
            elseif key == keys.pageUp then
                curLine = math.max(1, curLine - contentH)
                scrollTop = math.max(1, scrollTop - contentH)
                clampCol(); renderEditor()
            elseif key == keys.pageDown then
                curLine = math.min(#lines, curLine + contentH)
                if curLine - scrollTop >= contentH then
                    scrollTop = math.min(#lines - contentH + 1, scrollTop + contentH)
                end
                clampCol(); renderEditor()
            elseif key == keys.insert then
                insertMode = not insertMode
                renderEditor()
            elseif key == keys.enter then
                local before = lines[curLine]:sub(1, curCol - 1)
                local after  = lines[curLine]:sub(curCol)
                lines[curLine] = before
                table.insert(lines, curLine + 1, after)
                curLine = curLine + 1; curCol = 1
                if curLine - scrollTop >= contentH then scrollTop = scrollTop + 1 end
                renderEditor()
            elseif key == keys.backspace then
                if curCol > 1 then
                    local ln = lines[curLine]
                    lines[curLine] = ln:sub(1, curCol - 2) .. ln:sub(curCol)
                    curCol = curCol - 1
                elseif curLine > 1 then
                    local prevLen = #lines[curLine - 1]
                    lines[curLine - 1] = lines[curLine - 1] .. lines[curLine]
                    table.remove(lines, curLine)
                    curLine = curLine - 1; curCol = prevLen + 1
                    if curLine < scrollTop then scrollTop = math.max(1, scrollTop - 1) end
                end
                renderEditor()
            elseif key == keys.delete then
                if curCol <= #lines[curLine] then
                    local ln = lines[curLine]
                    lines[curLine] = ln:sub(1, curCol - 1) .. ln:sub(curCol + 1)
                elseif curLine < #lines then
                    lines[curLine] = lines[curLine] .. lines[curLine + 1]
                    table.remove(lines, curLine + 1)
                end
                renderEditor()
            elseif key == keys.f1 then
                local savePath = filepath
                if not savePath then
                    term.setCursorPos(1, h)
                    setColor(colors.black, colors.yellow)
                    term.write(("  Save as: " .. string.rep(" ", w)):sub(1, w))
                    term.setCursorPos(11, h); resetColor()
                    local newName = io.read()
                    if newName and newName ~= "" then
                        savePath = resolvePath(newName)
                        filepath = savePath; filename = newName
                    end
                end
                if savePath then
                    local f = fs.open(savePath, "w")
                    f.write(table.concat(lines, "\n"))
                    f.close()
                    term.setCursorPos(1, h)
                    setColor(colors.black, colors.green)
                    term.write(("  Saved: " .. savePath .. string.rep(" ", w)):sub(1, w))
                    os.sleep(1)
                end
                renderEditor()
            elseif key == keys.f2 then
                running = false
            end

        elseif event == "char" then
            local ch = p1
            local ln = lines[curLine]
            if insertMode then
                lines[curLine] = ln:sub(1, curCol-1) .. ch .. ln:sub(curCol)
            else
                lines[curLine] = ln:sub(1, curCol-1) .. ch .. ln:sub(curCol+1)
            end
            curCol = curCol + 1
            renderEditor()
        end
    end

    term.clear()
    term.setCursorPos(1, 1)
    resetColor()
end

local helpTexts = {
    attrib = "ATTRIB [+R|-R] [+A|-A] [+S|-S] [+H|-H] [drive:][path][filename] [/S]\n  Displays or changes file attributes.",
    chdir  = "CHDIR [drive:][path] | CHDIR[..]\n  Displays the name of or changes the current directory.",
    chkdsk = "CHKDSK [drive:][[path]filename] [/F] [/V]\n  Checks a disk and displays a status report.",
    cls    = "CLS\n  Clears the screen.",
    copy   = "COPY [/A|/B] source [/A|/B] [+ source [/A|/B] [+ ...]] [destination]\n  Copies one or more files to another location.",
    date   = "DATE [date]\n  Displays or sets the date.",
    del    = "DEL [drive:][path]filename [/P]\n  Deletes one or more files.",
    dir    = "DIR [drive:][path][filename] [/P] [/W] [/A] [/S]\n  Displays a list of files and subdirectories.",
    echo   = "ECHO [on|off|message]\n  Displays messages or turns echo on/off.",
    edit   = "EDIT [filename]\n  Starts the MS-DOS Editor.",
    erase  = "ERASE [drive:][path]filename\n  Deletes one or more files.",
    find   = "FIND [/V] [/C] [/N] [/I] \"string\" [[drive:][path]filename[...]]\n  Searches for a text string in a file or files.",
    format = "FORMAT drive: [/V[:label]] [/Q] [/U]\n  Formats a disk for use with MS-DOS.",
    help   = "HELP [command]\n  Provides Help information for MS-DOS commands.",
    label  = "LABEL [drive:][label]\n  Creates, changes, or deletes the volume label of a disk.",
    md     = "MD [drive:]path\n  Creates a directory.",
    mem    = "MEM [/C] [/F] [/M module] [/P]\n  Displays the amount of used and free memory.",
    mkdir  = "MKDIR [drive:]path\n  Creates a directory.",
    more   = "MORE [drive:][path]filename | command | MORE\n  Displays output one screen at a time.",
    move   = "MOVE [/Y | /-Y] [drive:][path]filename1[,...] destination\n  Moves files and renames files and directories.",
    path   = "PATH [[drive:]path[;...]]\n  Displays or sets a search path for executable files.",
    pause  = "PAUSE\n  Suspends processing of a batch file.",
    prompt = "PROMPT [text]\n  Changes the Windows command prompt.",
    rd     = "RD [drive:]path\n  Removes (deletes) a directory.",
    ren    = "REN [drive:][path]filename1 filename2\n  Renames a file or files.",
    rename = "RENAME [drive:][path]filename1 filename2\n  Renames a file or files.",
    rmdir  = "RMDIR [drive:]path\n  Removes (deletes) a directory.",
    set    = "SET [variable=[string]]\n  Displays, sets, or removes MS-DOS environment variables.",
    sort   = "SORT [/R] [/+n] [[drive1:][path1]filename1] [> [drive2:][path2]filename2]\n  Reads input, sorts data, and writes the results to the screen.",
    time   = "TIME [time]\n  Displays or sets the system time.",
    tree   = "TREE [drive:][path] [/F] [/A]\n  Graphically displays the directory structure of a drive or path.",
    type   = "TYPE [drive:][path]filename\n  Displays the contents of a text file.",
    ver    = "VER\n  Displays the MS-DOS version.",
    verify = "VERIFY [on|off]\n  Tells MS-DOS whether to verify that files are written correctly.",
    vol    = "VOL [drive:]\n  Displays a disk volume label and serial number.",
    xcopy  = "XCOPY source [destination] [/S] [/E]\n  Copies files (except hidden and system) and directory trees.",
}

commands["help"] = function(args)
    if args[1] then
        local cmd = args[1]:lower()
        if helpTexts[cmd] then
            print()
            print(helpTexts[cmd])
            print()
        else
            print()
            print("This command is not supported by the Help utility.")
            print("Try \"" .. args[1]:upper() .. " /?\" for more information on this command.")
            print()
        end
        return
    end

    print()
    print("For more information on a specific command, type HELP command-name")
    print()
    local cmds = {
        "ATTRIB   CHDIR    CHKDSK   CLS      COPY     DATE",
        "DEL      DIR      ECHO     EDIT     ERASE    FIND",
        "FORMAT   HELP     LABEL    MD       MEM      MKDIR",
        "MORE     MOVE     PATH     PAUSE    PROMPT   RD",
        "REN      RENAME   RMDIR    SET      SORT     TIME",
        "TREE     TYPE     VER      VERIFY   VOL      XCOPY",
    }
    for _, line in ipairs(cmds) do
        setColor(colors.cyan, colors.black)
        print(line)
    end
    resetColor()
    print()
end

commands["exit"] = function(args)
    term.clear()
    term.setCursorPos(1, 1)
    resetColor()
    os.reboot()
end

local batchVars = {}

local function expandVars(line)
    line = line:gsub("%%([^%%]+)%%", function(k)
        return env[k:upper()] or batchVars[k:upper()] or ("%" .. k .. "%")
    end)
    line = line:gsub("%%(%d)", function(n)
        return batchVars[n] or ""
    end)
    return line
end

local function runBatch(filepath, batchArgs)
    if not fs.exists(filepath) then return false end
    local f = fs.open(filepath, "r")
    local content = f.readAll()
    f.close()

    for i, v in ipairs(batchArgs) do
        batchVars[tostring(i)] = v
    end

    local linesList = {}
    for l in (content .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(linesList, l)
    end

    local labels = {}
    for i, l in ipairs(linesList) do
        local lbl = l:match("^%s*:([%w_]+)")
        if lbl then labels[lbl:lower()] = i end
    end

    local i = 1
    local echoOn = true

    while i <= #linesList do
        local rawLine = linesList[i]:match("^%s*(.-)%s*$")
        i = i + 1

        if rawLine == "" then goto continue end
        if rawLine:lower():match("^rem%s") or rawLine:lower() == "rem" then goto continue end
        if rawLine:sub(1,1) == ":" then goto continue end

        rawLine = expandVars(rawLine)

        local atLine = rawLine
        local silent = false
        if rawLine:sub(1,1) == "@" then
            silent = true
            atLine = rawLine:sub(2)
        end

        local cmd, args2 = (function(input)
            input = input:match("^%s*(.-)%s*$")
            if input == "" then return nil, {} end
            local parts = {}
            for part in input:gmatch("%S+") do table.insert(parts, part) end
            local c = table.remove(parts, 1):lower()
            return c, parts
        end)(atLine)

        if not cmd then goto continue end

        if echoOn and not silent then
            print(currentDir .. ">" .. atLine)
        end

        if cmd == "echo" then
            local rest = atLine:match("^[Ee][Cc][Hh][Oo](.*)")
            if rest and rest:match("^[%.%(%)!%+%-%,;=@#%$%%^&%*]") then
                print("")
            elseif #args2 == 0 then
                print(echoOn and "ECHO is on." or "ECHO is off.")
            elseif args2[1]:lower() == "on" then
                echoOn = true
            elseif args2[1]:lower() == "off" then
                echoOn = false
            else
                print(table.concat(args2, " "))
            end
        elseif cmd == "goto" then
            local lbl = args2[1] and args2[1]:lower()
            if lbl and labels[lbl] then
                i = labels[lbl] + 1
            else
                setColor(colors.red, colors.black)
                print("Label not found")
                resetColor()
                break
            end
        elseif cmd == "if" then
            local rest2 = table.concat(args2, " ")
            local negate = false
            if rest2:lower():sub(1,4) == "not " then
                negate = true
                rest2 = rest2:sub(5)
            end
            local cond = false
            local existFile = rest2:match("^[Ee][Xx][Ii][Ss][Tt]%s+(%S+)%s+")
            local eqA, eqB, eqCmd = rest2:match('^"([^"]*)"==["]([^"]*)"["]?%s+(.*)')
            local elN, elCmd = rest2:match("^[Ee][Rr][Rr][Oo][Rr][Ll][Ee][Vv][Ee][Ll]%s+(%d+)%s+(.*)")
            if existFile then
                local fp2 = resolvePath(existFile)
                cond = fs.exists(fp2)
                local ifCmd2 = rest2:match("^[Ee][Xx][Ii][Ss][Tt]%s+%S+%s+(.*)")
                if (cond and not negate) or (not cond and negate) then
                    local c2, a2 = (function(inp)
                        local parts = {}
                        for p in inp:gmatch("%S+") do table.insert(parts, p) end
                        if #parts == 0 then return nil, {} end
                        local cc = table.remove(parts, 1):lower()
                        return cc, parts
                    end)(ifCmd2 or "")
                    if c2 and commands[c2] then
                        pcall(commands[c2], a2)
                    end
                end
            elseif eqA and eqB then
                cond = (eqA == eqB)
                if (cond and not negate) or (not cond and negate) then
                    local c2, a2 = (function(inp)
                        local parts = {}
                        for p in inp:gmatch("%S+") do table.insert(parts, p) end
                        if #parts == 0 then return nil, {} end
                        local cc = table.remove(parts, 1):lower()
                        return cc, parts
                    end)(eqCmd or "")
                    if c2 and commands[c2] then pcall(commands[c2], a2) end
                end
            end
        elseif cmd == "pause" then
            _pause({})
        elseif cmd == "call" then
            if args2[1] then
                local batPath = resolvePath(args2[1])
                if not batPath:match("%.bat$") then batPath = batPath .. ".bat" end
                runBatch(batPath, {table.unpack(args2, 2)})
            end
        elseif commands[cmd] then
            local ok, err = pcall(commands[cmd], args2)
            if not ok then
                setColor(colors.red, colors.black)
                print("Error: " .. tostring(err))
                resetColor()
            end
        else
            setColor(colors.red, colors.black)
            print("Bad command or file name")
            resetColor()
        end

        ::continue::
    end

    for i2 = 1, 9 do batchVars[tostring(i2)] = nil end
    return true
end

local function parseCommand(input)
    input = input:match("^%s*(.-)%s*$")
    if input == "" then return nil, {}, input end
    local parts = {}
    for part in input:gmatch("%S+") do table.insert(parts, part) end
    local cmd = table.remove(parts, 1):lower()
    return cmd, parts, input
end

local function bootScreen()
    term.clear()
    term.setCursorPos(1, 1)
    setColor(colors.white, colors.black)

    print("BIOS (C) 1994, All Rights Reserved")
    print("CPU Type: 8086  Coprocessor: Installed")
    os.sleep(0.1)
    io.write("Memory Test: ")
    os.sleep(0.15)
    io.write("640K Base  ")
    os.sleep(0.1)
    io.write("3072K Extended")
    os.sleep(0.1)
    print()
    print()
    os.sleep(0.2)

    print("Loading " .. BOOT_TITLE .. "...")
    os.sleep(0.3)
    print()

    local batPath = "/AUTOEXEC.BAT"
    if fs.exists(batPath) then
        print("Executing C:\\AUTOEXEC.BAT")
        os.sleep(0.1)
        runBatch(batPath, {})
    end

    print()
end

local function runExternal(cmd, args)
    local paths = {
        resolvePath(cmd),
        resolvePath(cmd .. ".lua"),
        resolvePath(cmd .. ".bat"),
        resolvePath(cmd .. ".BAT"),
        "/dos/" .. cmd,
        "/dos/" .. cmd .. ".lua",
    }
    if env.PATH then
        for dir in (env.PATH .. ";"):gmatch("([^;]*);") do
            local ccDir = dosToCC(dir)
            table.insert(paths, fs.combine(ccDir, cmd))
            table.insert(paths, fs.combine(ccDir, cmd .. ".lua"))
            table.insert(paths, fs.combine(ccDir, cmd .. ".bat"))
        end
    end

    for _, p in ipairs(paths) do
        if fs.exists(p) and not fs.isDir(p) then
            local name = p:lower()
            if name:match("%.bat$") then
                return runBatch(p, args)
            else
                local ok, err = loadfile(p)
                if ok then
                    local success, msg = pcall(ok, table.unpack(args))
                    if not success then
                        setColor(colors.red, colors.black)
                        print("Runtime error: " .. tostring(msg))
                        resetColor()
                    end
                    return true
                else
                    setColor(colors.red, colors.black)
                    print("Error loading file: " .. tostring(err))
                    resetColor()
                    return true
                end
            end
        end
    end
    return false
end

local function main()
    bootScreen()

    while true do
        setColor(colors.white, colors.black)
        io.write(renderPrompt())
        resetColor()

        local input = io.read()
        if input == nil then break end
        input = input:match("^%s*(.-)%s*$")
        if input ~= "" then
            local cmd, args, raw = parseCommand(input)
            if cmd then
                if commands[cmd] then
                    local ok, err = pcall(commands[cmd], args, raw)
                    if not ok then
                        setColor(colors.red, colors.black)
                        print("Error: " .. tostring(err))
                        resetColor()
                    end
                elseif not runExternal(cmd, args) then
                    setColor(colors.red, colors.black)
                    print("Bad command or file name")
                    resetColor()
                end
            end
        end
        print()
    end
end

main()