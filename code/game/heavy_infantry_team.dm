//STRIKE TEAMS
//Thanks to Kilakk for the admin-button portion of this code.

var/list/infantry_team_members = list()
var/global/send_infantry_team = 0 // Used for automagic response teams
                                   // 'admin_emergency_team' for admin-spawned response teams
var/ert_base_chance = 10 // Default base chance. Will be incremented by increment ERT chance.
var/can_call_ert

/client/proc/infantry_team()
	set name = "Dispatch Heavy Infantry Team"
	set category = "Special Verbs"
	set desc = "Send an emergency response team to the station"

	var/count_observers = 0
	for(var/client/C in clients)
		if(isobserver(C.mob) && !C.holder)
			count_observers++
	var/count_humans = 0
	for(var/client/C in clients)
		if(ishuman(C.mob) && C.mob.stat != DEAD)
			count_humans++
	var/count_aliens = 0
	for(var/client/C in clients)
		if(isalien(C.mob) && C.mob.stat != DEAD)
			count_aliens++

	if(!holder)
		usr << "\red Only administrators may use this command."
		return
	if(!ticker)
		usr << "\red The game hasn't started yet!"
		return
	if(ticker.current_state == 1)
		usr << "\red The round hasn't started yet!"
		return
	if(send_infantry_team)
		usr << "\red Central Command has already dispatched an emergency response team!"
		return
	if(emergency_shuttle.online)
		usr << "\red No. The emergency shuttle has been called."
		return
	if(count_humans > count_aliens)
		// var/confirm = alert(src, "There are more humans than aliens! This is NOT recommended! Are you POSITIVE?","Confirm","Yes","No")
		src << "No. There are more humans than aliens."
		// if(confirm != "Yes")
		return
	if(count_observers < 5)
		// var/confirm2 = alert(src, "There are less than 5 observers! This is NOT recommended! Are you ABSOLUTELY SURE?","Confirm","Yes","No")
		src << "No. There are less than 5 observers."
		// if(confirm2 != "Yes")
		return
	if(alert("FINAL CHANCE - Call the Heavy Infantry Team?",,"Yes","No") != "Yes")
		return
	if(send_infantry_team)
		usr << "\red Looks like somebody beat you to it!"
		return

	message_admins("[key_name_admin(usr)] is dispatching a Heavy Infantry Team.", 1)
	log_admin("[key_name(usr)] used Dispatch Response Team.")
	trigger_armed_infantry_team(1)


client/verb/JoinInfantryTeam()
	set name = "Join Heavy Infantry"
	set category = "IC"

	if(istype(usr,/mob/dead/observer) || istype(usr,/mob/new_player))
		if(!send_infantry_team)
			usr << "No heavy infantry team is currently being sent."
			return
	/*	if(admin_emergency_team)
			usr << "An emergency response team has already been sent."
			return */

		if(jobban_isbanned(usr, "Syndicate") || jobban_isbanned(usr, "Emergency Response Team") || jobban_isbanned(usr, "Military Officer"))
			usr << "<font color=red><b>You are jobbanned from the heavy infantry team!"
			return

		if(infantry_team_members.len > 5) usr << "The heavy infantry team is already full!"


		for (var/obj/effect/landmark/L in landmarks_list) if (L.name == "Commando")
			L.name = null//Reserving the place.
			var/new_name = input(usr, "Pick a name","Name") as null|text
			if(!new_name)//Somebody changed his mind, place is available again.
				L.name = "Commando"
				return
			var/leader_selected = isemptylist(infantry_team_members)
			var/mob/living/carbon/human/new_commando = create_infantry_team(L.loc, leader_selected, new_name)
			del(L)
			new_commando.mind.key = usr.key
			new_commando.key = usr.key

			new_commando << "\blue You are [!leader_selected?"a member":"the <B>LEADER</B>"] of a heavy infantry support team, a powerful element of the Nanotrasen military. The NMV Sulaco is in trouble and you are tasked with assisting marine forces there."
			new_commando << "<b>You should first gear up and discuss a plan with your team. More members may be joining, don't move out before you're ready."
			if(!leader_selected)
				new_commando << "<b>As member of the heavy infantry team, you answer only to your leader and CentComm officials.</b>"
			else
				new_commando << "<b>As leader of the heavy infantry team, you answer only to CentComm, and have authority to override the Commander where it is necessary to achieve your mission goals. It is recommended that you attempt to cooperate with the Commander where possible, however."
			return

	else
		usr << "You need to be an observer or new player to use this."

// returns a number of dead players in %
proc/percentage_dead()
	var/total = 0
	var/deadcount = 0
	for(var/mob/living/carbon/human/H in mob_list)
		if(H.client) // Monkeys and mice don't have a client, amirite?
			if(H.stat == 2) deadcount++
			total++

	if(total == 0) return 0
	else return round(100 * deadcount / total)

// counts the number of antagonists in %
proc/percentage_antagonists()
	var/total = 0
	var/antagonists = 0
	for(var/mob/living/carbon/human/H in mob_list)
		if(is_special_character(H) >= 1)
			antagonists++
		total++

	if(total == 0) return 0
	else return round(100 * antagonists / total)

// Increments the ERT chance automatically, so that the later it is in the round,
// the more likely an ERT is to be able to be called.
proc/increment_ert_chance()
	while(send_infantry_team == 0) // There is no ERT at the time.
		if(get_security_level() == "green")
			ert_base_chance += 1
		if(get_security_level() == "blue")
			ert_base_chance += 2
		if(get_security_level() == "red")
			ert_base_chance += 3
		if(get_security_level() == "delta")
			ert_base_chance += 10           // Need those big guns
		sleep(600 * 3) // Minute * Number of Minutes


proc/trigger_armed_infantry_team(var/force = 0)
	if(!can_call_ert && !force)
		return
	if(send_infantry_team)
		return

	var/send_team_chance = ert_base_chance // Is incremented by increment_ert_chance.
	send_team_chance += 2*percentage_dead() // the more people are dead, the higher the chance
	send_team_chance += percentage_antagonists() // the more antagonists, the higher the chance
	send_team_chance = min(send_team_chance, 100)

	if(force) send_team_chance = 100

	command_alert("A heavy infantry team has been requested and is preparing to be dispatched to the NMV Sulaco.", "Nanotrasen Special Forces")

	can_call_ert = 0 // Only one call per round, gentleman.
	send_infantry_team = 1
	score_hit_called = 1

	sleep(600 * 5)
	send_infantry_team = 0 // Can no longer join the ERT.

/*	var/area/security/nuke_storage/nukeloc = locate()//To find the nuke in the vault
	var/obj/machinery/nuclearbomb/nuke = locate() in nukeloc
	if(!nuke)
		nuke = locate() in world
	var/obj/item/weapon/paper/P = new
	P.info = "Your orders, Commander, are to use all means necessary to return the station to a survivable condition.<br>To this end, you have been provided with the best tools we can give in the three areas of Medicine, Engineering, and Security. The nuclear authorization code is: <b>[ nuke ? nuke.r_code : "AHH, THE NUKE IS GONE!"]</b>. Be warned, if you detonate this without good reason, we will hold you to account for damages. Memorise this code, and then burn this message."
	P.name = "Emergency Nuclear Code, and ERT Orders"
	for (var/obj/effect/landmark/A in world)
		if (A.name == "nukecode")
			P.loc = A.loc
			del(A)
			continue
*/

/client/proc/create_infantry_team(obj/spawn_location, leader_selected = 0, commando_name)

	//usr << "\red ERT has been temporarily disabled. Talk to a coder."
	//return

	var/mob/living/carbon/human/M = new(null)
	infantry_team_members |= M

	//todo: god damn this.
	//make it a panel, like in character creation
	var/new_facial = input("Please select facial hair color.", "Character Generation") as color
	if(new_facial)
		M.r_facial = hex2num(copytext(new_facial, 2, 4))
		M.g_facial = hex2num(copytext(new_facial, 4, 6))
		M.b_facial = hex2num(copytext(new_facial, 6, 8))

	var/new_hair = input("Please select hair color.", "Character Generation") as color
	if(new_facial)
		M.r_hair = hex2num(copytext(new_hair, 2, 4))
		M.g_hair = hex2num(copytext(new_hair, 4, 6))
		M.b_hair = hex2num(copytext(new_hair, 6, 8))

	var/new_eyes = input("Please select eye color.", "Character Generation") as color
	if(new_eyes)
		M.r_eyes = hex2num(copytext(new_eyes, 2, 4))
		M.g_eyes = hex2num(copytext(new_eyes, 4, 6))
		M.b_eyes = hex2num(copytext(new_eyes, 6, 8))

	var/new_tone = input("Please select skin tone level: 1-220 (1=albino, 35=caucasian, 150=black, 220='very' black)", "Character Generation")  as text

	if (!new_tone)
		new_tone = 35
	M.s_tone = max(min(round(text2num(new_tone)), 220), 1)
	M.s_tone =  -M.s_tone + 35

	// hair
	var/list/all_hairs = typesof(/datum/sprite_accessory/hair) - /datum/sprite_accessory/hair
	var/list/hairs = list()

	// loop through potential hairs
	for(var/x in all_hairs)
		var/datum/sprite_accessory/hair/H = new x // create new hair datum based on type x
		hairs.Add(H.name) // add hair name to hairs
		del(H) // delete the hair after it's all done

	var/new_hstyle = input(usr, "Select a hair style", "Grooming")  as null|anything in hair_styles_list
	if(new_hstyle)
		M.h_style = new_hstyle

	// facial hair
	var/new_fstyle = input(usr, "Select a facial hair style", "Grooming")  as null|anything in facial_hair_styles_list
	if(new_fstyle)
		M.f_style = new_fstyle


	var/new_gender = alert(usr, "Please select gender.", "Character Generation", "Male", "Female")
	if (new_gender)
		if(new_gender == "Male")
			M.gender = MALE
		else
			M.gender = FEMALE
	//M.rebuild_appearance()
	M.update_hair()
	M.update_body()
	M.check_dna(M)

	M.real_name = commando_name
	M.name = commando_name
	M.age = !leader_selected ? rand(23,35) : rand(35,45)

	M.dna.ready_dna(M)//Creates DNA.

	//Creates mind stuff.
	M.mind = new
	M.mind.current = M
	M.mind.original = M
	M.mind.assigned_role = "MODE"
	M.mind.special_role = "Heavy Infantry"
	if(!(M.mind in ticker.minds))
		ticker.minds += M.mind//Adds them to regular mind list.
	M.loc = spawn_location
	M.equip_infantry_team(leader_selected)
	return M

/mob/living/carbon/human/proc/equip_infantry_team(leader_selected = 0)

	//Special radio setup
	equip_to_slot_or_del(new /obj/item/device/radio/headset/mcom(src), slot_l_ear)

	//Replaced with new ERT uniform
	equip_to_slot_or_del(new /obj/item/clothing/under/rank/centcom_officer(src), slot_w_uniform)
	equip_to_slot_or_del(new /obj/item/clothing/shoes/marine(src), slot_shoes)
	equip_to_slot_or_del(new /obj/item/clothing/gloves/swat(src), slot_gloves)
	equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(src), slot_glasses)
	equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(src), slot_back)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Heavy Infantry Team[leader_selected ? " Leader" : ""]"
	W.registered_name = real_name
	W.name = "[real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	W.access += get_all_marine_accesses()
	equip_to_slot_or_del(W, slot_wear_id)

	return 1

//debug verb (That is horribly coded, LEAVE THIS OFF UNLESS PRIVATELY TESTING. Seriously.
/*client/verb/ResponseTeam()
	set category = "Admin"
	if(!send_emergency_team)
		send_emergency_team = 1*/