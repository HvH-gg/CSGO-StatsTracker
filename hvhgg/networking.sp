char g_HvHggToken[512] = "some-token";
char g_ApiKey[512] = "some-token";
bool g_bAuthenticated = false;
bool g_bStartedAuthentication = false;

void Networking_Init()
{
    Networking_GetApiToken();
}

void Networking_GetApiToken()
{
    if (g_bAuthenticated || g_bStartedAuthentication) return;
    
    g_bStartedAuthentication = true;
    PrintToServer("[HvH.gg] Starting authentication.")
    
    HTTPRequest request = new HTTPRequest("https://api.hvh.gg/auth/token/session");
    request.SetHeader("Authorization", "Bearer %s", g_HvHggToken);
    request.SetHeader("Server-IP", "%s:%s", g_ServerIp, g_ServerPort);
    request.Post(new JSONObject(), OnGetApiToken);
}

void Networking_OnRoundStart()
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

    HTTPRequest request = new HTTPRequest("https://api.hvh.gg/stats/public");
    request.SetHeader("API-Key", g_ApiKey);
    request.SetHeader("Server-IP", "%s:%s", g_ServerIp, g_ServerPort);
    request.Post(body, OnRoundStart);

    delete body;
    delete g_RoundEvents;
    delete g_RoundPlayers;
}

void OnGetApiToken(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_OK) {
        return;
    }

    PrintToServer("[HvH.gg] Authentication successful.");

    JSONObject apiToken = view_as<JSONObject>(response.Data);
    g_bAuthenticated = true;
    apiToken.GetString("apiToken", g_ApiKey, sizeof(g_ApiKey));
}

void OnRoundStart(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_NoContent) {
        PrintToServer("[HvH.gg] Failed to send round information. Not retrying.");
    }
}

void Networking_DummyCallback(HTTPResponse response, any value) {}