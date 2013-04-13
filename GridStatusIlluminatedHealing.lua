--[[
	Copyright (c) 2013 Bastien Clément

	Permission is hereby granted, free of charge, to any person obtaining a
	copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be included
	in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local GridRoster = Grid:GetModule("GridRoster")
local GridStatus = Grid:GetModule("GridStatus")

local GridStatusIlluminatedHealing = GridStatus:NewModule("GridStatusIlluminatedHealing")

local SPELL_IH_NAME = GetSpellInfo(86273)
local shield_ratio = 1/3
local shield_max = 0

local function update_shield_max()
	shield_max = math.floor(UnitHealthMax("player") * shield_ratio)
end

GridStatusIlluminatedHealing.defaultDB = {
	unit_illuminated_healing = {
		color = { r = 0.84, g = 0.32, b = 0, a = 1.0 },
		colorFull = { r = 0.42, g = 0.76, b = 0.11, a = 1.0 },
		text = "Illuminated Healing",
		enable = true,
		priority = 30,
		range = false,
		shortText = true,
		percAsStack = true,
		noneAsZero = false,
	}
}

GridStatusIlluminatedHealing.menuName = SPELL_IH_NAME
GridStatusIlluminatedHealing.options = false

local settings
local unitHasShield = {}

local IlluminatedHealing_options = {
	["break1"] = {
		type = "description",
		order = 80,
		name = "",
	},
	["color"] = {
		type = "color",
		name = "Color 1",
		desc = "Color when the shield is not fully stacked",
		hasAlpha = true,
		order = 81,
		get = function ()
			local color = settings.color
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = settings.color
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
		end,
	},
	["colorFull"] = {
		type = "color",
		name = "Color 2",
		desc = "Color once the shield is fully stacked.",
		hasAlpha = true,
		order = 82,
		get = function ()
			local color = settings.colorFull
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = settings.colorFull
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
		end,
	},
	["break2"] = {
		type = "description",
		order = 90,
		name = "",
	},
	["shortText"] = {
		type = "toggle",
		name = "Short text",
		desc = "Displays 1250 as 1.2k",
		order = 91,
		get = function()
			return settings.shortText
		end,
		set = function(_, v)
			settings.shortText = v
			GridStatusIlluminatedHealing:UpdateAllUnits()
		end,
	},
	["percAsStack"] = {
		type = "toggle",
		name = "Percent as stacks",
		desc = "Displays shield percent as stacks (like Sanity on Yogg-Saron)",
		order = 92,
		get = function()
			return settings.percAsStack
		end,
		set = function(_, v)
			settings.percAsStack = v
			GridStatusIlluminatedHealing:UpdateAllUnits()
		end,
	},
	["noneAsZero"] = {
		type = "toggle",
		name = "Show missing shields",
		desc = "Displays the status even if there is no shield on the target",
		order = 93,
		get = function()
			return settings.noneAsZero
		end,
		set = function(_, v)
			settings.noneAsZero = v
			GridStatusIlluminatedHealing:Reset()
		end,
	},
	["opacity"] = false
}

function GridStatusIlluminatedHealing:OnInitialize()
	self.super.OnInitialize(self)
	self:RegisterStatus("unit_illuminated_healing", SPELL_IH_NAME, IlluminatedHealing_options, true)
	settings = self.db.profile.unit_illuminated_healing
end

function GridStatusIlluminatedHealing:OnStatusEnable(status)
	if status == "unit_illuminated_healing" then
		self:RegisterMessage("Grid_RosterUpdated", "UpdateAllUnits")
		self:RegisterEvent("UNIT_MAXHEALTH", "UpdatePlayerHealth")
		self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "UpdateUnit")
		self:UpdateAllUnits()
	end
end

function GridStatusIlluminatedHealing:OnStatusDisable(status)
	if status == "unit_illuminated_healing" then
		for guid, unitid in GridRoster:IterateRoster() do
			self.core:SendStatusLost(guid, "unit_illuminated_healing")
		end
		self:UnregisterMessage("Grid_RosterUpdated", "UpdateAllUnits")
		self:UnregisterEvent("UNIT_MAXHEALTH")
		self:UnregisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
	end
end

function GridStatusIlluminatedHealing:Reset()
	for guid, unitid in GridRoster:IterateRoster() do
		self.core:SendStatusLost(guid, "unit_illuminated_healing")
	end
	wipe(unitHasShield)
	update_shield_max()
	self:UpdateAllUnits()
end

function GridStatusIlluminatedHealing:UpdateAllUnits()
	if shield_max < 1 then
		update_shield_max()
	end
	for guid, unitid in GridRoster:IterateRoster() do
		self:UpdateUnitShield(unitid)
	end
end

function GridStatusIlluminatedHealing:UpdatePlayerHealth(_, unitid)
	if UnitIsUnit("player", unitid) then
		update_shield_max()
		self:Reset()
	end
end

function GridStatusIlluminatedHealing:UpdateUnit(_, unitid)
	self:UpdateUnitShield(unitid)
end

function GridStatusIlluminatedHealing:UpdateUnitShield(unitid)
	local shield = select(15, UnitBuff(unitid, SPELL_IH_NAME, nil, "PLAYER"))
	local guid = UnitGUID(unitid)
	
	if not shield then
		if settings.noneAsZero then
			shield = 0
		else
			if unitHasShield[guid] then
				unitHasShield[guid] = nil
				self.core:SendStatusLost(guid, "unit_illuminated_healing")
			end
			return
		end
	elseif not unitHasShield[guid] then
		unitHasShield[guid] = true
	end
	
	shieldFull = (shield >= shield_max)

	self.core:SendStatusGained(
		guid,
		"unit_illuminated_healing",
		settings.priority,
		nil,
		shieldFull and settings.colorFull or settings.color,
		(shield > 999 and settings.shortText) and string.format("%.1fk", shield / 1000) or tostring(shield),
		shield,
		shield_max,
		"Interface\\Icons\\spell_holy_absolution",
		nil,
		nil,
		settings.percAsStack and (shieldFull and 100 or (math.floor((shield / shield_max) * 99) + 1)) or nil
	)
end
