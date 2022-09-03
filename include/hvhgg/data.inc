methodmap PlayerInfo < JSONObject
{
	// Constructor
	public PlayerInfo() { return view_as<PlayerInfo>(new JSONObject()); }

	public void GetUsername(char[] buffer, int maxlength)
	{
		this.GetString("username", buffer, maxlength);
	}
	public void SetUsername(const char[] value)
	{
		this.SetString("username", value);
	}
	
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

	property float TimeOnline {
		public get() { return this.GetFloat("timeOnline"); }
		public set(float value) { this.SetFloat("timeOnline", value); }
	}

    property float ConnectTime {
		public get() { return this.GetFloat("connectTime"); }
		public set(float value) { this.SetFloat("connectTime", value); }
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
    float TimeOnline;
    float SpawnTime;
    float ConnectTime;
    char SteamId[20];
    char Username[32];
	bool SupposedToReset;

    void Reset() {
        this.SupposedToReset = false;
        this.SteamId = "\0";
        this.Username = "\0";
        this.ConnectTime = 0.0;
        this.ResetStats();
    }

    void ResetStats() {
        this.TeamId = 0;
        this.TimeOnline = 0.0;
        this.SpawnTime = 0.0;
    }
}