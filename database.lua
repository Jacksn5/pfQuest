pfDatabase = {}

local loc = GetLocale()
local dbs = { "items", "quests", "objects", "units", "zones" }

-- detect localized databases
for id, db in pairs(dbs) do
  -- assign existing locale
  pfDB[db]["loc"] = pfDB[db][loc] or pfDB[db]["enUS"]
end

-- add database shortcuts
local items = pfDB["items"]["data"]
local units = pfDB["units"]["data"]
local objects = pfDB["objects"]["data"]
local quests = pfDB["quests"]["data"]
local zones = pfDB["zones"]["loc"]

local bitraces = {
  [1] = "Human",
  [2] = "Orc",
  [4] = "Dwarf",
  [8] = "NightElf",
  [16] = "Scourge",
  [32] = "Tauren",
  [64] = "Gnome",
  [128] = "Troll"
}

local bitclasses = {
  [1] = "WARRIOR",
  [2] = "PALADIN",
  [4] = "HUNTER",
  [8] = "ROGUE",
  [16] = "PRIEST",
  [64] = "SHAMAN",
  [128] = "MAGE",
  [256] = "WARLOCK",
  [1024] = "DRUID"
}

-- GetBitByRace
-- Returns bit of the current race
function pfDatabase:GetBitByRace(model)
  -- local _, model == UnitRace("player")
  for bit, v in pairs(bitraces) do
    if model == v then return bit end
  end
end

-- GetBitByClass
-- Returns bit of the current class
function pfDatabase:GetBitByClass(class)
  -- local _, class == UnitClass("player")
  for bit, v in pairs(bitclasses) do
    if class == v then return bit end
  end
end

local function strcomp(old, new)
  local prv = {}
  for o = 0, string.len(old) do
    prv[o] = ""
  end
  for n = 1, string.len(new) do
    local nxt = {[0] = string.sub(new,1, n)}
    local nn = string.sub(new, n, n)
    for o = 1, string.len(old) do
      local result
      if nn == string.sub(old, o, o) then
        result = prv[o-1]
      else
        result = prv[o]..nn
        if string.len(nxt[o-1]) <= string.len(result) then
          result = nxt[o-1]
        end
      end
      nxt[o] = result
    end
    prv = nxt
  end

  local diff = strlen(prv[string.len(old)])
  if diff == 0 then 
    return 0
  else
    return diff/strlen(old)
  end
end

-- CompareString
-- Shows a score based on the similarity of two strings
function pfDatabase:CompareString(old, new)
  local s1 = strcomp(old, new)
  local s2 = strcomp(new, old)
  return (math.abs(s1) + math.abs(s2))/2
end

-- GetHexDifficultyColor
-- Returns a string with the difficulty color of the given level
function pfDatabase:GetHexDifficultyColor(level, force)
  if force and UnitLevel("player") < level then
    return "|cffff5555"
  else
    local c = GetDifficultyColor(level)
    return string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
  end
end

-- GetIDByName
-- Scans localization tables for matching IDs
-- Returns table with all IDs
function pfDatabase:GetIDByName(name, db)
  if not pfDB[db] then return nil end
  local ret = {}

  for id, loc in pairs(pfDB[db]["loc"]) do
    if db == "quests" then loc = loc["T"] end

    if strlower(loc) == strlower(name) then
      ret[id] = true
    end
  end
  return ret
end

-- GetBestMap
-- Scans a map table for all spawns
-- Returns the map with most spawns
function pfDatabase:GetBestMap(maps)
  local bestmap, bestscore = nil, 0

  -- calculate best map results
  for map, count in pairs(maps) do
    if count > bestscore then
      bestscore = count
      bestmap   = map
    end
  end

  return bestmap or nil, bestscore or nil
end

-- SearchMobID
-- Scans for all mobs with a specified ID
-- Adds map nodes for each and returns its map table
function pfDatabase:SearchMobID(id, meta, maps)
  if not units[id] or not units[id]["coords"] then return maps end

  local maps = maps or {}

  for _, data in pairs(units[id]["coords"]) do
    local x, y, zone, respawn = unpack(data)

    if pfMap:IsValidMap(zone) and zone > 0 then
      -- add all gathered data
      meta = meta or {}
      meta["spawn"] = pfDB.units.loc[id]

      meta["title"] = meta["quest"] or meta["item"] or meta["spawn"]
      meta["zone"]  = zone
      meta["x"]     = x
      meta["y"]     = y

      meta["level"] = units[id]["lvl"] or UNKNOWN
      meta["spawntype"] = "Unit"
      meta["respawn"] = respawn and SecondsToTime(respawn)

      maps[zone] = maps[zone] and maps[zone] + 1 or 1
      pfMap:AddNode(meta)
    end
  end

  return maps
end

-- SearchMob
-- Scans for all mobs with a specified name
-- Adds map nodes for each and returns its map table
function pfDatabase:SearchMob(mob, meta, show)
  local maps = {}

  for id in pairs(pfDatabase:GetIDByName(mob, "units")) do
    if units[id] and units[id]["coords"] then
      maps = pfDatabase:SearchMobID(id, meta, maps)
    end
  end

  return maps
end

-- Scans for all objects with a specified ID
-- Adds map nodes for each and returns its map table
function pfDatabase:SearchObjectID(id, meta, maps)
  if not objects[id] or not objects[id]["coords"] then return maps end

  local maps = maps or {}

  for _, data in pairs(objects[id]["coords"]) do
    local x, y, zone, respawn = unpack(data)

    if pfMap:IsValidMap(zone) and zone > 0 then
      -- add all gathered data
      meta = meta or {}
      meta["spawn"] = pfDB.objects.loc[id]

      meta["title"] = meta["quest"] or meta["item"] or meta["spawn"]
      meta["zone"]  = zone
      meta["x"]     = x
      meta["y"]     = y

      meta["level"] = nil
      meta["spawntype"] = "Object"
      meta["respawn"] = respawn and SecondsToTime(respawn)

      maps[zone] = maps[zone] and maps[zone] + 1 or 1
      pfMap:AddNode(meta)
    end
  end

  return maps
end

-- SearchObject
-- Scans for all objects with a specified name
-- Adds map nodes for each and returns its map table
function pfDatabase:SearchObject(obj, meta)
  local maps = {}

  for id in pairs(pfDatabase:GetIDByName(obj, "objects")) do
    if objects[id] and objects[id]["coords"] then
      maps = pfDatabase:SearchObjectID(id, meta, maps)
    end
  end

  return maps
end

-- SearchItemID
-- Scans for all items with a specified ID
-- Adds map nodes for each drop and vendor
-- Returns its map table
function pfDatabase:SearchItemID(id, meta, maps)
  if not items[id] then return maps end

  local maps = maps or {}
  local meta = meta or {}

  meta["itemid"] = id
  meta["item"] = pfDB.items.loc[id]

  -- search unit drops
  if items[id]["U"] then
    for unit, chance in pairs(items[id]["U"]) do
      meta["texture"] = nil
      meta["droprate"] = chance
      meta["sellcount"] = nil
      maps = pfDatabase:SearchMobID(unit, meta, maps)
    end
  end

  -- search object loot (veins, chests, ..)
  if items[id]["O"] then
    for object, chance in pairs(items[id]["O"]) do
      meta["texture"] = nil
      meta["droprate"] = chance
      meta["sellcount"] = nil
      maps = pfDatabase:SearchObjectID(object, meta, maps)
    end
  end

  -- search vendor goods
  if items[id]["V"] then
    for unit, chance in pairs(items[id]["V"]) do
      meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\icon_vendor"
      meta["droprate"] = nil
      meta["sellcount"] = chance
      maps = pfDatabase:SearchMobID(unit, meta, maps)
    end
  end

  return maps
end

-- SearchItem
-- Scans for all items with a specified name
-- Adds map nodes for each drop and vendor
-- Returns its map table
function pfDatabase:SearchItem(item, meta)
  local maps = {}
  local bestmap, bestscore = nil, 0

  for id in pairs(pfDatabase:GetIDByName(item, "items")) do
    maps = pfDatabase:SearchItemID(id, meta, maps)
  end

  return maps
end

-- SearchVendor
-- Scans for all items with a specified name
-- Adds map nodes for each vendor
-- Returns its map table
function pfDatabase:SearchVendor(item, meta)
  local maps = {}
  local meta = meta or {}
  local bestmap, bestscore = nil, 0

  for id in pairs(pfDatabase:GetIDByName(item, "items")) do
    meta["itemid"] = id
    meta["item"] = pfDB.items.loc[id]

    -- search vendor goods
    if items[id] and items[id]["V"] then
      for unit, chance in pairs(items[id]["V"]) do
        meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\icon_vendor"
        meta["droprate"] = nil
        meta["sellcount"] = chance
        maps = pfDatabase:SearchMobID(unit, meta, maps)
      end
    end
  end

  return maps
end

-- SearchQuestID
-- Scans for all quests with a specified ID
-- Adds map nodes for each objective and involved units
-- Returns its map table
function pfDatabase:SearchQuestID(id, meta, maps)
  local maps = maps or {}
  local meta = meta or {}

  meta["questid"] = id
  meta["quest"] = pfDB.quests.loc[id].T
  meta["qlvl"] = quests[id]["lvl"]
  meta["qmin"] = quests[id]["min"]

  -- search quest-starter
  if quests[id]["start"] then
    -- units
    if quests[id]["start"]["U"] then
      for _, unit in pairs(quests[id]["start"]["U"]) do
        meta = meta or {}
        meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\available_c"
        maps = pfDatabase:SearchMobID(unit, meta, maps)
      end
    end

    -- objects
    if quests[id]["start"]["O"] then
      for _, object in pairs(quests[id]["start"]["O"]) do
        meta = meta or {}
        meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\available_c"
        maps = pfDatabase:SearchObjectID(object, meta, maps)
      end
    end
  end

  -- search quest-ender
  if quests[id]["end"] then
    -- units
    if quests[id]["end"]["U"] then
      for _, unit in pairs(quests[id]["end"]["U"]) do
        meta = meta or {}
        meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\complete_c"
        maps = pfDatabase:SearchMobID(unit, meta, maps)
      end
    end

    -- objects
    if quests[id]["end"]["O"] then
      for _, object in pairs(quests[id]["end"]["O"]) do
        meta = meta or {}
        meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\complete_c"
        maps = pfDatabase:SearchObjectID(object, meta, maps)
      end
    end
  end

  -- search quest-objectives
  if quests[id]["obj"] then
    -- units
    if quests[id]["obj"]["U"] then
      for _, unit in pairs(quests[id]["obj"]["U"]) do
        meta = meta or {}
        meta["texture"] = nil
        maps = pfDatabase:SearchMobID(unit, meta, maps)
      end
    end

    -- objects
    if quests[id]["obj"]["O"] then
      for _, object in pairs(quests[id]["obj"]["O"]) do
        meta = meta or {}
        meta["texture"] = nil
        maps = pfDatabase:SearchObjectID(object, meta, maps)
      end
    end

    -- items
    if quests[id]["obj"]["I"] then
      for _, item in pairs(quests[id]["obj"]["I"]) do
        meta = meta or {}
        meta["texture"] = nil
        maps = pfDatabase:SearchItemID(item, meta, maps)
      end
    end
  end

  return maps
end

-- SearchQuest
-- Scans for all quests with a specified name
-- Adds map nodes for each objective and involved unit
-- Returns its map table
function pfDatabase:SearchQuest(quest, meta)
  local maps = {}

  for id in pairs(pfDatabase:GetIDByName(quest, "quests")) do
    maps = pfDatabase:SearchQuestID(id, meta, maps)
  end

  return maps
end

-- SearchQuests
-- Scans for all available quests
-- Adds map nodes for each quest starter and ender
-- Returns its map table
function pfDatabase:SearchQuests()
  local level, minlvl, maxlvl, race, class, prof
  local maps = {}
  local meta = {}

  local plevel = UnitLevel("player")
  local pfaction = ( UnitFactionGroup("player") == "Horde" ) and "H" or "A"
  local _, race = UnitRace("player")
  local prace = pfDatabase:GetBitByRace(race)
  local _, class = UnitClass("player")
  local pclass = pfDatabase:GetBitByClass(class)

  for id in pairs(quests) do
    meta["quest"] = ( pfDB.quests.loc[id] and pfDB.quests.loc[id].T ) or UNKNOWN
    meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\available_c"

    minlvl = quests[id]["min"] or quests[id]["lvl"]
    maxlvl = quests[id]["lvl"]

    meta["qlvl"] = quests[id]["lvl"]
    meta["qmin"] = quests[id]["min"]

    meta["vertex"] = { 0, 0, 0 }
    meta["layer"] = 3

    -- tint high level quests red
    if minlvl > plevel then
      meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\available"
      meta["vertex"] = { 1, .6, .6 }
      meta["layer"] = 2
    end

    -- treat highlevel quests with low requirements as dailies
    if minlvl == 1 and maxlvl > 50 then
      meta["texture"] = "Interface\\AddOns\\pfQuest\\img\\available"
      meta["vertex"] = { .2, .8, 1 }
      meta["layer"] = 2
    end

-- elseif quests[id]["skill"] and not ( bit.band(quests[id]["skill"], pskill) == pskill ) then
-- hide non-available quests for your class

    if pfQuest_history and pfQuest_history[id] then
      -- hide completed quests
    elseif quests[id]["race"] and not ( bit.band(quests[id]["race"], prace) == prace ) then
      -- hide non-available quests for your race
    elseif quests[id]["class"] and not ( bit.band(quests[id]["class"], pclass) == pclass ) then
      -- hide non-available quests for your class
    elseif quests[id]["lvl"] and quests[id]["lvl"] < plevel - 9 then
      -- hide lowlevel quests
    elseif quests[id]["lvl"] and quests[id]["lvl"] > plevel + 10 then
      -- hide highlevel quests
    elseif quests[id]["min"] and quests[id]["min"] > plevel + 3 then
      -- hide highlevel quests
    else
      -- iterate over all questgivers
      if quests[id]["start"] then
        -- units
        if quests[id]["start"]["U"] then
          for _, unit in pairs(quests[id]["start"]["U"]) do
            maps = pfDatabase:SearchMobID(unit, meta, maps)
          end
        end

        -- objects
        if quests[id]["start"]["O"] then
          for _, object in pairs(quests[id]["start"]["O"]) do
            maps = pfDatabase:SearchObjectID(object, meta, maps)
          end
        end
      end
    end
  end

  return num
end

function pfDatabase:FormatQuestText(questText)
  questText = string.gsub(questText, "$[Nn]", UnitName("player"))
  questText = string.gsub(questText, "$[Cc]", strlower(UnitClass("player")))
  questText = string.gsub(questText, "$[Rr]", strlower(UnitRace("player")))
  questText = string.gsub(questText, "$[Bb]", "\n")
  -- UnitSex("player") returns 2 for male and 3 for female
  -- that's why there is an unused capture group around the $[Gg]
  return string.gsub(questText, "($[Gg])(.+):(.+);", "%"..UnitSex("player"))
end

-- GetQuestID
-- Try to guess the quest ID based on the questlog ID
-- Returns possible quest IDs
function pfDatabase:GetQuestIDs(qid, deep)
  local oldID = GetQuestLogSelection()
  SelectQuestLogEntry(qid)
  local text, objective = GetQuestLogQuestText()
  local title, level, _, header = GetQuestLogTitle(qid)
  SelectQuestLogEntry(oldID)

  local _, race = UnitRace("player")
  local prace = pfDatabase:GetBitByRace(race)
  local _, class = UnitClass("player")
  local pclass = pfDatabase:GetBitByClass(class)

  local best = 0
  local results = {}

  for id, data in pairs(pfDB["quests"]["loc"]) do
    local score = 0

    if data.T == title or ( deep and strsub(pfDatabase:FormatQuestText(pfDB.quests.loc[id]["O"]),0,10) == strsub(objective,0,10)) then
      if quests[id]["lvl"] == level then
        score = score + 1
      end

      if pfDB.quests.loc[id]["O"] == objective then
        score = score + 2
      end

      if quests[id]["race"] and ( bit.band(quests[id]["race"], prace) == prace ) then
        score = score + 4
      end

      if quests[id]["class"] and ( bit.band(quests[id]["class"], pclass) == pclass ) then
        score = score + 4
      end

      local dbtext = strsub(pfDatabase:FormatQuestText(pfDB.quests.loc[id]["D"]),0,10)
      local qstext = strsub(text,0,10)

      if pfDatabase:CompareString(dbtext, qstext) < 0.1 then
        score = score + 8
      end

      if score > best then best = score end
      results[score] = results[score] or {}
      table.insert(results[score], id)
    end
  end

  return results[best] or pfDatabase:GetQuestIDs(qid, 1) or {}
end