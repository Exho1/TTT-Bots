# TTT Bots
Semi-intelligent, functional AI players for Trouble in Terrorist Town in Garry's Mod. They are not intended to replace actual players or be active participants in the match (because coding that level of intelligence would be a nightmare) but instead are passive players whose purpose is to make the server feel less empty at low player counts. Innocent bots will never attack unless they are attacked first in which case they will kill you unless you manage to get away. Traitor bots will attempt to find a weapon before going on a mass murder spree. Detective bots will buy a health station and then suicide.

## Dependencies:
This requires the serverside gm_navigation module in order to properly function. It can be found on the Facepunch thread or downloaded directly from googlecode (I included the archive for when google code goes down)

#### gm_navigation
Facepunch - http://facepunch.com/showthread.php?t=953805

Direct - http://spacetechmodules.googlecode.com/svn/trunk/gm_navigation/Release%20-%20Server/gmsv_navigation_win32.dll

Archive - https://code.google.com/archive/p/spacetechmodules/

## Installation:
THIS ADDON ONLY WORKS ON WINDOWS!! Until somebody ports the module to other OSes

1. Drag gmsv_navigation_win32.dll to "\garrysmod\lua\bin". NOT THE ADDONS FOLDER!
2. Put this repo's contents, the Lua stuff, inside the addons folder
3. Start up a multiplayer TTT match
