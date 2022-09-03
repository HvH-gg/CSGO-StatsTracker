#include <cstrike>

#define LOOP_CLIENTS(%1) for (int %1 = 1; %1 <= MaxClients; %1 ++)

stock EventKvPair CreateKvPair(const char[] key, const char[] value)
{
    EventKvPair kvp = new EventKvPair();
    kvp.SetKey(key);
    kvp.SetValue(value);

    return kvp;
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