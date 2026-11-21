![Copyright ev0lve Digital](https://img.shields.io/badge/Copyright-ev0lve%20Digital-blue)

# [HvH.gg](https://hvh.gg) CSGO Stats Tracker (1.5.0)

Our CSGO Stats tracker plugin enables stats tracking for all players on a server.

# What this plugin does
This is not a stats tracker for your own server. The plugin sends the rounds played on your server to [HvH.gg](https://hvh.gg), where they count towards the stats of every player on HvH.gg: profiles, rankings and match history. It adds no stats commands, menus or pages to your server itself.

# Scout bot
Servers without this plugin are visited by the HvH.gg scout bot, which joins to read the scoreboard. While your server sends rounds with this plugin, the scout bot no longer joins your server, so it does not take up a player slot.

# Requirements
- [Metamod:Source](https://www.sourcemm.net/downloads.php/?branch=master)
- [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) 1.12

# Install
1. Install Metamod:Source and SourceMod
2. Download the latest release for your server (`linux` or `windows`)
3. Place the `addons` folder in your servers `csgo/` directory
4. Add your API Key in the config file.  
   4.1. Located at `addons/sourcemod/configs/CSGO-StatsTracker.cfg`
5. Restart your server

When updating, keep your existing config file so your API Key is not overwritten.

# Config
```
"Config"
{
	"ApiKey"
	{
		"value"		"YOUR_API_KEY"
	}

	// do not change
	"ApiUrl"
	{
		"value"		"https://hvh.gg/api/"
	}

	// 1 if a plugin makes your deathmatch (see below)
	"Deathmatch"
	{
		"value"		"0"
	}

	// optional, these are the defaults
	"DeathmatchSegmentSeconds"
	{
		"value"		"60"
	}
	"RetryQueueSize"
	{
		"value"		"500"
	}
	"RetryMaxAgeMinutes"
	{
		"value"		"300"
	}
	"RetryMaxDelaySeconds"
	{
		"value"		"300"
	}
}
```

A deathmatch has no rounds, so it is sent every `DeathmatchSegmentSeconds`. The game's own deathmatch (`game_type 1`, `game_mode 2`) is detected. If a plugin makes your deathmatch on another game mode, set `Deathmatch` to `1`, otherwise nothing is counted there. The setting is what the variable `hvhgg_deathmatch` starts as: a server that runs it only at times leaves the setting off and sets `hvhgg_deathmatch 1` while it does (and `0` after), for example in the cfg of the mode. HvH.gg Recast reads the same variable. Rounds that cannot be sent (HvH.gg not reachable) are kept, sent again in order, and saved to `addons/sourcemod/data/hvhgg_pending_rounds.json` when the plugin unloads.

After changing the config file, `hvhgg_reload_config` in the server console reads it again (no restart needed).

# Match systems
If your match system has its own match ids, set `hvhgg_match_id "YOUR_MATCH_ID"` when a match starts and empty it (`hvhgg_match_id ""`) when it is over. Rounds are sent with it, so the match can be found by your id.

# Credits
- [HvH.gg](https://hvh.gg)
- [Metamod:Source](https://www.sourcemm.net/)
- [SourceMod](https://www.sourcemod.net/)
- [REST in Pawn](https://github.com/ErikMinekus/sm-ripext)
- [SteamWorks](https://github.com/KyleSanderson/SteamWorks)
