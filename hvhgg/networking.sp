char g_ApiToken[512] = "some-token";
bool g_bAuthenticated = true;

void Networking_Init()
{
    Networking_GetApiToken();
}

void Networking_GetApiToken()
{
    if (g_bAuthenticated) return;
    PrintToServer("[HvH.gg] Starting authentication.")
    HTTPRequest request = new HTTPRequest("http://localhost:8088/auth/token");
    request.SetHeader("Authorization", "Bearer %s", "some-token");
    request.Get(OnGetApiToken);
}

void Networking_OnRoundEnd()
{
    if (!g_bAuthenticated) return;
    PrintToServer("[HvH.gg] Sending round events list.")

    // json body
    JSONObject body = new JSONObject();
    body.SetString("name", "events_list");   

    LOOP_CLIENTS(i) {
        if (IsPlayer(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR && g_PlayerStats[i].SpawnTime > 0.0) {
            PlayerInfo p = new PlayerInfo();
            p.UserId = i;
            p.SetUsername(g_PlayerStats[i].Username);
            p.SetSteamId(g_PlayerStats[i].SteamId);
            p.TeamId = g_PlayerStats[i].TeamId;
            p.TimeOnline = g_PlayerStats[i].TimeOnline;
            p.ConnectTime = g_PlayerStats[i].ConnectTime;
            
            g_RoundPlayers.Push(p);
        }
    }

    body.Set("players", g_RoundPlayers);
    body.Set("events", g_RoundEvents);

    HTTPRequest request = new HTTPRequest("http://localhost:8088/match/public/stats");
    request.SetHeader("API-Key", g_ApiToken);
    request.Post(body, OnRoundEnd);

    delete body;
    delete g_RoundEvents;
    delete g_RoundPlayers;
}

void OnGetApiToken(HTTPResponse response, any value)
{
    PrintToServer("[HvH.gg] Authentication successful.");

    if (response.Status != HTTPStatus_OK) {
        return;
    }

    JSONObject apiToken = view_as<JSONObject>(response.Data);
    g_bAuthenticated = true;
    apiToken.GetString("apiToken", g_ApiToken, sizeof(g_ApiToken));
}

void OnRoundEnd(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_NoContent) {
        PrintToServer("[HvH.gg] Failed to send round information. Not retrying.");
    }

    // reset
    g_RoundEvents = new JSONArray();
    g_RoundPlayers = new JSONArray();
    g_EventNumber = 0;
}

void Networking_DummyCallback(HTTPResponse response, any value) {}