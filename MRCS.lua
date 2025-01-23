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
    SpawnedFriendlyGroup  = {},
    SpawnedEnemyGroup     = {},
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
    FirePointCoord        = {},
    SpawnedFriendly       = {},
    SpawnedEnemy          = {},
    IsOnStation             = {},
    casMenu,
    checkInmenu,
    checkOutMenu,
    NewSmokeMenu,
    RepeatBriefMenu,
    TracerMenu,
    FriendlyTemplates = {},
    lasercode = {},
    CASMissions = {},
    _CASMission = {
      MissionID = "",
      CreatedByGroup = "",
      JoinedGroups = {},
      SpawnedFriendlyGroup = "",
      SpawnedEnemyGroup = ""
    },
    mgrsAirframes = {
      "AH-64D_BLK_II",
      "F-16C_50",
      "AV8BNA",
      "A-10C",
      "A-10C_2",
      "FA-18C_hornet",
      "OH58D",
    },
    LLDDMAirframes = {
      "F-15ESE",
    }
  }

  CAS.version = "1.4.3"



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
    self.SpawnedFriendlyGroup = {}
    self.SpawnedEnemyGroup = {}
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
    self.Friendly = SPAWN:NewWithAlias(self.FriendlyTemplates[1], "FRD-GRP"):InitRandomizeTemplate(
      self.friendliesTable)
    self.Badgroup = SPAWN:NewWithAlias(self.BadGuyTemplates[1], 'NME-GRP'):InitRandomizeTemplate(self
      .baddiesTable)

    self.tracermark_groupname = "none"
    self.FirePointCoord = {}
    self.FirePointVec2 = {}
    self.SpawnedFriendly = {}
    self.SpawnedEnemy = {}
    self.coalition = coalition.side.BLUE
    self.coalitiontxt = "blue"
    self.IsOnStation = {}
    self.playerGroups = SET_GROUP:New():AddGroupsByName(CASGroupNames)
    self.lasercode = { 1688, 1776, 1113, 1772 }
    self.lasertime = 180
    self.CASMissions = {}

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

  function CAS:_CASMission(detectedGroup, FRD, NME)
    local newMission = {
        missionID = "Mission: " .. detectedGroup:GetCallsign(),
        CreatedByGroup = detectedGroup:GetName(),
        JoinedGroups = {detectedGroup:GetName()},
        SpawnedFriendlyGroup = FRD,
        SpawnedEnemyGroup = NME
    }
    setmetatable(newMission, { __index = detectedGroup:GetName() })
    return newMission
  end

  -- Function to spawn a group at a specified sub-zone
  function CAS:_spawnGroupAtSubZone(zoneName, selectedGroup)
    self:T(self.lid .. " _spawnGroupAtSubZone")
    self:F(zoneName, selectedGroup)

    local shoulderDir = ""
    Direction_num = math.random(1, 8)
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
    local hdg = 45 * Direction_num
    
    self.Friendly:InitRandomizeZones(subZones)
    local templateunit1 = self.Friendly.SpawnTemplate.units[1]
    local frdcrd = COORDINATE:NewFromVec3({x = templateunit1.x, y = self.Friendly.SpawnTemplate.route.points[1].alt, z = templateunit1.y})
    --change _generateDirectionAndOffset to take Vec3
    
    
    env.info("Heading: " .. hdg)
    --create Generate Bearing function to take either 1 or 2 Coords
    local frdbrng = _generateBearing(frdcrd)
    self.Friendly:InitGroupHeading(frdbrng):InitHeading(frdbrng)
    local badGroup = self.Badgroup
    -- seperate the enemy spawn into a seperate function to be returned
    self.Friendly:OnSpawnGroup(function(spawngroup)
    local  unit1 = spawngroup:GetUnit(1)
      local immcmd = { id = 'SetImmortal', params = { value = true } }
      spawngroup:_GetController():setCommand(immcmd)
      -- enemyGroup = spawnEnemyGroupNearFriendlies(unit1,enemySpawnDistance,detectedZoneName)
      Direction = "none"      
      local enemySpawnPoint = self:_generateDirectionAndOffset(unit1, self.offsetX, self.offsetZ)
      
      badGroup:OnSpawnGroup(
        function(sgrp)
          self:_SetSpawnBehaviour(sgrp, zoneName, selectedGroup)
          return self
        end, self)

      local nmebrg =  _generateBearing(enemySpawnPoint, frdcrd)
      badGroup:InitGroupHeading(nmebrg):InitHeading(nmebrg)
      
      badGroup = badGroup:SpawnFromCoordinate(enemySpawnPoint)
      local casMis = self:_CASMission(selectedGroup, spawngroup.GroupName, badGroup:GetName())
      self.CASMissions[selectedGroup:GetName()] = casMis--table.insert(self.CASMissions,casMis)
      self.SpawnedEnemy = badGroup
      self.SpawnedEnemy:SetCommandInvisible(true)
      self.SpawnedEnemyGroup[selectedGroup:GetName()] = self.SpawnedEnemy
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

      local enemycoor = self.SpawnedEnemy:GetCoordinate()
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
      
      local casMis = self:_CASMission(selectedGroup, spawngroup:GetName(), badGroup:GetName())
      self.CASMissions[selectedGroup:GetName()] = casMis--table.insert(self.CASMissions,casMis)
      self.IsOnStation[selectedGroup:GetName()] = true
      self.MenusDone[selectedGroup:GetName()] = false
      self:_RefreshF10Menus()
      return self
    end)
    --local hdg = 45 * Direction_num
    --self.Friendly:InitGroupHeading(hdg):InitHeading(hdg)
    self.SpawnedFriendly = self.Friendly:Spawn()
    self.SpawnedFriendlyGroup[selectedGroup:GetName()] = self.SpawnedFriendly
    return self
  end

  function CAS:_SetSpawnBehaviour(sgrp, zoneName, selectedGroup)
    self:T(self.lid .. " _SetSpawnBehaviour")
    CasSelf = self
    local zone = ZONE:FindByName(zoneName)
    local casgroups = self.CasGroups
    local selectedName = selectedGroup:GetName()

    local immcmd = { id = 'SetImmortal', params = { value = true } }
    sgrp:_GetController():setCommand(immcmd)
    local mortalTask = sgrp:TaskFunction("GroupMortalAgain")
    function GroupMortalAgain(mortals)
      local immcmd = { id = 'SetImmortal', params = { value = false } }
      mortals:_GetController():setCommand(immcmd)
      --env.info("TICDEBUG: group is mortal again!")
    end

    sgrp:OptionROEOpenFire()
    sgrp:SetTask(mortalTask, self.friendly_fire_time)
    --env.info("group mortal")

    CharlieMike = false
    samesameIniGroup = nil
    TICBaddieUnit1 = sgrp:GetUnit(1)
    _G[TICBaddieUnit1] = TICBaddieUnit1
    --env.info("group retreat")
    TICBaddieGroupName = sgrp:GetName()
    TICBaddieUnit1Heading = sgrp:GetUnit(1):GetHeading()
    --retreat_number = math.random(1, 100)
    --env.info("TICDEBUG: retreat_number: " .. retreat_number)
    local TICBaddieZone = ZONE_GROUP:New(sgrp:GetName(), sgrp, 250)
    sgrp:HandleEvent(EVENTS.Hit) --This requires the user who spawned in the CAS units to remain alive
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
              local IniOnStation = false
              for i,groupName in pairs(CasSelf.CASMissions[selectedName].JoinedGroups) do --pseudocode
                local grp = GROUP:FindByName(groupName)
                if groupName == EventData.IniGroupName then
                  IniOnStation = true
                  break
                end
              end

              if IniOnStation then
                for i,groupName in pairs(CasSelf.CASMissions[selectedName].JoinedGroups) do --pseudocode
                  local grp = GROUP:FindByName(groupName)
                  if grp:IsAlive() then
                    MESSAGE:New("... From JTAC: good effect on target!", CasSelf.TICMessageShowTime, ""):ToGroup(grp, 13)
                  end
                  
                end
              end
              --casgroups:ForEachGroup(function(grp)
                --if grp:IsPartlyOrCompletelyInZone(zone) == true then
                  --MESSAGE:New("... From JTAC: good effect on target!", CasSelf.TICMessageShowTime, ""):ToGroup(
                    --grp, 13)
                --end
              --end)

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

              for i,groupName in pairs(CasSelf.CASMissions[selectedName].JoinedGroups) do --pseudocode
                local grp = GROUP:FindByName(groupName)
                if grp:IsAlive() then
                  MESSAGE:New("Have secondaries in the target area. All enemies appear to be down. Thanks for the support, we are CM!"
                  , 15, ""):ToGroup(grp)
                end
              end
              --casgroups:ForEachGroup(function(grp)
                --if grp:IsAlive() and grp:IsPartlyOrCompletelyInZone(zone) == true then
                  --MESSAGE:New(
                    --"Have secondaries in the target area. All enemies appear to be down. Thanks for the support, we are CM!",
                    --15, ""):ToGroup(grp)
                --end
              --end)
              CharlieMike = true
              if CasSelf.SpawnedFriendlyGroup[selectedName]:IsAlive() then
                CasSelf.SpawnedFriendlyGroup[selectedName]:Destroy(nil, 30)
              end
              for key, grp in pairs(CasSelf.CASMissions[selectedName].JoinedGroups) do
                CasSelf.SpawnedFriendlyGroup[grp] = nil
                CasSelf.SpawnedEnemyGroup[grp] = nil
                CasSelf.IsOnStation[grp] = false
                --local units = GROUP:FindByName(grp):GetUnits()
               -- for key, unit in pairs(units) do
                  CasSelf.MenusDone[grp] = false
                --end
              end
              CasSelf:_ClearGroupsFromMission(CasSelf.CASMissions[selectedName])
              CasSelf:_RefreshF10Menus()
            end
          end
        end, {}, CasSelf.hit_check_interval)
      end
    end

    return CasSelf
  end

  function CAS:_OnStation(arg)
    self:T(self.lid .. " _OnStation")
    -- Check if the player is in a CAS zone
    local detectedZoneName
    local detectedGroup = arg

    --for _, GroupName in pairs( playerGroupNames ) do
    --local group = GROUP:FindByName(GroupName)
    local casZoneList = {}

    -- Calculate distances and populate the casZoneList table
    for _, zoneName in ipairs(self.CZones) do
      local zone = ZONE:FindByName(zoneName)
      local distance = dist(zone:GetVec2(), detectedGroup:GetVec2())
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
      self.IsOnStation[detectedGroup:GetName()] = false
      self.MenusDone[detectedGroup:GetName()] = false
      return self
    else
      -- Spawn the friendly group at the specified sub-zone
      self:_spawnGroupAtSubZone(detectedZoneName, detectedGroup)
    end
    --break
    --end
    return self
  end

  function CAS:_OffStation(arg, casMis)
    self:T(self.lid .. " _OffStation")
    --arg.IsOnStation = false    
    if self.SpawnedFriendlyGroup[arg:GetName()]:IsAlive() then
      local FriendlyToDelete = self.SpawnedFriendlyGroup[arg:GetName()]
      FriendlyToDelete:Destroy(nil, 30)
    end
    --rune spawnedFriendlyGroup and spawnedEnemyGroup into list
    if self.SpawnedEnemyGroup[arg:GetName()]:IsAlive() then
      local EnemyToDelete = self.SpawnedEnemyGroup[arg:GetName()]
      EnemyToDelete:Destroy(nil, 30)
    end
    local createdGroup = casMis.CreatedByGroup
    for key, grpnme in pairs(self.CASMissions[createdGroup].JoinedGroups) do
      self.SpawnedFriendlyGroup[grpnme] = nil
      self.SpawnedEnemyGroup[grpnme] = nil
      self.IsOnStation[grpnme] = false
      local grp = GROUP:FindByName(grpnme)
      self.MenusDone[grpnme] = false
    end

    self:_ClearGroupsFromMission(self.CASMissions[arg:GetName()])
    MESSAGE:New("Roger, confirm you are off-station.", 15):ToGroup(arg)
    self:_RefreshF10Menus()
    return self
  end

  function CAS:_Withdraw(arg, casMis)
    self:T(self.lid .. "_Withdraw")
    local selectedGroupName = arg:GetName()
    self.IsOnStation[selectedGroupName] = false
    self.SpawnedFriendlyGroup[selectedGroupName] = nil
    self.SpawnedEnemyGroup[selectedGroupName] = nil
    local createdGroup = casMis.CreatedByGroup
    for i, grpnme in pairs(self.CASMissions[createdGroup].JoinedGroups) do
      if grpnme == selectedGroupName then
          table.remove(self.CASMissions[createdGroup], i)
          break
      end
    end
    self.MenusDone[selectedGroupName] = false
    MESSAGE:New("Roger, will continue with remain assets on station.", 15):ToGroup(arg)
    self:_RefreshF10Menus()
    return self
  end

  function CAS:_ClearGroupsFromMission(casMis)
    self:T(self.lid .. " _ClearGroupsFromMission")
    local groupsToClear = casMis.JoinedGroups

    for i, grp in ipairs(groupsToClear) do
      self.CASMissions[grp].JoinedGroups = {}
      self.CASMissions[grp] = nil
    end

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

  function CAS:_JoinMission(selectedGroup, casMission)
    self.SpawnedFriendlyGroup[selectedGroup:GetName()] = GROUP:FindByName(self.SpawnedFriendlyGroup[casMission.CreatedByGroup].GroupName)
    self.SpawnedEnemyGroup[selectedGroup:GetName()] = GROUP:FindByName(self.SpawnedEnemyGroup[casMission.CreatedByGroup].GroupName)
    self.FirePointVec2[selectedGroup:GetName()] = self.FirePointVec2[casMission.CreatedByGroup]
    self.FirePointCoord[selectedGroup:GetName()] = self.FirePointCoord[casMission.CreatedByGroup]
    table.insert(casMission.JoinedGroups,selectedGroup:GetName())
    local callsign = GROUP:FindByName(selectedGroup:GetName()):GetCallsign()
    MESSAGE:New(callsign .. ", JTAC, ... STAND BY FOR NINE LINE IN PROGRESS... ", self.TICMessageShowTime):ToGroup(selectedGroup)
    self:_RepeatBrief(selectedGroup)
    
    local units = selectedGroup:GetUnits()
    for key, unit in pairs(units) do
      self.MenusDone[selectedGroup:GetName()] = false
    end

    for key, grp in pairs(casMission.JoinedGroups) do
      self.CASMissions[grp] = casMission
    end
    self.IsOnStation[selectedGroup:GetName()] = true
    self:_RefreshF10Menus()
    return self
  end

  function CAS:_RefreshF10Menus()
    self:T(self.lid .. " _RefreshF10Menus")
    self.CasGroups = SET_GROUP:New():FilterCoalitions(self.coalitiontxt):FilterPrefixes(self.prefixes):FilterStart()
    
    local GroupNames = {}
    self.CasGroups:ForEachGroup(
      function (grp)
        table.insert(GroupNames, grp:GetName())
      end
    )
    local PlayerSet = _DATABASE.CLIENTS --self.CasGroups              -- Core.Set#SET_GROUP
    local PlayerTable = self.CasGroups:GetSetObjects() -- #table of #GROUP objects
    --displayVariables(PlayerTable)
    

    -- build unit menus
    local menucount = 0
    local menus = {}
    for _, _groupName in pairs(GroupNames) do
      if not self.MenusDone[_groupName] then
        local _group = GROUP:FindByName(_groupName) -- Wrapper.Unit#UNIT
          if _group and _group:IsAlive() then
            --displayVariables(_group)
            local distinctCASMissions = CreateDistinctList(self.CASMissions)
            local misName = ""
            for key, mis in pairs(distinctCASMissions) do
              for key, grp in pairs(mis.JoinedGroups) do
                if grp == _group:GetName() then
                  misName = grp
                end
              end
            end
            -- get chopper capabilities
            -- top menu
            casMenu = MENU_GROUP:New(_group, "CAS MENU", nil)
            local checkInmenu = MENU_GROUP_COMMAND:New(_group, "Check-In", casMenu, self._OnStation, self, _group)
                :Refresh()
            local checkOutMenu = MENU_GROUP_COMMAND:New(_group, "Check-Out", casMenu, self._OffStation, self, _group,
             self.CASMissions[misName]):Refresh()

              local withdrawMenu = MENU_GROUP_COMMAND:New(_group, "Withdraw From Mission", casMenu, self._Withdraw, self, _group,
              self.CASMissions[misName]):Refresh()
            
            local missionsCount = ArrayCount(distinctCASMissions)
            local joinMenu = MENU_GROUP:New(_group, "Join CAS Mission", casMenu):Refresh()
            for index, casMis in pairs(distinctCASMissions) do
              --MESSAGE:New("Mission ID: " .. casMis.missionID, 120):ToAll()
              local MissionToAdd = MENU_GROUP_COMMAND:New(_group, casMis.missionID, joinMenu,
              self._JoinMission, self, _group, casMis):Refresh()
           end
           
            local NewSmokeMenu = MENU_GROUP_COMMAND:New(_group, "Deploy New Smoke", casMenu, self.NewSmoke, self, _group)
                :Refresh()
            local RepeatBriefMenu = MENU_GROUP_COMMAND:New(_group, "Repeat CAS Brief", casMenu, self._RepeatBrief, self,
              _group):Refresh()
            local TracerMenu = MENU_GROUP_COMMAND:New(_group, "MARK W/ TRACER", casMenu, self._TracerMark, self, _group)
                :Refresh()
            local LaserMenu = MENU_GROUP:New(_group, "MARK TGT W/LASER", casMenu):Refresh()

            for i = 1, #self.lasercode do
              MENU_GROUP_COMMAND:New(_group, "CODE: " .. self.lasercode[i], LaserMenu, self.LaseTarget, self, _group,
                self.lasercode[i]):Refresh()
            end
            
            -- sub menus
            -- sub menu troops management
            if self.IsOnStation[_group:GetName()] == true then
              checkInmenu:Remove()
              joinMenu:Remove()
              if self.CASMissions[_groupName] ~= nil and self.CASMissions[_groupName].CreatedByGroup == _groupName then
                withdrawMenu:Remove()
              end
            elseif self.IsOnStation[_group:GetName()] ~= true or self.IsOnStation[_group:GetName()] == nil then
              checkOutMenu:Remove()
              if withdrawMenu ~= nil then
                withdrawMenu:Remove()
              end
              NewSmokeMenu:Remove()
              RepeatBriefMenu:Remove()
              TracerMenu:Remove()
              LaserMenu:Remove()
              if (missionsCount < 1 or self.CASMissions[_group:GetName()] ~= nil) then
                joinMenu:Remove()
              end
            end
            self.MenusDone[_group:GetName()] = true
          end -- end group
      else    -- menu build check
        self:T(self.lid .. " Menus already done for this group!")
      end     -- end menu build check
    end       -- end for
    return self
  end

  function ArrayCount(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
  end

  function CAS:_generateDirectionAndOffset(unit1, offsetX, offsetZ)    
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
    self.SpawnedFriendlyGroup[PlayerGroup:GetName()]:Smoke(self.smokecolortype, 55, 1)
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
    local NMEGRP = self.SpawnedEnemyGroup[selectedGroup:GetName()]
    local isMGRS = false
    local isLLDDM = false
    for _, airFrameType in pairs(self.mgrsAirframes) do
      if selectedGroup:GetTypeName() == airFrameType then
        isMGRS = true
      end
    end
    if isMGRS ~= true then
      for _, airFrameType in pairs(self.LLDDMAirframes) do
        if selectedGroup:GetTypeName() == airFrameType then
          isLLDDM = true
        end
      end
    end
      
    local friendlycoor = self.SpawnedFriendlyGroup[selectedGroup:GetName()]:GetCoordinate()
    local friendlycoorstring = friendlycoor:ToStringLLDMS(Settings)

    local enemycoor = NMEGRP:GetCoordinate()
    local enemycoorstring = enemycoor:ToStringLLDMS(Settings)

    if(isMGRS) then
      friendlycoorstring = friendlycoor:ToStringMGRS(Settings)
      enemycoorstring = enemycoor:ToStringMGRS(Settings)
    elseif (isLLDDM) then
      friendlycoorstring = friendlycoor:ToStringLLDDM(Settings)
      enemycoorstring = enemycoor:ToStringLLDDM(Settings)
    end

    shouldernum = math.random(1, 2)
    if shouldernum == 1 then
      shoulderDir = "LEFT"
      shoulderSound = "leftshoulder.ogg"
    else
      shoulderDir = "RIGHT"
      shoulderSound = "rightshoulder.ogg"
    end
    local nineLineString = ""
    if selectedGroup:IsAirPlane() then
      nineLineString = "1. N/A.\n" ..
      "2. N/A.\n" ..
      "3. N/A.\n" ..
      "4. " .. math.floor(NMEGRP:GetAltitude() * 3.28084) .. " Feet ASL\n" ..
		  "5. ENEMY MECHANISED GROUP.\n" ..
		  "6. " .. enemycoorstring .. "\n" ..
		  "7. " .. self.distance_marking_text .. "\n" ..
		  "8. FROM THE " .. Direction .. " 300 to 500 METERS DANGER CLOSE!\n" ..
		  "MARKED BY " .. self.smokecolor .. " SMOKE!\n" ..
		  "9. EGRESS AT YOUR DISCRETION."
    else
      nineLineString = "1. TYPE 2 CONTROL, BOMB ON TARGET. MISSILES FOLLOWED BY ROCKETS & GUNS.\n" ..
    "2. MY POSITION " .. friendlycoorstring .. " MARKED BY " .. self.smokecolor .. " SMOKE!\n" ..
    "3. TARGET LOCATION: " .. Direction .. " 300 to 500 METERS!\n" ..
    "4. ENEMY TROOPS AND VEHICLES IN THE OPEN, \n" ..
		"5. " .. shoulderDir .. " SHOULDER. PULL YOUR DISCRETION. DANGER CLOSE, FOXTROT WHISKEY!"
    end
    MESSAGE:New(nineLineString, self.TICMessageShowTime, ""):ToGroup(selectedGroup)
  end

  function CAS:_TracerMark(selectedGroup)
    markgroup = self.SpawnedFriendlyGroup[selectedGroup:GetName()]
    markgroup:OptionROEHoldFire()
    markgroup:OptionAlarmStateGreen()
    --local deadsound = USERSOUND:New("weareCM2.ogg"):ToGroup(grp)
    MESSAGE:New("Roger that, marking enemy direction with 50 cal!"):ToGroup(selectedGroup)

    --end

    markTask = markgroup:TaskFireAtPoint(self.FirePointVec2[selectedGroup:GetName()], 1, 25, nil, 68)
    local fireStop = markgroup:TaskFunction("MarkGroupHoldFire")
    function MarkGroupHoldFire(grp)
      grp:OptionROEHoldFire()
      env.info("TICDEBUG: HOLD FIRE!")
      MESSAGE:New("TRACERS OUT, HOLDING FIRE... "):ToGroup(selectedGroup)
    end

    markgroup:SetTask(markTask, 1)
    markgroup:SetTask(fireStop, 15)
  end

  function CAS:LaseTarget(selectedGroup, lcode)
    local badGroup = self.SpawnedEnemyGroup[selectedGroup:GetName()]
    local badUnit = badGroup:GetUnit(1)
    markgroup = self.SpawnedFriendlyGroup[selectedGroup:GetName()]
    markgroup:OptionROEHoldFire()
    markgroup:OptionAlarmStateGreen()
    markgroupcoord = markgroup:GetCoordinate()

    if markgroupcoord:IsLOS(self.FirePointCoord[selectedGroup:GetName()]) and badUnit:IsAlive() then
      --GROUP:isal
      --DEBUG _G[FirePointCoord]:MarkToAll("firepointcoord")
      --MESSAGE:New("Lase is possible, standby!"):ToAll()
      laserspot = SPOT:New(markgroup:GetUnit(1))
      laserspot:LaseOn(badUnit, lcode, self.lasertime)
      --laserspot:LaseOnCoordinate(_G[FirePointCoord], 1688, 120)
      if laserspot:IsLasing() then
        MESSAGE:New("Laser on, code " .. lcode .. ", holding for " .. self.lasertime .. "  seconds!"):ToGroup(
          selectedGroup, TICMessageShowTime)
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

  function CAS:OnEventPlayerEnterAircraft(Event)
    self:T(Event)
    local groupName = Event.IniGroupName
    self.MenusDone[groupName] = false
    self:_RefreshF10Menus()
    return self
  end
end

function _generateBearing(point1, point2)
  local hdg = 0
  if point2 == nil then
    hdg = 45 * Direction_num
  elseif point2 ~= nil then
    local bearing = point2:GetDirectionVec3(point1:GetVec3())
    hdg = point2:GetAngleDegrees(bearing)
  end
  env.info("Angle: " .. hdg)
  return hdg
end

function displayVariables(arr, indent)
  if arr == nil then
    env.info("Variable is nil.")
  else
    indent = indent or 0
    local spacing = string.rep("  ", indent)

    for key, value in pairs(arr) do
      value = value or "nil"
        if type(value) == "table" then
            env.info(spacing .. "Variable name: " .. key)
            displayVariables(value, indent + 1)
        else
          env.info(spacing .. "Variable name: " .. key .. ", Value: " .. tostring(value))
      end
    end
  end
end

function CreateDistinctList(array)
  local distinctList = {}
  local seenIDs = {}

  for _, item in pairs(array) do
      local id = item.missionID

      if not seenIDs[id] then
          table.insert(distinctList, item)
          seenIDs[id] = true
      end
  end

  return distinctList
end

function dist(point1, point2)
  local x = point1.x - point2.x
  local y = point1.y - point2.y
  --local z = point1.z - point2.z

  return (x * x + y * y) ^ 0.5
end
