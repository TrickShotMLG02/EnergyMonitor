-- function to convert a decimal number
function formatNumberComma(number)
    local finalOutput =  format_int(number)
   
    return finalOutput
end

-- function to format a number to have a specific amount of decimals
function _G.formatDecimals(number, decimals) 
    return string.format("%." .. decimals .. "f", number)
end

-- function to convert game ticks to human readable time
function _G.convertTicksToTime(ticks)
  local seconds = math.floor(ticks / 20)
  local minutes = math.floor(seconds / 60)
  local hours = math.floor(minutes / 60)
  local days = math.floor(hours / 24)
  local years = math.floor(days / 365)

  local finalOutput = ""
  if years > 0 then
    finalOutput = finalOutput .. years .. "y "
  end
  if days > 0 then
    finalOutput = finalOutput .. days % 365 .. "d "
  end
  if hours > 0 then
    finalOutput = finalOutput .. hours % 24 .. "h "
  end
  if minutes > 0 then
    finalOutput = finalOutput .. minutes % 60 .. "m "
  end
  if seconds > 0 then
    finalOutput = finalOutput .. seconds % 60 .. "s"
  end

  return finalOutput
end

-- function to convert a number with energy unit back to a number in base unit
function _G.EnergyWithUnitToNumber(energy)
  --extract number and unit separately from string
  local number = energy:match("%d+%.?%d*")
  local unit = energy:match("%a+")
  if unit == "FE" then
    return tonumber(number)
  elseif unit == "KFE" then
    return tonumber(number) * 1000
  elseif unit == "MFE" then
    return tonumber(number) * 1000000
  elseif unit == "GFE" then
    return tonumber(number) * 1000000000
  elseif unit == "TFE" then
    return tonumber(number) * 1000000000000
  elseif unit == "PFE" then
    return tonumber(number) * 1000000000000000
  elseif unit == "EFE" then
    return tonumber(number) * 1000000000000000000
  elseif unit == "ZFE" then
    return tonumber(number) * 1000000000000000000000
  elseif unit == "YFE" then
    return tonumber(number) * 1000000000000000000000000
  end
end

-- function to convert a number to a string with the optimal unit at the end
function _G.numberToEnergyUnit(number)
  -- turn 1000 into 1kFE
  -- turn 1000000 into 1MFE
  -- turn 1000000000 into 1GFE
  -- turn 1000000000000 into 1TFE

  local decimal_places = 1

  local unit = "FE"
  local value = 0
  if number >= 1000000000000000000000000 then
    unit = "YFE"
    value = number / 1000000000000000000000000
  elseif number >= 1000000000000000000000 then
    unit = "ZFE"
    value = number / 1000000000000000000000
  elseif number >= 1000000000000000000 then
    unit = "EFE"
    value = number / 1000000000000000000
  elseif number >= 1000000000000000 then
    unit = "PFE"
    value = number / 1000000000000000
  elseif number >= 1000000000000 then
    unit = "TFE"
    value = number / 1000000000000
  elseif number >= 1000000000 then
    unit = "GFE"
    value = number / 1000000000
  elseif number >= 1000000 then
    unit = "MFE"
    value = number / 1000000
  elseif number >= 1000 then
    unit = "KFE"
    value = number / 1000
  else
    value = number
  end

  -- format value to have exact 3 decimal places
  return formatDecimals(value, 1) .. " " .. unit
end

-- function to add delimiters to a number
function format_int(number)
  --thanks to https://stackoverflow.com/questions/10989788/format-integer-in-lua answer by Bert Kiers
  local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

  if int == nil then
    int = ""
  end

  if fraction == nil then
    fraction = ""
  end

  if minus == nil then
    minus = ""
  end
  
  -- reverse the int-string and append a comma to all blocks of 3 digits
  int = int:reverse():gsub("(%d%d%d)", "%1".._G.language:getText("thousandsDelimiter"))

  if fraction:len() > 0 then
    fraction = _G.language:getText("fractionDelimiter")..fraction:sub(2)
  end

  -- reverse the int-string back remove an optional comma and put the 
  -- optional minus and fractional part back
  return minus .. int:reverse():gsub("^%p", "") .. fraction
end

-- auxilary function for ternary operator (cond ? T : F)
function _G.ternary ( cond , T , F )
  if cond then return T else return F end
end

-- auxilary function to return default value when input is Nil
function _G.defaultNil ( val , def )
  return ternary(val == nil, def, val)
end

-- auxilary function to return default value when input is Infinity
function _G.defaultInf ( val, def )
  return ternary(tostring(val) == "inf", def, val)
end

-- auxilary function to set return default value if input is Nan
function _G.defaultNan ( val , def )
  return ternary(val ~= val, def, val)
end

function _G.callPeripheralMethod(peripheralObject, methodName, defaultValue, ...)
  if peripheralObject == nil or methodName == nil or type(peripheralObject[methodName]) ~= "function" then
    if _G.debugOutput ~= nil then
      _G.debugOutput("Peripheral method unavailable: " .. tostring(methodName))
    end
    return defaultValue
  end

  local args = {...}
  local success, result = pcall(function()
    return peripheralObject[methodName](unpack(args))
  end)

  if not success then
    if _G.debugOutput ~= nil then
      _G.debugOutput("Peripheral method failed: " .. tostring(methodName) .. " - " .. tostring(result))
    end
    return defaultValue
  end

  return _G.defaultNil(result, defaultValue)
end
