
/datum/artifact_effect/forcefield
	effecttype = "forcefield"
	var/list/created_field = list()
	effect_type = 4

/datum/artifact_effect/forcefield/New()
	..()
	trigger = TRIGGER_TOUCH

/datum/artifact_effect/forcefield/ToggleActivate()
	..()
	if(created_field.len)
		for(var/obj/effect/energy_field/F in created_field)
			created_field.Remove(F)
			del F
	else if(holder)
		while(created_field.len < 16)
			var/obj/effect/energy_field/E = new (locate(holder.x,holder.y,holder.z))
			created_field.Add(E)
			E.strength = 1
			E.density = 1
			E.anchored = 1
			E.invisibility = 0
		spawn(10)
			UpdateMove()
	return 1

/datum/artifact_effect/forcefield/process()
	..()
	for(var/obj/effect/energy_field/E in created_field)
		if(E.strength < 1)
			E.Strengthen(0.15)
		else if(E.strength < 5)
			E.Strengthen(0.25)

/datum/artifact_effect/forcefield/UpdateMove()
	if(created_field.len && holder)
		while(created_field.len < 16)
			//for now, just instantly respawn the fields when they get destroyed
			var/obj/effect/energy_field/E = new (locate(holder.x,holder.y,holder))
			created_field.Add(E)
			E.anchored = 1
			E.density = 1
			E.invisibility = 0

		var/obj/effect/energy_field/E = created_field[1]
		E.loc = locate(holder.x + 2,holder.y + 2,holder.z)
		E = created_field[2]
		E.loc = locate(holder.x + 2,holder.y + 1,holder.z)
		E = created_field[3]
		E.loc = locate(holder.x + 2,holder.y,holder.z)
		E = created_field[4]
		E.loc = locate(holder.x + 2,holder.y - 1,holder.z)
		E = created_field[5]
		E.loc = locate(holder.x + 2,holder.y - 2,holder.z)
		E = created_field[6]
		E.loc = locate(holder.x + 1,holder.y + 2,holder.z)
		E = created_field[7]
		E.loc = locate(holder.x + 1,holder.y - 2,holder.z)
		E = created_field[8]
		E.loc = locate(holder.x,holder.y + 2,holder.z)
		E = created_field[9]
		E.loc = locate(holder.x,holder.y - 2,holder.z)
		E = created_field[10]
		E.loc = locate(holder.x - 1,holder.y + 2,holder.z)
		E = created_field[11]
		E.loc = locate(holder.x - 1,holder.y - 2,holder.z)
		E = created_field[12]
		E.loc = locate(holder.x - 2,holder.y + 2,holder.z)
		E = created_field[13]
		E.loc = locate(holder.x - 2,holder.y + 1,holder.z)
		E = created_field[14]
		E.loc = locate(holder.x - 2,holder.y,holder.z)
		E = created_field[15]
		E.loc = locate(holder.x - 2,holder.y - 1,holder.z)
		E = created_field[16]
		E.loc = locate(holder.x - 2,holder.y - 2,holder.z)
