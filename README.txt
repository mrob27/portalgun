portalgun

                   The portal gun that shoots portals,
            which I guess is why they call it a portal gun :D

 Portals teleport the player, mobs and dropped objects (use 'Q' to
throw something into a portal)


  Originally by UjEdwin (Ver 0.5)
    Posted to forums at forum.minetest.net/viewtopic.php?f=9&t=12772
    on 2015 July 9th
  Heavily modified by Robert Munafo (mrob27)

LICENSE

  Creative Commons Attribution Sharealike 3.0 Unported (CC-BY-SA-3.0)
  See creativecommons.org/licenses/by-sa/3.0 for details

  Details of individual components

  sound effects are clipped from the following original files, which
are from soundbible.com/tags-ray-gun.html, and licensed as CC-BY-3.0
    Laser_Cannon-Mike_Koenig-797224747.mp3
    Power_Up_Ray-Mike_Koenig-800933783.mp3


HOW TO INSTALL THIS MOD:
  1. Find your minetest folder, and create it if there isn't one yet (like if this is your first time installing a mod)
    Linux: It depends on what type of install you did.
      "RUN_IN_PLACE" installation, the path is:
        <directory where you insalled Minetest/mods
      If you have a normal "globally installed" Minetest, then the path is:
        <your home directory>/.minetest/mods
    Windows:
      <directory where you insalled Minetest/mods
    MacOS X:
      <your home directory>/Library/Application Support/minetest/mods
  2. If you didn't find a folder in step 1, you have to create the folder. If this your first time installing a mod?
  3. Make a folder inside your "mods" folder called "portalgun". All the portalgun files go in that folder.


DESIGN

The main effect of this mod is to create game entitites (via
#minetest.env:add_entity()#) for the orange and blue "portals", and
detect the proximity of other entities to the portals so that those
objects can be teleported.
   Entities "live" on the server, and are unloaded ("deactivated") by
the engine when all players walk far enough away to allow it. When a
player walks back into the proximity of a portal, the entity is
reactivated by the server, and we have to restore the portal's colour
and orientation (which direction it is facing); we also need to
remember where this portal links, and who it belongs to.
   This extra information can be stored in staticdata of the entity
and restored in the normal way (deserialise/serialise within the
on_activate and get_staticdata functions) but we cannot count on the
entity being active when we need the data. So we also keep all
the needed information in the op_prtl[] table.


REVISION HISTORY
 20150709 UjEdwin: Version 0.5. This is not a complitle version, so
still missing functions :)
 Feel Free to use the code and make a better version, I dont care :)

 20151006 mrob27: Reformat everything (spaces, tabs, indentation,
etc.). Use right-click for shooting orange portals. You can now only
shoot portals onto steel blocks.
 20151007 Clean up the code, add more comments
 20151008 More code cleanup; start adding staticdata for the portal
entities so they can be properly reactivated after the player wanders
away and back.
 20151009 More refactoring (added op_prtl table which will replace the
old portalgun_portals table)
 20151011 When a player is teleported and the exit portal points x+,
x-, z+ or z-, we now set their look direction appropriately so they
have their back to the portal they just emerged from.
 20151012 Set yaw of non-player entities as they emerge from a portal


TODO - BUG FIXES
 Extra portals get created sometimes, possibly because of mishandling
of nxt_id and failure to deal with entity deactivation/reactivation.
It can be handled by having the portalgun_portals table indexed by
player name rather than repeatedly incrementing nxt_id

 Portals become "dark" when their position is inside a node. The
proper fix here is to use better checks for deciding which way a portal
should face.

 Portals are invisible when seen from behind, even though they still
work.

 Set yaw appropriately (using setyaw) for non-player entities
similarly to how I present do set_look_yaw for players. Mobs like rats
and sheep will look more realistic if they emerge head-first from the
portal. As with the player, if the exit portal faces y+ or y-, yaw
should remain unchanged.

 Set player's velocity appropriately when exiting portal. On the
forums, Hybrid Dog suggested
(forum.minetest.net/viewtopic.php?f=9&t=12772#p184677) this can be
done by creating an invisible, nonpointable entity (we'd need one per
player) and doing set_attach on it (similarly to how boats work), then
set the object's velocity and acceleration, and then do a set_detach
in a minetest.after callback to release the player after the engine
has effected the velocity change. But actual experiments with the boat
mod seem to indicate this won't work: the player's velocity returns to
0 as soon as they are detached. So they would need to remain attached
as long as they're still airborne, using a globalstep to detect when
the invisible carrier hits something (e.g. any change to x or z
component of velocity).

TODO - COSMETIC

In the original, the gun glows blue or orange according to what colour
portal you just placed.

In the original, a portal that goes nowhere is filled in with its
colour.

In the original, the portalgun also functions as a gravity gun (as
seen in Half-Life) but with very limited launching range.

HOW TO PLAY:
 At present the only way to get a portal gun is to play Creative mode
and get one in the inventory screen, or give one to yourself using
"/giveme portalgun:gun"
 left-click to shoot blue portal
 right-click to shoot orange portal
 shift+left-click to close both portals
 Portals may only be anchored on steel blocks (which sort of look like
the walls of the Aperture Science test chambers)

NOTES

To create the "portalgun_shoot" sound effect I started with the file
"Laser_Cannon-Mike_Koenig-797224747.mp3" from
soundbible.com/tags-ray-gun.html, and renamed it to just
"797224747.mp3". Then I split off just the latter part of the sound
with the mp3splt utility:

   mp3splt 797224747.mp3 0.00.00 0.00.50 600.00.00

Then converted to OGG format with ffmpeg (also adjusting volume):

   ffmpeg -y -i 797224747_00m_00s_50h__00m_01s_99h.mp3 \
     -af volume=0.5 -codec:a libvorbis portalgun_shoot.ogg
