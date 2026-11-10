# [TF2] Behold, Merasmus!

Inspired by Mitch's [Be Merasmus](https://forums.alliedmods.net/showthread.php?p=1958263)

Allows admins and other plugins to turn players into Merasmus.

Merasmus is made to be faithful to the boss NPC both visually and mechanically, while still being loyal to RED/BLU.

[Video Demonstration](https://youtu.be/zYCzgQZqedE)

### Dependencies

- SourceMod 1.12+
- This plugin will not work without the custom model provided in the repo!

### Admin Command

- `sm_bemerasmus|sm_bemeras <#userid|name> [health]` - Choose a player to become Merasmus. Optionally set the health of the player. Setting the health to 0 or below will default to the value of `sm_beholdmerasmus_maxhealth`.

### Convars

- `sm_beholdmerasmus_dropammo (Default 0)` - Whether Merasmus should drop an ammo kit on death.
- `sm_beholdmerasmus_maxhealth (Default 1000)` - Merasmus default max health if no health parameter is specified.
- `sm_beholdmerasmus_melee_damage (Default 70)` - Merasmus melee damage.
- `sm_beholdmerasmus_hellfire_cooldown (Default 8.0)` -  Merasmus hellfire attack cooldown.
- `sm_beholdmerasmus_hellfire_damage_min (Default 20)` - Merasmus hellfire attack minimum damage.
- `sm_beholdmerasmus_hellfire_damage_max (Default 50)` - Merasmus hellfire attack maximum damage.
- `sm_beholdmerasmus_hellfire_ignite (Default 1)` - Whether the Merasmus hellfire attack ignites players.
- `sm_beholdmerasmus_aoe_cooldown (Default 30.0)` - Merasmus AoE attack cooldown.
- `sm_beholdmerasmus_aoe_damage (Default 50)` - Merasmus AoE bomb damage.
- `sm_beholdmerasmus_aoe_radius (Default 300.0)` - Merasmus AoE bomb explosion radius.
- `sm_beholdmerasmus_grenade_damage (Default 50)` - Merasmus grenade damage.
- `sm_beholdmerasmus_grenade_radius (Default 300.0)` - Merasmus grenade explosion radius.

### Model Credits

Wizard Staff and Bomb weapon models, removing jiggle bones to work with varying player model scales - [Dice](https://github.com/JimmyPLightning)