# MRCS

**M**OOSE-based **R**andomised **C**AS **S**cript, MRCS is a modified version of Fargo007 's TROOPSINCONTACT script modified to work
through MOOSE.
It allows to quickly setup complex missions using pre-scripted scenarios using the available classes within the MOOSE Framework.
MOOSE works with the current version of DCS world and earlier versions.

## 1. **To use MRC**

Ensure the DCS mission first runs [MOOSE.lua](https://github.com/FlightControl-Master/MOOSE/releases) file
Then run the MRCS.lua file.
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
