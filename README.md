https://teardownmods.com/index.php?/file/626-airstrike-inbound-a10-warthog
<br/>
# Change-log
<br/>

**2.1.2**
  * Fixes
    * A10 now spawns properly instead of occasionally glitching out and flying into the floor.
    * F15 always drops bombs (would sometimes fly by without dropping bombs) 
  * Tuning
    * Made target preview lines for the A10 less dense and lower in height.
    
**2.1.1**

  * Script
    * Implemented reliable airstrike phasing system
  * Fixes
    * Ready sound only plays once (glitch made it play several times)
    * Plane ready notifications properly show up at the end of airstrikes

**2.1.0**
  * Mod now works with Teardown 0.5 (experimental beta)
  * Added better target preview lines
  * Fixed duplicate fly-by sound glitch  
  <br/>

**2.0.1**
  * Fixed a bug that broke the a10's airstrike targeting when switching weapons just after calling it in.
  * Fixed a10 shooting more to the end of target than start. It now shoots evenly spaced out along target line.
  * Tuned the active time of the a10.
  * Reduced file size from 60mb to 12mb and removed unnecessary files in ui folder.
  * Further tuned a10 flying.  
  <br/>

**2.0.0**
  * Added A-10 Warthog:
    * Swoop n shoot plane mechanics
    * Explosive hit-scan shots with curated random explosion sizes
    * Unique fly-by sound for the A10
    * BRRRT sound effect
    * Shots progress from one target point to the other over the span of 2 seconds
    * Plane body aligns with shots
    * Plane adapts to any set of target points
  * General:
    * Directional airstrikes
    * Simultaneous airstrikes
    * Trajectory lines to help with target designation
  * F-15E:
    * Number of bombs dropped are accurate now
    * Single drop point, no more mini carpet bomb
    * Added cluster bomb visual effect
    * Scaled F-15E down to realistic size (A10 too)
    * Increased plane speed to 150m/s from 100m/s
  * Map:
    * Made a whole new demo map with themed sections
    * Credits are baked into the floor
    * A10 tutorial section
  * Script:
    * Major script rework
    * Script to supports multiple planes
    * Fixed a few bugs
    * Added more customization options
    * Went from 297 lines to 865 lines of code  
    <br/>

**1.0.4**
  * Forward velocity of dropped bombs added (customizable).
  * Added credits for the models/vehicles in the map.  
  <br/>

**1.0.3**
  * Cluster bomb tuning and optimization.
  * Fixes:
    * Target only designates on voxels (prevents glitch).
    <br/>

**1.0.2**
  * Added files for using the airstrike on other maps.  
  <br/>

**1.0.1**
  * Just the usual post release tuning + minor adjustments.  
  * Added customization for:
    * bombs amount multiplier.
    * bomb cluster spread.
    * fly-by sound volume.
  * These settings can be changed at the to of the data/mods/airstrike.lua file.
  * Reduced the default bombs amount and slightly increased the default bombs spread.
  * Improved fly-by sound start time.
  <br/>
