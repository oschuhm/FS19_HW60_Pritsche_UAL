-- A basic autoloading script
-- put together by alfalfa6945
-- version 0.1.0.8
-- ***script is still in early development, you really shouldn't use it in a production environment

easyAutoLoader = {}

local easyAutoLoader_directory = g_currentModDirectory
local autoloadModName = g_currentModName

function easyAutoLoader.prerequisitesPresent(specializations)
	return true
end

function easyAutoLoader.registerEventListeners(vehicleType)
	for _, spec in pairs({"onLoad", "onPostLoad", "onDelete", "onUpdate", "onDraw", "onReadStream", "onWriteStream", "onRegisterActionEvents", "saveToXMLFile"}) do
		SpecializationUtil.registerEventListener(vehicleType, spec, easyAutoLoader)
	end
end

function easyAutoLoader:onLoad(savegame)
	self.updateTable = easyAutoLoader.updateTable
	self.doStateChange = easyAutoLoader.doStateChange
	self.setMarkerVisibility = easyAutoLoader.setMarkerVisibility
	self.setMarkerPosition = easyAutoLoader.setMarkerPosition
	self.setUnloadPosition = easyAutoLoader.setUnloadPosition
	self.objectCallback = easyAutoLoader.objectCallback
	self.isDedicatedServer = easyAutoLoader.isDedicatedServer
	self.setWorkMode = easyAutoLoader.setWorkMode
	self.setSelect = easyAutoLoader.setSelect
	self.setUnload = easyAutoLoader.setUnload
	self.changeMarkerPosition = easyAutoLoader.changeMarkerPosition
	self.moveMarkerLeft = easyAutoLoader.moveMarkerLeft
	self.moveMarkerRight = easyAutoLoader.moveMarkerRight
	self.moveMarkerUp = easyAutoLoader.moveMarkerUp
	self.moveMarkerDown = easyAutoLoader.moveMarkerDown
	self.moveMarkerForward = easyAutoLoader.moveMarkerForward
	self.moveMarkerBackward = easyAutoLoader.moveMarkerBackward
	self.moveMarkerOriginal = easyAutoLoader.moveMarkerOriginal
	self.setMarkerRotation = easyAutoLoader.setMarkerRotation
	self.triggerHelperMode = easyAutoLoader.triggerHelperMode
	self.moveTrigger = getXMLString(self.xmlFile, "vehicle.easyAutoLoad#triggerAnimation")
	self.workMode = false
	self.currentNumObjects = 0
	self.unloadPosition = 1
	self.state = 1
	self.var = 0
	self.centerMarkerIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.easyAutoLoad#centerMarkerIndex"), 1)
	self.unloadHeightOffset = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.easyAutoLoad#unloadHeightOffset"), 1.1)
	self.unloadMarker = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.easyAutoLoad#markerIndex"), self.i3dMappings)
	self.markerVisible = false
	if self.unloadMarker then
		local markerLength = Utils.getNoNil(getUserAttribute(self.unloadMarker, "markerLength"), 15.77)
		 self.unloaderMarkerYoffset = markerLength / 2
		if getVisibility(self.unloadMarker) then
			self.markerVisible = true
			self:setMarkerVisibility(false)
		end
	end
	self.markerMoveSpeed = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#markerMoveSpeed"), 0.05)
	self.markerMinX = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#minX"), "0 4 -25 -25"))
	self.markerMaxX = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#maxX"), "0 25 25 -4"))
	self.markerMinY = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#minY"), "0 -0.7 -0.7 -0.7"))
	self.markerMaxY = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#maxY"), "0 15 15 15"))
	self.markerMinZ = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#minZ"), "0 -20 -30 -20"))
	self.markerMaxZ = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.moveableMarkerOptions#maxZ"), "0 20 -16 20"))
	self.palletIcon = false
	self.squareBaleIcon = false
	self.roundBaleIcon = false
	local markerPositions = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.easyAutoLoad#markerPositionsIndex"), self.i3dMappings)
	local numMarkerChildren = getNumOfChildren(markerPositions)
	if numMarkerChildren > 0 then
		self.markerPositions = {}
		for i = 1, numMarkerChildren do
			local entry = {}
			local markerId = getChildAt(markerPositions, i-1)
			local name = getName(markerId)
			entry.index = markerId
			entry.translation = {getTranslation(markerId)}
			entry.name = g_i18n:hasText(name) and g_i18n:getText(name) or name
			table.insert(self.markerPositions, entry)
		end
	end
	local triggerNode = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.easyAutoLoad#triggersIndex"), self.i3dMappings)
	local numTriggerChildren = getNumOfChildren(triggerNode)
	if numTriggerChildren > 0 then
		self.objectTriggers = {}
		for i = 1, numTriggerChildren do
			local triggerId = getChildAt(triggerNode, i-1)
			table.insert(self.objectTriggers, triggerId)
			addTrigger(triggerId, "objectCallback", self)
		end
	end
	local objectsNode = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.easyAutoLoad#objectsIndex"), self.i3dMappings)
	local numChildren = getNumOfChildren(objectsNode)
	if numChildren > 0 then
		self.autoLoadObjects = {}
		for i = 1, numChildren do
			local entry = {}
			local objectId = getChildAt(objectsNode, i-1)
			local name = getName(objectId)
			entry.index = objectId
			entry.name = name
			entry.nameL = g_i18n:hasText(name) and g_i18n:getText(name) or name
			entry.maxNumObjects = getNumOfChildren(objectId)
			entry.isRoundBale = Utils.getNoNil(getUserAttribute(objectId, "isRoundBale"), false)
			if entry.isRoundBale then
				entry.diameter = Utils.getNoNil(getUserAttribute(objectId, "diameter"), "1.30")
			end
			entry.isSquareBale = Utils.getNoNil(getUserAttribute(objectId, "isSquareBale"), false)
			if entry.isSquareBale then
				entry.width = Utils.getNoNil(getUserAttribute(objectId, "baleWidth"), "1.20")
				entry.length = Utils.getNoNil(getUserAttribute(objectId, "baleLength"), "2.40")
			end
			entry.isHDbale = Utils.getNoNil(getUserAttribute(objectId, "isHDbale"), false)
			entry.isMissionPallet = Utils.getNoNil(getUserAttribute(objectId, "isMissionPallet"), false)
			entry.excludedFillTypes = StringUtil.splitString(" ", getUserAttribute(objectId, "excludedFillTypes"))
			entry.includedFillTypes = StringUtil.splitString(" ", getUserAttribute(objectId, "includedFillTypes"))
			entry.usePalletSize = Utils.getNoNil(getUserAttribute(objectId, "usePalletSize"), false)
			if entry.usePalletSize then
				entry.sizeLength = Utils.getNoNil(getUserAttribute(objectId, "sizeLength"), "2.00")
				entry.sizeWidth = Utils.getNoNil(getUserAttribute(objectId, "sizeWidth"), "2.00")
				entry.secondaryPalletSize = Utils.getNoNil(getUserAttribute(objectId, "secondaryPalletSize"), false)
				if entry.secondaryPalletSize then
					entry.secondarySizeLength = Utils.getNoNil(getUserAttribute(objectId, "secondarySizeLength"), "1.50")
					entry.secondarySizeWidth = Utils.getNoNil(getUserAttribute(objectId, "secondarySizeWidth"), "2.00")
				end
			end
			entry.toMount = {}
			entry.objects = {}
			self:updateTable(entry.objects, objectId)
			table.insert(self.autoLoadObjects, entry)
		end
	end
	self.easyAutoLoaderRegistrationList = {}
	self.easyAutoLoaderRegistrationList[InputAction.workMode] = { eventId="", callback=self.setWorkMode, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=true, callbackState=-1, text=g_i18n:getText("workModeOn"), textVisibility=true }
	self.easyAutoLoaderRegistrationList[InputAction.select] = { eventId="", callback=self.setSelect, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=true, callbackState=-1, text=self.autoLoadObjects[self.state].nameL, textVisibility=true }
	self.easyAutoLoaderRegistrationList[InputAction.markerPosition] = { eventId="", callback=self.changeMarkerPosition, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerPosition"), textVisibility=true }
	self.easyAutoLoaderRegistrationList[InputAction.unload] = { eventId="", callback=self.setUnload, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=false, callbackState=-1, text=g_i18n:getText("input_unload"), textVisibility=true }
	self.easyAutoLoaderRegistrationList[InputAction.markerUp] = { eventId="", callback=self.moveMarkerUp, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerUp"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerDown] = { eventId="", callback=self.moveMarkerDown, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerDown"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerLeft] = { eventId="", callback=self.moveMarkerLeft, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerLeft"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerRight] = { eventId="", callback=self.moveMarkerRight, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerRight"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerForward] = { eventId="", callback=self.moveMarkerForward, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerForward"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerBackward] = { eventId="", callback=self.moveMarkerBackward, triggerUp=false, triggerDown=true, triggerAlways=true, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerBackward"), textVisibility=false }
	self.easyAutoLoaderRegistrationList[InputAction.markerOriginal] = { eventId="", callback=self.moveMarkerOriginal, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerOriginal"), textVisibility=true }
	self.easyAutoLoaderRegistrationList[InputAction.markerRotation] = { eventId="", callback=self.triggerHelperMode, triggerUp=false, triggerDown=true, triggerAlways=false, startActive=false, callbackState=-1, text=g_i18n:getText("input_markerRotation"), textVisibility=true }
	self.coloredIcons = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.easyAutoLoad.levelBarOptions#coloredIcons"), false)
	if not self:isDedicatedServer() then
		self.easyAutoLoaderIcons = {}
		local fillLevelColor = ConfigurationUtil.getColorFromString(Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.levelBarOptions#fillLevelColor"), "0.991 0.3865 0.01 1"))
		local fillLevelTextColor = {1, 1, 1, 0.2}
		self.fillLevelsTextColor = {1, 1, 1, 1}
		local uiScale = g_gameSettings:getValue("uiScale")
		local iconWidth, iconHeight = getNormalizedScreenValues(33 * uiScale, 33 * uiScale)
		local offsetX, offsetY = getNormalizedScreenValues(2 * uiScale, 4 * uiScale)
		self.easyAutoLoaderIcons.palletIconOverlay = Overlay:new(Utils.getFilename(self.coloredIcons and getXMLString(self.xmlFile, "vehicle.easyAutoLoad.palletIcon#colorIcon") or getXMLString(self.xmlFile, "vehicle.easyAutoLoad.palletIcon#overlayIcon"), easyAutoLoader_directory), g_currentMission.hud.fillLevelsDisplay.origX - offsetX, g_currentMission.hud.fillLevelsDisplay.origY, iconWidth, iconHeight)
		self.easyAutoLoaderIcons.roundBaleIconOverlay = Overlay:new(Utils.getFilename(self.coloredIcons and getXMLString(self.xmlFile, "vehicle.easyAutoLoad.roundBaleIcon#colorIcon") or getXMLString(self.xmlFile, "vehicle.easyAutoLoad.roundBaleIcon#overlayIcon"), easyAutoLoader_directory), g_currentMission.hud.fillLevelsDisplay.origX - offsetX, g_currentMission.hud.fillLevelsDisplay.origY, iconWidth, iconHeight)
		self.easyAutoLoaderIcons.squareBaleIconOverlay = Overlay:new(Utils.getFilename(self.coloredIcons and getXMLString(self.xmlFile, "vehicle.easyAutoLoad.squareBaleIcon#colorIcon") or getXMLString(self.xmlFile, "vehicle.easyAutoLoad.squareBaleIcon#overlayIcon"), easyAutoLoader_directory), g_currentMission.hud.fillLevelsDisplay.origX - offsetX, g_currentMission.hud.fillLevelsDisplay.origY, iconWidth, iconHeight)
		if not self.coloredIcons then
			local iconColor = ConfigurationUtil.getColorFromString(Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.easyAutoLoad.levelBarOptions#iconColor"), "0.6307 0.6307 0.6307 1"))
			for _, icon in pairs(self.easyAutoLoaderIcons) do
				icon:setColor(unpack(iconColor))
			end
		end
		local width, height = getNormalizedScreenValues(144 * uiScale, 10 * uiScale)
		self.fillLevelBar = StatusBar:new(g_baseUIFilename, g_colorBgUVs, nil, fillLevelTextColor, fillLevelColor, nil, g_currentMission.hud.fillLevelsDisplay.origX + iconWidth + offsetX, g_currentMission.hud.fillLevelsDisplay.origY + offsetY, width, height)
	end
	self.currentObjectId = 0
	self.triggerHelperModeEnabled = false
end

function easyAutoLoader:onPostLoad(savegame)
	if savegame ~= nil and not savegame.resetVehicles then
		local key = savegame.key.."."..autoloadModName..".easyAutoLoader"
		local state = Utils.getNoNil(getXMLInt(savegame.xmlFile, key.."#objectMode"), 1)
		self:doStateChange(3, false, state, 0, self.palletIcon, self.squareBaleIcon, self.roundBaleIcon, false)
	end
end

function easyAutoLoader:onDelete()
	if self.currentNumObjects > 0 then
		self:setUnload()
	end
	for i = 1, #self.objectTriggers do
		removeTrigger(self.objectTriggers[i])
	end
	if self.easyAutoLoaderIcons then
		for _, icon in pairs(self.easyAutoLoaderIcons) do
			icon:delete()
		end
		self.fillLevelBar:delete()
	end
end

function easyAutoLoader:onReadStream(streamId, connection)
    self.currentNumObjects = streamReadUInt16(streamId)
    self.state = streamReadUInt8(streamId)
	for i = 1, #self.autoLoadObjects[self.state].objects do
		local objectId = NetworkUtil.readNodeObjectId(streamId)
		if objectId == 694500 then
			objectId = nil
		end
		self.autoLoadObjects[self.state].objects[i].objectId = objectId
		if objectId then
			self.autoLoadObjects[self.state].toMount[objectId] = {serverId = objectId, linkNode = self.autoLoadObjects[self.state].objects[i].node, trans = {0,0,0}, rot = {0,0,0}}
		end
	end
	self.palletIcon = streamReadBool(streamId)
	self.squareBaleIcon = streamReadBool(streamId)
	self.roundBaleIcon = streamReadBool(streamId)
	self:setMarkerVisibility(streamReadBool(streamId))
	self.unloadPosition = streamReadUInt8(streamId)
end

function easyAutoLoader:onWriteStream(streamId, connection)
    streamWriteUInt16(streamId, self.currentNumObjects)
    streamWriteUInt8(streamId, self.state)
	for _, object in pairs(self.autoLoadObjects[self.state].objects) do
		local objectId = Utils.getNoNil(object.objectId, 694500)
		NetworkUtil.writeNodeObjectId(streamId, objectId)
	end
	streamWriteBool(streamId, self.palletIcon)
	streamWriteBool(streamId, self.squareBaleIcon)
	streamWriteBool(streamId, self.roundBaleIcon)
	streamWriteBool(streamId, self.markerVisible)
	streamWriteUInt8(streamId, self.unloadPosition)
end

function easyAutoLoader:onUpdate(dt)
	if not self.runOnce then
		self.runOnce = true
		for index, objectToMount in pairs(self.autoLoadObjects[self.state].toMount) do
			local object = NetworkUtil.getObject(objectToMount.serverId)
			if object ~= nil then
				local x,y,z = unpack(objectToMount.trans)
				local rx,ry,rz = unpack(objectToMount.rot)
				if object:isa(Vehicle) then
					object.synchronizePosition = false
				end
				object:mount(self, objectToMount.linkNode, x,y,z, rx,ry,rz, true)
				self.autoLoadObjects[self.state].toMount[index] = nil
			end
		end
	end
	if self:getIsActiveForInput() and self:getIsActive() then
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.workMode].eventId, self.currentNumObjects ~= self.autoLoadObjects[self.state].maxNumObjects)
		if self.workMode then
			g_inputBinding:setActionEventText(self.easyAutoLoaderRegistrationList[InputAction.workMode].eventId, g_i18n:getText("workModeOff"))
		elseif not self.workMode then
			g_inputBinding:setActionEventText(self.easyAutoLoaderRegistrationList[InputAction.workMode].eventId, g_i18n:getText("workModeOn"))
		end
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.select].eventId, self.currentNumObjects == 0 and not self.workMode)
		g_inputBinding:setActionEventText(self.easyAutoLoaderRegistrationList[InputAction.select].eventId, self.autoLoadObjects[self.state].nameL)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerPosition].eventId, self.currentNumObjects >= 1 and not self.workMode)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.unload].eventId, self.currentNumObjects >= 1 and not self.workMode)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerUp].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerDown].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerLeft].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerRight].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerForward].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerBackward].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerOriginal].eventId, self.markerVisible)
		g_inputBinding:setActionEventActive(self.easyAutoLoaderRegistrationList[InputAction.markerRotation].eventId, self.markerVisible and (self.squareBaleIcon or self.roundBaleIcon))
    end
end

function easyAutoLoader:onDraw()
	if not self:isDedicatedServer() and self.currentNumObjects >= 1 then
		local percentage = self.currentNumObjects / self.autoLoadObjects[self.state].maxNumObjects
		self.fillLevelBar:setValue(percentage)
		self.fillLevelBar:render()
		if self.easyAutoLoaderIcons.palletIconOverlay and self.palletIcon then
			self.easyAutoLoaderIcons.palletIconOverlay:render()
		end
		if self.easyAutoLoaderIcons.squareBaleIconOverlay and self.squareBaleIcon then
			self.easyAutoLoaderIcons.squareBaleIconOverlay:render()
		end
		if self.easyAutoLoaderIcons.roundBaleIconOverlay and self.roundBaleIcon then
			self.easyAutoLoaderIcons.roundBaleIconOverlay:render()
		end
		setTextBold(true)
		setTextColor(unpack(self.fillLevelsTextColor))
		setTextAlignment(RenderText.ALIGN_RIGHT)
		renderText(g_currentMission.hud.fillLevelsDisplay.origX + self.fillLevelBar.width + self.easyAutoLoaderIcons.palletIconOverlay.width, g_currentMission.hud.fillLevelsDisplay.origY + g_currentMission.hud.fillLevelsDisplay.fillLevelTextOffsetY, g_currentMission.hud.fillLevelsDisplay.fillLevelTextSize, self.currentNumObjects.." / "..self.autoLoadObjects[self.state].maxNumObjects)
		setTextBold(false)
	end
end

function easyAutoLoader:updateTable(objectTable, id)
	local i = 0
    while true do
		if i >= getNumOfChildren(id) then
			break
		end
		local entry = {}
		local index = getChildAt(id, i)
		if index ~= nil then
            entry.node = index
            entry.objectId = nil
            table.insert(objectTable, entry)
        end
        i = i + 1
	end
end

function easyAutoLoader:doStateChange(mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon, noEventSend)
	easyAutoLoaderEvent.sendEvent(self, mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon, noEventSend)
	if mode == 1 then
		local object = NetworkUtil.getObject(var)
        if object == nil then
            return
        end
		local okToLoad = true
		for _, loadObject in pairs(self.autoLoadObjects[state].objects) do
			if var == loadObject.objectId then
				okToLoad = false
				break
			end
		end
		if okToLoad then
			self.currentNumObjects = self.currentNumObjects + 1
			if self.autoLoadObjects[state].objects[self.currentNumObjects].node ~= nil then
				if object:isa(Vehicle) then
					object.synchronizePosition = false
				end
				object:mount(self, self.autoLoadObjects[state].objects[self.currentNumObjects].node, 0,0,0, 0,0,0, true)
				self.autoLoadObjects[state].objects[self.currentNumObjects].objectId = var
				self.currentObjectId = var
			end
		end
	elseif mode == 2 then
		local x, y, z = getTranslation(self.unloadMarker)
		local rx, ry, rz = getRotation(self.unloadMarker)
		if state > 1 then
			setTranslation(self.autoLoadObjects[self.state].index, x, y + self.unloadHeightOffset, z)
			setRotation(self.autoLoadObjects[self.state].index, rx, ry, rz)
		else
			setTranslation(self.autoLoadObjects[self.state].index, unpack(self.markerPositions[self.centerMarkerIndex].translation))
			setRotation(self.autoLoadObjects[self.state].index, 0, 0, 0)
		end
		for _, placeholder in pairs(self.autoLoadObjects[self.state].objects) do
			if placeholder.objectId ~= nil then
				local object = NetworkUtil.getObject(placeholder.objectId)
				if object ~= nil then
					if object:isa(Vehicle) then
						object.synchronizePosition = true
					end
					object:unmount()
				end
				placeholder.objectId = nil
			end
		end
        self.currentNumObjects = var
		self:setMarkerVisibility(bool)
		self:setMarkerPosition(unpack(self.markerPositions[self.centerMarkerIndex].translation))
		self:setUnloadPosition(self.centerMarkerIndex)
		setTranslation(self.autoLoadObjects[self.state].index, unpack(self.markerPositions[self.centerMarkerIndex].translation))
		setRotation(self.autoLoadObjects[self.state].index, 0, 0, 0)
		if self.triggerHelperModeEnabled then
			self:triggerHelperMode()
		end
		self.currentObjectId = var
	elseif mode == 3 then
        self.state = state
	elseif mode == 4 then
        self.workMode = bool
		if self.moveTrigger then
			self:playAnimation(self.moveTrigger, self.workMode and 1 or -1, nil, true)
		end
	end
	self.palletIcon = palletIcon
	self.squareBaleIcon = squareBaleIcon
	self.roundBaleIcon = roundBaleIcon
end

function easyAutoLoader:objectCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if onEnter and self.workMode then
		local object = g_currentMission:getNodeObject(otherId)
		if object == nil or object.mountObject ~= nil then
			return
		end
		local objectId = NetworkUtil.getObjectId(object)
		if objectId == self.currentObjectId then
			return
		end
		local isPallet = object:isa(Vehicle)
		local isRoundbale = false
		local isHDbale = false
		local isNotExcluded = false
		if object:isa(Bale) then
			isRoundbale = self.autoLoadObjects[self.state].isRoundBale and Utils.getNoNil(getUserAttribute(object.nodeId, "isRoundbale"), false)
			isHDbale = self.autoLoadObjects[self.state].isHDbale and Utils.getNoNil(getUserAttribute(object.nodeId, "isHDbale"), false)
			if isRoundbale and self.autoLoadObjects[self.state].diameter == string.format("%1.2f", object.baleDiameter) then
				isNotExcluded = true
			elseif isHDbale and self.autoLoadObjects[self.state].isHDbale then
				isNotExcluded = true
			elseif object.baleLength ~= nil and object.baleWidth ~= nil then
				isNotExcluded = self.autoLoadObjects[self.state].length == string.format("%1.2f", object.baleLength) and self.autoLoadObjects[self.state].width == string.format("%1.2f", object.baleWidth)
			end
		elseif isPallet then
			local objectFillType = object:getFillUnitFillType(1)
			if objectFillType == g_fillTypeManager:getFillTypeIndexByName("potato") and object:getFillUnitFillLevelPercentage(1) < 1 then
				return
			end
			if self.autoLoadObjects[self.state].includedFillTypes then
				for _, includedFillType in pairs(self.autoLoadObjects[self.state].includedFillTypes) do
					if objectFillType == g_fillTypeManager:getFillTypeIndexByName(includedFillType) then
						isNotExcluded = true
						break
					end
				end
			end
			if self.autoLoadObjects[self.state].usePalletSize then
				if string.format("%1.2f", object.sizeWidth) == self.autoLoadObjects[self.state].sizeWidth and string.format("%1.2f", object.sizeLength) == self.autoLoadObjects[self.state].sizeLength then
					isNotExcluded = true
				else
					isNotExcluded = false
				end
				if not isNotExcluded and self.autoLoadObjects[self.state].secondaryPalletSize then
					if string.format("%1.2f", object.sizeWidth) == self.autoLoadObjects[self.state].secondarySizeWidth and string.format("%1.2f", object.sizeLength) == self.autoLoadObjects[self.state].secondarySizeLength then
						isNotExcluded = true
					else
						isNotExcluded = false
					end
				end
			end
			if self.autoLoadObjects[self.state].excludedFillTypes and isNotExcluded then
				for _, excludedFillType in pairs(self.autoLoadObjects[self.state].excludedFillTypes) do
					if objectFillType == g_fillTypeManager:getFillTypeIndexByName(excludedFillType) then
						isNotExcluded = false
						break
					else
						isNotExcluded = true
					end
				end
			end
		elseif object.mission ~= nil and self.autoLoadObjects[self.state].isMissionPallet then
			isNotExcluded = true
			isPallet = true
		end
		if isNotExcluded then
			local palletIcon = isPallet
			local squareBaleIcon = not isRoundbale and not isPallet
			local roundBaleIcon = isRoundbale
			self:doStateChange(1, false, self.state, objectId, palletIcon, squareBaleIcon, roundBaleIcon, false)
			if self.currentNumObjects == self.autoLoadObjects[self.state].maxNumObjects then
				self:doStateChange(4, false, 0, 0, palletIcon, squareBaleIcon, roundBaleIcon, false)
			end
		end
	end
end

function easyAutoLoader:setMarkerVisibility(markervisibility, noEventSend)
	if markervisibility ~= self.markerVisible then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(SetMarkerVisibilityEvent:new(self, markervisibility), nil, nil, self)
            else
                g_client:getServerConnection():sendEvent(SetMarkerVisibilityEvent:new(self, markervisibility))
            end
        end
        self.markerVisible = markervisibility
        setVisibility(self.unloadMarker, markervisibility)
    end
end

function easyAutoLoader:setUnloadPosition(unloadPosition, noEventSend)
	if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetUnloadPositionEvent:new(self, unloadPosition), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(SetUnloadPositionEvent:new(self, unloadPosition))
        end
    end
	self.unloadPosition = unloadPosition
end

function easyAutoLoader:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	if self.isClient then
		if self.easyAutoLoaderActionEvents == nil then
			self.easyAutoLoaderActionEvents = {}
		else
			self:clearActionEventsTable(self.easyAutoLoaderActionEvents)
		end
		if isSelected then
			for actionId, entry in pairs(self.easyAutoLoaderRegistrationList) do
				eventAdded, entry.eventId = self:addActionEvent(self.easyAutoLoaderActionEvents, actionId, self, entry.callback, entry.triggerUp, entry.triggerDown, entry.triggerAlways, entry.startActive, nil)
				if eventAdded then
					if actionId == InputAction.workMode then
						g_inputBinding:setActionEventTextPriority(entry.eventId, GS_PRIO_VERY_HIGH)
					elseif actionId == InputAction.select or actionId == InputAction.unload or actionId == InputAction.markerRotation then
						g_inputBinding:setActionEventTextPriority(entry.eventId, GS_PRIO_HIGH)
					else
						g_inputBinding:setActionEventTextPriority(entry.eventId, GS_PRIO_NORMAL)
					end
				end
			end
		end
	end
end

function easyAutoLoader:setWorkMode()
	if self.currentNumObjects ~= self.autoLoadObjects[self.state].maxNumObjects then
		self:setMarkerVisibility(false)
		self:setUnloadPosition(self.centerMarkerIndex)
		self:doStateChange(4, not self.workMode, 0, 0, self.palletIcon, self.squareBaleIcon, self.roundBaleIcon, false)
		if self.triggerHelperModeEnabled then
			self:triggerHelperMode()
		end
	end
end

function easyAutoLoader:setSelect()
	self.state = self.state + 1
	if self.state > #self.autoLoadObjects then
		self.state = 1
	end
	self:doStateChange(3, false, self.state, 0, self.palletIcon, self.squareBaleIcon, self.roundBaleIcon, false)
end

function easyAutoLoader:changeMarkerPosition()
	local unloadPosition = self.unloadPosition + 1
	if unloadPosition > #self.markerPositions then
		unloadPosition = 1
	end
	self:setUnloadPosition(unloadPosition)
	self:setMarkerVisibility(unloadPosition > 1)
	self:setMarkerPosition(unpack(self.markerPositions[unloadPosition].translation))
	if self.triggerHelperModeEnabled then
		self:triggerHelperMode()
	end
end

function easyAutoLoader:setUnload()
	self:doStateChange(2, false, self.unloadPosition, 0, false, false, false, false)
end

function easyAutoLoader:setMarkerPosition(markerX, markerY, markerZ, noEventSend)
	if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetMarkerMoveEvent:new(self, markerX, markerY, markerZ), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(SetMarkerMoveEvent:new(self, markerX, markerY, markerZ))
        end
    end
	setTranslation(self.unloadMarker, markerX, markerY, markerZ)
end

function easyAutoLoader:moveMarkerLeft()
	local x, y, z = getTranslation(self.unloadMarker)
	x = MathUtil.clamp(x + self.markerMoveSpeed, self.markerMinX[self.unloadPosition], self.markerMaxX[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerRight()
	local x, y, z = getTranslation(self.unloadMarker)
	x = MathUtil.clamp(x - self.markerMoveSpeed, self.markerMinX[self.unloadPosition], self.markerMaxX[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerUp()
	local x, y, z = getTranslation(self.unloadMarker)
	y = MathUtil.clamp(y + self.markerMoveSpeed, self.markerMinY[self.unloadPosition], self.markerMaxY[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerDown()
	local x, y, z = getTranslation(self.unloadMarker)
	y = MathUtil.clamp(y - self.markerMoveSpeed, self.markerMinY[self.unloadPosition], self.markerMaxY[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerForward()
	local x, y, z = getTranslation(self.unloadMarker)
	z = MathUtil.clamp(z + self.markerMoveSpeed, self.markerMinZ[self.unloadPosition], self.markerMaxZ[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerBackward()
	local x, y, z = getTranslation(self.unloadMarker)
	z = MathUtil.clamp(z - self.markerMoveSpeed, self.markerMinZ[self.unloadPosition], self.markerMaxZ[self.unloadPosition])
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:moveMarkerOriginal()
	x, y, z = unpack(self.markerPositions[self.unloadPosition].translation)
	self:setMarkerPosition(x, y, z)
	if self.triggerHelperModeEnabled then
		self:triggerHelperMode()
	end
end

function easyAutoLoader:saveToXMLFile(xmlFile, key)
	setXMLInt(xmlFile, key.."#objectMode", Utils.getNoNil(self.state, 1))
	if self.currentNumObjects > 0 then
		self:setUnload()
	end
end

function easyAutoLoader:isDedicatedServer()
	if g_server ~= nil and g_client ~= nil and g_dedicatedServerInfo ~= nil then
		return true
	end
	return
end

function easyAutoLoader:triggerHelperMode()
	self.triggerHelperModeEnabled = not self.triggerHelperModeEnabled
	local x, y, z = getTranslation(self.unloadMarker)
	local rx, ry, rz = getRotation(self.unloadMarker)
	if self.triggerHelperModeEnabled then
		y =  self.unloaderMarkerYoffset + y
		rx = math.rad(90)
	else
		_, y, _ = unpack(self.markerPositions[self.unloadPosition].translation)
		rx = 0
	end
	self:setMarkerRotation(rx, ry, rz)
	self:setMarkerPosition(x, y, z)
end

function easyAutoLoader:setMarkerRotation(markerRX, markerRY, markerRZ, noEventSend)
	if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetMarkerRotationEvent:new(self, markerRX, markerRY, markerRZ), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(SetMarkerRotationEvent:new(self, markerRX, markerRY, markerRZ))
        end
    end
	setRotation(self.unloadMarker, markerRX, markerRY, markerRZ)
end

easyAutoLoaderEvent = {}
easyAutoLoaderEvent_mt = Class(easyAutoLoaderEvent, Event)
InitEventClass(easyAutoLoaderEvent, "easyAutoLoaderEvent")

function easyAutoLoaderEvent:emptyNew()
	local self = Event:new(easyAutoLoaderEvent_mt)
    self.className = "easyAutoLoaderEvent"
    return self
end

function easyAutoLoaderEvent:new(vehicle, mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon)
    local self = easyAutoLoaderEvent:emptyNew()
    self.vehicle = vehicle
    self.mode = mode
    self.bool = bool
    self.stateNum = state
    self.var = var
    self.palletIcon = palletIcon
    self.squareBaleIcon = squareBaleIcon
    self.roundBaleIcon = roundBaleIcon
    return self
end

function easyAutoLoaderEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUInt8(streamId)
    self.bool = streamReadBool(streamId)
    self.stateNum = streamReadUInt8(streamId)
	self.var = NetworkUtil.readNodeObjectId(streamId)
    self.palletIcon = streamReadBool(streamId)
    self.squareBaleIcon = streamReadBool(streamId)
    self.roundBaleIcon = streamReadBool(streamId)
    self:run(connection)
end

function easyAutoLoaderEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUInt8(streamId, self.mode)
    streamWriteBool(streamId, self.bool)
    streamWriteUInt8(streamId, self.stateNum)
	NetworkUtil.writeNodeObjectId(streamId, self.var)
    streamWriteBool(streamId, self.palletIcon)
    streamWriteBool(streamId, self.squareBaleIcon)
    streamWriteBool(streamId, self.roundBaleIcon)
end

function easyAutoLoaderEvent:run(connection)  
    self.vehicle:doStateChange(self.mode, self.bool, self.stateNum, self.var, self.palletIcon, self.squareBaleIcon, self.roundBaleIcon, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(easyAutoLoaderEvent:new(self.vehicle, self.mode, self.bool, self.stateNum, self.var, self.palletIcon, self.squareBaleIcon, self.roundBaleIcon), nil, connection, self.vehicle)
    end
end

function easyAutoLoaderEvent.sendEvent(vehicle, mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(easyAutoLoaderEvent:new(vehicle, mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(easyAutoLoaderEvent:new(vehicle, mode, bool, state, var, palletIcon, squareBaleIcon, roundBaleIcon))
        end
    end
end

SetMarkerVisibilityEvent = {}
SetMarkerVisibilityEvent_mt = Class(SetMarkerVisibilityEvent, Event)
InitEventClass(SetMarkerVisibilityEvent, "SetMarkerVisibilityEvent")

function SetMarkerVisibilityEvent:emptyNew()
    local self = Event:new(SetMarkerVisibilityEvent_mt)
    self.className="SetMarkerVisibilityEvent"
    return self
end

function SetMarkerVisibilityEvent:new(markerObject, active)
    local self = SetMarkerVisibilityEvent:emptyNew()
    self.markerObject = markerObject
	self.markerActive = active
    return self
end

function SetMarkerVisibilityEvent:readStream(streamId, connection)
	self.markerObject = NetworkUtil.readNodeObject(streamId)
    self.markerActive = streamReadBool(streamId)
    self:run(connection)
 end

function SetMarkerVisibilityEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.markerObject)
    streamWriteBool(streamId, self.markerActive)
end

function SetMarkerVisibilityEvent:run(connection)
    self.markerObject:setMarkerVisibility(self.markerActive, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SetMarkerVisibilityEvent:new(self.markerObject, self.markerActive), nil, connection, self.markerObject)
    end
end

SetUnloadPositionEvent = {}
SetUnloadPositionEvent_mt = Class(SetUnloadPositionEvent, Event)
InitEventClass(SetUnloadPositionEvent, "SetUnloadPositionEvent")

function SetUnloadPositionEvent:emptyNew()
    local self = Event:new(SetUnloadPositionEvent_mt)
    self.className="SetUnloadPositionEvent"
    return self
end

function SetUnloadPositionEvent:new(object, unloadPosition)
    local self = SetUnloadPositionEvent:emptyNew()
    self.object = object
	self.unloadPosition = unloadPosition
    return self
end

function SetUnloadPositionEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.unloadPosition = streamReadInt8(streamId)
    self:run(connection)
 end

function SetUnloadPositionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt8(streamId, self.unloadPosition)
end

function SetUnloadPositionEvent:run(connection)
    self.object:setUnloadPosition(self.unloadPosition, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SetUnloadPositionEvent:new(self.object, self.unloadPosition), nil, connection, self.object)
    end
end

SetMarkerMoveEvent = {}
SetMarkerMoveEvent_mt = Class(SetMarkerMoveEvent, Event)
InitEventClass(SetMarkerMoveEvent, "SetMarkerMoveEvent")

function SetMarkerMoveEvent:emptyNew()
    local self = Event:new(SetMarkerMoveEvent_mt)
    self.className="SetMarkerMoveEvent"
    return self
end

function SetMarkerMoveEvent:new(object, markerX, markerY, markerZ)
    local self = SetMarkerMoveEvent:emptyNew()
    self.object = object
	self.markerX = markerX
	self.markerY = markerY
	self.markerZ = markerZ
    return self
end

function SetMarkerMoveEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
    self.markerX = streamReadFloat32(streamId)
	self.markerY = streamReadFloat32(streamId)
	self.markerZ = streamReadFloat32(streamId)
    self:run(connection)
 end

function SetMarkerMoveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteFloat32(streamId, self.markerX)
	streamWriteFloat32(streamId, self.markerY)
	streamWriteFloat32(streamId, self.markerZ)
end

function SetMarkerMoveEvent:run(connection)
	self.object:setMarkerPosition(self.markerX, self.markerY, self.markerZ, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SetMarkerMoveEvent:new(self.object, self.markerX, self.markerY, self.markerZ), nil, connection, self.object)
    end
end

SetMarkerRotationEvent = {}
SetMarkerRotationEvent_mt = Class(SetMarkerRotationEvent, Event)
InitEventClass(SetMarkerRotationEvent, "SetMarkerRotationEvent")

function SetMarkerRotationEvent:emptyNew()
    local self = Event:new(SetMarkerRotationEvent_mt)
    self.className="SetMarkerRoationEvent"
    return self
end

function SetMarkerRotationEvent:new(object, markerX, markerY, markerZ)
    local self = SetMarkerRotationEvent:emptyNew()
    self.object = object
	self.markerRX = markerRX
	self.markerRY = markerRY
	self.markerRZ = markerRZ
    return self
end

function SetMarkerRotationEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
    self.markerRX = streamReadFloat32(streamId)
	self.markerRY = streamReadFloat32(streamId)
	self.markerRZ = streamReadFloat32(streamId)
    self:run(connection)
 end

function SetMarkerRotationEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteFloat32(streamId, self.markerRX)
	streamWriteFloat32(streamId, self.markerRY)
	streamWriteFloat32(streamId, self.markerRZ)
end

function SetMarkerRotationEvent:run(connection)
	self.object:setMarkerRotation(self.markerRX, self.markerRY, self.markerRZ, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SetMarkerRotationEvent:new(self.object, self.markerRX, self.markerRY, self.markerRZ), nil, connection, self.object)
    end
end