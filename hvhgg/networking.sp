#define HVHGG_DEFAULT_API_URL "https://hvh.gg/api/"

// Per-server stats key, taken from configs/CSGO-StatsTracker.cfg. The backend resolves the
// server from this key, so there is no separate authentication round trip.
char g_HvHggToken[512] = "";

// Base url of the API, the stats endpoint is appended. Same default as the CS2 tracker.
char g_HvHggApiUrl[256] = HVHGG_DEFAULT_API_URL;

// From the config, same defaults as the CS2 tracker: a deathmatch is sent in pieces of this many seconds (at least
// 10); unsent rounds kept for retrying (past the size the oldest goes, past the age a round is dropped: the API stops
// recognising a round it already counted after 6 hours); the pause between tries grows from 5 seconds up to the max.
int g_DeathmatchSegmentSeconds = 60;
int g_RetryQueueSize = 500;
int g_RetryMaxAgeMinutes = 300;
int g_RetryMaxDelaySeconds = 300;

// Rounds are sent in the order they were played. One that cannot be delivered (the API down, a timeout) stays at the
// head of the queue and is tried again with a growing pause, the later ones wait behind it. On unload the queue is
// written to disk and sent after the next load. The API drops a round it already counted, so one sent twice counts
// once. Entries: { "seq", "createdAt", "payload" }.
JSONArray g_Pending;
bool g_Sending = false;
int g_NextSeq = 0;
int g_Failures = 0;
int g_NextAttempt = 0;
// while unloading nothing is sent anymore, the queue goes to disk
bool g_Unloading = false;

void Networking_Init()
{
    if (g_HvHggToken[0] == '\0')
        SetFailState("[HvH.gg] No API key configured, refusing to start.");

    g_Pending = new JSONArray();

    // the existing variable when another plugin (HvH.gg Recast) made it first
    // The config's Deathmatch is what it starts as (on only: HvH.gg Recast has the same variable and may have set it); a
    // server that runs its deathmatch only at times sets it in the cfg of the mode.
    ConVar deathmatch = CreateConVar("hvhgg_deathmatch", "0", "1 while the server runs a deathmatch made by a plugin (not detected: game_type and game_mode are not deathmatch there); starts as Deathmatch in the config", _, true, 0.0, true, 1.0);
    if (g_Deathmatch && deathmatch != null)
        deathmatch.SetBool(true);
    CreateConVar("hvhgg_match_id", "", "set by a partner's match system: its id of the running match (at most 64 characters, empty when there is none)");
}

static void PendingPath(char[] path, int maxlength, const char[] suffix)
{
    BuildPath(Path_SM, path, maxlength, "data/hvhgg_pending_rounds.json%s", suffix);
}

// Writes what is still queued to disk, the next load sends it.
void Networking_SaveQueue()
{
    char path[PLATFORM_MAX_PATH];
    PendingPath(path, sizeof(path), "");

    if (g_Pending.Length == 0) {
        if (FileExists(path))
            DeleteFile(path);
        return;
    }

    if (g_Pending.ToFile(path))
        PrintToServer("[HvH.gg] Saved %d unsent rounds.", g_Pending.Length);
    else
        PrintToServer("[HvH.gg] Could not save %d unsent rounds.", g_Pending.Length);
}

// Queues the rounds the last unload left on disk, ahead of anything new.
void Networking_LoadQueue()
{
    char path[PLATFORM_MAX_PATH];
    char loading[PLATFORM_MAX_PATH];
    PendingPath(path, sizeof(path), "");
    PendingPath(loading, sizeof(loading), ".loading");

    // a file that broke the last load is not read again
    if (FileExists(loading))
        DeleteFile(loading);
    if (!FileExists(path) || !RenameFile(loading, path))
        return;

    JSONArray loaded = JSONArray.FromFile(loading);
    DeleteFile(loading);
    if (loaded == null)
        return;

    int count = loaded.Length;
    for (int i = 0; i < g_Pending.Length; i++) {
        JSON entry = g_Pending.Get(i);
        loaded.Push(entry);
        delete entry;
    }
    delete g_Pending;
    g_Pending = loaded;

    for (int i = 0; i < g_Pending.Length; i++) {
        JSONObject entry = view_as<JSONObject>(g_Pending.Get(i));
        entry.SetInt("seq", g_NextSeq++);
        delete entry;
    }

    PrintToServer("[HvH.gg] Loaded %d unsent rounds.", count);
    TrimQueue();
    Networking_Pump();
}

static void TrimQueue()
{
    int max = g_RetryQueueSize > 0 ? g_RetryQueueSize : 1;
    while (g_Pending.Length > max) {
        g_Pending.Remove(0);
        PrintToServer("[HvH.gg] Unsent rounds queue is full (%d), dropped the oldest round.", max);
    }
}

static void DropExpired()
{
    int oldest = GetTime() - (g_RetryMaxAgeMinutes > 0 ? g_RetryMaxAgeMinutes : 1) * 60;
    while (g_Pending.Length > 0) {
        JSONObject entry = view_as<JSONObject>(g_Pending.Get(0));
        int createdAt = entry.GetInt("createdAt");
        delete entry;
        if (createdAt >= oldest)
            break;

        g_Pending.Remove(0);
        PrintToServer("[HvH.gg] Dropped an unsent round older than %d minutes.", g_RetryMaxAgeMinutes);
    }
}

static void Enqueue(JSONObject body)
{
    JSONObject entry = new JSONObject();
    entry.SetInt("seq", g_NextSeq++);
    entry.SetInt("createdAt", GetTime());
    entry.Set("payload", body);
    g_Pending.Push(entry);
    delete entry;

    TrimQueue();
    Networking_Pump();
}

// Sends the head of the queue unless a send is running or the pause after a failure is not over.
void Networking_Pump()
{
    if (g_Unloading || g_Sending || GetTime() < g_NextAttempt)
        return;

    DropExpired();
    if (g_Pending.Length == 0)
        return;

    JSONObject entry = view_as<JSONObject>(g_Pending.Get(0));
    JSON payload = entry.Get("payload");
    int seq = entry.GetInt("seq");
    delete entry;

    char url[300];
    Format(url, sizeof(url), "%sstats/log/server", g_HvHggApiUrl);

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("X-Api-Key", g_HvHggToken);
    request.Post(payload, OnRoundSent, seq);
    delete payload;

    g_Sending = true;
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

// hvhgg_match_id: a partner's match system sets it to its id of the running match, this plugin only reads it
// (HvH.gg Recast has the same variable). Sent when set, at most 64 characters.
static void AddPartnerMatchId(JSONArray cvars)
{
    ConVar cvar = FindConVar("hvhgg_match_id");
    if (cvar == null)
        return;

    char value[128];
    cvar.GetString(value, sizeof(value));
    TrimString(value);
    if (value[0] == '\0' || strlen(value) > 64)
        return;

    PushKv(cvars, "hvhgg_match_id", value);
}

static JSONArray BuildCvars()
{
    JSONArray cvars = new JSONArray();

    AddCvar(cvars, "game_type");
    AddCvar(cvars, "game_mode");
    AddCvar(cvars, "mp_teammates_are_enemies");
    AddCvar(cvars, "steamworks_sessionid_server");
    AddPartnerMatchId(cvars);

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

// Queues the buffered round for sending. The backend rejects rounds without round_end, so those are dropped; a
// deathmatch piece has no round_end until the match ends and is sent as long as anything happened in it.
void Networking_SendRound()
{
    bool send = g_RoundEvents.Length > 0 &&
        (g_RoundClosed || (g_CurrentSegment > 0 && g_RoundEvents.Length > 1));
    int segment = g_CurrentSegment;
    g_RoundClosed = false;
    g_CurrentSegment = 0;
    g_RoundStarted = false;
    if (!send)
        return;

    // rounds played including the one that just ended, the same number CS2 reports (warmup = 0)
    int roundNumber = GameRules_GetProp("m_totalRoundsPlayed");

    PrintToServer("[HvH.gg] Queueing round %d (segment %d).", roundNumber, segment);

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
    if (segment > 0)
        body.SetInt("segment", segment);

    Enqueue(body);

    delete body;
    delete cvars;
    delete combat;

    // the queued round holds the event list, anything after this must not land in it
    delete g_RoundEvents;
    g_RoundEvents = new JSONArray();
}

void OnRoundSent(HTTPResponse response, any seq)
{
    g_Sending = false;

    int status = view_as<int>(response.Status);
    bool delivered = status >= 200 && status < 300;
    // no answer (0), the API failing or busy: try again; it refused the round (a wrong key, a malformed round):
    // sending it again changes nothing
    if (!delivered && (status == 0 || status >= 500 || status == 408 || status == 429)) {
        g_Failures++;
        int maxDelay = g_RetryMaxDelaySeconds > 5 ? g_RetryMaxDelaySeconds : 5;
        int delay = 5 << (g_Failures - 1 < 10 ? g_Failures - 1 : 10);
        if (delay > maxDelay)
            delay = maxDelay;
        g_NextAttempt = GetTime() + delay;
        PrintToServer("[HvH.gg] Round not delivered (status %d), %d queued, next try in %d s.", status, g_Pending.Length, delay);
        return;
    }

    if (!delivered)
        PrintToServer("[HvH.gg] Round refused (status %d), dropped.", status);

    // the queue may have been trimmed meanwhile
    if (g_Pending.Length > 0) {
        JSONObject head = view_as<JSONObject>(g_Pending.Get(0));
        bool same = head.GetInt("seq") == seq;
        delete head;
        if (same)
            g_Pending.Remove(0);
    }
    g_Failures = 0;
    g_NextAttempt = 0;

    // the next one in line right away
    Networking_Pump();
}
