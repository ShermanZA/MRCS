# MRCS

**M**OOSE-based **R**andomised **C**AS **S**cript, MRCS is a modified version of Fargo007 's TROOPSINCONTACT script modified to work
through MOOSE.

This is script is based on the code of the TROOPSINCONTACTV10 script by Fargo007.

## 1. **To use MRC**

Ensure the DCS mission first runs [MOOSE.lua](https://github.com/FlightControl-Master/MOOSE/releases) file

Then run the  MRCS.lua file. [Latest release available here](https://github.com/ShermanZA/MRCS/releases).

Lastly run another file containing the CAS:NEW() function, containing the following items:
* CASGroupNames: List of player groups that will access the CAS menus via F10
* ZoneNames: List of CAS zones where CAS missions will be spawned in
* FriendlyGroupTemplates: Templates used for friendly ground forces during a CAS mission
* BadGuyGroupTemplates:Templates used for hostile ground forces during a CAS mission

Ensure at least one CASZONE exists.
Ensure each CASZone is populated with subzones with the following nameing convention: 
"{CASZONE name}-SubZone-{number}".

Ensure at least one FriendlyGroup exists with the "LateActivation" set to true.

Ensure at least one BadGuyGroup exists with the "LateActivation" set to true.

## 2. **When running the script from a player perspective**

An F-10 menu named "CAS-Menu" will appear with the option "Check-In".
The Check-In option will first check the player's position relative to the CAS Zones as follows:

* If the player is in a Helicopter, then the player must be inside of the CAS trigger zone.
* If the player is in a fixed-wing aircraft, then the script will check the nearest zone's
distance to the player and check the following:
  * If the radius of the CAS zone is less than 50 nautical miles, then the script will check if the player is within 50 nautical miles.
  * If the radius of the CAS zone is greater than 50 nautical miles, then the script will check if the player is within 100 nautical miles.
  * If the radius of the CAS zone is greater then 100 nautical miles, then the script will check if the player is within the trigger zone.

If the player succeeds the inZone check, then a friendly and enemy group will be created from the available templates and spawned into an engagement at a random sub-zone. The player will then recieve either a 9-line as fixed wing, or a 5-line as a helicopter.

At this point the player menu will change to replace the Check-In option with a "Check-Out".
The Check-Out function will delete these groups from the map after 2 minutes and confirm that the player group is off station to the player group.

Alternatively, if the enemy group is destroyed, then the ground forces will report the enemy's destruction before being deleted after 2 minutes and automatically reset the group's CAS menu options.
