// Mirrors hvhgg_common.Models.Stats.ServerPlayer.
methodmap PlayerInfo < JSONObject
{
	// Constructor
	public PlayerInfo() { return view_as<PlayerInfo>(new JSONObject()); }

	public void GetSteamId(char[] buffer, int maxlength)
	{
		this.GetString("steamId", buffer, maxlength);
	}
	public void SetSteamId(const char[] value)
	{
		this.SetString("steamId", value);
	}

	property int UserId {
		public get() { return this.GetInt("userId"); }
		public set(int value) { this.SetInt("userId", value); }
	}

	property int TeamId {
		public get() { return this.GetInt("teamId"); }
		public set(int value) { this.SetInt("teamId", value); }
	}

	// The server never knows which cheat a player runs, so this stays 0.
	property int CheatId {
		public get() { return this.GetInt("cheatId"); }
		public set(int value) { this.SetInt("cheatId", value); }
	}

	// Bots are sent so the backend knows who is alive, it never credits them.
	property bool IsBot {
		public get() { return this.GetBool("isBot"); }
		public set(bool value) { this.SetBool("isBot", value); }
	}

	// Latency in ms as the scoreboard shows it. Left out for bots.
	property int Ping {
		public get() { return this.GetInt("ping"); }
		public set(int value) { this.SetInt("ping", value); }
	}
};

// Mirrors hvhgg_common.Models.Stats.RoundCombatPlayer. Values are match totals,
// not per-round deltas, because the backend merges them as scoreboard state.
methodmap CombatInfo < JSONObject
{
	public CombatInfo() { return view_as<CombatInfo>(new JSONObject()); }

	public void SetSteamId(const char[] value) { this.SetString("steamId", value); }

	property int Kills {
		public get() { return this.GetInt("kills"); }
		public set(int value) { this.SetInt("kills", value); }
	}
	property int Deaths {
		public get() { return this.GetInt("deaths"); }
		public set(int value) { this.SetInt("deaths", value); }
	}
	property int Assists {
		public get() { return this.GetInt("assists"); }
		public set(int value) { this.SetInt("assists", value); }
	}
	property int Damage {
		public get() { return this.GetInt("damage"); }
		public set(int value) { this.SetInt("damage", value); }
	}
	property int UtilityDamage {
		public get() { return this.GetInt("utilityDamage"); }
		public set(int value) { this.SetInt("utilityDamage", value); }
	}
	property int HeadshotKills {
		public get() { return this.GetInt("headshotKills"); }
		public set(int value) { this.SetInt("headshotKills", value); }
	}
	property int Mvps {
		public get() { return this.GetInt("mvps"); }
		public set(int value) { this.SetInt("mvps", value); }
	}
	property int Score {
		public get() { return this.GetInt("score"); }
		public set(int value) { this.SetInt("score", value); }
	}
};

methodmap EventKvPair < JSONObject
{
    public EventKvPair() { return view_as<EventKvPair>(new JSONObject()); }
    public void GetKey(char[] buffer, int maxlength) { this.GetString("key", buffer, maxlength); }
    public void SetKey(const char[] value) { this.SetString("key", value); }
    public void GetValue(char[] buffer, int maxlength) { this.GetString("value", buffer, maxlength); }
    public void SetValue(const char[] value) { this.SetString("value", value); }
}

enum struct PlayerStats {
    int TeamId;
    float SpawnTime;
    float ConnectTime;
    char SteamId[32];
    char Username[32];
    bool Connected;
    // player_disconnect was already recorded through the event, OnClientDisconnect must not add it again
    bool DisconnectReported;

    // Fallback match totals for servers where cs_player_manager has no match stats.
    // Enemy damage only, capped at the health the victim had left.
    int Damage;
    int UtilityDamage;
    int Headshots;
    int LastHealth;

    void Reset() {
        this.Connected = false;
        this.DisconnectReported = false;
        this.SteamId = "";
        this.Username = "";
        this.ConnectTime = 0.0;
        this.TeamId = 0;
        this.SpawnTime = 0.0;
        this.LastHealth = 0;
        this.ResetStats();
    }

    void ResetStats() {
        this.Damage = 0;
        this.UtilityDamage = 0;
        this.Headshots = 0;
    }
}
