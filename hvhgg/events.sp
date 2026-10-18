void Events_Init()
{
    HookEvent("round_announce_match_start", Match_Start);
    HookEvent("cs_win_panel_match", Match_End);

    HookEvent("bot_takeover", Bot_Takeover);

    HookEvent("item_purchase", Item_Purchase);

    HookEvent("bomb_beginplant", Bomb_Events);
    HookEvent("bomb_abortplant", Bomb_Events);
    HookEvent("bomb_planted", Bomb_Events);
    HookEvent("bomb_defused", Bomb_Events);
    HookEvent("bomb_exploded", Bomb_Events);

    HookEvent("hostage_follows", Hostage_Events);
    HookEvent("hostage_rescued", Hostage_Events);
    HookEvent("hostage_stops_following", Hostage_Events);

    HookEvent("weapon_fire", Weapon_Fire);

    HookEvent("player_spawn", Player_Spawned);
    HookEvent("player_hurt", Player_Hurt);
    HookEvent("player_death", Player_Death);
    // pre, the client is still valid there and the event carries the reason
    HookEvent("player_disconnect", Player_Disconnect, EventHookMode_Pre);

    HookEvent("round_mvp", Round_Mvp);
    HookEvent("round_start", Round_Start);
    HookEvent("round_end", Round_End);
}

public void Match_Start(Event event, const char[] name, bool dB)
{
    Stats_OnMatchStart();
}

public void Match_End(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnMatchEnd(event, name);
}

public void Bot_Takeover(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnBotTakeover(event, name);
}

public void Item_Purchase(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnItemPurchase(event, name);
}

public void Bomb_Events(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnBombEvent(event, name);
}

public void Hostage_Events(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnHostageEvent(event, name);
}

public void Weapon_Fire(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnWeaponFire(event, name);
}

public void Player_Spawned(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnPlayerSpawned(event, name);
}

public void Player_Hurt(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnPlayerHurt(event, name);
}

public void Player_Death(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnPlayerDeath(event, name);
}

public Action Player_Disconnect(Event event, const char[] name, bool dB)
{
    if (g_CollectEvents)
        Stats_OnPlayerDisconnect(event);
    return Plugin_Continue;
}

public void Round_Mvp(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnRoundMvp(event, name);
}

public void Round_Start(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnRoundStart(event, name);
}

public void Round_End(Event event, const char[] name, bool dB)
{
    if (!g_CollectEvents) return;
    Stats_OnRoundEnd(event, name);
}
