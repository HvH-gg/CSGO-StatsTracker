void Stats_Init()
{
    LOOP_CLIENTS(i)
        g_PlayerStats[i].Reset();
}

void Stats_OnClientPutInServer(int client)
{
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

    // save playtime data
    g_PlayerStats[client].TeamId = GetClientTeam(client);
    g_PlayerStats[client].ConnectTime = GetTickedTime();
    g_PlayerStats[client].SpawnTime = GetTickedTime();
    g_PlayerStats[client].TimeOnline = 0.0;

    PrintToServer("[HvH.gg] Player %s (%s) connected.", g_PlayerStats[client].Username, g_PlayerStats[client].SteamId);
}

void Stats_OnClientDisconnect(int client)
{
    char name[] = "client_disconnect";
    
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(client, userid, sizeof(userid));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;

    g_PlayerStats[client].Reset();
}

void Stats_OnBotTakeover(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnItemPurchase(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    char team[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));
    IntToString(GetClientOfUserId(event.GetInt("team")), team, sizeof(team));

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));
    kvPairs.Push(CreateKvPair("team", team));
    kvPairs.Push(CreateKvPair("weapon", weapon));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnBombEvent(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));
    char site[10];
    IntToString(event.GetInt("site"), site, sizeof(site));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));
    kvPairs.Push(CreateKvPair("site", site));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnHostageEvent(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnRoundStart(Event event, const char[] name)
{
    Networking_OnRoundStart();
    PrintToServer("[HvH.gg] Handling %s.", name);
    g_RoundEvents = new JSONArray();
    g_RoundPlayers = new JSONArray();
    g_EventNumber = 0;
}

void Stats_OnPlayerSpawned(Event event, const char[] name)
{
    int userid = GetClientOfUserId(event.GetInt("userid"));

    if (IsPlayer(userid) && GetClientTeam(userid) > CS_TEAM_SPECTATOR) {
        PrintToServer("[HvH.gg] Updating player %i.", userid);
        g_PlayerStats[userid].TeamId = GetClientTeam(userid);
        g_PlayerStats[userid].SpawnTime = GetTickedTime();
    }
}

void Stats_OnWeaponFire(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));
    kvPairs.Push(CreateKvPair("userid", userid));

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    kvPairs.Push(CreateKvPair("weapon", weapon));

    Stats_BuildEvent(name, kvPairs);
    delete kvPairs;
}

void Stats_OnPlayerDeath(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    int userId = GetClientOfUserId(event.GetInt("userid"));
    int attackerId = GetClientOfUserId(event.GetInt("attacker"));
    int assisterId = GetClientOfUserId(event.GetInt("assister"));

    char userid[10];
    char attacker[10];
    char assister[10];
    IntToString(userId, userid, sizeof(userid));
    IntToString(attackerId, attacker, sizeof(attacker));
    IntToString(assisterId, assister, sizeof(assister));

    if (IsPlayer(userId)) {
        char x[10], y[10], z[10];
        float pos[3];
        GetClientAbsOrigin(userId, pos);
        FloatToString(pos[0], x, sizeof(x));
        FloatToString(pos[1], y, sizeof(y));
        FloatToString(pos[1], z, sizeof(z));
        kvPairs.Push(CreateKvPair("userid_x", x));
        kvPairs.Push(CreateKvPair("userid_y", y));
        kvPairs.Push(CreateKvPair("userid_z", z));
    }
    if (IsPlayer(attackerId)) {
        char x[10], y[10], z[10];
        float pos[3];
        GetClientAbsOrigin(attackerId, pos);
        FloatToString(pos[0], x, sizeof(x));
        FloatToString(pos[1], y, sizeof(y));
        FloatToString(pos[2], z, sizeof(z));
        kvPairs.Push(CreateKvPair("attacker_x", x));
        kvPairs.Push(CreateKvPair("attacker_y", y));
        kvPairs.Push(CreateKvPair("attacker_z", z));
    }
    if (IsPlayer(assisterId)) {
        char x[10], y[10], z[10];
        float pos[3];
        GetClientAbsOrigin(assisterId, pos);
        FloatToString(pos[0], x, sizeof(x));
        FloatToString(pos[1], y, sizeof(y));
        FloatToString(pos[2], z, sizeof(z));
        kvPairs.Push(CreateKvPair("assister_x", x));
        kvPairs.Push(CreateKvPair("assister_y", y));
        kvPairs.Push(CreateKvPair("assister_z", z));
    }

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));
    kvPairs.Push(CreateKvPair("attacker", attacker));
    kvPairs.Push(CreateKvPair("assister", assister));

    kvPairs.Push(CreateKvPair("headshot", event.GetBool("headshot") ? "true" : "false"));

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    kvPairs.Push(CreateKvPair("weapon", weapon));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnPlayerHurt(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    char attacker[10];
    char hitgroup[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));
    IntToString(GetClientOfUserId(event.GetInt("attacker")), attacker, sizeof(attacker));
    IntToString(GetClientOfUserId(event.GetInt("hitgroup")), hitgroup, sizeof(hitgroup));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));
    kvPairs.Push(CreateKvPair("attacker", attacker));
    kvPairs.Push(CreateKvPair("hitgroup", hitgroup));

    char dmg_health[10];
    IntToString(event.GetInt("dmg_health"), dmg_health, sizeof(dmg_health));
    kvPairs.Push(CreateKvPair("dmg_health", dmg_health));

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    kvPairs.Push(CreateKvPair("weapon", weapon));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnRoundMvp(Event event, const char[] name)
{
    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char userid[10];
    IntToString(GetClientOfUserId(event.GetInt("userid")), userid, sizeof(userid));

    // add to array
    kvPairs.Push(CreateKvPair("userid", userid));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_OnRoundEnd(Event event, const char[] name)
{
    LOOP_CLIENTS(i) {
		if (IsPlayer(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR && g_PlayerStats[i].SpawnTime > 0.0) {
            // record time online
			g_PlayerStats[i].TimeOnline = GetTickedTime() - g_PlayerStats[i].SpawnTime;
        }
    }

    // create required kvPair
    JSONArray kvPairs = new JSONArray();

    // get int value from event and transform to string
    char winner[10];
    char reason[10];
    IntToString(event.GetInt("winner"), winner, sizeof(winner));
    IntToString(event.GetInt("reason"), reason, sizeof(reason));

    // add to array
    kvPairs.Push(CreateKvPair("winner", winner));
    kvPairs.Push(CreateKvPair("reason", reason));

    Stats_BuildEvent(name, kvPairs);

    delete kvPairs;
}

void Stats_BuildEvent(const char[] name, JSONArray kvPairs)
{
    // json body
    JSONObject body = new JSONObject();
    body.SetInt("id", g_EventNumber);
    body.SetString("name", name);
    body.SetFloat("time", GetTickedTime());

    // add array to body
    body.Set("kvPairs", kvPairs);

    // add event to round events
    g_RoundEvents.Push(body);
    g_EventNumber++;

    delete body;
}