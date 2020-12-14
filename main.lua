--====================================================================================================================
-- Airstrike Inbound v2.0 - by Cheejins (F15-E Cluster Bomb + A10 BRRRT)
----------------------------------------------------------------------------------------------------------------------
--
--  CUSTOMIZATION
--      
--      I will be adding in-game UI options for all of these in a future update.
--
--      [All Planes]
--          Jet fly-by sound volume. (default = 100, mute = 0)
                local planes_fly_by_sound_volume = 100
--          Smoke trails behind the plane. Setting this to true can improve fps at the cost of visual appeal.
                local enable_planes_engine_smoke = true
--          Ready planes hud notifications. (label at the top of the screen)
                local ready_planes_notifications = true
--
--
--      [F15-E - CBU-87 Cluster Bomb]
--          Number of bombs to drop.
                local cluster_bombs_amount = 15
--          Bomb cluster spread (between 0 and 10. 0 recommended for 1 bomb):
                local cluster_bombs_spread = 3
--          Bomb forward forward velocity
--              N/A (will add it back once fixed. Currently locked at 30m)
--
--
--      [A10 Thunderbolt - BRRRT - (GAU-8/A Avenger Gatling Cannon- 30mm HEI rounds)]
--          Shot spread (0 to 10)
                local a10_shot_spread = 3.5
--          RPM (recommended between 800 to 1800) 
                local a10_rpm = 2100
--          Max explosion size (explosions are curated random sizes per shot. Min = 1, Max = 4.0)
                local a10_max_explosion_size = 2.6
--          Constant cannon explosion size (overrides max explosion size)
--          (0 = no override. Between 0.5 and 4.0. Rocket explosion = 1.0)
                local a10_constant_explosion_size = 0
--
--
--      NOTE: Changing the values outside of the customization can lead to unexpected results.
--      It will very likely break the mod, but hey, who am I to stop you?
--
----------------------------------------------------------------------------------------------------------------------
--  ABOUT SCRIPT
--      I've made some huge improvements to the script, but there are still many things to rework and optimize.
--      I'm relatively new to Lua and still learning, so please forgive me for any stuff that could be better implemented.
--      I'm going to continue improving this script over time.
--      Also, I know the script is big, but I wanted to keep everything in one file for simplicity's sake. Folding the
--      script levels/blocks helps a lot, and I've set it up to make it work that way.
--====================================================================================================================


local checkedPlaneInMap = false
local readyNotificationsOn = false
local planes = nil


colors = {
    yellow  = Vec(255,255,0),
    red     = Vec(255,0,0),
    green   = Vec(0,255,0),
    blue    = Vec(0,0,255),
    white   = Vec(255,255,255),
    black   = Vec(0,0,0),
}


--[[Sounds]]
local sounds = {
    beep             = LoadSound("warning-beep"),
    buzz             = LoadSound("light/spark0"),
    chime            = LoadSound("elevator-chime"),
    engine           = LoadLoop("tools/blowtorch-loop"),
    planeEntry       = LoadSound("chopper-sound"),
    airstrikeEnded     = LoadSound("valuable0"),
    planeNotReady    = LoadSound("error0"),
    click            = LoadSound("tool_pickup"),
    
    f15_flyby        = LoadSound("vehicle/woodboat-drive"),
    a10_flyby        = LoadSound("vehicle/woodboat-idle"),
    a10_gun          = LoadSound("vehicle/yacht-idle"),
}


--[[Debug]]
local db = {all = true, lines = true}
db.all = false -- comment out to enable debugging
db.lines = false -- comment out to enable debugging
local effectsAreOn = true

--- Creates a particle line between ve1 and vec2.
db.vecline = function(vec1, vec2, particle, density)
    if db.lines == true then
        if vec1 ~= nil and vec2 ~= nil then
            local transform = Transform(vec1, QuatLookAt(vec1,vec2))
            for i=1, VecLength(VecSub(vec1, vec2))*(density or 1) do
                local fwdpos = TransformToParentPoint(transform, Vec(0,0,-i/(density or 1)))
                SpawnParticle(particle or "darksmoke", fwdpos, 1, 1, 0.2, 0, 0)
            end
        end
    end
end
--- Creates a particle line in the forward direction of the transform.
db.trline = function(transform, length, particle, density)
    for i=density or 2, length do
        local fwdpos = TransformToParentPoint(transform, Vec(0,0,-i/(density or 2)))
        SpawnParticle(particle or "darksmoke", fwdpos, 1, 1, 0.2, 0, 0)
    end
end



--- Passthrough function to make lines colors easier. color vector from color table (ex: color.yellow)
db.line = function(vec1, vec2, color, a)
    DebugLine(vec1, vec2, color[1] or 255, color[2] or 255, color[3] or 255, a or 1)
end

db.particleLine = function(vec1, vec2, particle, density, thickness)
    local maxLength = 500 -- prevents infinite particle line crashing your game.
    if vec1 ~= nil and vec2 ~= nil then
        local transform = Transform(vec1, QuatLookAt(vec1,vec2))
        for i=1, VecLength(VecSub(vec1, vec2))*(density or 1) do
            if i < maxLength then
                local fwdpos = TransformToParentPoint(transform, Vec(0,0,-i/(density or 1)))
                SpawnParticle(particle or "darksmoke", fwdpos, 1, 1 or thickness, 0.2, 0, 0)
            end
        end
    end
end



--[[Plane Table]] -- I'm still figuring out metatables, I know they'd be far more efficient here.
    --- Returns a base plane object made for f15. To be a base for other planes and modified as needed.
    function constructDefaultPlane(name, tag, tool)

        local plane = {}

        --[[Variables]]
                plane.tool  = tool
                plane.displayName = "[  F-15E  ]"
                plane.tag   = tag
                plane.name  = name
            -- transform
                plane.body              = FindBody(tag, true)
                plane.speed             = 160
                plane.spawnHeight       = 50
                plane.spawnDistance     = 600
                plane.adjustedSpawnDistance = plane.spawnDistance
                if db.all then
                    plane.speed             = 25
                    plane.spawnHeight       = 25
                    plane.spawnDistance     = 100
                end
                plane.flyDirection      = nil
                plane.isDoneExitSwoop   = true
                plane.exitSwoopLerpValDefault  = 0.005
                plane.exitSwoopLerpVal  = 0.005
                plane.exitSwoopLerpValExp = 1.01--- exponential multiplier
                plane.exitDistMult      = 1.0
            -- a10 swoop
                plane.entryPos          = nil
                plane.exitPos           = nil
                plane.targetLerpPos     = nil
            -- activity
                plane.isReadySoundPlayed            = true
                plane.isActive                      = false
                plane.flyBySoundHasPlayed           = true
                plane.minimumDistanceToPlayer       = plane.spawnDistance
                plane.proxyPlayerPos                = Vec(0,0,0)
                plane.sound_flyby_offset            = 100
                plane.flyBySoundVolume              = planes_fly_by_sound_volume/200 -- gv
                plane.airstrikeEnded                = true ---  main control/trigger for the airstrike. true when airstrike starts (plane.setEntryTransform()) until plane leaves airstrike zone.
                plane.pathLineTimerDefault          = 1 --- seconds to draw lines between key airstrike points (entry direction, a10 shoot strip, etc.)
                plane.pathLineTimer                 = 0 --- seconds to draw lines between key airstrike points (entry direction, a10 shoot strip, etc.)
                plane.airstrikeEndedConfirmed       = false
            -- shooting
                plane.shootLength           = 40
                plane.rpm                   = 2000
                plane.shotType              = 1
                plane.smokeTimer            = 0
                plane.smokeIsOn             = false
                plane.smokeType             = "smoke"
                plane.bombSpread            = plane.spawnHeight/1300 * cluster_bombs_spread
                plane.bombsAmount           = cluster_bombs_amount
                plane.timer                 = 0
                plane.targetRaycastPos      = nil
                plane.targetEndRaycastPos   = nil
                plane.proxyPos              = nil
                plane.gunPosOffset          = Vec(0,-2,0)
                plane.isDoneShooting        = true
                plane.shootPrefireDistance  = 20
                plane.shootTimerDefault     = 1.4 -- seconds
                plane.shootTimer            = plane.shootTimerDefault
            -- sound
                plane.sound_flyBy           = LoadSound("vehicle/woodboat-drive")
                plane.sound_customShotSound = nil
                plane.customSoundPlayed     = true
                plane.distancePlaneToPlayer = nil
                plane.soundTimer            = 0
            -- UI
                plane.notificationPlayed            = false
                plane.notificationTimerDefault      = 0.1
                plane.notificationTimer             = plane.notificationTimerDefault 
    
    --- Called on the frame the airstrike ends. Resets values so the next airstrike can start.
    plane.endAirtrike = function()

        plane.airstrikeEnded = true
        plane.airstrikeEndedConfirmed = true
        PlaySound(sounds.airstrikeEnded, GetPlayerPos(), 1)
        
        plane.resetAirstrikeData() -- reset targets

        if ready_planes_notifications then planeNotification(planes) end
        planeNotification(planes)
    end


    plane.startAirstrike = function()
    --- Called on the frame the airstrike starts.
         
        plane.airstrikeEnded = false -- main control/trigger for the airstrike
        PlaySound(sounds.planeEntry, GetPlayerPos(), 0.5)

        plane.pathLineTimer = plane.pathLineTimerDefault
        plane.flyBySoundHasPlayed = false
        plane.isReadySoundPlayed = false

        -- a10
        plane.isDoneShooting = false
        plane.isDoneExitSwoop = false

        -- plane.resetNotificationTimer()
    end


    plane.resetNotificationTimer = function()
        plane.notificationTimer = plane.notificationTimerDefault
    end



    plane.setEntryTransform = 
    --- Spawn point and transform of the plane when airstrike designated.
        function()

            plane.airstrikeEndedConfirmed = false
            plane.startAirstrike()

            -- I KNOW THIS IS TERRIBLE, NASTY, STINKY BLOAT, OKAY? I WILL MERGE THESE LATER. THIS WILL HAVE TO DO FOR NOW REEEEEE
            if plane.name == "f15" then
                local planeTransform = GetBodyTransform(plane.body)
                
                local targetEndPos = Vec(plane.targetEndRaycastPos[1], plane.targetEndRaycastPos[2], plane.targetEndRaycastPos[3]) -- 
                targetEndPos[2] = plane.targetRaycastPos[2] -- match entry height to target height
                local targetstartPos = plane.targetRaycastPos

                
                planeTransform.pos = targetEndPos
                planeTransform.rot = QuatLookAt(planeTransform.pos, plane.targetRaycastPos) -- face plane towards target
                planeTransform.pos = targetstartPos
                SetBodyTransform(plane.body, planeTransform)

                -- move body pos of plane backwards to entry point.
                planeTransform.pos = TransformToParentPoint(planeTransform, Vec(0, plane.targetRaycastPos[2] + plane.spawnHeight, plane.spawnDistance)) -- plane at same height as target and facing target

                plane.targetDirection = VecSub(planeTransform.pos, TransformToParentPoint(planeTransform, Vec(0,0,plane.speed))) -- plane will approach targetdirection
                SetBodyTransform(plane.body, planeTransform) -- move plane to entry point

                plane.isDoneShooting = false
                plane.isDoneExitSwoop = false

            elseif plane.name == "a10" then

                -- set up entry and exit points
                local targetpos = plane.targetRaycastPos
                local targetendpos = plane.targetEndRaycastPos

                local tr = Transform(
                    Vec(targetendpos[1], 
                        targetpos[2], 
                        targetendpos[3]), QuatEuler(0, 0, 0)) -- endpos xy, targetpos y
                tr.rot = QuatLookAt(tr.pos, targetpos) -- horizontal line form targetend to targetpos, both same y

                db.vecline(tr.pos, targetendpos, "darksmoke", 3)


                tr.pos = targetpos -- move pos to targetpos (center airstrike), rot still horizontal
                plane.exitPos = TransformToParentPoint(tr, Vec(0, targetpos[2] + plane.spawnHeight, -plane.spawnDistance*plane.exitDistMult)) --  set exit pos to -planedistance in strip direction from center strip                    
                
                plane.entryPos = TransformToParentPoint(tr, Vec(0, targetpos[2] + plane.spawnHeight, plane.spawnDistance))

                db.vecline(tr.pos, plane.exitPos, "smoke", 3)
                

                tr.rot = QuatLookAt(tr.pos, targetpos) -- just to make sure because earlier of glitch
                tr.pos = TransformToParentPoint(tr, Vec(0, 0, -plane.spawnDistance)) -- move point to plane spawn pos aligned with target strip
                -- plane.entryPos = tr.pos 

                db.vecline(plane.entryPos, targetpos, "smoke", 3)

                
                -- local planeTransform = TransformCopy(tr) -- spawn point. tr already in correct config for this.
                local planeTr = Transform(plane.entryPos, QuatEuler(tr.rot)) -- spawn pos and rot
                planeTr.rot = QuatLookAt(planeTr, plane.exitPos)
                SetBodyTransform(plane.body, planeTr) -- move plane body to airstrike entry point


                if plane.name == "a10" then
                    planeTr.rot = QuatLookAt(planeTr.pos, plane.targetEndRaycastPos) -- face transform towards beginning of target shoot strip
                    SetBodyTransform(plane.body, planeTr) -- set body transform
                end

                plane.targetDirection = VecSub(planeTr.pos, TransformToParentPoint(planeTr, Vec(0,0,plane.speed)))
                plane.targetLerpPos = plane.targetEndRaycastPos -- lerp pos = targetendpos

                plane.adjustedSpawnDistance = math.sqrt(plane.spawnDistance^2 + plane.spawnHeight^2 + (30 or plane.raycastFromPlayerTransform[2])) -- hypotenuse (plane angled down, then moved backward in its transform's z direction)
            end

        end


        plane.setTargetRaycastPos =
        --- Sets the target positions sequentially.
            function()
                if plane.targetRaycastPos == nil then
                    plane.targetRaycastPos = raycastFromPlayerTransform()
                elseif plane.targetEndRaycastPos == nil then
                    plane.targetEndRaycastPos = raycastFromPlayerTransform()
                end
            end


        plane.resetAirstrikeData =
        --- Reset target positions to nil and turn off smoke.
            function()
                plane.targetEndRaycastPos = nil
                plane.targetRaycastPos = nil
                plane.smokeIsOn = false
                plane.smokeTimer = 0
                plane.shootTimer                = plane.shootTimerDefault
                plane.exitSwoopLerpVal          = plane.exitSwoopLerpValDefault
                plane.notificationTimer         = plane.notificationTimerDefault
                plane.isReadySoundPlayed        = true
                plane.customSoundPlayed         = false
                plane.isDoneShooting            = true
            end


        plane.checkTargetsValid =
        --- Returns true when both targets are not nil.
            function()
                return plane.targetRaycastPos ~= nil and plane.targetEndRaycastPos ~= nil
            end
        

        plane.checkTargetsCancelled =
        --- Scroll mouse up or down (change weapon) to reset target pos values before plane starts airstrike.
            function()
                if (InputValue("mousewheel") > 0 or InputValue("mousewheel") < 0) and plane.isActive == false then
                    plane.targetRaycastPos = nil
                    plane.targetEndRaycastPos = nil
                    plane.smokeIsOn = false
                end
            end
        

        plane.smokeSignal =     
        --- Process smoke signal if any target points are valid.
            function()
                if plane.smokeTimer > 0 and plane.smokeIsOn then

                    SpawnParticle(plane.smokeType, plane.targetRaycastPos, Vec(0, 2.5+math.random(10,40)*0.1, 0), 1.0, 5.0) -- first smoke

                    if plane.targetEndRaycastPos ~= nil and plane.name == "a10" then
                        SpawnParticle(plane.smokeType, plane.targetEndRaycastPos, Vec(0, 2.5+math.random(10,40)*0.1, 0), 1.0, 5.0) -- second smoke
                    end

                    if plane.targetEndRaycastPos == nil or plane.isActive then
                        plane.smokeTimer = plane.smokeTimer - GetTimeStep()
                    end
                end
            end

        plane.swoopShoot = 
        --- Lerps the plane's forward direction between target positions based on time.
            function(lerpTime)
                local planeTransform = GetBodyTransform(plane.body)

                plane.targetLerpPos = VecLerp(plane.targetLerpPos, plane.targetRaycastPos, lerpTime)
                planeTransform.rot = QuatLookAt(planeTransform.pos, plane.targetLerpPos)
                SetBodyTransform(plane.body, planeTransform)

                plane.targetDirection = VecSub(planeTransform.pos, TransformToParentPoint(planeTransform, Vec(0, 0, plane.speed))) -- direction of velocity = plane fwdpos
            end

        plane.swoopExit = 
        --- Lerps the plane's forward direction between the ending target point and the exit piont.
            function(lerpTime)
                local planeTransform = GetBodyTransform(plane.body)

                plane.targetLerpPos = VecLerp(plane.targetLerpPos, plane.exitPos, lerpTime)
                planeTransform.rot = QuatLookAt(planeTransform.pos, plane.targetLerpPos)
                SetBodyTransform(plane.body, planeTransform)

                plane.targetDirection = VecSub(planeTransform.pos, TransformToParentPoint(planeTransform, Vec(0, 0, plane.speed))) -- direction of velocity = plane fwdpos
            end

            
        plane.drawPathLines =
        --- Creates a static trajectory preview after the airstrike is confirmed.
            function()
                local lineColor = colors.white

                if plane.checkTargetsValid() then
                    if plane.pathLineTimer > 0 then

                        if plane.name == "a10" then

                            local playerRaycastPosTargetEndHeightPos = VecAdd(plane.targetEndRaycastPos, 
                                Vec(0,plane.targetRaycastPos[2]+(CalcDistance(plane.targetRaycastPos,plane.targetEndRaycastPos))/3,0))

                            local lineSpacing = CalcDistance(plane.targetEndRaycastPos,plane.targetRaycastPos)/2
                            for i=1, lineSpacing do
                                local targetLineLerpPos = VecLerp(plane.targetEndRaycastPos, plane.targetRaycastPos, i/lineSpacing)
                                local raycastThroughTargetLinePos = raycastFromTransform(Transform(playerRaycastPosTargetEndHeightPos, QuatLookAt(playerRaycastPosTargetEndHeightPos, targetLineLerpPos)))
                                db.line(playerRaycastPosTargetEndHeightPos, raycastThroughTargetLinePos, lineColor)
                            end

                            
                            db.line(plane.targetEndRaycastPos, playerRaycastPosTargetEndHeightPos, lineColor)
                            db.line(plane.targetEndRaycastPos, plane.targetRaycastPos, lineColor)
                            db.line(playerRaycastPosTargetEndHeightPos, plane.targetRaycastPos, lineColor)
                        end
                        plane.pathLineTimer = plane.pathLineTimer - GetTimeStep()
                    end
                end

            end

        plane.drawTargetPreview =
        --- Creates a dynamic trajectory preview after the first click, based on the player's raycast position.
            function()
                local lineColor = colors.yellow
                local playerRaycastCopy = raycastFromPlayerTransform()

                if plane.checkPlayerTool() and raycastFromPlayerTransform() ~= nil 
                and plane.isActive == false and plane.targetRaycastPos ~= nil then
                    if plane.name == "f15" then
                        
                            local playerRaycastPosTargetHeight = Vec(raycastFromPlayerTransform()[1], plane.targetRaycastPos[2], raycastFromPlayerTransform()[3])
                            local targetPosFloor = Vec(plane.targetRaycastPos[1], playerRaycastCopy[2], plane.targetRaycastPos[3])

                            local d = Transform(playerRaycastPosTargetHeight, QuatLookAt(playerRaycastPosTargetHeight, plane.targetRaycastPos))
                            local dist = -(CalcDistance(d.pos, plane.targetRaycastPos)*3)
                            local endPos = TransformToParentPoint(d, Vec(0,0,dist*2))

                            local playerRaycastTargetHeightTransform = Transform(
                                playerRaycastPosTargetHeight, 
                                QuatLookAt(playerRaycastPosTargetHeight, plane.targetRaycastPos))

                            local arrowDistanceFromCenter = 2
                            local arrowPoints = {
                                top = TransformToParentPoint(playerRaycastTargetHeightTransform, Vec(0,arrowDistanceFromCenter,0)),
                                bottom = TransformToParentPoint(playerRaycastTargetHeightTransform, Vec(0,-arrowDistanceFromCenter,0)),
                                left = TransformToParentPoint(playerRaycastTargetHeightTransform, Vec(arrowDistanceFromCenter,0,0)),
                                right = TransformToParentPoint(playerRaycastTargetHeightTransform, Vec(-arrowDistanceFromCenter,0,0)),
                            }

                            -- TODO for loops
                            -- outer to center
                            db.line(arrowPoints.top, playerRaycastPosTargetHeight, colors.yellow)
                            db.line(arrowPoints.bottom, playerRaycastPosTargetHeight, colors.yellow)
                            db.line(arrowPoints.left, playerRaycastPosTargetHeight, colors.yellow)
                            db.line(arrowPoints.right, playerRaycastPosTargetHeight, colors.yellow)

                            -- outer to target
                            db.line(arrowPoints.top, plane.targetRaycastPos, colors.yellow)
                            db.line(arrowPoints.bottom, plane.targetRaycastPos, colors.yellow)
                            db.line(arrowPoints.left, plane.targetRaycastPos, colors.yellow)
                            db.line(arrowPoints.right, plane.targetRaycastPos, colors.yellow)

                            -- outer to outer
                            db.line(arrowPoints.top, arrowPoints.right, colors.yellow)
                            db.line(arrowPoints.right, arrowPoints.bottom, colors.yellow)
                            db.line(arrowPoints.bottom, arrowPoints.left, colors.yellow)
                            db.line(arrowPoints.left, arrowPoints.top, colors.yellow)

                            -- db.line(plane.targetRaycastPos, endPos, lineColor)
                            db.line(playerRaycastPosTargetHeight, playerRaycastCopy, lineColor)
                            db.line (plane.targetRaycastPos, targetPosFloor, lineColor)

                            db.particleLine(playerRaycastPosTargetHeight, endPos, "darksmoke", 0.5, 0.1)

                        end

                        if plane.name == "a10" then


                            local playerRaycastPosTargetEndHeightPos = VecAdd(playerRaycastCopy, Vec(0,plane.targetRaycastPos[2]+(CalcDistance(plane.targetRaycastPos,VecAdd(playerRaycastCopy)))/3,0))

                            local lineSpacing = CalcDistance(playerRaycastCopy,plane.targetRaycastPos)/2
                            for i=1, lineSpacing do
                                local targetLineLerpPos = VecLerp(playerRaycastCopy, plane.targetRaycastPos, i/lineSpacing)
                                local raycastThroughTargetLinePos = raycastFromTransform(Transform(playerRaycastPosTargetEndHeightPos, QuatLookAt(playerRaycastPosTargetEndHeightPos, targetLineLerpPos)))
                                db.line(playerRaycastPosTargetEndHeightPos, raycastThroughTargetLinePos, lineColor)
                            end

                            db.line(playerRaycastCopy, playerRaycastPosTargetEndHeightPos, lineColor)
                            db.line(plane.targetRaycastPos, playerRaycastPosTargetEndHeightPos, lineColor)
                            db.line(plane.targetRaycastPos, playerRaycastCopy, lineColor)
                        end

                    end
                end


        plane.checkPlayerTool =
        --- Decides which plane object to use based on which weapon is equipped.
            function()
                return GetString("game.player.tool") == plane.tool
            end

    return plane
end

--[[Planes]]
    -- F15-E (base plane)
        local f15 = constructDefaultPlane("f15", "airstrike_f15", "spraycan")
    -- A10 Config (changing these settings might break the mod)
        local a10 = constructDefaultPlane("a10","airstrike_a10", "blowtorch")
            if db.all then
                a10.spawnHeight = 50
                a10.speed       = 40
            else
                a10.speed       = 160   -- speed
                a10.spawnHeight = 400   -- controls angle of entry and exit point height. pair it with exitDistMult
            end
            a10.displayName             = "[  A-10  ]"
            a10.exitSwoopLerpDefault    = 0.004                         -- swoop speed (0.002 to 0.006)
            a10.exitSwoopLerpValExp     = a10.exitSwoopLerpVal*0.07     -- swoop speed exponentiator (0.005 to 0.02)
            a10.exitDistMult            = 1.5                           -- extra distance until exit (helps with swoop)
            a10.spawnDistance           = 800
            a10.shootPrefireDistance    = a10.spawnDistance*0.4         -- 1 = shoot right on entrance, 0.5 shoot halfway to target
            a10.shootLength             = 20                            -- not relevant
            a10.rpm                     = a10_rpm/2                     -- customizable from top of script
            a10.bombSpread              = a10_shot_spread               -- customizable from top of script
            a10.gunPosOffset            = Vec(0,1,-14)
            a10.sound_flyBy             = sounds.a10_flyby
            a10.sound_customShotSound   = sounds.a10_gun
            a10.flyBySoundVolume        = planes_fly_by_sound_volume*1.2
            a10.smokeType               = "darksmoke"

            planes = {a10, f15}
      
            
            
    --[[Plane Functions]]
    function init()
        a10.endAirtrike()
        f15.endAirtrike()

        planes = {a10, f15}
        if ready_planes_notifications then planeNotification(planes) end
    end
    function tick()        
        manageAirstrike(f15)
        manageAirstrike(a10)
    end
    function manageAirstrike(plane)

        -- DebugPrint(plane.name .. " - " ..  plane.notificationTimer)

        checkAirstrikeState(plane)
        designateTarget(plane)
        planeFly(plane)
        planeShoot(plane)

        if effectsAreOn then planeSound(plane) end
        if effectsAreOn and plane.airstrikeEnded == false and enable_planes_engine_smoke then planeEngineSmoke(plane) end

        -- -- debug positions with particle lines
            -- planeCameraAirstrike = false
            -- local planeTransform = GetBodyTransform(plane.body)
            -- db.vecline(plane.targetRaycastPos, planeTransform.pos, "darksmoke", 0.5)
            -- db.vecline(plane.targetEndRaycastPos, planeTransform.pos, "darksmoke", 0.5)
            -- db.vecline(plane.targetLerpPos, planeTransform.pos, "smoke", 0.5)
            -- db.vecline(plane.entryPos, plane.exitPos, "smoke", 0.5)
    end


    function checkAirstrikeState(plane)

        local planeTransform = GetBodyTransform(plane.body)

        -- check if plane is active (in airstrike zone)
        if CalcDistance(planeTransform.pos, plane.targetRaycastPos) < plane.adjustedSpawnDistance *1.1
        and plane.airstrikeEndedConfirmed == false then 
            plane.isActive = true
        else
            plane.isActive = false
        end

        if plane.isActive == false and plane.airstrikeEnded == false then
            plane.endAirtrike() -- called one frame onlys
        end
        
    end


    function designateTarget(plane)
        if InputPressed("lmb") then
            if plane.isActive == false 
            and GetString("game.player.tool") == plane.tool 
            and raycastFromPlayerTransform() ~= nil 
            -- and plane.airstrikeEnded == true 
            -- and plane.airstrikeEndedConfirmed == true 
            then -- player is looking at a valid voxel while plane ready

                local planeTransform = GetBodyTransform(plane.body)
                local playerPos = GetPlayerPos()

                plane.setTargetRaycastPos()

                plane.smokeIsOn = true
                plane.smokeTimer = 100

                -- proxy player starts at playerpos
                plane.proxyPlayerPos = playerPos

                -- start distance from plane to proxy player 
                plane.minimumDistanceToPlayer = CalcDistance(planeTransform.pos, plane.proxyPlayerPos)

                PlaySound(sounds.click, GetPlayerPos(), 1)
            elseif plane.isActive == true and GetString("game.player.tool") == plane.tool then
                PlaySound(sounds.planeNotReady, GetPlayerPos(), 10)  -- play not ready sound.
            end

            if plane.isActive == false then
                if plane.targetRaycastPos == nil then -- first target pos not set yet
                    plane.smokeIsOn = true
                elseif plane.targetEndRaycastPos ~= nil then -- second target pos not set yet
                    plane.setEntryTransform()
                end            
            end

        end

        plane.checkTargetsCancelled()
        plane.smokeSignal()
        plane.drawTargetPreview()
        plane.drawPathLines()
    end

    function planeFly(plane) -- handles flying

        -- Movement
        SetBodyVelocity(plane.body, plane.targetDirection)

        -- SetBodyVelocity(a10.body, Vec(0,0,-50))
        -- SetBodyVelocity(f15.body, Vec(0,0,-50))
        -- planeEngineSmoke(a10)
        -- planeEngineSmoke(f15)
    end
    function planeSound(plane)

        plane.soundTimer = plane.soundTimer + 1

        local planeTransform = GetBodyTransform(plane.body)
        plane.distancePlaneToPlayer = CalcDistance(planeTransform.pos, GetPlayerPos())

        if plane.distancePlaneToPlayer < plane.minimumDistanceToPlayer and plane.isActive then  -- incoming
            plane.minimumDistanceToPlayer = plane.distancePlaneToPlayer -- set updated plane.minimumDistanceToPlayer as plane is incoming
        end

        if plane.distancePlaneToPlayer > plane.minimumDistanceToPlayer and plane.isActive then

            if plane.flyBySoundHasPlayed == false then
                PlaySound(plane.sound_flyBy, GetPlayerPos(), plane.flyBySoundVolume)
                PlaySound(plane.sound_flyBy, planeTransform.pos, plane.flyBySoundVolume)
                plane.flyBySoundHasPlayed = true
            end
        end

        PlayLoop(sounds.engine, planeTransform.pos, 60) -- engine sound
    end
    function planeEngineSmoke(plane)
        local planeTransform = GetBodyTransform(plane.body)

        local engineLeft = TransformToParentPoint(planeTransform, VecAdd(Vec(-1, 2.3, 13)))
        local engineRight = TransformToParentPoint(planeTransform, VecAdd(Vec(1, 2.3, 13)))
        SpawnParticle("smoke", engineLeft, 1, 1.5, 2, 0, 0)
        SpawnParticle("smoke", engineRight, 1, 1.5, 2, 0, 0)
    end

    function planeShoot(plane)

        if plane.isActive then

            if plane.name == "f15" then
                local planeTransform = GetBodyTransform(plane.body)

                -- plane foward position at target's height 
                plane.proxyPos = TransformToParentPoint(planeTransform, Vec(0,0,-plane.shootPrefireDistance))
                plane.proxyPos[2] = plane.targetRaycastPos[2] -- match height of target pos


                if CalcDistance(plane.proxyPos, plane.targetRaycastPos) < plane.shootPrefireDistance * 1.1 then
                    if plane.isDoneShooting == false then
                        for hfajklsfhsjadlkfhjsdklsjdkhlf=1, plane.bombsAmount do
                            shoot(plane, plane.bombSpread)
                        end
                        plane.isDoneShooting = true
                    end
                end
            
            elseif plane.name == "a10" then
                    
                local planeTransform = GetBodyTransform(plane.body)
                
                --start shooting at a certain point/distance from target until shooting duration done
                if CalcDistance(planeTransform.pos, plane.entryPos) > plane.shootPrefireDistance
                and plane.isDoneShooting == false then

                    -- shoot for duration of time then stop
                    if plane.shootTimer > 0 then -- shoot time in seconds

                        plane.swoopShoot(plane.shootTimerDefault*GetTimeStep()*plane.shootTimerDefault)
                        
                        if plane.timer <= 0 then -- rpm timer
                            plane.timer = 60/plane.rpm

                            shoot(plane, plane.bombSpread)

                            if plane.customSoundPlayed == false then -- custom shoot sound
                                PlaySound(plane.sound_customShotSound, planeTransform.pos, 60)
                                PlaySound(plane.sound_customShotSound, GetPlayerPos(), 0.8)
                                plane.customSoundPlayed = true
                            end
                        else
                            plane.timer = plane.timer - GetTimeStep()
                        end

                        plane.shootTimer = plane.shootTimer - GetTimeStep()
                    end
                end

                if CalcDistance(planeTransform.pos, plane.entryPos) > 1
                and plane.shootTimer <= 0 then
                    plane.isDoneShooting = true

                    if plane.isDoneExitSwoop == false then
                        plane.swoopExit(plane.exitSwoopLerpVal) -- swoop up after plane done shooting
                        plane.exitSwoopLerpVal = plane.exitSwoopLerpVal + plane.exitSwoopLerpValExp
                        
                        if CalcDistance(planeTransform.pos, plane.entryPos) > plane.spawnDistance*1.5 then
                            plane.isDoneExitSwoop = true
                            plane.targetDirection = VecSub(planeTransform.pos, TransformToParentPoint(planeTransform, Vec(0,0,plane.speed)))
                        end

                    end
                end

            end
        end
    end
    function shoot(plane, spread)

        if plane.name == "f15" then

            local planeTransform = GetBodyTransform(plane.body) -- plane transform
            local p = planeTransform -- plane shoot pos
            p.pos = VecAdd(p.pos, plane.gunPosOffset) -- set shoot pos

            -- counter the prefire distance
            local planeProxyShoot = TransformToParentPoint(planeTransform, Vec(0,0,-plane.shootPrefireDistance))
            planeProxyShoot[2] = plane.targetRaycastPos[2] + plane.shootPrefireDistance/10

            local d = VecNormalize(VecSub(planeProxyShoot, p.pos))
            d[1] = d[1] + (math.random()-0.5)*spread
            d[2] = d[2] + (math.random()-0.5)*spread + plane.shootPrefireDistance/40
            d[3] = d[3] + (math.random()-0.5)*spread

            p.pos = VecAdd(p.pos, VecScale(d, 5))
            d = VecNormalize(d)

            Shoot(p.pos, d, 1)
            Explosion(p.pos, 0)

        elseif plane.name == "a10" then

            local planeTransform = GetBodyTransform(plane.body) -- plane transform
            local p = planeTransform -- plane shoot pos
            p.pos = TransformToParentPoint(p, plane.gunPosOffset) -- gunPosOffset = Vec(0,0,-13)

            local targetDirection = plane.targetLerpPos
            local unifiedSpread = (math.random()-0.5)*spread
            targetDirection[1] = targetDirection[1] + unifiedSpread -- (math.random()-0.5)*spread
            targetDirection[2] = targetDirection[2] + (math.random()-0.5)*spread/3
            targetDirection[3] = targetDirection[3] - unifiedSpread --(math.random()-0.5)*spread

            local d = QuatLookAt(p.pos, targetDirection)
            local hitpos = raycastFromTransform(Transform(p.pos, d))

            local size = 0.5
            if a10_constant_explosion_size <= 0 then
                size = math.random() + 0.5 * a10_max_explosion_size
            else
                size = a10_constant_explosion_size
            end
            if size > 0.1 and size < a10_max_explosion_size/1.7 then
                size = a10_max_explosion_size*0.8
            end
            Explosion(hitpos, size) -- actual shot explosion

            -- gun visual effects
            if effectsAreOn then Explosion(p.pos, 0) end -- plane gun muzzle effect
            if effectsAreOn and CalcDistance(hitpos, p.pos) < 1000 then
                db.particleLine(hitpos, p.pos, "fire")
            end
        end
    end
    
    function planeNotification(planes)
  
        local notificationText = ""

        readyNotificationsOn = false
        for i=1, #planes do -- if any timer value is > 0, display notification.
            if planes[i].notificationTimer > 0 then
                readyNotificationsOn = true
                break
            end
        end
        if readyNotificationsOn then
            for i=1, #planes do
                if planes[i].isActive == false then

                    notificationText = notificationText .. planes[i].displayName
                    planes[i].notificationTimer = planes[i].notificationTimer - GetTimeStep()
                    SetString("hud.notification", "Ready: " .. notificationText)
                end
            end
        end

    end


--[[Utility Functions]]
    function CalcDistance(vec1, vec2)
        return VecLength(VecSub(vec1, vec2))
    end
    function raycastFromTransform(tr)
        local plyTransform = tr
        local fwdPos = TransformToParentPoint(plyTransform, Vec(0, 0, -3000))
        local direction = VecSub(fwdPos, plyTransform.pos)
        local dist = VecLength(direction)
        direction = VecNormalize(direction)
        local hit, dist = QueryRaycast(tr.pos, direction, dist)
        if hit then
            local hitPos = TransformToParentPoint(plyTransform, Vec(0, 0, dist * -1))
            return hitPos
        end
        return TransformToParentPoint(tr, Vec(0, 0, -1000))
    end


    function raycastFromPlayerTransform()
        local plyTransform = GetCameraTransform()
        local fwdPos = TransformToParentPoint(plyTransform, Vec(0, 0, -3000))
        local direction = VecSub(fwdPos, plyTransform.pos)
        local dist = VecLength(direction)
        direction = VecNormalize(direction)
        local hit, dist = QueryRaycast(plyTransform.pos, direction, dist)
        if hit then
            local hitPos = TransformToParentPoint(plyTransform, Vec(0, 0, dist * -1))
            return hitPos
        end
        return nil
    end

    function drawTransformLine(transform, length, particle, density, thickness)
        for i=1, length do
            local fwdpos = TransformToParentPoint(transform, Vec(0,0,-i/(density or 1)))
            SpawnParticle(particle or "darksmoke", fwdpos, 1, 1 or thickness, 0.1, 0, 0)
        end
    end

    function beep()
        PlaySound(sounds.beep, GetPlayerPos(), 0.3)
    end
    function buzz()
        PlaySound(sounds.buzz, GetPlayerPos(), 0.3)
    end
    function chime()
        PlaySound(sounds.chime, GetPlayerPos(), 0.3)
    end