#include <sourcemod>
#include <SteamWorks>
#include <ripext>
#include <cstrike>

bool hvh_lateload = false;
char g_ServerIp[16] = "127.0.0.1";
char g_ServerPort[6] = "27015";

// "ip:port", sent as RoundInput.serverIp. The backend overwrites it with the address
// it has on file for the API key, so it is only a fallback.
char g_ServerAddress[32] = "127.0.0.1:27015";

#include "include/hvhgg/data"
#include "include/hvhgg/globals"

#include "hvhgg/utils.sp"
#include "hvhgg/networking.sp"
#include "hvhgg/events.sp"
#include "hvhgg/stats.sp"

public Plugin:myinfo =
{
    name = "HvH.gg - Global stats tracker",
    author = "imi-tat0r",
    description = "Global HvH ranking and statistics by hvh.gg",
    version = "v1.1.0"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    hvh_lateload = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_RoundEvents = new JSONArray();
    g_RoundPlayers = new JSONArray();

    LoadConfig();

    Networking_Init();
    Events_Init();
    Stats_Init();

    // late load handler
    if (hvh_lateload) {
        GetServerIP();
        PrintToServer("[HvH.gg] Plugin late load detected.");
        LOOP_CLIENTS(i) {
            if (IsClientInGame(i))
                Stats_TryRegisterClient(i);
        }
    }
    else
        CreateTimer(10.0, GetServerIPTimer);

    PrintToServer("[HvH.gg] Stats tracker initialized.");
    // show ad every 10 minutes
    CreateTimer(600.0, Advertising, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    // a match that ended with cs_win_panel_match stopped the collection, a new map always starts it again
    g_CollectEvents = true;
    Stats_NewMatchId();
}

public void OnMapEnd()
{
    // the next round_start happens on another map, so flush here
    Networking_SendRound();
    g_RoundClosed = false;
}

public Action GetServerIPTimer(Handle timer)
{
    GetServerIP();
    return Plugin_Handled;
}

public GetServerIP()
{
    GetConVarString(FindConVar("hostport"), g_ServerPort, sizeof(g_ServerPort));

    int octets[4];
    SteamWorks_GetPublicIP(octets);
    Format(g_ServerIp, 16, "%d.%d.%d.%d", octets[0], octets[1], octets[2], octets[3]);
    Format(g_ServerAddress, sizeof(g_ServerAddress), "%s:%s", g_ServerIp, g_ServerPort);
    PrintToServer("[HvH.gg] Starting on server %s", g_ServerAddress);
}

// A client is registered once it is both in game and authorized, whichever happens last.
public void OnClientPutInServer(int client)
{
    Stats_TryRegisterClient(client);
}

public void OnClientAuthorized(int client, const char[] auth)
{
    Stats_TryRegisterClient(client);
}

public void OnClientDisconnect(int client)
{
    Stats_OnClientDisconnect(client);
}

void LoadConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/CSGO-StatsTracker.cfg");

    if (!FileExists(path)) {
        SetFailState("[HvH.gg] Configuration file %s does not exist", path);
        return;
    }

    KeyValues kv = new KeyValues("Config");
    if (!kv.ImportFromFile(path)) {
        SetFailState("[HvH.gg] Configuration file %s is not valid", path);
        delete kv;
        return;
    }

    if (!KvJumpToKey(kv, "ApiKey")) {
        SetFailState("[HvH.gg] Configuration file %s has no ApiKey", path);
        delete kv;
        return;
    }

    kv.GetString("value", g_HvHggToken, sizeof(g_HvHggToken), "");
    kv.GoBack();

    if (KvJumpToKey(kv, "ApiUrl")) {
        kv.GetString("value", g_HvHggApiUrl, sizeof(g_HvHggApiUrl), HVHGG_DEFAULT_API_URL);
        kv.GoBack();
    }

    PrintToServer("[HvH.gg] Loaded configuration (api %s).", g_HvHggApiUrl);

    delete kv;
}

public Action Advertising(Handle timer)
{
    PrintToServer("[HvH.gg] Printing Advertisement.");

    // TODO: Ad print

    return Plugin_Continue;
}
