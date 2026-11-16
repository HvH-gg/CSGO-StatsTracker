void Stats_Init()
{
    LOOP_CLIENTS(i)
        g_PlayerStats[i].Reset();

    Stats_NewMatchId();
}

// "unixtime|map". No ip (matches are always looked up per server) and the plain map name,
// so workshop paths cannot push the timestamp out of the 64 characters the backend keeps.
void Stats_NewMatchId()
{
    char map[PLATFORM_MAX_PATH];
    char displayName[64];
    GetCurrentMap(map, sizeof(map));
    if (!GetMapDisplayName(map, displayName, sizeof(displayName)))
        strcopy(displayName, sizeof(displayName), map);

    Format(g_MatchId, sizeof(g_MatchId), "%d|%s", GetTime(), displayName);
}

void Stats_OnMatchStart()
{
    g_CollectEvents = true;
    Stats_NewMatchId();

    LOOP_CLIENTS(i)
        g_PlayerStats[i].ResetStats();
}

// Registers a human once it is in game and authorized (both forwards call this, the second one wins).
void Stats_TryRegisterClient(int client)
{
    if (!IsPlayer(client) || !IsClientAuthorized(client) || g_PlayerStats[client].Connected)
        return;

    // get steamId
    char sID[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, sID, sizeof(sID)))
        return;

    // save username
    char Username[32];
    GetClientName(client, Username, sizeof(Username));
    g_PlayerStats[client].Username = Username;

    // save steamId
    g_PlayerStats[client].SteamId = sID;

    g_PlayerStats[client].Connected = true;
    g_PlayerStats[client].TeamId = GetClientTeam(client);
    g_PlayerStats[client].ConnectTime = GetTickedTime();
    g_PlayerStats[client].SpawnTime = GetTickedTime();
    g_PlayerStats[client].LastHealth = GetClientHealth(client);

    PrintToServer("[HvH.gg] Player %s (%s) connected.", g_PlayerStats[client].Username, g_PlayerStats[client].SteamId);

    if (!g_CollectEvents)
        return;

    // the backend replays connects into the round it is emulating
    JSONArray kvPairs = new JSONArray();
    PushKvInt(kvPairs, "userid", client);
    PushKv(kvPairs, "steamid", sID);
    PushKvInt(kvPairs, "teamid", GetClientTeam(client));

    Stats_BuildEvent("player_connect", kvPairs);

    delete kvPairs;
}

static void BuildDisconnectEvent(int client, const char[] reason)
{
    JSONArray kvPairs = new JSONArray();
    PushKvInt(kvPairs, "userid", client);
    PushKvInt(kvPairs, "teamid", IsClientInGame(client) ? GetClientTeam(client) : g_PlayerStats[client].TeamId);
    PushKv(kvPairs, "steamid", g_PlayerStats[client].SteamId);
    PushKv(kvPairs, "reason", reason);

    Stats_BuildEvent("player_disconnect", kvPairs);

    delete kvPairs;
}

// The event carries the reason, OnClientDisconnect below covers the case where it does not fire first.
void Stats_OnPlayerDisconnect(Event event)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsEntityClient(client) || !g_PlayerStats[client].Connected || g_PlayerStats[client].DisconnectReported)
        return;

    char reason[64];
    event.GetString("reason", reason, sizeof(reason));

    BuildDisconnectEvent(client, reason);
    g_PlayerStats[client].DisconnectReported = true;
}

void Stats_OnClientDisconnect(int client)
{
    if (g_CollectEvents && g_PlayerStats[client].Connected && !g_PlayerStats[client].DisconnectReported)
        BuildDisconnectEvent(client, "");

    g_PlayerStats[client].Reset();
}

void Stats_OnBotTakeover(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    // the bot whose body is taken over, the backend stops counting it as alive
    PushKvInt(kvPairs, "botid", GetClientOfUserId(event.GetInt("botid")));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnItemPurchase(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    StripWeaponPrefix(weapon, sizeof(weapon));

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    // "team" is already a team id, not a user id
    PushKvInt(kvPairs, "team", event.GetInt("team"));
    PushKv(kvPairs, "weapon", weapon);

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnBombEvent(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    PushKvInt(kvPairs, "site", event.GetInt("site"));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnHostageEvent(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    // "hostage" is an entity index, not a user id
    PushKvInt(kvPairs, "hostage", event.GetInt("hostage"));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnRoundStart(Event event, const char[] name)
{
    // flush the round that just finished before starting a new buffer
    Networking_SendRound();

    PrintToServer("[HvH.gg] Handling %s.", name);

    delete g_RoundEvents;
    delete g_RoundPlayers;

    g_RoundEvents = new JSONArray();
    g_RoundPlayers = new JSONArray();
    g_EventNumber = 0;
    g_RoundClosed = false;

    GetCurrentMap(g_RoundMap, sizeof(g_RoundMap));

    // snapshot of the players the round is emulated with; bots are included so the backend
    // knows who is alive, it never credits them
    LOOP_CLIENTS(i) {
        if (!IsValidClient(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR)
            continue;

        bool isBot = IsFakeClient(i);
        if (!isBot && g_PlayerStats[i].SteamId[0] == '\0')
            continue;

        PlayerInfo p = new PlayerInfo();
        p.UserId = i;
        p.SetSteamId(isBot ? "BOT" : g_PlayerStats[i].SteamId);
        p.TeamId = GetClientTeam(i);
        p.CheatId = 0;
        p.IsBot = isBot;
        if (!isBot)
            p.Ping = RoundToNearest(GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0);

        g_RoundPlayers.Push(p);
        delete p;
    }

    JSONArray kvPairs = new JSONArray();
    Stats_BuildEvent("round_start", kvPairs);
    delete kvPairs;
}

void Stats_OnPlayerSpawned(Event event, const char[] name)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_SPECTATOR)
        return;

    g_PlayerStats[client].TeamId = GetClientTeam(client);
    g_PlayerStats[client].SpawnTime = GetTickedTime();
    g_PlayerStats[client].LastHealth = GetClientHealth(client);

    // who the slot is and the team: a spectator joining a team isn't in the round's player list and sends no
    // connect, without these the backend can't name him
    JSONArray kvPairs = new JSONArray();
    PushKvInt(kvPairs, "userid", client);
    if (!IsFakeClient(client) && g_PlayerStats[client].SteamId[0] != '\0')
        PushKv(kvPairs, "steamid", g_PlayerStats[client].SteamId);
    PushKvInt(kvPairs, "teamid", GetClientTeam(client));

    Stats_BuildEvent("player_spawn", kvPairs);

    delete kvPairs;
}

void Stats_OnWeaponFire(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    StripWeaponPrefix(weapon, sizeof(weapon));

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    PushKv(kvPairs, "weapon", weapon);

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

static void PushPosition(JSONArray kvPairs, const char[] prefix, int client)
{
    if (!IsValidClient(client))
        return;

    float pos[3];
    GetClientAbsOrigin(client, pos);

    char key[32];
    char value[16];
    char axisNames[] = "xyz";

    for (int axis = 0; axis < 3; axis++) {
        Format(key, sizeof(key), "%s_%c", prefix, axisNames[axis]);
        FloatToString(pos[axis], value, sizeof(value));
        PushKv(kvPairs, key, value);
    }
}

void Stats_OnPlayerDeath(Event event, const char[] name)
{
    int victimId = GetClientOfUserId(event.GetInt("userid"));
    int attackerId = GetClientOfUserId(event.GetInt("attacker"));
    int assisterId = GetClientOfUserId(event.GetInt("assister"));
    bool headshot = event.GetBool("headshot");

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    StripWeaponPrefix(weapon, sizeof(weapon));

    // CSGO has no attackerinair field, CS2 does
    bool attackerInAir = IsValidClient(attackerId) && !(GetEntityFlags(attackerId) & FL_ONGROUND);

    JSONArray kvPairs = new JSONArray();

    PushPosition(kvPairs, "userid", victimId);
    PushPosition(kvPairs, "attacker", attackerId);
    PushPosition(kvPairs, "assister", assisterId);

    PushKvInt(kvPairs, "userid", victimId);
    PushKvInt(kvPairs, "attacker", attackerId);
    PushKvInt(kvPairs, "assister", assisterId);
    PushKv(kvPairs, "weapon", weapon);
    PushKv(kvPairs, "headshot", headshot ? "true" : "false");
    PushKv(kvPairs, "penetrated", event.GetInt("penetrated") > 0 ? "true" : "false");
    PushKv(kvPairs, "attackerinair", attackerInAir ? "true" : "false");
    PushKv(kvPairs, "noscope", event.GetBool("noscope") ? "true" : "false");

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;

    // fallback headshot total, only enemy kills count
    if (headshot && IsPlayer(attackerId) && IsValidClient(victimId) && attackerId != victimId &&
        !AreTeammates(attackerId, victimId))
        g_PlayerStats[attackerId].Headshots++;
}

void Stats_OnPlayerHurt(Event event, const char[] name)
{
    int victimId = GetClientOfUserId(event.GetInt("userid"));
    int attackerId = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    int health = event.GetInt("health");

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    StripWeaponPrefix(weapon, sizeof(weapon));

    JSONArray kvPairs = new JSONArray();

    PushPosition(kvPairs, "userid", victimId);
    PushPosition(kvPairs, "attacker", attackerId);

    PushKvInt(kvPairs, "userid", victimId);
    PushKvInt(kvPairs, "attacker", attackerId);
    PushKvInt(kvPairs, "health", health);
    PushKvInt(kvPairs, "armor", event.GetInt("armor"));
    // "hitgroup" is a hitgroup id, not a user id
    PushKvInt(kvPairs, "hitgroup", event.GetInt("hitgroup"));
    PushKv(kvPairs, "weapon", weapon);
    PushKvInt(kvPairs, "dmg_health", damage);

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;

    if (!IsValidClient(victimId))
        return;

    // dmg_health is not capped at the health the victim had left, the fallback total is
    int dealt = damage < g_PlayerStats[victimId].LastHealth ? damage : g_PlayerStats[victimId].LastHealth;
    g_PlayerStats[victimId].LastHealth = health;

    if (!IsPlayer(attackerId) || attackerId == victimId || AreTeammates(attackerId, victimId))
        return;

    g_PlayerStats[attackerId].Damage += dealt;
    if (IsUtilityWeapon(weapon))
        g_PlayerStats[attackerId].UtilityDamage += dealt;
}

void Stats_OnRoundMvp(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    PushKvInt(kvPairs, "userid", GetClientOfUserId(event.GetInt("userid")));
    PushKvInt(kvPairs, "reason", event.GetInt("reason"));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnRoundEnd(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();

    PushKvInt(kvPairs, "winner", event.GetInt("winner"));
    PushKvInt(kvPairs, "reason", event.GetInt("reason"));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;

    g_RoundClosed = true;
}

void Stats_OnMatchEnd(Event event, const char[] name)
{
    JSONArray kvPairs = new JSONArray();
    Stats_BuildEvent("cs_win_panel_match", kvPairs);
    delete kvPairs;

    // flush what is buffered, the next round_start may never arrive
    Networking_SendRound();
    g_RoundClosed = false;

    g_CollectEvents = false;
}

void Stats_BuildEvent(const char[] name, JSONArray kvPairs)
{
    if (g_RoundEvents == null)
        return;

    JSONObject body = new JSONObject();
    body.SetInt("id", g_EventNumber);
    body.SetString("name", name);
    body.SetInt("serverTick", GetGameTickCount());
    body.SetBool("isWarmup", IsWarmupPeriod());
    body.SetFloat("bombTimer", GetBombTimer());
    body.SetFloat("bombDefuseTime", GetBombDefuseTime());

    body.Set("kvPairs", kvPairs);

    g_RoundEvents.Push(body);
    g_EventNumber++;

    delete body;
}
