-- EnergyMonitor language helper.
-- EnergyMonitor modifications Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- This helper is adapted from ExtremeReactorControl by SeekerOfHonjo at commit f0f223ec.

local Language = {
    text = {},
    getText = function(self, entry)
        if entry == nil then
            return ""
        end
        if text[entry] == nil then
            return entry
        else
            return text[entry]
        end
    end,
    dumpText = function(self) 
        for k, v in pairs(text) do
            print(k..") "..v)
        end
    end,
    yesCheck = function (self, inputString)
        return inputString:sub(1, 1):lower() == text["wordYes"]:sub(1, 1):lower()
    end,
    noCheck = function (self, inputString)
        return inputString:sub(1, 1):lower() == text["wordNo"]:sub(1, 1):lower()
    end,
    loadLanguageByFile = function(self, languageFile)
        local file = fs.open(languageFile,"r")
        local list = file.readAll()
        file.close()
        text = textutils.unserialise(list)
    end,

    loadLanguageById = function(self, languageId)
        local fileName = "/EnergyMonitor/lang/"..languageId..".txt"
        self:loadLanguageByFile(fileName)
    end
}

function _G.newLanguageById(languageId)
    local language = {}
    setmetatable(language,{__index=Language}) 
    language:loadLanguageById(languageId) 
    print(language:getText("language"))
    return language
end




