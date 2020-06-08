PickupAndDeliverMode = ADInheritsFrom(AbstractMode)

PickupAndDeliverMode.STATE_INIT = 1
PickupAndDeliverMode.STATE_PICKUP = 2
PickupAndDeliverMode.STATE_DELIVER = 3
PickupAndDeliverMode.STATE_RETURN_TO_START = 4
PickupAndDeliverMode.STATE_FINISHED = 5
PickupAndDeliverMode.STATE_EXIT_FIELD = 6
PickupAndDeliverMode.STATE_DELIVER_TO_NEXT_TARGET = 7
PickupAndDeliverMode.STATE_PICKUP_FROM_NEXT_TARGET = 8

function PickupAndDeliverMode:new(vehicle)
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:new")
    local o = PickupAndDeliverMode:create()
    o.vehicle = vehicle
    PickupAndDeliverMode.reset(o)
    return o
end

function PickupAndDeliverMode:reset()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:reset set STATE_INIT")
    self.state = PickupAndDeliverMode.STATE_INIT
    self.loopsDone = 0
    self.activeTask = nil
end

function PickupAndDeliverMode:start()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:start start self.state %s", tostring(self.state))

    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:start end self.state %s", tostring(self.state))
end

function PickupAndDeliverMode:monitorTasks(dt)
end

function PickupAndDeliverMode:handleFinishedTask()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode: handleFinishedTask")
    self.vehicle.ad.trailerModule:reset()
    self.activeTask = self:getNextTask(true)
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function PickupAndDeliverMode:stop()
end

function PickupAndDeliverMode:continue()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:continue")
    if self.activeTask ~= nil and self.state == PickupAndDeliverMode.STATE_DELIVER or self.state == PickupAndDeliverMode.STATE_PICKUP or self.state == PickupAndDeliverMode.STATE_EXIT_FIELD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:continue activeTask:continue")
        -- self.activeTask:continue()
        if self.activeTask ~= nil then
            self.vehicle.ad.taskModule:abortCurrentTask()
        end
        self.activeTask = self:getNextTask(true)
        if self.activeTask ~= nil then
            self.vehicle.ad.taskModule:addTask(self.activeTask)
        end
    end
end

function PickupAndDeliverMode:getNextTask(forced)
    local nextTask
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask start forced %s self.state %s", tostring(forced), tostring(self.state))

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local point = nil
    local distanceToStart = 0
    if self.vehicle.ad ~= nil and ADGraphManager.getWayPointById ~= nil and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule.getFirstMarker ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= 0 and self.vehicle.ad.stateModule:getFirstMarker().id ~= nil then
        point = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstMarker().id)
        if point ~= nil then
            distanceToStart = MathUtil.vector2Length(x - point.x, z - point.z)
        end
    end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

    local setPickupTarget = function()
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setPickupTarget start %s", tostring(self.vehicle))
        if AutoDrive.getSetting("pickupFromFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
            -- multiple targets to handle
            -- get the next target to pickup from
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setPickupTarget -> getNextTarget")
            local nextTarget = ADMultipleTargetsManager:getNextPickup(self.vehicle, forced)
            if nextTarget ~= nil then
                self.vehicle.ad.stateModule:setFirstMarker(nextTarget)
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setPickupTarget setFirstMarker -> nextTarget getFirstMarkerName() %s", tostring(self.vehicle.ad.stateModule:getFirstMarkerName()))
            end
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setPickupTarget getFirstMarkerName() %s", tostring(self.vehicle.ad.stateModule:getFirstMarkerName()))
        end
    end

    local setDeliverTarget = function()
        if AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
            -- multiple targets to handle
            -- get the next target to deliver to
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setDeliverTarget -> getNextTarget")
            local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, forced)
            if nextTarget ~= nil then
                self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setDeliverTarget setSecondMarker -> nextTarget getSecondMarkerName() %s", tostring(self.vehicle.ad.stateModule:getSecondMarkerName()))
            end
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:setDeliverTarget getSecondMarkerName() %s", tostring(self.vehicle.ad.stateModule:getSecondMarkerName()))
        end
    end

    if self.state == PickupAndDeliverMode.STATE_INIT then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_INIT self.state %s distanceToStart %s", tostring(self.state), tostring(distanceToStart))
        if AutoDrive.checkIsOnField(x, y, z)  and distanceToStart > 30 then
            -- is activated on a field - use ExitFieldTask to leave field according to setting
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_EXIT_FIELD")
            self.state = PickupAndDeliverMode.STATE_EXIT_FIELD
        elseif filledToUnload then
            -- fill level above setting unload level
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_PICKUP")
            setDeliverTarget()
            self.state = PickupAndDeliverMode.STATE_PICKUP
        else
            -- fill capacity left - go to pickup
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_DELIVER")
            setPickupTarget()
            self.state = PickupAndDeliverMode.STATE_DELIVER
        end
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_INIT end self.state %s", tostring(self.state))
    end

    if self.state == PickupAndDeliverMode.STATE_PICKUP_FROM_NEXT_TARGET then
        -- STATE_PICKUP_FROM_NEXT_TARGET - load at multiple targets
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_PICKUP_FROM_NEXT_TARGET")
        setPickupTarget()
        -- by default - go to unload
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_PICKUP")
        self.state = PickupAndDeliverMode.STATE_PICKUP
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_PICKUP_FROM_NEXT_TARGET end")
    end

    if self.state == PickupAndDeliverMode.STATE_DELIVER_TO_NEXT_TARGET then
        -- STATE_DELIVER_TO_NEXT_TARGET - unload at multiple targets
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_DELIVER_TO_NEXT_TARGET")
        setDeliverTarget()
        if fillLevel > 1 and (AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders")) then
            -- if fill material left and multiple unload active - go to unload
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_PICKUP")
            self.state = PickupAndDeliverMode.STATE_PICKUP
        else
            -- no fill material - go to load
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_DELIVER")
            setPickupTarget()
            self.state = PickupAndDeliverMode.STATE_DELIVER
        end
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_DELIVER_TO_NEXT_TARGET end")
    end

    if self.state == PickupAndDeliverMode.STATE_DELIVER then
        -- STATE_DELIVER - drive to load destination
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_DELIVER self.loopsDone %s", tostring(self.loopsDone))
        if self.vehicle.ad.stateModule:getLoopCounter() == 0 or self.loopsDone < self.vehicle.ad.stateModule:getLoopCounter() or (AutoDrive.getSetting("pickupFromFolder", self.vehicle) and AutoDrive.getSetting("useFolders")) then
            -- until loops not finished or 0 - drive to load destination
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask LoadAtDestinationTask... getFirstMarkerName() %s", tostring(self.vehicle.ad.stateModule:getFirstMarkerName()))
            nextTask = LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_PICKUP_FROM_NEXT_TARGET")
            self.state = PickupAndDeliverMode.STATE_PICKUP_FROM_NEXT_TARGET
            self.loopsDone = self.loopsDone + 1
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask self.loopsDone %s", tostring(self.loopsDone))
        else
            -- if loops are finished - drive to load destination and stop AD
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask DriveToDestinationTask...")
            nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_RETURN_TO_START")
            self.state = PickupAndDeliverMode.STATE_RETURN_TO_START
        end
    elseif self.state == PickupAndDeliverMode.STATE_PICKUP then
        -- STATE_PICKUP - drive to unload destination
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_PICKUP UnloadAtDestinationTask... getSecondMarkerName() %s", tostring(self.vehicle.ad.stateModule:getSecondMarkerName()))
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        -- self.loopsDone = self.loopsDone + 1
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_DELIVER_TO_NEXT_TARGET")
        self.state = PickupAndDeliverMode.STATE_DELIVER_TO_NEXT_TARGET
    elseif self.state == PickupAndDeliverMode.STATE_EXIT_FIELD then
        -- is activated on a field - use ExitFieldTask to leave field according to setting
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_EXIT_FIELD ExitFieldTask...")
        nextTask = ExitFieldTask:new(self.vehicle)

        if filledToUnload then
            -- fill level above setting unload level - drive to unload destination
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_PICKUP")
            setDeliverTarget()
            self.state = PickupAndDeliverMode.STATE_PICKUP
        else
            -- fill capacity left - go to pickup
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask set STATE_DELIVER")
            self.state = PickupAndDeliverMode.STATE_DELIVER
        end
    elseif self.state == PickupAndDeliverMode.STATE_RETURN_TO_START then
        -- job done - stop AD and tasks
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask STATE_RETURN_TO_START StopAndDisableADTask...")
        nextTask = StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE)
        self.state = PickupAndDeliverMode.STATE_FINISHED
        AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_Driver_of; %s $l10n_AD_has_reached; %s", 5000, self.vehicle.ad.stateModule:getName(), self.vehicle.ad.stateModule:getFirstMarkerName())
    else
        -- error path - should never appear!
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask self.state %s NO nextTask assigned !!!", tostring(self.state))
        nextTask = StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE)
        self.state = PickupAndDeliverMode.STATE_FINISHED
        AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_has_reached; %s", 5000, self.vehicle.ad.stateModule:getName(), self.vehicle.ad.stateModule:getFirstMarkerName())
    end

    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:getNextTask end self.loopsDone %s self.state %s", tostring(self.loopsDone), tostring(self.state))
    return nextTask
end

function PickupAndDeliverMode:shouldUnloadAtTrigger()
    -- AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:shouldUnloadAtTrigger self.state %s ", tostring(self.state))
    return ((self.state == PickupAndDeliverMode.STATE_DELIVER) or (self.state == PickupAndDeliverMode.STATE_DELIVER_TO_NEXT_TARGET)) 
end

function PickupAndDeliverMode:shouldLoadOnTrigger()
    -- AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] PickupAndDeliverMode:shouldLoadOnTrigger self.state %s distance to target %s", tostring(self.state), tostring(AutoDrive.getDistanceToTargetPosition(self.vehicle)))
    return ((self.state == PickupAndDeliverMode.STATE_PICKUP) or (self.state == PickupAndDeliverMode.STATE_PICKUP_FROM_NEXT_TARGET)) and (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

