local shell = require("shell")
local filesystem = require("filesystem")
local internet = require("internet")

local usingPrefix = false
local repo = "https://raw.githubusercontent.com/hxync/BeeMasterXXL/"
local branch = "main"
local paths = { "lib" }

local scripts = {
    "strategy.lua",
    "config.lua",
    "bee.lua",
    "analyzeGenes.lua",
    "beeData.lua",
    "bot.lua",
    "doUntil.lua",
    "environment.lua",
    "tools.lua",
    "biomes.lua",
    "mutations.lua",
    "device.lua",
    "apiary.lua",
    "me.lua",
    "lib/inflate-bwo.lua",
    "lib/nbt.lua",
    "lib/zzlib.lua"
}

local prefix = "https://github.xutongxin.me/"
local retries = 3

local function download(url)
    local target = (usingPrefix and prefix or "") .. url
    local lastError = "unknown error"
    for attempt = 1, retries do
        local ok, handle = pcall(internet.request, target)
        if ok and handle then
            local chunks = {}
            ok, lastError = pcall(function()
                for chunk in handle do
                    chunks[#chunks + 1] = chunk
                end
            end)
            if ok then
                local result = table.concat(chunks)
                if #result > 0 then return result end
                lastError = "empty response"
            end
        else
            lastError = tostring(handle)
        end
        if attempt < retries then os.sleep(attempt) end
    end
    error("download failed: " .. target .. " (" .. lastError .. ")")
end

local function writeFile(path, content)
    local temporary = path .. ".tmp"
    local file = io.open(temporary, "w")
    if not file then error("cannot open " .. temporary) end
    file:write(content)
    file:close()
    local backup = path .. ".bak"
    if filesystem.exists(backup) then filesystem.remove(backup) end
    if filesystem.exists(path) then filesystem.rename(path, backup) end
    local ok, reason = filesystem.rename(temporary, path)
    if ok == false then
        if filesystem.exists(backup) then filesystem.rename(backup, path) end
        error("cannot rename temporary file: " .. tostring(reason))
    end
    if filesystem.exists(backup) then filesystem.remove(backup) end
end

local function exists(filename)
    return filesystem.exists(shell.getWorkingDirectory() .. "/" .. filename)
end

local function main()
    for i = 1, #paths do
        local dir = shell.getWorkingDirectory() .. "/" .. paths[i]
        if not filesystem.exists(dir) then
            filesystem.makeDirectory(dir)
        end
    end
    for i = 1, #scripts do
        local file_path = shell.getWorkingDirectory() .. "/" .. scripts[i]
        local url = string.format("%s%s/%s", repo, branch, scripts[i])
        print("Downloading /"..scripts[i])
        local content = download(url)
        writeFile(file_path, content)
    end
end

if pcall(download, "http://www.msftconnecttest.com/connecttest.txt") then
    main()
else
    print("Error: Internet Disconnected")
end
