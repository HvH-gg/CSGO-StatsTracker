#include <cstrike>
#include <sdktools>

#define LOOP_CLIENTS(%1) for (int %1 = 1; %1 <= MaxClients; %1 ++)

// Appends a { "key": ..., "value": ... } entry. The local handle is released again
// because pushing into the array keeps its own reference.
stock void PushKv(JSONArray array, const char[] key, const char[] value)
{
    EventKvPair kvp = new EventKvPair();
    kvp.SetKey(key);
    kvp.SetValue(value);

    array.Push(kvp);

    delete kvp;
}

stock void PushKvInt(JSONArray array, const char[] key, int value)
{
    char buffer[16];
    IntToString(value, buffer, sizeof(buffer));

    PushKv(array, key, buffer);
}

// The backend prepends "weapon_" itself, so the prefix has to be stripped here.
stock void StripWeaponPrefix(char[] weapon, int maxlength)
{
    if (StrContains(weapon, "weapon_") != 0)
        return;

    char stripped[64];
    strcopy(stripped, sizeof(stripped), weapon[7]);
    strcopy(weapon, maxlength, stripped);
}

// Weapon names as sent to the backend, i.e. without the "weapon_" prefix.
stock bool IsUtilityWeapon(const char[] weapon)
{
    return StrEqual(weapon, "hegrenade") || StrEqual(weapon, "inferno") ||
           StrEqual(weapon, "molotov") || StrEqual(weapon, "incgrenade") ||
           StrEqual(weapon, "flashbang") || StrEqual(weapon, "smokegrenade") ||
           StrEqual(weapon, "decoy");
}

stock bool IsWarmupPeriod()
{
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

// game_type 1 with game_mode 2, the same check the backend makes
stock bool IsDeathmatch()
{
    ConVar gameType = FindConVar("game_type");
    ConVar gameMode = FindConVar("game_mode");
    return gameType != null && gameMode != null && gameType.IntValue == 1 && gameMode.IntValue == 2;
}

// Same team and not FFA (mp_teammates_are_enemies), i.e. damage between them is friendly fire.
stock bool AreTeammates(int a, int b)
{
    ConVar ffa = FindConVar("mp_teammates_are_enemies");
    if (ffa != null && ffa.BoolValue)
        return false;

    return GetClientTeam(a) == GetClientTeam(b);
}

// Seconds left until detonation, -1.0 while no bomb is planted (same as the CS2 tracker).
stock float GetBombTimer()
{
    int c4 = FindEntityByClassname(-1, "planted_c4");
    if (c4 == -1)
        return -1.0;

    float remaining = GetEntPropFloat(c4, Prop_Send, "m_flC4Blow") - GetGameTime();

    return remaining > 0.0 ? remaining : 0.0;
}

// Seconds left until the running defuse finishes, -1.0 while nobody defuses. CS:GO has no m_bBeingDefused (that is
// CS2); a defuse runs while m_hBombDefuser holds the defusing player.
stock float GetBombDefuseTime()
{
    int c4 = FindEntityByClassname(-1, "planted_c4");
    if (c4 == -1 || !HasEntProp(c4, Prop_Send, "m_hBombDefuser") || GetEntPropEnt(c4, Prop_Send, "m_hBombDefuser") == -1)
        return -1.0;

    float remaining = GetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown") - GetGameTime();

    return remaining > 0.0 ? remaining : 0.0;
}

stock int CountAlivePlayersOnTeam(int csTeam) {
	int count = 0;
	LOOP_CLIENTS(i) {
		if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
			count++;
		}
	}
	return count;
}

stock int SumHealthOfTeam(int team) {
	int sum = 0;
	LOOP_CLIENTS(i) {
		if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) {
			sum += GetClientHealth(i);
		}
	}
	return sum;
}

stock bool IsEntityClient(int client) {
	return client > 0 && client <= MaxClients;
}

stock bool IsValidClient(int client) {
	return IsEntityClient(client) && IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsPlayer(int client) {
	return IsValidClient(client) && !IsFakeClient(client);
}

stock void PrintToChatTeam(int team, char[] msg) {
	LOOP_CLIENTS(i) {
		if (IsValidClient(i) && GetClientTeam(i) == team)
			PrintToChat(i, msg);
	}
}

stock void SwitchPlayerTeam(int client, int team) {
	if (GetClientTeam(client) == team) return;

	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
		CS_RespawnPlayer(client);
	} else {
		ChangeClientTeam(client, team);
	}
}
