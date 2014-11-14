//Spacesuit
//Note: Everything in modules/clothing/spacesuits should have the entire suit grouped together.
//      Meaning the the suit is defined directly after the corrisponding helmet. Just like below!

/obj/item/clothing/head/helmet/space
	name = "Space helmet"
	icon_state = "space"
	desc = "A special helmet designed for work in a hazardous, low-pressure environment."
	flags = FPRINT | TABLEPASS | HEADCOVERSEYES | BLOCKHAIR | HEADCOVERSMOUTH | STOPSPRESSUREDMAGE | THICKMATERIAL | AIRTIGHT
	item_state = "space"
	permeability_coefficient = 0.01
	armor = list(melee = 0, bullet = 0, laser = 0,energy = 0, bomb = 0, bio = 100, rad = 50)
	flags_inv = HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE
	body_parts_covered = HEAD|FACE|EYES
	cold_protection = HEAD
	min_cold_protection_temperature = SPACE_HELMET_MIN_COLD_PROTECTION_TEMPERATURE
	siemens_coefficient = 0.9
	species_restricted = list("exclude","Diona","Vox")

	var/obj/machinery/camera/camera
	var/list/camera_networks
	var/brightness_on
	var/on = 0

/obj/item/clothing/head/helmet/space/attack_self(mob/user)

	if(!camera && camera_networks)
		camera = new /obj/machinery/camera(src)
		camera.network = camera_networks
		cameranet.removeCamera(camera)
		camera.c_tag = user.name
		user << "\blue User scanned as [camera.c_tag]. Camera activated."
		return 1

	else if(brightness_on)

		if(!isturf(user.loc))
			user << "You cannot turn the light on while in this [user.loc]" //To prevent some lighting anomalities.
			return

		on = !on
		icon_state = "rig[on]-[item_color]"

		if(on)
			user.SetLuminosity(user.luminosity + brightness_on)
		else
			user.SetLuminosity(user.luminosity - brightness_on)

		if(istype(user,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = user
			H.update_inv_head()

	else
		return ..(user)

/obj/item/clothing/head/helmet/space/proc/update_light(mob/user)

	if(!brightness_on)
		return

	if(on)
		user.SetLuminosity(user.luminosity - brightness_on)
		SetLuminosity(brightness_on)

/obj/item/clothing/head/helmet/space/equipped(mob/user)
	..()
	update_light(user)

/obj/item/clothing/head/helmet/space/pickup(mob/user)
	..()
	update_light(user)

/obj/item/clothing/head/helmet/space/dropped(mob/user)
	..()
	update_light(user)

/obj/item/clothing/head/helmet/space/examine()
	..()
	if(camera_networks && get_dist(usr,src) <= 1)
		usr << "This helmet has a built-in camera. It's [camera ? "" : "in"]active."

/obj/item/clothing/suit/space
	name = "Space suit"
	desc = "A suit that protects against low pressure environments. \"NSS EXODUS\" is written in large block letters on the back."
	icon_state = "space"
	item_state = "s_suit"
	w_class = 4//bulky item
	gas_transfer_coefficient = 0.01
	permeability_coefficient = 0.02
	flags = FPRINT | TABLEPASS | STOPSPRESSUREDMAGE | THICKMATERIAL
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|FEET|ARMS|HANDS
	allowed = list(/obj/item/device/flashlight,/obj/item/weapon/tank/emergency_oxygen,/obj/item/device/suit_cooling_unit)
	slowdown = 3
	armor = list(melee = 0, bullet = 0, laser = 0,energy = 0, bomb = 0, bio = 100, rad = 50)
	flags_inv = HIDEGLOVES|HIDESHOES|HIDEJUMPSUIT|HIDETAIL
	cold_protection = UPPER_TORSO | LOWER_TORSO | LEGS | FEET | ARMS | HANDS
	min_cold_protection_temperature = SPACE_SUIT_MIN_COLD_PROTECTION_TEMPERATURE
	siemens_coefficient = 0.9
	species_restricted = list("exclude","Diona","Vox")

	var/list/supporting_limbs //If not-null, automatically splints breaks. Checked when removing the suit.

/obj/item/clothing/suit/space/equipped(mob/M)
	check_limb_support()
	..()

/obj/item/clothing/suit/space/dropped()
	check_limb_support()
	..()

// Some space suits are equipped with reactive membranes that support
// broken limbs - at the time of writing, only the ninja suit, but
// I can see it being useful for other suits as we expand them. ~ Z
// The actual splinting occurs in /datum/organ/external/proc/fracture()
/obj/item/clothing/suit/space/proc/check_limb_support()

	// If this isn't set, then we don't need to care.
	if(!supporting_limbs || !supporting_limbs.len)
		return

	var/mob/living/carbon/human/H = src.loc

	// If the holder isn't human, or the holder IS and is wearing the suit, it keeps supporting the limbs.
	if(!istype(H) || H.wear_suit == src)
		return

	// Otherwise, remove the splints.
	for(var/datum/organ/external/E in supporting_limbs)
		E.status &= ~ ORGAN_SPLINTED
	supporting_limbs = list()