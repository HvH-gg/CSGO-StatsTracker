#include <sourcemod>
#include <cstrike>

bool hvh_lateload = false;

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

    // init plugins stuff
    Networking_Init();
    Events_Init();
    Stats_Init();

    // late load handler
    if (hvh_lateload) {
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

public void OnClientPutInServer(int client)
{
    Stats_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
    Stats_OnClientDisconnect(client);
}

public Action Advertising(Handle timer)
{
    // TODO: Ad print
    PrintToServer("[HvH.gg] Printing Advertisement.");

    return Plugin_Continue;
}