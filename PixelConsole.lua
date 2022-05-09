if _G.pixelConsoleTypeChosen then return end

local IO = {}

local PixelConsole = {}
PixelConsole.__index = PixelConsole

PixelConsole.io = function()
    return IO
end

local HttpService = game:GetService("HttpService")

local ansi = {}
ansi.color = {}

ansi.up = function(a) rconsoleprint("\027[" .. ((a and tostring(a)) or "1") .. "A") end
ansi.down = function(a) rconsoleprint("\027[" .. ((a and tostring(a)) or "1") .. "B") end
ansi.left = function(a) rconsoleprint("\027[" .. ((a and tostring(a)) or "1") .. "D") end
ansi.clearPrevious = function(ri) 
    ansi.up()
    rconsoleprint(string.rep(" ", ri:len()))
    ansi.left(ri:len())
end

ansi.color.warn = "\027[33mwarn:\27[0m "
ansi.color.error = "\027[31merror:\27[0m "

PixelConsole.redirect = function()
    _G.pixelConsoleTypeChosen = true
    
    local defaultOptions = {
        timeStamp = false,
        filterMethod = "exact",
        delInput = true,
        conName = "output"
    }

    local options
    local optionsPath = "PixelOutput/options.txt"

    if not isfolder(optionsPath:split("/")[1]) then
        makefolder(optionsPath:split("/")[1])
    end
    if not isfile(optionsPath) then
        writefile(optionsPath, HttpService:JSONEncode(defaultOptions))
        options = defaultOptions
    else
        options = HttpService:JSONDecode(readfile(optionsPath))
    end

    local function saveOption(t)
        for i,v in pairs(t) do
            if options[i] ~= nil then
                options[i] = v
            end
        end
        writefile(optionsPath, HttpService:JSONEncode(options))
    end

    rconsolename(options.conName)

    local outputTypes = {
        warn = ansi.color.warn, 
        error = ansi.color.error, 
        print = ""
    }
    local currentOutput = {}
    local filteredWord

    local function checkFilter(wordsTable)
        local filterFlagged = false
        local filterMethodFlag = options.filterMethod
    
        if filterMethodFlag == "exact" then
            for _,v in ipairs(wordsTable) do
                if v:lower():sub(1, #filteredWord) == filteredWord:lower() then
                    filterFlagged = true
                end
            end
        end
    
        if filterMethodFlag == "fuzzy" then
            for _,v in ipairs(wordsTable) do
                if v:lower():match(filteredWord:lower()) then
                    filterFlagged = true
                end
            end
        end
    
        return filterFlagged
    end

    local function out(outputType, ...)
        local currentTS = os.date("%X")
        local inputs = {...}
        local stringStructure = ""
    
        if options.timeStamp then
            stringStructure = stringStructure .. currentTS .. " -- "
        end
    
        stringStructure = stringStructure .. outputTypes[outputType]
    
        for i,v in pairs(inputs) do
            stringStructure = stringStructure .. tostring(v) .. " "
        end
    
        currentOutput[#currentOutput + 1] = {TS = (options.timeStamp and currentTS) or false, outputInfo = inputs, outType = outputType}
    
        if filteredWord then 
            if checkFilter(inputs) then
                return rconsoleprint(stringStructure .. "\n")
            end
            return
        end
        rconsoleprint(stringStructure .. "\n")
    end

    local function refresh()
        rconsoleclear()
        for i, v in pairs(currentOutput) do
            local stringStructure = ""
            if v.TS then
                stringStructure = stringStructure .. v.TS .. " -- "
            end
        
            stringStructure = stringStructure .. outputTypes[v.outType]
        
            for _,v in ipairs(v.outputInfo) do
                stringStructure = stringStructure .. v .. " "
            end
        
            if filteredWord then
                if checkFilter(v.outputInfo) then
                    rconsoleprint(stringStructure .. "\n")
                    continue
                end
                continue
            end
            rconsoleprint(stringStructure .. "\n")
        end
    end

    local allowedFlags = {
        ["-type"] = {
            ["fuzzy"] = true,
            ["exact"] = true
        }
    }

    local cmds = {
        filter = function(s)
            local flags = {}
            for i, v in pairs(s) do
                v = v:lower()
                if allowedFlags[v] and s[i + 1] and allowedFlags[v][s[i + 1]] and not flags[v] then
                    flags[v] = s[i + 1]
                    table.remove(s, i)
                    table.remove(s, i)
                end
            end
            s = table.concat(s, " ")
            if s == nil or s:match("^%s*$") then return end
            filteredWord = s
            options.filterMethod = (#flags == 0 and flags["-type"]) or options.filterMethod
            refresh()
        end,
    
        unfilter = function()
            filteredWord = nil
            refresh()
        end,
    
        clear = function()
            rconsoleclear()
            for v in pairs(currentOutput) do
                currentOutput[v] = nil
            end
        end,
    
        name = function(s)
            rconsolename(table.concat(s, " "))
            saveOption({conName = table.concat(s, " ")})
        end,
    
        delinput = function(s)
            local bool = HttpService:JSONDecode(s[1]:lower())
            if type(bool) == "boolean" then
                saveOption({delInput = bool})
            end
        end,
    
        timestamp = function(s)
            local bool = HttpService:JSONDecode(s[1]:lower())
            if type(bool) == "boolean" then
                saveOption({timeStamp = bool})
            end
        end,
    
        filtermethod = function(s)
            if allowedFlags["-type"][s[1]:lower()] then
                saveOption({filterMethod = s[1]:lower()})
            end
        end,
    
        copyout = function()
            local clipboardString = "-start of output-\n\n\n"
            for _, v in ipairs(currentOutput) do
                local stringStructure = ""
        
                stringStructure = stringStructure .. outputTypes[v.outType]
        
                for _,v in ipairs(v.outputInfo) do
                    stringStructure = stringStructure .. v .. " "
                end
                clipboardString = clipboardString .. stringStructure .. "\n"
            end
            clipboardString = clipboardString .. "\n\n\n-end of output-"
            setclipboard(clipboardString)
        end,
    }

    coroutine.resume(coroutine.create(function()
        while true do
            local rInput = rconsoleinput()
            local cmdInput = rInput:split(" ")
            local signalCmd = cmdInput[1]
            table.remove(cmdInput, 1)
            if not cmds[signalCmd] then ansi.clearPrevious(rInput) rconsoleprint("> ") continue end
            ansi.clearPrevious(rInput)
            rconsoleprint("> ")
            cmds[signalCmd](cmdInput)
            task.wait()
        end
    end))

    hookfunction(print, function(...)
        out("print", ...)
    end)

    hookfunction(warn, function(...)
        out("warn", ...)
    end)

    hookfunction(error, function(...)
        out("error", ...)
    end)
end

return PixelConsole
