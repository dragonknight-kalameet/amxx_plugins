#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

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

const m_flNextAttack = 83;
const m_pActiveItem =	373; 
const OFFSET_LINUX 	= 	5; 

new const v_injectorX[]	= "models/v_injectorX.mdl"; // v_ model
new const p_injectorX[]	= "models/p_injectorX.mdl"; // p_ model

new const heal_sound[]	= { "items/medshot4.wav" };	// Sound

new shpr_ammo[33];
new g_round = 1;

#if defined IMPULSE
new const WEAPONS_NAMES[][] = { "weapon_p228", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" };
#endif

public plugin_init() {	
	register_plugin("Injector X", "1.2", "Deadly|Darkness feat DK.Kalameet");
#if defined IMPULSE
	RegisterHam(Ham_Player_ImpulseCommands, "player", "fw_Impulse");
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
	RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", 1);
	register_event("TextMsg", "ev_Restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	register_event("HLTV", "ev_RoundStart", "a", "1=0", "2=0");
}

public plugin_precache() {
	precache_model(v_injectorX);
	precache_model(p_injectorX);
	precache_sound(heal_sound);
}

public ev_Restart() {
	g_round = 0;
}

public ev_RoundStart() {
	g_round++;
}

public fw_Spawn_Post(id) {
	shpr_ammo[id] = (get_user_flags(id) & FLAG) ? VIP_AMMO:PLR_AMMO;
}
#if defined IMPULSE
public fw_Impulse(id) {
	if(!is_user_alive(id))
		return HAM_IGNORED;

	if(pev(id, pev_impulse) == 100) {
		set_pev(id, pev_impulse, 0);
		use_inj(id);
    }
	return HAM_HANDLED;
}
#endif

#if defined OLD_VERSION
public fw_Drop(id) {
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE;
		
	if(get_user_weapon(id) == CSW_KNIFE) {
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
		
	if(pev(id, pev_health) < MAXHEALTH) {
		remove_task(id+TASK_HEAL);
		set_pev(id, pev_viewmodel2, v_injectorX);
		set_pev(id, pev_weaponmodel2, p_injectorX);
		set_pdata_float(id, m_flNextAttack, DELAY_HEAL+0.1, 5);
		play_wpn_anim(id, ANIM_USE);
		set_task(DELAY_HEAL, "use_inj2", id+TASK_HEAL);
	}
}

public use_inj2(id) {
	id -= TASK_HEAL;

	if(is_user_alive(id)) {
		new weapon = get_pdata_cbase(id , m_pActiveItem, OFFSET_LINUX);
		shpr_ammo[id]--;
		set_hp(id);
		ExecuteHamB(Ham_Item_Deploy, weapon);
	}
}

public fw_Item_Holstered_Post(weapon) {
	if(!pev_valid(weapon))
		return HAM_IGNORED;

	new id = get_pdata_cbase(weapon, 41, 4);
	
	remove_task(id+TASK_HEAL);
	return HAM_IGNORED;
}

stock set_hp(plr) {
	new health = pev(plr, pev_health);

	if(health < MAXHEALTH) {
		new Float: newhealth = (health + HEAL > MAXHEALTH) ? MAXHEALTH:health + HEAL;
		set_pev(plr, pev_health, newhealth);
	#if defined SOUND_FROM_R
		emit_sound(plr, CHAN_BODY, heal_sound, 1.0, ATTN_NORM, 0, PITCH_NORM);
	#else
		PlaySound(plr, plr, heal_sound, PITCH_NORM);
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
	set_pev(Player, pev_weaponanim, Sequence);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player);
	write_byte(Sequence);
	write_byte(pev(Player, pev_body));
	message_end();
}
stock PlaySound(const pReceiver = 0, const pSender = 0, const szSound[], const iPitch = PITCH_NORM, const bool:bReliable = false) {
	static sendAudio;
	
	if(!sendAudio)
		sendAudio = get_user_msgid("SendAudio");
	
	if (bReliable) {
		if (pReceiver) {
			message_begin(MSG_ONE, sendAudio, _, pReceiver);
		}
		else {
			message_begin(MSG_ALL, sendAudio);
		}
	}
	else {
		if (pReceiver) {
			message_begin(MSG_ONE_UNRELIABLE, sendAudio, _, pReceiver);
			}
		else
		{
			message_begin(MSG_BROADCAST, sendAudio);
		}
	}
	write_byte(pSender);
	write_string(szSound);
	write_short(iPitch);
	message_end();
}