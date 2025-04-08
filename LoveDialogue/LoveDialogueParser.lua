local Parser = {}
local LD_PATH = (...):match('(.-)[^%.]+$')
local PortraitManager = require(LD_PATH .. "PortraitManager")
local LD_Character = require(LD_PATH .. "LoveCharacter")
local CharacterParser = require(LD_PATH .. "LoveCharacterParser")
local ResourceManager = require(LD_PATH .. "ResourceManager")
local peachy = require(LD_PATH .. "peachy")

local function loadLuaFile(filePath)
    local chunk, err = loadfile(filePath)
    if not chunk then
        print("Error loading file:", err)
        return nil
    end
    return chunk()
end

-- local function parseTextWithTags(text)
--     local parsedText = ""
--     local effectsTable = {}
--     local openEffects = {}
--     local currentIndex = 1

--     while currentIndex <= #text do
--         local startTag, endTag, tag, content = text:find("{([^:}]+):([^}]*)}", currentIndex)
--         local soundStartTag, soundEndTag, soundFile = text:find("{sound:([^}]+)}", currentIndex)
--         local closingStartTag, closingEndTag, closingTag = text:find("{/([^}]+)}", currentIndex)
        
--         if soundStartTag and (not startTag or soundStartTag < startTag) then
--             parsedText = parsedText .. text:sub(currentIndex, soundStartTag - 1)
            
--             table.insert(effectsTable, {
--                 type = "sound",
--                 content = soundFile,
--                 startIndex = #parsedText + 1,
--                 endIndex = #parsedText + 1  -- 音效立即触发，所以起止索引相同
--             })
            
--             currentIndex = soundEndTag + 1
--         end

--         if not startTag and not closingStartTag then
--             parsedText = parsedText .. text:sub(currentIndex)
--             break
--         end

--         if closingStartTag and (not startTag or closingStartTag < startTag) then
--             parsedText = parsedText .. text:sub(currentIndex, closingStartTag - 1)

--             local effect
--             for i = #openEffects, 1, -1 do
--                 if openEffects[i].type == closingTag then
--                     effect = table.remove(openEffects, i)
--                     break
--                 end
--             end

--             if effect then
--                 effect.endIndex = #parsedText
--                 table.insert(effectsTable, effect)
--             end

--             currentIndex = closingEndTag + 1
--         else
--             parsedText = parsedText .. text:sub(currentIndex, startTag - 1)

--             table.insert(openEffects, {type = tag, content = content, startIndex = #parsedText + 1})

--             currentIndex = endTag + 1
--         end
--     end

--     for _, effect in ipairs(openEffects) do
--         effect.endIndex = #parsedText
--         table.insert(effectsTable, effect)
--     end

--     return parsedText, effectsTable
-- end

local function parseTextWithTags(text)
    local parsedText = ""
    local effectsTable = {}
    local openEffects = {}
    local currentIndex = 1

    while currentIndex <= #text do
        local startTag, endTag, tag, content = text:find("{([^:}]+):([^}]*)}", currentIndex)
        local soundStartTag, soundEndTag, soundFile = text:find("{sound:([^}]+)}", currentIndex)
        local frametagStartTag, frametagEndTag, frametag = text:find("{frametag:([^}]+)}", currentIndex)
        local closingStartTag, closingEndTag, closingTag = text:find("{/([^}]+)}", currentIndex)
        
        -- 处理 {frametag:动画循环}
        if frametagStartTag and (not startTag or frametagStartTag < startTag) and (not soundStartTag or frametagStartTag < soundStartTag) then
            parsedText = parsedText .. text:sub(currentIndex, frametagStartTag - 1)
            table.insert(effectsTable, {
                type = "frametag",
                content = frametag,
                startIndex = #parsedText + 1,
                endIndex = #parsedText + 1  -- frametag 立即触发
            })
            currentIndex = frametagEndTag + 1
        -- 处理 {sound:文件名}
        elseif soundStartTag and (not startTag or soundStartTag < startTag) then
            parsedText = parsedText .. text:sub(currentIndex, soundStartTag - 1)
            table.insert(effectsTable, {
                type = "sound",
                content = soundFile,
                startIndex = #parsedText + 1,
                endIndex = #parsedText + 1  -- 音效立即触发
            })
            currentIndex = soundEndTag + 1
        -- 处理其他标签和闭合标签
        elseif not startTag and not closingStartTag then
            parsedText = parsedText .. text:sub(currentIndex)
            break
        elseif closingStartTag and (not startTag or closingStartTag < startTag) then
            parsedText = parsedText .. text:sub(currentIndex, closingStartTag - 1)
            local effect
            for i = #openEffects, 1, -1 do
                if openEffects[i].type == closingTag then
                    effect = table.remove(openEffects, i)
                    break
                end
            end
            if effect then
                effect.endIndex = #parsedText
                table.insert(effectsTable, effect)
            end
            currentIndex = closingEndTag + 1
        else
            parsedText = parsedText .. text:sub(currentIndex, startTag - 1)
            table.insert(openEffects, {type = tag, content = content, startIndex = #parsedText + 1})
            currentIndex = endTag + 1
        end
    end

    for _, effect in ipairs(openEffects) do
        effect.endIndex = #parsedText
        table.insert(effectsTable, effect)
    end

    return parsedText, effectsTable
end

Parser.parseTextWithTags = parseTextWithTags

--- Parses a dialogue file and returns a table of lines
--- @param filePath string
--- @return string[]
--- @return table<string, LD_Character>
--- @return table
-- function Parser.parseFile(filePath)
--     local lines = {}
--     local currentLine = 1
--     local scenes = {}
--     local currentScene = "default"
--     local characters = {}
    
--     -- Validate filePath
--     if not filePath or type(filePath) ~= "string" then
--         error("Invalid filePath: " .. tostring(filePath))
--         return
--     end
    
--     -- Check if file exists
--     local fileInfo = love.filesystem.getInfo(filePath)
--     if not fileInfo then
--         error("File does not exist or cannot be accessed: " .. filePath)
--         return
--     end
    
--     -- Read file content
--     local fileContent, readError = love.filesystem.read(filePath)
--     if not fileContent then
--         error("Could not read file '" .. filePath .. "': " .. (readError or "Unknown error"))
--         return
--     end
    
--     -- 处理 @resource 指令
--     local resourcePaths = {font = {}, sound = {}, background = {}}
--     for line in fileContent:gmatch("[^\r\n]+") do
--         local resourceType, path = line:match("^@resource%s+(%w+)%s+(.+)$")
--         if resourceType and path then
--             if resourceType == "font" then
--                 table.insert(resourcePaths.font, path)
--             elseif resourceType == "sound" then
--                 table.insert(resourcePaths.sound, path)
--             elseif resourceType == "background" then
--                 table.insert(resourcePaths.background, path)
--             end
--         end
--     end
    
--     -- 加载资源
--     for _, fontDir in ipairs(resourcePaths.font) do
--         ResourceManager:loadFonts(instanceId or "global", fontDir)
--     end
--     for _, soundDir in ipairs(resourcePaths.sound) do
--         ResourceManager:loadSounds(instanceId or "global", soundDir)
--     end
    
--     -- Handle @portrait with dynamic font path
--     for line in fileContent:gmatch("[^\r\n]+") do
--         if line:match("^@portrait") then
--             local words = {}
--             for word in line:gmatch("%S+") do
--                 table.insert(words, word)
--             end
--             if #words >= 3 then
--                 local characterName = words[2]
--                 local path = words[3]
--                 local nameFontStr = #words >= 4 and words[4] or nil
--                 local fontStr = #words >= 5 and words[5] or nil
                
--                 local nameFontFile, nameFontSize = parseFontString(nameFontStr)
--                 local fontFile, fontSize = parseFontString(fontStr)
                
--                 local character, error = CharacterParser.parseCharacterFromPortrait(characterName, path)
--                 if error or not character then
--                     print("Error parsing character file: " .. tostring(error))
--                 else
--                     -- Use font path from @resource
--                     local fontBasePath = resourcePaths.font[1] or "demo/Assets/font"
                    
--                     -- 设置名称字体 (nameFont)
--                     if nameFontFile and nameFontSize then
--                         local fontKey = nameFontFile .. "_" .. nameFontSize
--                         if not ResourceManager.fonts[fontKey] then
--                             local fullPath = fontBasePath .. "/" .. nameFontFile
--                             print("Loading name font:", fullPath) -- Debug output
--                             ResourceManager.fonts[fontKey] = love.graphics.newFont(fullPath, nameFontSize)
--                         end
--                         character.nameFont = ResourceManager.fonts[fontKey]
--                     else
--                         character.nameFont = love.graphics.newFont(12)
--                     end
                    
--                     -- 设置正文字体 (font)
--                     if fontFile and fontSize then
--                         local fontKey = fontFile .. "_" .. fontSize
--                         if not ResourceManager.fonts[fontKey] then
--                             local fullPath = fontBasePath .. "/" .. fontFile
--                             print("Loading text font:", fullPath) -- Debug output
--                             ResourceManager.fonts[fontKey] = love.graphics.newFont(fullPath, fontSize)
--                         end
--                         character.font = ResourceManager.fonts[fontKey]
--                     else
--                         character.font = love.graphics.newFont(12)
--                     end
                    
--                     characters[characterName] = character
--                     PortraitManager.loadPortrait(characterName, path:match("^%s*(.-)%s*$"), instanceId)
--                 end
--             else
--                 print("Invalid @portrait line: " .. line)
--             end
--         end
--         -- local characterPath = line:match("@Character%s+([^#%s]+)")
--         -- if characterPath then
--         --     local character, error = CharacterParser.parseCharacter(characterPath)

--         --     if error or character == nil then
--         --         print("Error parsing character file:", error)
--         --     else
--         --         for _, c in ipairs(character) do
--         --             characters[c.name] = c
--         --         end
--         --     end
--         -- end
--     end

--     -- First pass: Handle portrait definitions
--     -- for line in fileContent:gmatch("[^\r\n]+") do
--     --     local characterName, path = line:match("^@portrait%s+(%S+)%s+(.+)$")
--     --     if characterName and path then
--     --         local character, error = CharacterParser.parseCharacterFromPortrait(characterName, path)
            
--     --         if error or character == nil then
--     --             print("Error parsing character file:", error)
--     --         end
            
--     --         characters[characterName] = character
--     --         PortraitManager.loadPortrait(character, path:match("^%s*(.-)%s*$"))
--     --     end
        
--     --     local characterPath = line:match("@Character%s+([^#%s]+)")
--         -- if characterPath then
--         --     local character, error = CharacterParser.parseCharacter(characterPath)

--         --     if error or character == nil then
--         --         print("Error parsing character file:", error)
--         --     else
--         --         for _, c in ipairs(character) do
--         --             characters[c.name] = c
--         --         end
--         --     end
--         -- end
--     -- end
    
--     local fileLines = {}
--     for line in fileContent:gmatch("[^\r\n]+") do
--         if not line:match("^@callback") then
--             table.insert(fileLines, line)
--         end
--     end

--     for _, line in ipairs(fileLines) do
--         local character, text = line:match("^(%S+):%s*(.+)$")
--         if character and text then
--             local characterName = character:gsub("%(.*%)$", "")
--             local expression = character:match("%((.-)%)")
--             if not characters[characterName] then
--                 characters[characterName] = LD_Character.new(characterName)
--             end

--             local isEnd = text:match("%(end%)$")
--             if isEnd then
--                 text = text:gsub("%s*%(end%)$", "")
--             end

--             local parsedText, effects = Parser.parseTextWithTags(text)
--             local parsedLine = {
--                 character = characterName,
--                 expression = expression or "Default",
--                 text = parsedText,
--                 isEnd = isEnd,
--                 effects = effects,
--                 choices = {}
--             }

--             lines[currentLine] = parsedLine
--             currentLine = currentLine + 1
--         elseif line:match("^%->") then
--             print("DEBUG: Processing choice line:", line)
--             line = line:gsub("[\r\n]", "")
            
--             local choiceText, target = line:match("^%->%s*([^%[]+)%s*%[target:([%w_]+)%]%s*$")
            
--             print("DEBUG: Raw matches:")
--             print("  Text:", choiceText and '"'..choiceText..'"' or "nil")
--             print("  Target:", target and '"'..target..'"' or "nil")
            
--             if choiceText then
--                 -- Trim whitespace
--                 choiceText = choiceText:match("^%s*(.-)%s*$")
--                 target = target and target:match("^%s*(.-)%s*$")
                
--                 print("DEBUG: After trimming:")
--                 print("  Text:", '"'..choiceText..'"')
--                 print("  Target:", target and '"'..target..'"' or "nil")
                
--                 local parsedChoiceText, choiceEffects = Parser.parseTextWithTags(choiceText)
                
--                 local choice = {
--                     text = choiceText,
--                     parsedText = parsedChoiceText,
--                     effects = choiceEffects,
--                     target = target
--                 }
                
--                 if lines[currentLine - 1] then
--                     table.insert(lines[currentLine - 1].choices, choice)
--                     print("DEBUG: Added choice successfully")
--                 else
--                     print("DEBUG: Warning - No previous line to attach choice to")
--                 end
--             else
--                 print("DEBUG: Failed to parse choice line:", line)
--             end
--         elseif line:match("^%[.*%]") then
--             currentScene = line:match("^%[(.*)%]")
--             scenes[currentScene] = currentLine
--         end
--     end

--     return lines, characters, scenes
-- end

--- Parses a dialogue file and returns a table of lines
--- @param filePath string
--- @return string[]
--- @return table<string, LD_Character>
--- @return table
function Parser.parseFile(filePath)
    local lines = {}
    local currentLine = 1
    local scenes = {}
    local currentScene = "default"
    local characters = {}
    
    -- Validate filePath
    if not filePath or type(filePath) ~= "string" then
        error("Invalid filePath: " .. tostring(filePath))
        return
    end
    
    -- Check if file exists
    local fileInfo = love.filesystem.getInfo(filePath)
    if not fileInfo then
        error("File does not exist or cannot be accessed: " .. filePath)
        return
    end
    
    -- Read file content
    local fileContent, readError = love.filesystem.read(filePath)
    if not fileContent then
        error("Could not read file '" .. filePath .. "': " .. (readError or "Unknown error"))
        return
    end
    
    -- 处理 @resource 指令，包括 characta
    local resourcePaths = {font = {}, sound = {}, background = {}, characta = nil}
    for line in fileContent:gmatch("[^\r\n]+") do
        local resourceType, path = line:match("^@resource%s+(%w+)%s+(.+)$")
        if resourceType and path then
            if resourceType == "font" then
                table.insert(resourcePaths.font, path)
            elseif resourceType == "sound" then
                table.insert(resourcePaths.sound, path)
            elseif resourceType == "background" then
                table.insert(resourcePaths.background, path)
            elseif resourceType == "characta" then
                resourcePaths.characta = path  -- 存储 characta 目录路径
            end
        end
    end
    
    -- 加载资源
    for _, fontDir in ipairs(resourcePaths.font) do
        ResourceManager:loadFonts(instanceId or "global", fontDir)
    end
    for _, soundDir in ipairs(resourcePaths.sound) do
        ResourceManager:loadSounds(instanceId or "global", soundDir)
    end
    
    -- 处理 @portrait 和 @charata
    for line in fileContent:gmatch("[^\r\n]+") do
        -- 处理 @portrait
        if line:match("^@portrait") then
            local words = {}
            for word in line:gmatch("%S+") do
                table.insert(words, word)
            end
            if #words >= 3 then
                local characterName = words[2]
                local path = words[3]
                local nameFontStr = #words >= 4 and words[4] or nil
                local fontStr = #words >= 5 and words[5] or nil
                
                local nameFontFile, nameFontSize = parseFontString(nameFontStr)
                local fontFile, fontSize = parseFontString(fontStr)
                
                local character, error = CharacterParser.parseCharacterFromPortrait(characterName, path)
                if error or not character then
                    print("Error parsing character file: " .. tostring(error))
                else
                    character.type = "portrait"  -- 标记为静态肖像类型
                    local fontBasePath = resourcePaths.font[1] or "demo/Assets/font"
                    
                    -- 设置名称字体 (nameFont)
                    if nameFontFile and nameFontSize then
                        local fontKey = nameFontFile .. "_" .. nameFontSize
                        if not ResourceManager.fonts[fontKey] then
                            local fullPath = fontBasePath .. "/" .. nameFontFile
                            ResourceManager.fonts[fontKey] = love.graphics.newFont(fullPath, nameFontSize)
                        end
                        character.nameFont = ResourceManager.fonts[fontKey]
                    else
                        character.nameFont = love.graphics.newFont(12)
                    end
                    
                    -- 设置正文字体 (font)
                    if fontFile and fontSize then
                        local fontKey = fontFile .. "_" .. fontSize
                        if not ResourceManager.fonts[fontKey] then
                            local fullPath = fontBasePath .. "/" .. fontFile
                            ResourceManager.fonts[fontKey] = love.graphics.newFont(fullPath, fontSize)
                        end
                        character.font = ResourceManager.fonts[fontKey]
                    else
                        character.font = love.graphics.newFont(12)
                    end
                    
                    characters[characterName] = character
                    PortraitManager.loadPortrait(characterName, path:match("^%s*(.-)%s*$"), instanceId)
                end
            else
                print("Invalid @portrait line: " .. line)
            end
        end
        
        -- 处理 @charata
        if line:match("^@charata") then
            local words = {}
            for word in line:gmatch("%S+") do
                table.insert(words, word)
            end
            if #words >= 5 then
                local characterName = words[2]
                local jsonFile = words[3]
                local imageFile = words[4]
                local initialTag = words[5]

                -- 构建完整的文件路径
                local charactaDir = resourcePaths.characta or "demo/Assets/characta"
                local jsonPath = charactaDir .. "/" .. jsonFile
                local imagePath = charactaDir .. "/" .. imageFile

                -- 使用 Peachy 加载动画
                local success, animation = pcall(peachy.new, jsonPath, love.graphics.newImage(imagePath), initialTag)
                if success and animation then
                    -- 创建 LD_Character 对象并存储动画
                    local character = LD_Character.new(characterName, nil)
                    character.type = "charata"       -- 标记为动画类型
                    character.animation = animation  -- 存储 Peachy 动画对象
                    characters[characterName] = character
                else
                    print("Failed to load animation for " .. characterName .. ": " .. (animation or "Unknown error"))
                end
            else
                print("Invalid @charata line: " .. line)
            end
        end
    end
    
    -- 解析对话行
    local fileLines = {}
    for line in fileContent:gmatch("[^\r\n]+") do
        if not line:match("^@callback") then
            table.insert(fileLines, line)
        end
    end

    for _, line in ipairs(fileLines) do
        local character, text = line:match("^(%S+):%s*(.+)$")
        if character and text then
            local characterName = character:gsub("%(.*%)$", "")
            local expression = character:match("%((.-)%)")
            if not characters[characterName] then
                characters[characterName] = LD_Character.new(characterName)
                characters[characterName].type = "portrait"  -- 默认类型
            end

            local isEnd = text:match("%(end%)$")
            if isEnd then
                text = text:gsub("%s*%(end%)$", "")
            end

            local parsedText, effects = Parser.parseTextWithTags(text)
            local parsedLine = {
                character = characterName,
                expression = expression or "Default",
                text = parsedText,
                isEnd = isEnd,
                effects = effects,
                choices = {}
            }

            lines[currentLine] = parsedLine
            currentLine = currentLine + 1
        elseif line:match("^%->") then
            line = line:gsub("[\r\n]", "")
            local choiceText, target = line:match("^%->%s*([^%[]+)%s*%[target:([%w_]+)%]%s*$")
            if choiceText then
                choiceText = choiceText:match("^%s*(.-)%s*$")
                target = target and target:match("^%s*(.-)%s*$")
                local parsedChoiceText, choiceEffects = Parser.parseTextWithTags(choiceText)
                local choice = {
                    text = choiceText,
                    parsedText = parsedChoiceText,
                    effects = choiceEffects,
                    target = target
                }
                if lines[currentLine - 1] then
                    table.insert(lines[currentLine - 1].choices, choice)
                end
            end
        elseif line:match("^%[.*%]") then
            currentScene = line:match("^%[(.*)%]")
            scenes[currentScene] = currentLine
        end
    end

    return lines, characters, scenes
end

    -- 辅助函数：解析 {font_file, size} 格式
function parseFontString(str)
    if str and str:match("^{.+}$") then
        local fontFile, size = str:match("^{(.-),(.-)}$")
        if fontFile and size then
            return fontFile, tonumber(size)
        end
    end
    return nil, nil
end

function Parser.printDebugInfo(lines, characters)
    print("Parsed Lines:")
    for i, line in ipairs(lines) do
        print(string.format("Line %d:", i))
        print(string.format("  Character: %s", line.character))
        print(string.format("  Text: %s", line.text))
        print(string.format("  Is End: %s", tostring(line.isEnd)))

        print("  Effects:")
        for _, effect in ipairs(line.effects) do
            print(string.format("    Type: %s", effect.type))
            print(string.format("    Content: %s", effect.content))
            print(string.format("    Start Index: %d", effect.startIndex))
            print(string.format("    End Index: %d", effect.endIndex))
        end

        if line.branches then
            print("  Branches:")
            for branchIndex, branch in ipairs(line.branches) do
                print(string.format("    Branch %d:", branchIndex))
                print(string.format("      Target Line: %d", branch.targetLine))
                print(string.format("      Text: %s", branch.text))

                if branch.effects then
                    print("      Effects:")
                    for _, effect in ipairs(branch.effects) do
                        print(string.format("        Type: %s", effect.type))
                        print(string.format("        Content: %s", effect.content))
                        print(string.format("        Start Index: %d", effect.startIndex))
                        print(string.format("        End Index: %d", effect.endIndex))
                    end
                else
                    print("      Effects: None")
                end

            end
        end
    end

    print("Characters:")
    for character, color in pairs(characters) do
        print(string.format("  Character: %s", character))
        print(string.format("    Color: R=%f, G=%f, B=%f", color.r, color.g, color.b))
    end
end

return Parser
