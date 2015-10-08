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


REVISION HISTORY
 20150709 UjEdwin: Version 0.5. This is not a complitle version, so
still missing functions :)
 Feel Free to use the code and make a better version, I dont care :)

 20151006 mrob27: Reformat everything (spaces, tabs, indentation,
etc.). Use right-click for shooting orange portals. You can now only
shoot portals onto steel blocks.
 20151007 Clean up the code, add more comments


TODO
 Extra portals get created sometimes, possibly because of mishandling
of nxt_id and failure to deal with entity deactivation/reactivation.
It can be handled by having the portalgun_portals table indexed by
player name rather than repeatedly incrementing nxt_id

 Portals become "dark" when their position is inside a node. The
proper fix here is to use better checks for deciding which way a portal
should face.

 Portals are invisible when seen from behind, even though they still
work.

 Set player's velocity appropriately when exiting portal. On the
forums, Hybrid Dog suggested
(forum.minetest.net/viewtopic.php?f=9&t=12772#p184677) this can be
done by creating an invisible, nonpointable entity (we'd need one per
player) and doing set_attach on it (similarly to how boats work), then
set the object's velocity, and then do a set_detach in a
minetest.after callback to release the player after the engine has
effected the velocity change. But actual experiments with the boat mod
seem to indicate this won't work: the player's velocity returns to 0
as soon as they are detached. So they would need to remain attached as
long as they're still airborne, using a globalstep to detect when the
invisible carrier hits something.

HOW TO PLAY:
 At present the only way to get a portal gun is to play Creative mode
and get one in the inventory screen, or give one to yourself using
"/giveme portalgun:gun"
 left-click to shoot blue portal
 right-click to shoot orange portal
 shift+left-click to close both portals
 Portals may only be anchored on steel blocks (which sort of look like
the walls of the Aperture Science test chambers)
