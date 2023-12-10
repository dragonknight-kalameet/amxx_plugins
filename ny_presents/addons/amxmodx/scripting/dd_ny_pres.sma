#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <amxmisc>

#define NAME		"DD_Presents"
#define VERSION		"0.8"
#define AUTHOR		"D|D feat DK.Kalameet"

//Options
#define RESPAWN_TIME	10.0
#define REWARD			random_num(50, 100) // Comment it if there's no reward.
#define RENDER 								// Comment it out so that the models have a glow effect.


#define ITEMS_SKINS	3		// Change only if you edit models


//***********Menu and items***********
new const MENU_TITLE[] = "DK Presents";

new const Menu[][] = {
	"Set",
	"Delete",
	"Delete all",
	"Save",
	"Load^n",
	"\yItem [\w%s\y]"
};

new const Items[][] = 
{
	"Present 1",
	"Present 2",
	"Present 3",
	"Snowman R",
	"Snowman Y",
	"Snowman G"
};

#if defined RENDER
new const g_render[][3] = 
{
	{255, 255, 0},
	{255, 255, 255},
	{0, 255, 255},
	{255, 200, 200},
	{255, 255, 150},
	{100, 255, 127},
};
#endif
// Resources
new const g_decore_model[][] = 
{
	"models/by_dk/dk_present.mdl",
	"models/by_dk/dk_snowman_sp.mdl"
};

new const exp_sound[] = "by_dk/ny_exp_sound.wav";
new const SPRITE_EXPLODE[] = "sprites/by_dk/ny_exp.spr";

new const Float: sizes[4][3] = {
	{-20.0, -20.0, 0.0},
	{20.0, 20.0, 33.0},
	{-5.0, -5.0, 0.0},
	{5.0, 5.0, 58.0}
};

new const g_class[] = "ny_decor";

const OFFSET_MONEY  =    115;
const OFFSET_LINUX  =    5;

new g_szConfigFile[128];

new spriteexpl;

new type_item[33];

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR)
	register_clcmd( "say /presents",  "OpenMenu");
	register_event("HLTV", "NewRound", "a", "1=0", "2=0");
}
	
public plugin_precache() 
{
	for(new i = 0; i < sizeof g_decore_model; i++)
		precache_model(g_decore_model[i])
	spriteexpl = precache_model(SPRITE_EXPLODE);
	precache_sound(exp_sound)
}

public plugin_cfg( ) 
{
	new g_LoadDir[81]
	get_configsdir(g_LoadDir, charsmax( g_LoadDir ))

	formatex(g_LoadDir, charsmax( g_LoadDir ), "%s/DD_NY", g_LoadDir)

	if(!dir_exists( g_LoadDir )) {
		mkdir(g_LoadDir);
	}
	new mapname[32]
	get_mapname(mapname, charsmax(mapname));
	formatex(g_szConfigFile, charsmax( g_szConfigFile), "%s/%s.ini", g_LoadDir, mapname);
	set_task(0.5, "read_coord")
}

public create_pres(id)
{
	if(~get_user_flags(id) & ADMIN_RCON)
		return;
		
	new iOrigin[3], Float: fOrigin[3], Float:angles[3];
	
	pev(id, pev_angles, angles) 

	get_user_origin( id, iOrigin, 3 );
	IVecFVec(iOrigin, fOrigin);
	spawn_present(fOrigin, angles[1] + 90.0, type_item[id])
}

public read_coord()
{
	if(!file_exists( g_szConfigFile ))
		return;
	new File = fopen(g_szConfigFile, "rt");
	new iLine;
	while(!feof( File ))
	{
		new szText[128]
		fgets(File, szText, charsmax( szText ))

		trim( szText )
			
		++iLine
					
		if(!strlen( szText ) || szText[0] == ';')
			continue

		new szParse[4][17], Number[2];
		parse(szText, 
			szParse[0], 16, 
			szParse[1], 16, 
			szParse[2], 16,
			szParse[3], 16,
			Number, 1
		)
		if(strlen(szParse[0]) && strlen(szParse[1]) && strlen(szParse[2]) && strlen(szParse[3])) {
			new Float:Origin[3];
			for(new i = 0; i < 3; i++) 
			{
				Origin[i] = str_to_float(szParse[i]);
			}
			new Float:Angle = str_to_float(szParse[3]);
			new Decor = str_to_num(Number);
			spawn_present(Origin, Angle, Decor);
		}
	}

	fclose(File);
}

public spawn_present(Float:Origin[3], Float:Angle, decor)
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	
	if(!pev_valid(ent))
		return;
	
	new Float:angles[3];
	static reg;
	Origin[2] += 15.0;
	angles[1] = Angle;

	set_pev(ent, pev_classname, g_class);
	set_model(ent, decor);
	set_pev(ent, pev_iuser1, decor);
	set_visib(ent);

	size_entity(ent, decor);
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	set_pev(ent, pev_origin, Origin);
	set_pev(ent, pev_angles, angles);

	engfunc(EngFunc_DropToFloor, ent);

	if(!reg) {
		RegisterHamFromEntity(Ham_TraceAttack, ent, "fw_TraceAttack", 1);
		RegisterHamFromEntity(Ham_Think, ent, "fw_PresentThink", 1);
		reg = 1;
	}
}
public set_model(ent, decor) {
	engfunc(EngFunc_SetModel, ent, g_decore_model[(decor < ITEMS_SKINS) ? 0:1]);
	set_pev(ent, pev_skin, decor%3);
}
public size_entity(ent, decor)
{
	if(decor < ITEMS_SKINS) {
		engfunc(EngFunc_SetSize, ent, sizes[0], sizes[1]);
	}
	else {
		engfunc(EngFunc_SetSize, ent, sizes[2], sizes[3]);
	}
}

public fw_TraceAttack(ent, attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!pev_valid(ent))
		return HAM_IGNORED;

	create_exp(ent);
	#if defined REWARD
	give_reward(attacker);
	#endif
	set_pev(ent, pev_nextthink, get_gametime() + RESPAWN_TIME);
	return HAM_IGNORED;
}

public fw_PresentThink(ent) {
	if(!pev_valid(ent))
		return HAM_IGNORED;
		
	if(pev(ent, pev_solid) == SOLID_NOT) {
		set_visib(ent);
	}
	
	return HAM_IGNORED;
}
#if defined REWARD
public give_reward(id) {
	new money = fm_cs_get_user_money(id);
	rg_add_account(id, money + REWARD);
}
#endif
public OpenMenu(id) 
{
	if(~get_user_flags(id) & ADMIN_RCON)
		return;
			
	new menu = menu_create(MENU_TITLE, "menu_case");
	new lastItem = charsmax(Menu);
	
	for(new i = 0; i < lastItem; i++) {
		new num[3];
		formatex(num, 2, "%d", i) ;
		menu_additem(menu, Menu[i], num);
	}
	
	new mode[64];
	formatex(mode, charsmax(mode), Menu[lastItem], Items[type_item[id]]);
	menu_additem(menu, mode, "5");
	
	menu_display(id, menu, 0);
}
	 
public menu_case(id, menu, item) 
{
	if(item == MENU_EXIT) 
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[6], iName[64], access, callback;
	menu_item_getinfo(menu, item, access, data, 6, iName, 63, callback);
	new key = str_to_num(data);
		
	switch(key)
	{
		case 0: {
			create_pres(id);
		}

		case 1: {
			remove_present(id);
		}
		case 2: {
			delete_all_presents();
		}
		case 3: {
			Save_Cord();
		}
		case 4: {
			delete_all_presents();
			read_coord();
		}
		case 5: {
			type_item[id] = (type_item[id] < charsmax(Items)) ? type_item[id]+1:0;
		}
	}
	menu_destroy(menu);
	OpenMenu(id);
	return PLUGIN_CONTINUE;
}


public remove_present(id)
{
	new szClassName[32], iEntity = -1;

	new iOrigin[3], Float: fOrigin[3];
	get_user_origin( id, iOrigin, 3 );
	IVecFVec(iOrigin, fOrigin);

	while((iEntity = engfunc(EngFunc_FindEntityInSphere, iEntity, fOrigin, 15.0))) {
		pev(iEntity, pev_classname, szClassName, charsmax(szClassName));

		if(equal( szClassName, g_class)) {
			engfunc(EngFunc_RemoveEntity, iEntity);
		}
	}
}

public create_exp(ent)
{
	if(!pev_valid(ent))
		return;

	emit_sound(ent, CHAN_BODY, exp_sound, 1.0, ATTN_NORM, 0, PITCH_NORM);
	set_pev(ent, pev_solid, SOLID_NOT);
	fm_set_rendering(ent, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
	static Float:flOrigin [3];
	pev(ent, pev_origin, flOrigin);
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, flOrigin[0])
	engfunc(EngFunc_WriteCoord, flOrigin[1])
	engfunc(EngFunc_WriteCoord, flOrigin[2]+50.0)
	write_short(spriteexpl)
	write_byte(12)
	write_byte(200)
	message_end()	

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_DLIGHT)
	engfunc(EngFunc_WriteCoord, flOrigin[0])
	engfunc(EngFunc_WriteCoord, flOrigin[1])
	engfunc(EngFunc_WriteCoord, flOrigin[2])
	write_byte(20)//Radius
	write_byte(250)	// r
	write_byte(120)	// g
	write_byte(120)	// b
	write_byte(15)	//Life
	write_byte(10)
	message_end()
}
public set_visib(ent)
{
	set_pev(ent, pev_solid, SOLID_BBOX);
	#if defined RENDER
	static render;
	render = pev(ent, pev_iuser1);
	
	fm_set_rendering(ent, kRenderFxGlowShell, g_render[render][0], g_render[render][1], g_render[render][2], kRenderNormal, 0);
	#else
	fm_set_rendering(ent, kRenderFxNone, 0,0 ,0 ,kRenderNormal, 0); 
	#endif
}

public NewRound()
{
	set_task(0.33, "set_visib_all");
}

public set_visib_all()
{
	new ent = -1
	while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_class)))
        set_visib(ent);

}

public delete_all_presents()
{
	new ent = -1
	while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_class)))
		engfunc(EngFunc_RemoveEntity, ent);

}

public Save_Cord() 
{
	if(file_exists( g_szConfigFile ))
		delete_file( g_szConfigFile );

	new File = fopen( g_szConfigFile, "wt" );

	if(!File )
		return;

	new Float:Origin[3], Float:Angles[3];
	new ent = -1
	while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_class)))
	{
		pev(ent, pev_origin, Origin);
		pev(ent, pev_angles, Angles);
		fprintf(File, "%f %f %f %f %d^n", Origin[0], Origin[1], Origin[2], Angles[1], pev(ent, pev_iuser1));
	}

	fclose(File);
}
#if defined REWARD
stock rg_add_account(id, money, flash=1) {
     set_pdata_int(id,OFFSET_MONEY, money, OFFSET_LINUX);

     message_begin(MSG_ONE, get_user_msgid("Money"),{0,0,0}, id);
     write_long(money);
     write_byte(flash);
     message_end();
}

stock fm_cs_get_user_money(id)
{
	return get_pdata_int(id,OFFSET_MONEY, OFFSET_LINUX);
}
#endif
stock fm_set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16) {
	new Float:RenderColor[3];
	RenderColor[0] = float(r);
	RenderColor[1] = float(g);
	RenderColor[2] = float(b);

	set_pev(entity, pev_renderfx, fx);
	set_pev(entity, pev_rendercolor, RenderColor);
	set_pev(entity, pev_rendermode, render);
	set_pev(entity, pev_renderamt, float(amount));

	return 1;
}
