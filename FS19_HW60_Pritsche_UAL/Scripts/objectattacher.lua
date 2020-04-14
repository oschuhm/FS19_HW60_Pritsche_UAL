--
-- objectAttacher
-- Specialization for attaching objects on a trailer
--
-- @author Geri-G
--
-- edited by PeterJ FS-UK modteam
-- 16/11/2012
--

objectAttacher = {};

function objectAttacher.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Attachable, specializations);
end;

function objectAttacher:load(savegame)

    self.setIsBaleAttached = SpecializationUtil.callSpecializationsFunction("setIsBaleAttached");
    self.searchObjects = objectAttacher.searchObjects;
    self.attachobjects = objectAttacher.attachobjects;
    self.detachobjects = objectAttacher.detachobjects;
    self.OrientJoint = objectAttacher.OrientJoint;
    self.isObjectInRange = objectAttacher.isObjectInRange;
    self.place = {};
    local i=0;
    while true do
        local basename = string.format("vehicle.baleCastPoints.baleCastPoint(%d)",i);
        local place = {};
        place.node1 = Utils.indexToObject(self.components, getXMLString(xmlFile,basename.."#frontRight"));

        if place.node1 == nil then
            break;
        end;
        place.node2 = Utils.indexToObject(self.components, getXMLString(xmlFile,basename.."#backLeft"));
        place.attacherNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(xmlFile,basename.."#attacherNode"),"0>"));
        place.highOffset = Utils.getNoNil(getXMLFloat(xmlFile,basename.."#highOffset"),4);
        table.insert(self.place,place);
        i=i+1;
    end;
    self.allowVehicleAttachment = getXMLBool(xmlFile,"vehicle.baleCastPoints#allowVehicleAttachment");
    self.Attachedobjects = {};
    self.objectsAttached = false;
    self.isBaleAttach = false;    
end;

function objectAttacher:delete()
end;

function objectAttacher:readStream(streamId, connection)
    local baleAttach = streamReadBool(streamId);
    self:setIsBaleAttached(baleAttach, true);            
end;

function objectAttacher:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isBaleAttach);
end;

function objectAttacher:keyEvent(unicode, sym, modifier, isDown)
end;

function objectAttacher:mouseEvent(posX, posY, isDown, isUp, button)
end;

function objectAttacher:update(dt)
    if self:getIsActiveForInput() then
        if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA3) then
            self:setIsBaleAttached(not self.isBaleAttach);
        end;
    end;
end;

function objectAttacher:updateTick(dt)
end;

function objectAttacher:draw()
    if self:getIsActive() then
        if not self.isBaleAttach then
            g_currentMission:addHelpButtonText(g_i18n:getText("Unlock"), InputBinding.IMPLEMENT_EXTRA3);
        else
            g_currentMission:addHelpButtonText(g_i18n:getText("Lock"), InputBinding.IMPLEMENT_EXTRA3);
        end;
    end;
end;

function objectAttacher:isObjectInRange(place,object)
    local Xmax, Ymax, Zmax = getWorldTranslation(place.node1);
          Xmax, Ymax, Zmax = worldToLocal(place.attacherNode,Xmax, Ymax, Zmax);
          
    local Xmin, Ymin, Zmin = getWorldTranslation(place.node2);    
          Xmin, Ymin, Zmin = worldToLocal(place.attacherNode,Xmin, Ymin, Zmin);
    
    local Xt, Yt, Zt = getWorldTranslation(object);
          Xt, Yt, Zt = worldToLocal(place.attacherNode,Xt, Yt, Zt);
        
    if (Xt < math.max(Xmax,Xmin) and Xt > math.min(Xmax,Xmin)) and (Zt < math.max(Zmax,Zmin) and Zt > math.min(Zmax,Zmin)) and (Yt<= ((Ymax+Ymin)/2)+place.highOffset and Yt>= (Ymax+Ymin)/2) then
        return true;
    else
        return false;
    end;
end;

function objectAttacher:searchObjects()
    for index,item in pairs(g_currentMission.itemsToSave) do
        if item.item:isa(Bale) then 
            if item.item.isAttached == nil then--and (getUserAttribute(item.item.nodeId, "isHaybale") == true or getUserAttribute(item.item.nodeId, "isStrawbale") == true or getUserAttribute(item.item.nodeId, "isRoundbale") == true) then
                for k,v in pairs(self.place) do
                    local isInRange = self:isObjectInRange(v,item.item.nodeId);            
                    local is1stAttached = false;
                    if isInRange then
                        is1stAttached = self:attachobjects(v,item.item.nodeId,item.item);
                    end;
                    if is1stAttached then
                        self.objectsAttached = true;
                    end;
                end;
            end;
        end;
    end;
    if self.allowVehicleAttachment == true then
        for k,v in pairs(g_currentMission.vehicles) do
            if v ~= self and v ~= self.attacherVehicle then
                local is1stAttached = false;
                for index,components in pairs(v.components) do        
                    for k1,v1 in pairs(self.place) do
                        local isInRange = self:isObjectInRange(v1,components.node);    
                        if isInRange then    
                            is1stAttached = self:attachobjects(v1,components.node);
                        end;
                    end;
                end;
                if is1stAttached then
                    self.objectsAttached = true;
                end;
            end;
        end;
    end;
end;

function objectAttacher:setIsBaleAttached(baleAttach, noEventSend)
    SetBaleAttachEvent.sendEvent(self, baleAttach, noEventSend)
    self.isBaleAttach = baleAttach;
    
    if baleAttach then
        self:detachobjects();    
    else
        self:searchObjects();
    end;
end;

function objectAttacher:OrientJoint(Source, Target)    
    local xw, yw, zw = getWorldTranslation(Source);        
    local x,y,z = worldToLocal(getParent(Target), xw, yw, zw);    
    setTranslation(Target, x,y,z);            
    
    local zX, zY, zZ = localDirectionToWorld(Source, 0,0,1);
    local zX, zY, zZ = worldDirectionToLocal(getParent(Target), zX, zY, zZ);
    local yX, yY, yZ = localDirectionToWorld(Source, 0,1,0);
    local yX, yY, yZ = worldDirectionToLocal(getParent(Target), yX, yY, yZ);
    setDirection(Target, zX, zY, zZ, yX, yY, yZ);
    return false;
end;

function objectAttacher:attachobjects(place,object,baleT)
    local attachedobject = {};
    attachedobject.object = object;
    if self.isServer then
        attachedobject.AT = createTransformGroup("AT");
        link(place.attacherNode,attachedobject.AT);
        
        self:OrientJoint(object,attachedobject.AT);

        local constr = JointConstructor:new();                    
        constr:setActors(place.attacherNode, object);
        constr:setJointTransforms(attachedobject.AT,  object);
        for i=1, 3 do
            constr:setTranslationLimit(i-1, true, 0, 0);
            constr:setRotationLimit(i-1,0,0);
        end;
        attachedobject.JointIndex = constr:finalize();
        
        if baleT ~= nil then
            attachedobject.baleT = baleT;
            baleT.isAttached = true;
        end;
    end;

    table.insert(self.Attachedobjects, attachedobject);
    return true;
end;

function objectAttacher:detachobjects()
    if self.isServer then
        for k,v in pairs(self.Attachedobjects) do
            removeJoint(v.JointIndex);
            delete(v.AT);
            v.JointIndex = nil;
            if v.baleT ~= nil then
                v.baleT.isAttached = nil;
            end;
        end;
    end;
    
    self.Attachedobjects = nil;
    self.Attachedobjects = {};
    self.objectsAttached = false;
end;

function objectAttacher:onAttach(attacherVehicle)
    if self.isServer then
        self:setIsBaleAttached(false);
    end;
end;

function objectAttacher:onDetach()
    if self.isServer then
        self:setIsBaleAttached(true);
    end;
end;



SetBaleAttachEvent = {};
SetBaleAttachEvent_mt = Class(SetBaleAttachEvent, Event);
  
InitEventClass(SetBaleAttachEvent, "SetBaleAttachEvent");
  
function SetBaleAttachEvent:emptyNew()
     local self = Event:new(SetBaleAttachEvent_mt);
      self.className="SetBaleAttachEvent";
      return self;
end;
  
function SetBaleAttachEvent:new(object, baleAttach)
      local self = SetBaleAttachEvent:emptyNew()
      self.object = object;
      self.baleAttach = baleAttach;
      return self;
end;
  
function SetBaleAttachEvent:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.baleAttach = streamReadBool(streamId);
      self.object = networkGetObject(id);
      self:run(connection);
end;
  
function SetBaleAttachEvent:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
      streamWriteBool(streamId, self.baleAttach);
end;
  
function SetBaleAttachEvent:run(connection)
      if not connection:getIsServer() then
         g_server:broadcastEvent(self, false, connection, self.object);
      end;
      self.object:setIsBaleAttached(self.baleAttach, true);
end;
  
function SetBaleAttachEvent.sendEvent(vehicle, baleAttach, noEventSend)
      if baleAttach ~= vehicle.isBaleAttach then
          if noEventSend == nil or noEventSend == false then
              if g_server ~= nil then
                  g_server:broadcastEvent(SetBaleAttachEvent:new(vehicle, baleAttach), nil, nil, vehicle);
              else
                  g_client:getServerConnection():sendEvent(SetBaleAttachEvent:new(vehicle, baleAttach));
              end;
          end;
      end;
end;

