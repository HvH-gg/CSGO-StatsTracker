// Event collection is disabled between cs_win_panel_match and the next map or match start.
bool g_CollectEvents = true;

// Incrementing event id inside the current round buffer, reset on every round_start.
int g_EventNumber = 0;

// Buffer of the round that is currently being recorded. Flushed on the next round_start.
JSONArray g_RoundEvents;

// Snapshot of the players that were on the server when the buffered round started.
JSONArray g_RoundPlayers;

// Map of the buffered round, captured at round_start so a map change cannot corrupt it.
char g_RoundMap[64] = "";

// Set by round_end. A buffer without a round_end is rejected by the backend, so it is not sent.
bool g_RoundClosed = false;

// The buffer was started with a round_start (by the game or as a deathmatch piece).
bool g_RoundStarted = false;

// A deathmatch has one long round, so it is sent in pieces (segments) of DeathmatchSegmentSeconds instead of at its
// end: a crash or map change loses at most one piece. Numbered per map from 1; 0 while buffering a round.
int g_SegmentCount = 0;
int g_CurrentSegment = 0;
float g_SegmentStartedAt = 0.0;

// Stable identifier of the running match, used as RoundInput.matchId ("unixtime|map").
char g_MatchId[64] = "";

PlayerStats g_PlayerStats[MAXPLAYERS + 1];
