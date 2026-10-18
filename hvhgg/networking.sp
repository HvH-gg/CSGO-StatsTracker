#define HVHGG_DEFAULT_API_URL "https://hvh.gg/api/"

// Per-server stats key, taken from configs/stats_tracker.cfg. The backend resolves the
// server from this key, so there is no separate authentication round trip.
char g_HvHggToken[512] = "";

// Base url of the API, the stats endpoint is appended. Same default as the CS2 tracker.
char g_HvHggApiUrl[256] = HVHGG_DEFAULT_API_URL;

void Networking_Init()
{
    if (g_HvHggToken[0] == '\0')
        SetFailState("[HvH.gg] No API key configured, refusing to start.");
}

// Appends the cvars the backend reads (game mode detection and external match id).
static void AddCvar(JSONArray cvars, const char[] name)
{
    ConVar cvar = FindConVar(name);
    if (cvar == null)
        return;

    char value[64];
    cvar.GetString(value, sizeof(value));

    PushKv(cvars, name, value);
}

static JSONArray BuildCvars()
{
    JSONArray cvars = new JSONArray();

    AddCvar(cvars, "game_type");
    AddCvar(cvars, "game_mode");
    AddCvar(cvars, "mp_teammates_are_enemies");
    AddCvar(cvars, "steamworks_sessionid_server");

    return cvars;
}

// Reads one of the scoreboard match totals of cs_player_manager, -1 when the server has none.
static int GetMatchStat(int playerManager, const char[] prop, int client)
{
    if (playerManager == -1 || !HasEntProp(playerManager, Prop_Send, prop))
        return -1;

    return GetEntProp(playerManager, Prop_Send, prop, _, client);
}

// Match totals from the scoreboard, like CS2's MatchStats. Our own counters are only the fallback.
static JSONArray BuildCombat()
{
    JSONArray combat = new JSONArray();
    int playerManager = FindEntityByClassname(-1, "cs_player_manager");

    LOOP_CLIENTS(i) {
        if (!IsPlayer(i) || g_PlayerStats[i].SteamId[0] == '\0')
            continue;

        int kills = GetMatchStat(playerManager, "m_iMatchStats_Kills_Total", i);
        int deaths = GetMatchStat(playerManager, "m_iMatchStats_Deaths_Total", i);
        int assists = GetMatchStat(playerManager, "m_iMatchStats_Assists_Total", i);
        int damage = GetMatchStat(playerManager, "m_iMatchStats_Damage_Total", i);
        int utilityDamage = GetMatchStat(playerManager, "m_iMatchStats_UtilityDamage_Total", i);
        int headshotKills = GetMatchStat(playerManager, "m_iMatchStats_HeadShotKills_Total", i);

        CombatInfo c = new CombatInfo();
        c.SetSteamId(g_PlayerStats[i].SteamId);
        // the scoreboard counters are the fallback, frags already subtract team kills and suicides
        c.Kills = kills >= 0 ? kills : GetClientFrags(i);
        c.Deaths = deaths >= 0 ? deaths : GetClientDeaths(i);
        c.Assists = assists >= 0 ? assists : CS_GetClientAssists(i);
        c.Damage = damage >= 0 ? damage : g_PlayerStats[i].Damage;
        c.UtilityDamage = utilityDamage >= 0 ? utilityDamage : g_PlayerStats[i].UtilityDamage;
        c.HeadshotKills = headshotKills >= 0 ? headshotKills : g_PlayerStats[i].Headshots;
        c.Mvps = CS_GetMVPCount(i);
        c.Score = CS_GetClientContributionScore(i);

        combat.Push(c);
        delete c;
    }

    return combat;
}

// Sends the buffered round to the backend. Called right before the buffer is reset.
void Networking_SendRound()
{
    if (!g_RoundClosed || g_RoundEvents.Length == 0)
        return;

    // rounds played including the one that just ended, the same number CS2 reports (warmup = 0)
    int roundNumber = GameRules_GetProp("m_totalRoundsPlayed");

    PrintToServer("[HvH.gg] Sending round %d.", roundNumber);

    // the map is [Required] on the backend, so it must never be empty
    if (g_RoundMap[0] == '\0')
        GetCurrentMap(g_RoundMap, sizeof(g_RoundMap));

    JSONArray cvars = BuildCvars();
    JSONArray combat = BuildCombat();

    JSONObject body = new JSONObject();
    body.SetString("serverIp", g_ServerAddress);
    body.SetInt("game", 0);
    body.SetInt("software", 0);
    body.SetString("map", g_RoundMap);
    body.SetInt("roundNumber", roundNumber);
    // read at send time so they already contain the round that just finished
    body.SetInt("ctScore", CS_GetTeamScore(CS_TEAM_CT));
    body.SetInt("tScore", CS_GetTeamScore(CS_TEAM_T));
    body.SetString("senderSteamId", "server");
    body.SetString("matchId", g_MatchId);
    body.Set("players", g_RoundPlayers);
    body.Set("events", g_RoundEvents);
    body.Set("combat", combat);
    body.Set("cvars", cvars);

    char url[300];
    Format(url, sizeof(url), "%sstats/log/server", g_HvHggApiUrl);

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("X-Api-Key", g_HvHggToken);
    request.Post(body, OnRoundSent);

    delete body;
    delete cvars;
    delete combat;
}

void OnRoundSent(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_OK) {
        PrintToServer("[HvH.gg] Failed to send round information (status %d). Not retrying.", response.Status);
    }
}
