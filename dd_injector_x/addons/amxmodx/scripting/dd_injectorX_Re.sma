#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#pragma semicolon 1

#if AMXX_VERSION_NUM < 183
    #define client_disconnected client_disconnect
	#include <colorchat>
#endif

//Options
#define HEAL			20.0 + (MAXHEALTH - health)*0.1		//Amount of health to be restored
															//default: 20 + 10% from the missing health
															
#define MAXHEALTH		100.0			//Max health on your server
#define VIP_AMMO		2				//Number of injectors for VIP
#define PLR_AMMO		1				//Number of injectors for player without flags
#define FLAG			ADMIN_LEVEL_H	// VIP flag
#define START_ROUND		2				// The round from which you can use injectors, set 0 to from any
//#define SOUND_FROM_R					// if defined plrs can hear sound in range else only player who use

#define IMPULSE						// if defined plrs can use heal from bind flashlight "impulse 100" with any weapons
//#define OLD_VERSION					// if defined plrs can use heal from command "drop" with knife in hands
									// You can use both methods or choose one of them

//Chat messages, you can comment out any so that it is not displayed
#define MSG_REMAINS						"^1[^4DD_InjX^1] ^1You ^3healed^1 ^4%2.f ^1health. Remaining: ^4%d injector%s."
#define MSG_RANOUT						"^1[^4DD_InjX^1] You ^3dont have injectors ^1for heal"
#if START_ROUND > 0
	#define MSG_ROUND					"^1[^4DD_InjX^1] Injectors can be used from ^3%d round"
#endif


#define ANIM_USE		0
#define DELAY_HEAL		2.0

#define TASK_HEAL		25071973


new const v_injectorX[]	= "models/v_injectorX.mdl"; // v_ model
new const p_injectorX[]	= "models/p_injectorX.mdl"; // p_ model

new const heal_sound[]	= { "items/medshot4.wav" };	// Sound

#if defined IMPULSE
new const WEAPONS_NAMES[][] = { "weapon_p228", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" };
#endif

new shpr_ammo[33];
new g_round = 1;


public plugin_init() {	
	register_plugin("Injector X RE", "0.9", "Deadly|Darkness feat DK.Kalameet");
#if defined IMPULSE
	RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "fw_Impulse", false);
#endif
#if defined OLD_VERSION
	register_clcmd("drop", "fw_Drop");
#endif
#if defined IMPULSE
	for (new i = 0; i < sizeof WEAPONS_NAMES; i++)
		RegisterHam(Ham_Item_Holster, WEAPONS_NAMES[i], "fw_Item_Holstered_Post", 1);
#else
		RegisterHam(Ham_Item_Holster, "weapon_knife", "fw_Item_Holstered_Post", 1);
#endif
	RegisterHookChain(RG_CBasePlayer_Spawn, "fw_Spawn_Post", 1);
	RegisterHookChain(RG_RoundEnd, "RoundEnd", 1);
}

public plugin_precache() {
	precache_model(v_injectorX);
	precache_model(p_injectorX);
	precache_sound(heal_sound);
}

public RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	switch(event) {
		case ROUND_GAME_COMMENCE, ROUND_GAME_RESTART: g_round = 1;
		default: g_round++;
	}
}

public fw_Spawn_Post(id) {
	shpr_ammo[id] = (get_user_flags(id) & FLAG) ? VIP_AMMO:PLR_AMMO;
}

#if defined IMPULSE
public fw_Impulse(id) {
	if(!is_user_alive(id))
		return HC_CONTINUE;

	if(get_entvar(id, var_impulse) == 100) {
		set_entvar(id, var_impulse, 0);
		use_inj(id);
    }
	return HC_CONTINUE;
}
#endif

#if defined OLD_VERSION
public fw_Drop(id) {
	if(get_entvar(id, var_deadflag) != DEAD_NO)
		return PLUGIN_CONTINUE;
		
	new cur_weapon = get_member(id, m_pActiveItem);

	if(get_member(cur_weapon, m_iId) == CSW_KNIFE) {
		use_inj(id);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}
#endif

public use_inj(id) {
#if START_ROUND > 0
	if(g_round < START_ROUND) {
	#if defined MSG_ROUND
		client_print_color(id, print_team_red, MSG_ROUND, START_ROUND);
	#endif
		return;
	}
#endif

	if(!shpr_ammo[id]) {
	#if defined MSG_RANOUT
		client_print_color(id, print_team_red, MSG_RANOUT);
	#endif
		return;
	}
		
	if(get_entvar(id, var_health) < MAXHEALTH) {
		remove_task(id+TASK_HEAL);
		set_entvar(id, var_viewmodel, v_injectorX);
		set_entvar(id, var_weaponmodel, p_injectorX);
		set_member(id, m_flNextAttack, DELAY_HEAL+0.1);
		play_wpn_anim(id, ANIM_USE);
		set_task(DELAY_HEAL, "use_inj2", id+TASK_HEAL);
	}
}

public use_inj2(id) {
	id -= TASK_HEAL;

	if(get_entvar(id, var_deadflag) == DEAD_NO) {
		new weapon = get_member(id, m_pActiveItem);
		shpr_ammo[id]--;
		set_hp(id);
		ExecuteHamB(Ham_Item_Deploy, weapon);
	}
}

public fw_Item_Holstered_Post(weapon) {
	if(!is_entity(weapon))
		return HAM_IGNORED;

	new id = get_member(weapon, m_pPlayer);
	
	remove_task(id+TASK_HEAL);
	return HAM_IGNORED;
}

stock set_hp(plr) {
	new Float:health = get_entvar(plr, var_health);

	if(health < MAXHEALTH) {
		new Float: newhealth = (health + HEAL > MAXHEALTH) ? MAXHEALTH:health + HEAL;
		set_entvar(plr, var_health, newhealth);
	#if defined SOUND_FROM_R
		rh_emit_sound2(plr, 0, CHAN_BODY, heal_sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	#else
		rg_send_audio(plr, heal_sound, PITCH_NORM);
	#endif
	#if defined MSG_REMAINS
		static postfix[3]; get_postfix(shpr_ammo[plr], postfix);
		client_print_color(plr, print_team_red, MSG_REMAINS, newhealth-health, shpr_ammo[plr], postfix);
	#endif
	}
}

stock get_postfix(count, postfix[3]) {
	switch(count) {
		case 1: {
			formatex(postfix, charsmax(postfix), "");
		}
		default: {
			formatex(postfix, charsmax(postfix), "s");
		}
	}
}

stock play_wpn_anim(const Player, const Sequence) {
	set_entvar(Player, var_weaponanim, Sequence);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player);
	write_byte(Sequence);
	write_byte(get_entvar(Player, var_body));
	message_end();
}