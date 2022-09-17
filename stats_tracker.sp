#include <sourcemod>
#include <steamworks>
#include <cstrike>

bool hvh_lateload = false;
char g_ServerIp[16] = "127.0.0.1";
char g_ServerPort[6] = "27015";

// http stuff
#include <ripext>

#include <hvhgg/data>
#include <hvhgg/globals>

#include "hvhgg/utils.sp"
#include "hvhgg/networking.sp"
#include "hvhgg/events.sp"
#include "hvhgg/stats.sp"

public Plugin:myinfo = 
{ 
    name = "HvH.gg - Global stats tracker", 
    author = "imi-tat0r", 
    description = "Global HvH ranking and statistics by hvh.gg", 
    version = "v0.1.0"
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

    // init plugins stuff
    Networking_Init();
    Events_Init();
    Stats_Init();

    // late load handler
    if (hvh_lateload) {
        OnConfigsExecuted();
        PrintToServer("[HvH.gg] Plugin late load detected.");
        LOOP_CLIENTS(i) {
            if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
                Stats_OnClientPutInServer(i);
            }
        }
    }

    PrintToServer("[HvH.gg] Stats tracker initialized.");
    // show ad every 10 minutes
    CreateTimer(600.0, Advertising, _, TIMER_REPEAT);
}

public OnConfigsExecuted()
{
    GetConVarString(FindConVar("hostport"), g_ServerPort, sizeof(g_ServerPort));

    int octets[4];
    SteamWorks_GetPublicIP(octets);
    Format(g_ServerIp, 16, "%d.%d.%d.%d", octets[0], octets[1], octets[2], octets[3]);
    PrintToServer("ip = %s, port = %s", g_ServerIp, g_ServerPort);
}

public void OnClientPutInServer(int client)
{
    Stats_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
    Stats_OnClientDisconnect(client);
}

void LoadConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/stats_tracker.cfg");

    if (!FileExists(path)) {
        SetFailState("[HvH.gg] Configuration file %s does not exist", path);
        return;
    }

    KeyValues kv = new KeyValues("Config");
    if (!kv.ImportFromFile(path) || !KvJumpToKey(kv, "ApiKey")) {
        SetFailState("[HvH.gg] Configuration file %s is not valid", path);
        return;
    }

    kv.GetString("value", g_HvHggToken, 512, "");

    PrintToServer("[HvH.gg] Loaded API Key from config: %s", g_HvHggToken);

    delete kv;
}

public Action Advertising(Handle timer)
{
    PrintToServer("[HvH.gg] Printing Advertisement.");

    // TODO: Ad print

    return Plugin_Continue;
}