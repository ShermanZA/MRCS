-- MOOSE-BASED RANDOMISED CAS SCRIPT (MRCS)

-- This is a modified and simplified version the "TROOPSINCONTACT!" script
-- originally created by [BSD] FARGO OF BLACKSHARKDEN.

-- The idea of this modification
-- is to intergrate and expand the functionality of TROOPSINCONTACT! in a MOOSE based
-- setup allowing for a more dynamic selection of player flights, CAS zones, friend and
-- enemy unit templates for the CAS missions. In addition, the menu functionality now allows
-- for multiple missions to be undertaken by various groups and a check out function to  allow
-- players to despawn a CAS mission should they choose to.




do
  CAS = {
    ClassName             = "CAS",
    verbose               = 0,
    lid                   = "",
    coalition             = 1,
    coalitiontxt          = "blue",
    CasGroups             = {}, -- #GROUP_SET of heli pilots
    CasUnits              = {}, -- Table of helicopter #GROUPs
    spawnedFriendlyGroup  = {},
    spawnedEnemyGroup     = {},
    -- Define the list of CAS zones
    CZones                = {},
    CZoneSets             = {},
    smokecolor            = {},
	smokecolortype        = {},
    TICMessageShowTime    = 120,
    hit_check_interval    = 30,
    friendly_return_fire  = true,
    friendly_fire_time    = 50,

    -- Define the name prefix for the sub-zones
    subZoneNamePrefix     = "",

    -- Define the distance from friendlies for enemy group spawn
    enemySpawnDistance    = 1000, -- meters

    -- Define the CAS message
    casMessage            = "Friendly units have checked in at %s. Requesting close air support.",
    distance_marking_text = "NO MARK ON TARGET AT THIS TIME",

    offsetX               = 300,
    offsetZ               = 300,
    playerGroups          = {},
    --FRIENDLIES:
    friendliesTable       = {},
    friendliesSet         = {},
    baddiesTable          = {},
    baddiesSet            = {},
    Friendly              = {},
    Badgroup              = {},
    tracermark_groupname  = "none",
    FirePointVec2         = {},
	FirePointCoord		  = {},
    SpawnedFriendly       = {},
    OnStation             = {},
    casMenu,
    checkInmenu,
    checkOutMenu,
	NewSmokeMenu,
	RepeatBriefMenu,
	TracerMenu,
    FriendlyTemplates = {},
	lasercode = {},
  }

  CAS.version = "0.0.1"



  -- @param #CAS self
  -- @param #table CASGroupNames table of pilot prefixes
  -- @param #table ZoneNames Table of zone names.
  -- @param #table GGTemplates Table of good guy template names.
  -- @param #table BGTemplates Table of good bad template names.
  function CAS:New(CASGroupNames, ZoneNames, GGTemplates, BGTemplates)
    -- Inherit everything from FSM class.
    local self = BASE:Inherit(self, FSM:New())
    BASE:T({ CASGroupNames, ZoneNames, GGTemplates, BGTemplates })

    -- Start State.
    self:SetStartState("Stopped")

    -- Add FSM transitions.
    --                 From State  -->   Event        -->      To State
    self:AddTransition("Stopped", "Start", "Running") -- Start FSM.
    self:AddTransition("*", "Status", "*")            -- CAS status update.
    self:AddTransition("*", "Stop", "Stopped")        -- Stop FSM.
    self:AddTransition("*", "SetSpawnBehaviour", "*") -- Stop FSM.

    self.CasGroups = {}
    self.MenusDone = {}
    self.CasUnits = {}
    self.prefixes = CASGroupNames
    self.spawnedFriendlyGroup = {}
    self.spawnedEnemyGroup = {}
    self.CZoneTemplates = ZoneNames
    self.CZones = {}
    self.CZoneSets = SET_ZONE:New():AddZonesByName(self.CZoneTemplates)
    self.CZoneSets:ForEachZone(function(zn)
      if zn ~= nil then
        table.insert(self.CZones, zn:GetName())
      end
    end)
    self.smokecolor = ""
	self.smokecolortype = ""
    self.TICMessageShowTime = 120
    self.hit_check_interval = 30
    self.friendly_return_fire = true
    self.friendly_fire_time = 50
    self.subZoneNamePrefix = "SubZone"
    self.enemySpawnDistance = 1000
    self.casMessage = "Friendly units have checked in at %s. Requesting close air support."
    self.distance_marking_text = "NO MARK ON TARGET AT THIS TIME"

    self.offsetX = 300
    self.offsetZ = 300

    --FRIENDLIES:
    self.FriendlyTemplates = GGTemplates
    self.friendliesTable = {}
    self.friendliesSet = SET_GROUP:New():FilterCategoryGround():FilterCoalitions("blue"):FilterPrefixes(self
      .FriendlyTemplates):FilterOnce()
    self.friendliesSet:ForEachGroup(function(grp)
      table.insert(self.friendliesTable, grp:GetName())
    end)
    self.BadGuyTemplates = BGTemplates
    self.baddiesTable = {}
    self.baddiesSet = SET_GROUP:New():FilterCategoryGround():FilterCoalitions("red"):FilterPrefixes(self.BadGuyTemplates)
        :FilterOnce()
    self.baddiesSet:ForEachGroup(function(grp)
      table.insert(self.baddiesTable, grp:GetName())
    end)
    self.Friendly = SPAWN:NewWithAlias(self.FriendlyTemplates[1], "FRD-GRP"):InitHeading(0, 1):InitRandomizeTemplate(
      self.friendliesTable)
    self.Badgroup = SPAWN:NewWithAlias(self.BadGuyTemplates[1], 'NME-GRP'):InitHeading(0, 1):InitRandomizeTemplate(self
      .baddiesTable)

    self.tracermark_groupname = "none"
	self.FirePointCoord = {}
    self.FirePointVec2 = {}
    self.SpawnedFriendly = {}
    self.coalition = coalition.side.BLUE
    self.coalitiontxt = "blue"
    self.OnStation = {}
    self.playerGroups = SET_GROUP:New():AddGroupsByName(CASGroupNames)
	self.lasercode = {1688, 1776, 1113, 1772}

    ------------------------
    --- Pseudo Functions ---
    ------------------------

    --- Triggers the FSM event "Start". Starts the CAS. Initializes parameters and starts event handlers.
    -- @function [parent=#CAS] Start
    -- @param #CAS self

    --- Triggers the FSM event "Start" after a delay. Starts the CAS. Initializes parameters and starts event handlers.
    -- @function [parent=#CAS] __Start
    -- @param #CAS self
    -- @param #number delay Delay in seconds.

    --- Triggers the FSM event "Stop". Stops the CAS and all its event handlers.
    -- @param #CAS self

    --- Triggers the FSM event "Stop" after a delay. Stops the CAS and all its event handlers.
    -- @function [parent=#CAS] __Stop
    -- @param #CAS self
    -- @param #number delay Delay in seconds.

    --- Triggers the FSM event "Status".
    -- @function [parent=#CAS] Status
    -- @param #CAS self

    --- Triggers the FSM event "Status" after a delay.
    -- @function [parent=#CAS] __Status
    -- @param #CAS self
    -- @param #number delay Delay in seconds.

    --- FSM Function OnBeforeSetSpawnBehaviour.
    -- @function [parent=#CAS] OnBeforeSetSpawnBehaviour
    -- @param #CAS self
    -- @param #string From State.
    -- @param #string Event Trigger.
    -- @param #string To State.
    -- @param Wrapper.Group#GROUP sgrp Group Object.
    -- @param #string zoneName string.
    -- @param Wrapper.Group#GROUP selectedGroup selectedPlayerGroup.
    -- @return #CTLD self

    return self
  end

  -- Function to spawn a group at a specified sub-zone
  function CAS:_spawnGroupAtSubZone(zoneName, selectedGroup, detectedUnit)
    self:T(self.lid .. " _spawnGroupAtSubZone")
    self:F(zoneName, selectedGroup)

    local shoulderDir = ""
    local subZones = {}
    local zone = ZONE:FindByName(zoneName)
    local subZoneFilter = zoneName .. "-"
    local subZoneSet = SET_ZONE:New():FilterPrefixes(subZoneFilter):FilterOnce()
    subZoneSet:ForEachZone(function(z)
      if (zone:IsVec2InZone(z:GetVec2())) and zone:GetName() ~= z:GetName() then
        z:Scan({ Object.Category.UNIT }, { Unit.Category.GROUND_UNIT })
        if z:IsNoneInZone() == true then
          table.insert(subZones, z)
        end
      end
    end)

    self.Friendly:InitRandomizeZones(subZones)
    local badGroup = self.Badgroup
    self.Friendly:OnSpawnGroup(function(spawngroup)
      unit1 = spawngroup:GetUnit(1)
      local immcmd = { id = 'SetImmortal', params = { value = true } }
      spawngroup:_GetController():setCommand(immcmd)
      -- enemyGroup = spawnEnemyGroupNearFriendlies(unit1,enemySpawnDistance,detectedZoneName)
      Direction = "none"
      local enemySpawnPoint = self:_generateDirectionAndOffset(unit1, self.offsetX, self.offsetZ)

      self.Badgroup:OnSpawnGroup(
        function(sgrp)
          self:_SetSpawnBehaviour(sgrp, zoneName, selectedGroup, detectedUnit)
          return self
        end, self)

      local enemyGroup = badGroup:SpawnFromCoordinate(enemySpawnPoint)
      self.spawnedEnemyGroup[selectedGroup:GetName()] = enemyGroup
      --enemyGroup:OptionROEHoldFire(true)

      if self.friendly_return_fire == true then
        spawngroup:OptionAlarmStateGreen()
        self.FirePointCoord[selectedGroup:GetName()] = unit1:GetOffsetCoordinate(offset1, 0, offset2)
        self.FirePointVec2[selectedGroup:GetName()] = self.FirePointCoord[selectedGroup:GetName()]:GetVec2()
        local fireTask = spawngroup:TaskFireAtPoint(self.FirePointVec2[selectedGroup:GetName()], 1, nil, 3221225470, 8)
        local fireStop = spawngroup:TaskFunction("GroupHoldFire")
        function GroupHoldFire(grp)
          grp:OptionROEHoldFire(true)
          MESSAGE:New(".... YOU ARE CLEARED HOT!", self.TICMessageShowTime - self.friendly_fire_time, ""):ToGroup(
            selectedGroup)
          --if UseTICSounds == true then
          --soundplayCH = USERSOUND:New("clearedhot.ogg"):ToGroup(grp)
          --end
        end

        spawngroup:SetTask(fireTask, 1)
        spawngroup:SetTask(fireStop, self.friendly_fire_time)
        spawngroup:OptionAlarmStateGreen()
        spawngroup:OptionROT(ENUMS.ROT.NoReaction)

        self.distance_marking_text = "TARGET MARKED BY MY TRACER FIRE.."
      else
        self.distance_marking_text = "NO MARK ON TARGET AT THIS TIME"
      end


      --enemyGroup
      local friendlycoor = spawngroup:GetCoordinate()
      local friendlycoorstring = friendlycoor:ToStringMGRS(Settings)

      local enemycoor = enemyGroup:GetCoordinate()
      local enemycoorstring = enemycoor:ToStringMGRS(Settings)

      self:selectSmokeColour()
      spawngroup:Smoke(self.smokecolortype, 55, 1)

      if selectedGroup:IsAirPlane() then
        MESSAGE:New(selectedGroup:GetCallsign() .. ", JTAC, ... STAND BY FOR NINE LINE... ", self.TICMessageShowTime, "")
            :ToGroup(selectedGroup)
        MESSAGE:New("TYPE 3 CONTROL, BOMB ON TARGET. MISSILES FOLLOWED BY ROCKETS & GUNS.", self.TICMessageShowTime, "")
            :ToGroup(selectedGroup)
      else
        MESSAGE:New(selectedGroup:GetCallsign() .. ", JTAC, ... STAND BY FOR FIVE LINE... ", self.TICMessageShowTime, "")
            :ToGroup(selectedGroup)
      end
	  self:_RepeatBrief(selectedGroup)
      return self
    end)


    self.SpawnedFriendly = self.Friendly:Spawn()
    return self
  end

  function CAS:_SetSpawnBehaviour(sgrp, zoneName, selectedGroup, detectedUnit)
    self:T(self.lid .. " _SetSpawnBehaviour")
    CasSelf = self
    local zone = ZONE:FindByName(zoneName)
    local casgroups = self.CasGroups

    local immcmd = { id = 'SetImmortal', params = { value = true } }
    sgrp:_GetController():setCommand(immcmd)
    local mortalTask = sgrp:TaskFunction("GroupMortalAgain")
    function GroupMortalAgain(mortals)
      local immcmd = { id = 'SetImmortal', params = { value = false } }
      mortals:_GetController():setCommand(immcmd)
      --env.info("TICDEBUG: group is mortal again!")
    end

    sgrp:SetTask(mortalTask, self.friendly_fire_time)
    env.info("group mortal")

    CharlieMike = false
    samesameIniGroup = nil
    TICBaddieUnit1 = sgrp:GetUnit(1)
    _G[TICBaddieUnit1] = TICBaddieUnit1
    env.info("group retreat")
    TICBaddieGroupName = sgrp:GetName()
    TICBaddieUnit1Heading = sgrp:GetUnit(1):GetHeading()
    retreat_number = math.random(1, 100)
    env.info("TICDEBUG: retreat_number: " .. retreat_number)
    local TICBaddieZone = ZONE_GROUP:New(sgrp:GetName(), sgrp, 250)
    sgrp:HandleEvent(EVENTS.Hit)
    function sgrp:OnEventHit(EventData)
      local shooterCoalition = EventData.IniCoalition
      if shooterCoalition == 2 then
        --CasSelf:_RefreshF10Menus()
        local DeadScheduler = SCHEDULER:New(nil, function()
          env.info("TICDEBUG: hit_check_scheduler fires")

          TICBaddieZone:Scan({ Object.Category.UNIT }, { Unit.Category.GROUND_UNIT })
          if TICBaddieZone:CheckScannedCoalition(coalition.side.RED) == true then
            --MESSAGE:New("DEBUG 145 - Enemies still there!" ,15,""):ToAll()
            --env.info("TICDEBUG: red still in zone")
            -- GOOD EFFECTS ON TARGET!
            --retreat

            if EventData.IniGroup == samesameIniGroup or EventData.IniGroup:IsAir() ~= true then
              return
            else
              --if UseTICSounds == true then
              --hitsound = USERSOUND:New("goodeffectontarget2.ogg"):ToGroup(EventData.IniGroup,13)
              --end
              --casgroups:ForEachGroupPartlyInZone(zone,function (grp)
              casgroups:ForEachGroup(function(grp)
                if grp:IsPartlyOrCompletelyInZone(zone) == true then
                  MESSAGE:New("... From JTAC: good effect on target!", CasSelf.TICMessageShowTime, ""):ToGroup(
                    grp, 13)
                end
              end)

              samesameIniGroup = EventData.IniGroup
              --env.info("TICDEBUG: good effect sound played")
              return
            end
          else
            --env.info("TICDEBUG: red NOT in zone, weareCM2 coming :60")
            if CharlieMike == false then
              --  if UseTICSounds == true then
              --  TICgroupset:ForEachGroupCompletelyInZone(TICZoneObject,function (grp)
              --  local deadsound = USERSOUND:New("weareCM2.ogg"):ToGroup(grp) end)
              --end
              casgroups:ForEachGroup(function(grp)
                if grp:IsAlive() and grp:IsPartlyOrCompletelyInZone(zone) == true then
                  MESSAGE:New(
                    "Have secondaries in the target area. All enemies appear to be down. Thanks for the support, we are CM!",
                    15, ""):ToGroup(grp)
                end
              end)
              CharlieMike = true
              if CasSelf.spawnedFriendlyGroup[selectedGroup:GetName()]:IsAlive() then
                CasSelf.spawnedFriendlyGroup[selectedGroup:GetName()]:Destroy(nil, 30)
              end
              CasSelf.OnStation[selectedGroup:GetName()] = false
              CasSelf.MenusDone[detectedUnit:Name()] = false
              CasSelf:_RefreshF10Menus()
            end
          end
        end, {}, CasSelf.hit_check_interval)
      end
    end

    return CasSelf
  end

  function CAS:_OnStation(arg, _unit)
    self:T(self.lid .. " _OnStation")
    -- Check if the player is in a CAS zone
    local detectedZoneName
    local detectedUnit = _unit
    local detectedGroup = arg

    --for _, GroupName in pairs( playerGroupNames ) do
    --local group = GROUP:FindByName(GroupName)
    local casZoneList = {}

    -- Calculate distances and populate the casZoneList table
    for _, zoneName in ipairs(self.CZones) do
      local zone = ZONE:FindByName(zoneName)
      local distance = dist(zone:GetVec2(), _unit:GetVec2())
      casZoneList[zoneName] = distance
    end

    -- Create a sorted list of CZones based on the ascending distance
    local sortedCZones = {}
    for zoneName, _ in pairs(casZoneList) do
      table.insert(sortedCZones, zoneName)
    end
    table.sort(sortedCZones, function(zoneName1, zoneName2)
      return casZoneList[zoneName1] < casZoneList[zoneName2]
    end)

    for _, zoneName in ipairs(sortedCZones) do
      if self:_playerInCASZone(zoneName, detectedGroup) then
        inCASZone = true
        detectedZoneName = zoneName
        --detectedGroup = group
        --detectedUnit = UNIT:FindByName(detectedUnitName)
        break
      end
    end
    if not inCASZone then
      MESSAGE:New("You are outside of any CAS Zone. Enter a CAS zone and try again.", 15):ToGroup(detectedGroup)
      self.OnStation[detectedGroup:GetName()] = false
      self.MenusDone[detectedUnit:Name()] = false
      return
    else
      -- Spawn the friendly group at the specified sub-zone
      local friendlyGroup = self:_spawnGroupAtSubZone(detectedZoneName, detectedGroup, detectedUnit)
      self.spawnedFriendlyGroup[detectedGroup:GetName()] = self.SpawnedFriendly
      self.OnStation[detectedGroup:GetName()] = true
      self.MenusDone[detectedUnit:Name()] = false
      self:_RefreshF10Menus()
    end
    --break
    --end
    return self
  end

  function CAS:_OffStation(arg, reqUnit)
    self:T(self.lid .. " _OffStation")
    MESSAGE:New("Roger, confirm you are off-station.", 15):ToGroup(arg)
    arg.OnStation = false
    if self.spawnedFriendlyGroup[arg:GetName()]:IsAlive() then
		local FriendlyToDelete = self.spawnedFriendlyGroup[arg:GetName()]
		FriendlyToDelete:Destroy(nil, 30)
    end
    --rune spawnedFriendlyGroup and spawnedEnemyGroup into list
    if self.spawnedEnemyGroup[arg:GetName()]:IsAlive() then
		local EnemyToDelete = self.spawnedEnemyGroup[arg:GetName()]
		EnemyToDelete:Destroy(nil, 30)
    end
    self.OnStation[arg:GetName()] = false
    self.MenusDone[reqUnit:GetName()] = false
    self:_RefreshF10Menus()
    return self
  end

  function CAS:_EventHandler(EventData)
    self:T(string.format("%s Event = %d", self.lid, EventData.id))
    local event = EventData -- Core.Event#EVENTDATA	
    if event.id == EVENTS.PlayerEnterAircraft or event.id == EVENTS.PlayerEnterUnit then
      local _coalition = event.IniCoalition
      if _coalition ~= self.coalition then
        return --ignore!
      end
      -- check is Helicopter
      local _unit = event.IniUnit
      local _group = event.IniGroup
      if _group:IsHelicopter() or _group:IsAirPlane() then
        local unitname = event.IniUnitName or "none"
        --MESSAGE:New("Event Handler Refresh", 15):ToAll()
        --self.prefixes
        self:_RefreshF10Menus()
      end
      return
    elseif event.id == EVENTS.PlayerLeaveUnit then
      -- remove from pilot table
      local unitname = event.IniUnitName or "none"
      self.CasGroups[unitname] = nil
    end
    return self
  end

  function CAS:_RefreshF10Menus()
    self:T(self.lid .. " _RefreshF10Menus")
    local Players = CLIENT:GetPlayers()
    self.CasGroups = SET_GROUP:New():FilterCoalitions(self.coalitiontxt):FilterPrefixes(self.prefixes):FilterStart()
    local PlayerSet = self.CasGroups              -- Core.Set#SET_GROUP
    local PlayerTable = PlayerSet:GetSetObjects() -- #table of #GROUP objects
    -- rebuild units table
    local _UnitList = {}
    for _key, _group in pairs(PlayerTable) do
      local units = _group:GetUnits()
      for _, _unit in pairs(units) do
        local unit = CLIENT:FindByName(_unit:GetName())
        --MESSAGE:New(unit:GetName(), 15):ToAll()
        --local _unit = _group:GetUnit(1) -- Wrapper.Unit#UNIT Asume that there is only one unit in the flight for players
        if unit then
          -- if _unit:IsAlive() and _unit:IsPlayer() then
          if _group:IsPlayer() and _group:IsAlive() then
            if unit:IsHelicopter() or (unit:IsAirPlane()) then --ensure no stupid unit entries here
              local unitName = unit:GetName()
              _UnitList[unitName] = unitName
            end
          end -- end isAlive
        end   -- end if _unit
      end
    end       -- end for
    self.CasUnits = _UnitList

    -- subcats?


    -- build unit menus
    local menucount = 0
    local menus = {}
    for _, _unitName in pairs(self.CasUnits) do
      if not self.MenusDone[_unitName] then
        local _unit = CLIENT:FindByName(_unitName) -- Wrapper.Unit#UNIT
        if _unit then
          local _group = _unit:GetGroup()          -- Wrapper.Group#GROUP
          if _group then
            -- get chopper capabilities
            -- top menu
            casMenu = MENU_GROUP:New(_group, "CAS MENU", nil)
            local checkInmenu = MENU_GROUP_COMMAND:New(_group, "Check-In", casMenu, self._OnStation, self, _group, _unit)
                :Refresh()
            local checkOutMenu = MENU_GROUP_COMMAND:New(_group, "Check-Out", casMenu, self._OffStation, self, _group,
              _unit):Refresh()
			local NewSmokeMenu = MENU_GROUP_COMMAND:New(_group, "Deploy New Smoke", casMenu, self.NewSmoke, self, _group):Refresh()
			local RepeatBriefMenu = MENU_GROUP_COMMAND:New(_group, "Repeat CAS Brief", casMenu, self._RepeatBrief, self, _group):Refresh()
			local TracerMenu = MENU_GROUP_COMMAND:New(_group, "MARK W/ TRACER", casMenu, self._TracerMark, self, _group):Refresh()
			local LaserMenu = MENU_GROUP:New(_group, "MARK TGT W/LASER", casMenu):Refresh()
  
			for i=1,#self.lasercode do
				MENU_GROUP_COMMAND:New( _group,"CODE: " .. self.lasercode[i] ,LaserMenu,self.LaseTarget,self, _group, self.lasercode[i]):Refresh()
			end
			  
            -- sub menus
            -- sub menu troops management
            if self.OnStation[_group:GetName()] == true then
              checkInmenu:Remove()
            elseif self.OnStation[_group:GetName()] ~= true then
              checkOutMenu:Remove()
			  NewSmokeMenu:Remove()
			  RepeatBriefMenu:Remove()
			  TracerMenu:Remove()
			  LaserMenu:Remove()
            end
            local units = _group:GetUnits()
            for _, _unit in pairs(units) do
              self.MenusDone[_unit:Name()] = true
            end
          end -- end group
        end   -- end unit
      else    -- menu build check
        self:T(self.lid .. " Menus already done for this group!")
      end     -- end menu build check
    end       -- end for
    return self
  end

  function CAS:_generateDirectionAndOffset(unit1, offsetX, offsetZ)
    Direction_num = math.random(1, 8)
    offset1 = math.random(offsetX, offsetZ)
    offset2 = math.random(offsetX, offsetZ)

    if Direction_num == 1 then
      Direction = "NORTH"
      offset1 = math.random(offsetX, offsetZ)
      offset2 = 0
      direction_sound = "north.ogg"
    end
    if Direction_num == 2 then
      Direction = "NORTHEAST"
      offset1 = math.random(offsetX, offsetZ)
      offset2 = math.random(offsetX, offsetZ)
      direction_sound = "northeast.ogg"
    end
    if Direction_num == 3 then
      Direction = "EAST"
      offset1 = 0
      offset2 = math.random(offsetX, offsetZ)
      direction_sound = "east.ogg"
    end
    if Direction_num == 4 then
      Direction = "SOUTHEAST"
      offset1 = math.random(-offsetX, -offsetZ)
      offset2 = math.random(offsetX, offsetZ)
      direction_sound = "southeast.ogg"
    end
    if Direction_num == 5 then
      Direction = "SOUTH"
      offset1 = math.random(-offsetX, -offsetZ)
      offset2 = 0
      direction_sound = "south.ogg"
    end
    if Direction_num == 6 then
      Direction = "SOUTHWEST"
      offset1 = math.random(-offsetX, -offsetZ)
      offset2 = math.random(-offsetX, -offsetZ)
      direction_sound = "southwest.ogg"
    end
    if Direction_num == 7 then
      Direction = "WEST"
      offset1 = 0
      offset2 = math.random(-offsetX, -offsetZ)
      direction_sound = "west.ogg"
    end
    if Direction_num == 8 then
      Direction = "NORTHWEST"
      offset1 = math.random(offsetX, offsetZ)
      offset2 = math.random(-offsetX, -offsetZ)
    end
    local SpawnPoint = unit1:GetOffsetCoordinate(offset1, 0, offset2)
    return SpawnPoint
  end

  -- Function to check if the player's aircraft is in a zone with the specified name prefix
  function CAS:_playerInCASZone(zoneName, Unit)
    zone = ZONE:FindByName(zoneName)
    local compZone = trigger.misc.getZone(zoneName)
    local zoneRadius = compZone.radius -- radius IN METERS, NOT FEET!
    if (zoneRadius < 92600) then
      zoneRadius = 92600
    elseif (zoneRadius > 92600 and zoneRadius < 185200) then
      zoneRadius = 185200
    elseif (zoneRadius > 185200) then
      zoneRadius = zoneRadius
    end
    local inZone = false
    if Unit:IsAirPlane() then
      local jetZone = ZONE_RADIUS:New(zoneName, zone:GetVec2(), zoneRadius)
      inZone = Unit:IsInZone(jetZone)
    else
      inZone = Unit:IsInZone(zone)
    end
    return inZone
  end
  
  function CAS:NewSmoke(PlayerGroup)
	
	self:selectSmokeColour()
    self.spawnedFriendlyGroup[PlayerGroup:GetName()]:Smoke(self.smokecolortype, 55, 1)
	MESSAGE:New("REMARKING MY POSITION WITH  " .. self.smokecolor .. " SMOKE!", 15, ""):ToAll()
  end

  function CAS:selectSmokeColour()
	smokecolornum = math.random(1, 5)
      if smokecolornum == 1 then
        self.smokecolor = "GREEN"
        self.smokecolortype = SMOKECOLOR.Green
        --smoke_sound = "greensmoke.ogg"
      end
      if smokecolornum == 2 then
        self.smokecolor = "RED"
        self.smokecolortype = SMOKECOLOR.Red
        --smoke_sound = "redsmoke.ogg"
      end
      if smokecolornum == 3 then
        self.smokecolor = "WHITE"
        self.smokecolortype = SMOKECOLOR.White
        --smoke_sound = "whitesmoke.ogg"
      end
      if smokecolornum == 4 then
        self.smokecolor = "ORANGE"
        self.smokecolortype = SMOKECOLOR.Orange
        --smoke_sound = "orangesmoke.ogg"
      end
      if smokecolornum == 5 then
        self.smokecolor = "BLUE"
        self.smokecolortype = SMOKECOLOR.Blue
        --smoke_sound = "bluesmoke.ogg"
      end
  end
  
  function CAS:_RepeatBrief(selectedGroup)
	local NMEGRP = self.spawnedEnemyGroup[selectedGroup:GetName()]
	local friendlycoor = self.spawnedFriendlyGroup[selectedGroup:GetName()]:GetCoordinate()
    local friendlycoorstring = friendlycoor:ToStringMGRS(Settings)

    local enemycoor = NMEGRP:GetCoordinate()
    local enemycoorstring = enemycoor:ToStringMGRS(Settings)
	
	shouldernum = math.random(1, 2)
      if shouldernum == 1 then
        shoulderDir = "LEFT"
        shoulderSound = "leftshoulder.ogg"
      else
        shoulderDir = "RIGHT"
        shoulderSound = "rightshoulder.ogg"
      end
	
	if selectedGroup:IsAirPlane() then 
		MESSAGE:New("1. N/A.", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("2. N/A.", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("3. N/A.", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("4. " .. math.floor(NMEGRP:GetAltitude() * 3.28084) .. " Feet ASL", self.TICMessageShowTime, "")
            :ToGroup(selectedGroup)
        MESSAGE:New("5. ENEMY MECHANISED GROUP.", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("6. " .. enemycoorstring, self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("7. NO MARK", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("8. FROM THE " .. Direction .. " 300 to 500 METERS DANGER CLOSE!", self.TICMessageShowTime, "")
            :ToGroup(selectedGroup)
        MESSAGE:New(" MARKED BY " .. self.smokecolor .. " SMOKE!", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("9. EGRESS AT YOUR DISCRETION.", self.TICMessageShowTime, ""):ToGroup(selectedGroup)
	else
		MESSAGE:New("1. TYPE 2 CONTROL, BOMB ON TARGET. MISSILES FOLLOWED BY ROCKETS & GUNS.", self.TICMessageShowTime,
          ""):ToGroup(selectedGroup)
        MESSAGE:New("2. MY POSITION " .. friendlycoorstring .. " MARKED BY " .. self.smokecolor .. " SMOKE!",
          self.TICMessageShowTime, ""):ToGroup(selectedGroup)
        MESSAGE:New("3. TARGET LOCATION: " .. Direction .. " 300 to 500 METERS!", self.TICMessageShowTime, ""):ToGroup(
          selectedGroup)
        MESSAGE:New("4. ENEMY TROOPS AND VEHICLES IN THE OPEN, " .. self.distance_marking_text, self.TICMessageShowTime,
          ""):ToGroup(selectedGroup)
        MESSAGE:New("5. " .. shoulderDir .. " SHOULDER. PULL YOUR DISCRETION. DANGER CLOSE, FOXTROT WHISKEY!",
          self.TICMessageShowTime, ""):ToGroup(selectedGroup)
	end
  
  end
  
  function CAS:_TracerMark(selectedGroup)
  
   markgroup = self.spawnedFriendlyGroup[selectedGroup:GetName()]
   markgroup:OptionROEHoldFire()
   markgroup:OptionAlarmStateGreen()                           
      --local deadsound = USERSOUND:New("weareCM2.ogg"):ToGroup(grp) 
        MESSAGE:New("Roger that, marking enemy direction with 50 cal!"):ToGroup(selectedGroup)      
       
     --end
     
    markTask = markgroup:TaskFireAtPoint(self.FirePointVec2[selectedGroup:GetName()],1,25,nil,68)
    local fireStop = markgroup:TaskFunction("MarkGroupHoldFire")
    function MarkGroupHoldFire(grp) 
      grp:OptionROEHoldFire()
      env.info("TICDEBUG: HOLD FIRE!") 
      MESSAGE:New("TRACERS OUT, HOLDING FIRE... "):ToGroup(selectedGroup)
         
    end
          
    markgroup:SetTask(markTask,1)
    markgroup:SetTask(fireStop,15)

  end
  
  function CAS:LaseTarget(selectedGroup, lcode)
   local badGroup = self.spawnedEnemyGroup[selectedGroup:GetName()]
   local badUnit = badGroup:GetUnit(1)
   markgroup = self.spawnedFriendlyGroup[selectedGroup:GetName()]
   markgroup:OptionROEHoldFire()
   markgroup:OptionAlarmStateGreen()
   markgroupcoord = markgroup:GetCoordinate()
   
   if markgroupcoord:IsLOS(self.FirePointCoord[selectedGroup:GetName()]) and badUnit:IsAlive() then
      --GROUP:isal
      --DEBUG _G[FirePointCoord]:MarkToAll("firepointcoord")
      --MESSAGE:New("Lase is possible, standby!"):ToAll()
      laserspot = SPOT:New(markgroup:GetUnit(1))
      laserspot:LaseOn(badUnit,lcode,lasertime)
      --laserspot:LaseOnCoordinate(_G[FirePointCoord], 1688, 120)
      if laserspot:IsLasing() then
      MESSAGE:New("Laser on, code " .. lcode ..  ", holding for " .. lasertime .. "  seconds!"):ToGroup(selectedGroup,TICMessageShowTime)
	  end
   else
      MESSAGE:New("Negative Lase, unable.."):ToGroup(selectedGroup)
    return
   end
   
  end

  function CAS:onafterStart(From, Event, To)
    --MESSAGE:New("Test CAS onafterstart STARTED" ,15,""):ToAll()
    self:T({ From, Event, To })
    self:I(self.lid .. "Started (" .. self.version .. ")")
    local prefix = self.prefixes
    --MESSAGE:New("Test CAS onafterstart create group" ,120,""):ToAll()
    self.CasGroups = SET_GROUP:New():FilterCoalitions(self.coalitiontxt):FilterPrefixes(prefix):FilterStart()


    -- Events
    --MESSAGE:New("Test CAS onafterstart handle events" ,120,""):ToAll()
    self:HandleEvent(EVENTS.PlayerEnterAircraft, self._EventHandler)
    self:HandleEvent(EVENTS.PlayerEnterUnit, self._EventHandler)
    self:HandleEvent(EVENTS.PlayerLeaveUnit, self._EventHandler)
    self:__Status(-5)

    return self
  end

  function CAS:onafterStop(From, Event, To)
    self:T({ From, Event, To })
    self:UnhandleEvent(EVENTS.PlayerEnterAircraft)
    self:UnhandleEvent(EVENTS.PlayerEnterUnit)
    self:UnhandleEvent(EVENTS.PlayerLeaveUnit)
    return self
  end

  function CAS:onbeforeStatus(From, Event, To)
    self:T({ From, Event, To })
    --MESSAGE:New("onbeforeStatus", 15):ToAll()
    self:_RefreshF10Menus()
    return self
  end

  function CAS:onafterStatus(From, Event, To)
    self:T({ From, Event, To })
    -- gather some stats
    -- pilots
    local pilots = 0
    for _, _pilot in pairs(self.CasUnits) do
      pilots = pilots + 1
    end
    self:__Status(-30)
    --MESSAGE:New("onafterStatus", 15):ToAll()
    self:_RefreshF10Menus()
    return self
  end

  function CAS:OnBeforeSetSpawnBehaviour(From, Event, To, sgrp, zoneName, selectedGroup)
    self:T({ From, Event, To })
    return self
  end
end

function dist(point1, point2)
  local x = point1.x - point2.x
  local y = point1.y - point2.y
  --local z = point1.z - point2.z

  return (x * x + y * y) ^ 0.5
end
