===========================================================
			S C _ R E F L U X
===========================================================

Number of players (recommended/max): 4-8/32

	Objective

Sven Coop Intelligence (SCI) wants you to investigate what's going on in the biolabs of this facility. You have just landed on the roof of one of the buildings, which is also your extraction point. Have fun.

	Version info/changelog

1.2	- Fixed the monsters for "mp_npckill 2" servers.
1.1	- Improved aesthetics and ambience in a few places: sound effects, textures, lighting etc.
	- Changed slime texture in silo and added a short camera sequence so people know where to go.
	- Fixed an exploit that would allow you to skip a section of the map. And no I'm still not saying what it was.
	- Adjusted the weapons/items/enemy balance a little. The python is no longer part of the initial weapons loadout, but I'll give you a hint that it is hidden in the map somewhere. A sniper rifle can easily be found near the end of the map to help deal with the snipers there. You could previously pick up a rifle from dead assassins if you were quick, but now its guaranteed. This combined with having a few less sniper assassins should address the complaints about there being too many of them in the first release. If you still find them annoying, you need to stop charging into every room :). There are now some health and armour pickups around the place, some hidden.
	- Changed the classic grunts and some of the male assassins in the tunnel to OpFor grunts. They have a sound replacement file to make them sound more like the classic grunts, you can delete this file (sound/sc_reflux/fgrunt_radio.txt) if you don't like it. I seriously wish it was possible to use custom sentences instead of single .wav's in replacement files, but oh well.
	- Added a puddle of water below the initial spawn. If you accidentally fall off the ropes that go down, you can try and land in this puddle and it will break your fall. Not exactly realistic (it's because of a bug in the game), but quite convenient.
	- Probably some other minor tweaks that I've forgotten about.
1.0	- Initial release

	!!! Important information about this map !!!

You must not lose the AI node graphs (.nod and .nrp files) because the nodes have been removed from the map itself, so the graphs can't be regenerated. If you do lose them you will have to download the full package of this map (links available from: dfgdfggfdg). This contains a stripped down version of the map (sc_reflux_nodes.bsp) that does contain the nodes, instructions on how to regenerate the graphs are available below.

	How to regenerate the node graphs

1.) Start Steam.
2.) Set your system date to some time in the future, but not too far (I used 2035).
3.) Start Sven-Coop and load up the map "sc_reflux_nodes.bsp".
4.) It should generate the graphs automatically when you start playing. This will take a few minutes to complete. If for some reason it doesn't work (like you get a time-out error) try starting the map in offline mode.
5.) Rename the graph files. They should be in the folder: "SvenCoop/maps/graphs" and you need to rename the "sc_reflux_nodes" files to "sc_reflux". Then reset the system date to what it should be.

- g1l