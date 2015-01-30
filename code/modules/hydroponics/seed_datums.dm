var/global/list/plant_sprites = list()         // List of all harvested product sprites.
var/global/list/plant_product_sprites = list() // List of all growth sprites plus number of growth stages.

// Debug for testing seed genes.
/client/proc/show_plant_genes()
	set category = "Debug"
	set name = "Show Plant Genes"
	set desc = "Prints the round's plant gene masks."

	if(!holder)	return

	if(!gene_tag_masks)
		usr << "Gene masks not set."
		return

	for(var/mask in gene_tag_masks)
		usr << "[mask]: [gene_tag_masks[mask]]"

// Predefined/roundstart varieties use a string key to make it
// easier to grab the new variety when mutating. Post-roundstart
// and mutant varieties use their uid converted to a string instead.
// Looks like shit but it's sort of necessary.

proc/populate_seed_list()

	// Build the icon lists.
	for(var/icostate in icon_states('icons/obj/hydroponics_growing.dmi'))
		var/split = findtext(icostate,"-")
		if(!split)
			// invalid icon_state
			continue

		var/ikey = copytext(icostate,(split+1))
		if(ikey == "dead")
			// don't count dead icons
			continue
		ikey = text2num(ikey)
		var/base = copytext(icostate,1,split)

		if(!(plant_sprites[base]) || (plant_sprites[base]<ikey))
			plant_sprites[base] = ikey

	for(var/icostate in icon_states('icons/obj/hydroponics_products.dmi'))
		plant_product_sprites |= icostate

	// Populate the global seed datum list.
	for(var/type in typesof(/datum/seed)-/datum/seed)
		var/datum/seed/S = new type
		seed_types[S.name] = S
		S.uid = "[seed_types.len]"
		S.roundstart = 1

	// Make sure any seed packets that were mapped in are updated
	// correctly (since the seed datums did not exist a tick ago).
	for(var/obj/item/seeds/S in world)
		S.update_seed()

	//Might as well mask the gene types while we're at it.
	var/list/gene_tags = list("products","consumption","environment","resistance","vigour","flowers")
	var/list/used_masks = list()

	while(gene_tags && gene_tags.len)
		var/gene_tag = pick(gene_tags)
		var/gene_mask = "[num2hex(rand(0,255))]"

		while(gene_mask in used_masks)
			gene_mask = "[num2hex(rand(0,255))]"

		used_masks += gene_mask
		gene_tags -= gene_tag
		gene_tag_masks[gene_tag] = gene_mask

/datum/plantgene
	var/genetype    // Label used when applying trait.
	var/list/values // Values to copy into the target seed datum.

/datum/seed

	//Tracking.
	var/uid                        // Unique identifier.
	var/name                       // Index for global list.
	var/seed_name                  // Plant name for seed packet.
	var/seed_noun = "seeds"        // Descriptor for packet.
	var/display_name               // Prettier name.
	var/roundstart                 // If set, seed will not display variety number.
	var/mysterious                 // Only used for the random seed packets.

	// Output.
	var/list/products              // Possible fruit/other product paths.
	var/list/mutants               // Possible predefined mutant varieties, if any.
	var/list/chems                 // Chemicals that plant produces in products/injects into victim.
	var/list/consume_gasses        // The plant will absorb these gasses during its life.
	var/list/exude_gasses          // The plant will exude these gasses during its life.

	//Tolerances.
	var/requires_nutrients = 1      // The plant can starve.
	var/nutrient_consumption = 0.25 // Plant eats this much per tick.
	var/requires_water = 1          // The plant can become dehydrated.
	var/water_consumption = 3       // Plant drinks this much per tick.
	var/ideal_heat = 293            // Preferred temperature in Kelvin.
	var/heat_tolerance = 20         // Departure from ideal that is survivable.
	var/ideal_light = 8             // Preferred light level in luminosity.
	var/light_tolerance = 5         // Departure from ideal that is survivable.
	var/toxins_tolerance = 5        // Resistance to poison.
	var/lowkpa_tolerance = 25       // Low pressure capacity.
	var/highkpa_tolerance = 200     // High pressure capacity.
	var/pest_tolerance = 5          // Threshold for pests to impact health.
	var/weed_tolerance = 5          // Threshold for weeds to impact health.

	//General traits.
	var/endurance = 100             // Maximum plant HP when growing.
	var/yield = 0                   // Amount of product.
	var/lifespan = 0                // Time before the plant dies.
	var/maturation = 0              // Time taken before the plant is mature.
	var/production = 0              // Time before harvesting can be undertaken again.
	var/growth_stages = 6           // Number of stages the plant passes through before it is mature.
	var/harvest_repeat = 0          // If 1, this plant will fruit repeatedly..
	var/potency = 1                 // General purpose plant strength value.
	var/spread = 0                  // 0 limits plant to tray, 1 = creepers, 2 = vines.
	var/carnivorous = 0             // 0 = none, 1 = eat pests in tray, 2 = eat living things  (when a vine).
	var/parasite = 0                // 0 = no, 1 = gain health from weed level.
	var/immutable = 0               // If set, plant will never mutate. If -1, plant is highly mutable.
	var/alter_temp                  // If set, the plant will periodically alter local temp by this amount.

	// Cosmetics.
	var/plant_icon                  // Icon to use for the plant growing in the tray.
	var/plant_colour = "#6EF86A"    // Colour of the plant icon.
	var/product_icon                // Icon to use for fruit coming from this plant.
	var/product_colour              // Colour to apply to product icon.
	var/packet_icon = "seed"        // Icon to use for physical seed packet item.
	var/biolum                      // Plant is bioluminescent.
	var/biolum_colour               // The colour of the plant's radiance.
	var/flowers                     // Plant has a flower overlay.
	var/flower_icon = "vine_fruit"  // Which overlay to use.
	var/flower_colour               // Which colour to use.

	// Special traits.
	var/produces_power              // Can be used to make a battery.
	var/juicy                       // When thrown, causes a splatter decal.
	var/stings						// Can cause damage/inject reagents when thrown or handled.
	var/explosive                   // When thrown, acts as a grenade.
	var/teleporting                 // Uses the bluespace tomato effect.
	var/splat_type = /obj/effect/decal/cleanable/fruit_smudge

// Does brute damage to a target.
/datum/seed/proc/do_thorns(var/mob/living/carbon/human/target, var/obj/item/fruit, var/target_limb)

	if(!istype(target) || !carnivorous)
		return

	if(!target_limb) target_limb = pick("l_foot","r_foot","l_leg","r_leg","l_hand","r_hand","l_arm", "r_arm","head","chest","groin")
	var/datum/organ/external/affecting = target.get_organ(target_limb)
	var/damage = 0

	if(carnivorous)
		if(carnivorous == 2)
			if(affecting)
				target << "<span class='danger'>\The [fruit]'s thorns pierce your [affecting.display_name] greedily!</span>"
			else
				target << "<span class='danger'>\The [fruit]'s thorns pierce your flesh greedily!</span>"
			damage = potency/2
		else
			if(affecting)
				target << "<span class='danger'>\The [fruit]'s thorns dig deeply into your [affecting.display_name]!</span>"
			else
				target << "<span class='danger'>\The [fruit]'s thorns dig deeply into your flesh!</span>"
			damage = potency/5
	else
		return

	if(affecting)
		affecting.take_damage(damage, 0)
		affecting.add_autopsy_data("Thorns",damage)
	else
		target.adjustBruteLoss(damage)
	target.UpdateDamageIcon()
	target.updatehealth()

// Adds reagents to a target.
/datum/seed/proc/do_sting(var/mob/living/carbon/human/target, var/obj/item/fruit)
	if(!stings)
		return
	if(chems && chems.len)
		target << "<span class='danger'>You are stung by \the [fruit]!</span>"
		for(var/rid in chems)
			var/injecting = min(5,max(1,potency/5))
			target.reagents.add_reagent(rid,injecting)

//Splatter a turf.
/datum/seed/proc/splatter(var/turf/T,var/obj/item/thrown)
	if(splat_type)
		var/obj/effect/decal/cleanable/fruit_smudge/splat = new splat_type(T)
		splat.name = "[thrown.name] [pick("smear","smudge","splatter")]"
		if(biolum)
			if(biolum_colour)
				splat.l_color = biolum_colour
			splat.SetLuminosity(biolum)
		if(istype(splat))
			if(product_colour)
				splat.color = product_colour

	if(chems)
		for(var/mob/living/M in T.contents)
			if(!M.reagents)
				continue
			for(var/chem in chems)
				var/injecting = min(5,max(1,potency/3))
				M.reagents.add_reagent(chem,injecting)

//Applies an effect to a target atom.
/datum/seed/proc/thrown_at(var/obj/item/thrown,var/atom/target)

	var/splatted
	var/turf/origin_turf = get_turf(target)

	if(explosive)

		var/flood_dist = min(10,max(1,potency/15))
		var/list/open_turfs = list()
		var/list/closed_turfs = list()
		var/list/valid_turfs = list()
		open_turfs |= origin_turf

		// Flood fill to get affected turfs.
		while(open_turfs.len)
			var/turf/T = pick(open_turfs)
			open_turfs -= T
			closed_turfs |= T
			valid_turfs |= T

			for(var/dir in alldirs)
				var/turf/neighbor = get_step(T,dir)
				if(!neighbor || (neighbor in closed_turfs) || (neighbor in open_turfs))
					continue
				if(neighbor.density || get_dist(neighbor,origin_turf) > flood_dist || istype(neighbor,/turf/space))
					closed_turfs |= neighbor
					continue
				// Check for windows.
				var/no_los
				for(var/turf/target_turf in getline(origin_turf,neighbor))
					if(target_turf.density)
						no_los = 1
						break

				if(!no_los)
					var/los_dir = get_dir(neighbor,origin_turf)
					var/list/blocked = list()
					for(var/obj/machinery/door/D in neighbor.contents)
						if(istype(D,/obj/machinery/door/window))
							blocked |= D.dir
						else
							if(D.density)
								no_los = 1
								break
					for(var/obj/structure/window/W in neighbor.contents)
						if(W.is_fulltile())
							no_los = 1
							break
						blocked |= W.dir
					if(!no_los)
						switch(los_dir)
							if(NORTHEAST)
								if((NORTH in blocked) && (EAST in blocked))
									no_los = 1
							if(SOUTHEAST)
								if((SOUTH in blocked) && (EAST in blocked))
									no_los = 1
							if(NORTHWEST)
								if((NORTH in blocked) && (WEST in blocked))
									no_los = 1
							if(SOUTHWEST)
								if((SOUTH in blocked) && (WEST in blocked))
									no_los = 1
							else
								if(los_dir in blocked)
									no_los = 1
				if(no_los)
					closed_turfs |= neighbor
					continue
				open_turfs |= neighbor

		for(var/turf/T in valid_turfs)
			for(var/mob/living/M in T.contents)
				apply_special_effect(M)
			splatter(T,thrown)
		origin_turf.visible_message("<span class='danger'>The [thrown.name] violently explodes against [target]!</span>")
		del(thrown)
		return

	if(istype(target,/mob/living))
		splatted = apply_special_effect(target,thrown)
	else if(istype(target,/turf))
		splatted = 1
		for(var/mob/living/M in target.contents)
			apply_special_effect(M)

	if(juicy && splatted)
		splatter(origin_turf,thrown)
		origin_turf.visible_message("<span class='danger'>The [thrown.name] splatters against [target]!</span>")
		del(thrown)

/datum/seed/proc/handle_environment(var/turf/current_turf, var/datum/gas_mixture/environment)

	var/health_change = 0
	// Handle gas consumption.
	if(consume_gasses && consume_gasses.len)
		var/missing_gas = 0
		for(var/gas in consume_gasses)
			if(environment && environment.gas && environment.gas[gas] && \
			 environment.gas[gas] >= consume_gasses[gas])
				environment.adjust_gas(gas,-consume_gasses[gas],1)
			else
				missing_gas++

		if(missing_gas > 0)
			health_change += missing_gas * HYDRO_SPEED_MULTIPLIER

	// Process it.
	var/pressure = environment.return_pressure()
	if(pressure < lowkpa_tolerance || pressure > highkpa_tolerance)
		health_change += rand(1,3) * HYDRO_SPEED_MULTIPLIER

	if(abs(environment.temperature - ideal_heat) > heat_tolerance)
		health_change += rand(1,3) * HYDRO_SPEED_MULTIPLIER

	// Handle gas production.
	if(exude_gasses && exude_gasses.len)
		for(var/gas in exude_gasses)
			environment.adjust_gas(gas, max(1,round((exude_gasses[gas]*potency)/exude_gasses.len)))

	// Handle light requirements.
	var/area/A = get_area(current_turf)
	if(A)
		var/light_available
		if(A.lighting_use_dynamic)
			light_available = max(0,min(10,current_turf.lighting_lumcount)-5)
		else
			light_available =  5
		if(abs(light_available - ideal_light) > light_tolerance)
			health_change += rand(1,3) * HYDRO_SPEED_MULTIPLIER

	return health_change

/datum/seed/proc/apply_special_effect(var/mob/living/target,var/obj/item/thrown)

	var/impact = 1
	do_sting(target,thrown)
	do_thorns(target,thrown)

	// Bluespace tomato code copied over from grown.dm.
	if(teleporting)

		//Plant potency determines radius of teleport.
		var/outer_teleport_radius = potency/5
		var/inner_teleport_radius = potency/15

		var/list/turfs = list()
		if(inner_teleport_radius > 0)
			for(var/turf/T in orange(target,outer_teleport_radius))
				if(get_dist(target,T) >= inner_teleport_radius)
					turfs |= T

		if(turfs.len)
			// Moves the mob, causes sparks.
			var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
			s.set_up(3, 1, get_turf(target))
			s.start()
			var/turf/picked = get_turf(pick(turfs))                      // Just in case...
			new/obj/effect/decal/cleanable/molten_item(get_turf(target)) // Leave a pile of goo behind for dramatic effect...
			target.loc = picked                                          // And teleport them to the chosen location.

			impact = 1

	return impact

//Creates a random seed. MAKE SURE THE LINE HAS DIVERGED BEFORE THIS IS CALLED.
/datum/seed/proc/randomize()

	roundstart = 0
	seed_name = "strange plant"     // TODO: name generator.
	display_name = "strange plants" // TODO: name generator.
	mysterious = 1

	seed_noun = pick("spores","nodes","cuttings","seeds")
	products = list(pick(typesof(/obj/item/weapon/reagent_containers/food/snacks/grown)-/obj/item/weapon/reagent_containers/food/snacks/grown))
	potency = rand(5,30)

	packet_icon = "seed-replicapod"
	product_icon = pick(plant_product_sprites)
	plant_icon = pick(plant_sprites)
	plant_colour   = "#[pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))]"
	product_colour = "#[pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))]"
	update_growth_stages()

	if(prob(20))
		harvest_repeat = 1

	if(prob(15))
		if(prob(15))
			juicy = 2
		else
			juicy = 1

	if(prob(5))
		stings = 1

	if(prob(5))
		produces_power = 1

	if(prob(1))
		explosive = 1
	else if(prob(1))
		teleporting = 1

	if(prob(5))
		consume_gasses = list()
		var/gas = pick("oxygen","nitrogen","phoron","carbon_dioxide")
		consume_gasses[gas] = rand(3,9)

	if(prob(5))
		exude_gasses = list()
		var/gas = pick("oxygen","nitrogen","phoron","carbon_dioxide")
		exude_gasses[gas] = rand(3,9)

	chems = list()
	if(prob(80))
		chems["nutriment"] = list(rand(1,10),rand(10,20))

	var/additional_chems = rand(0,5)

	if(additional_chems)
		var/list/possible_chems = list(
			"bicaridine",
			"hyperzine",
			"cryoxadone",
			"blood",
			"water",
			"potassium",
			"plasticide",
			"mutationtoxin",
			"amutationtoxin",
			"inaprovaline",
			"space_drugs",
			"paroxetine",
			"mercury",
			"sugar",
			"radium",
			"ryetalyn",
			"alkysine",
			"thermite",
			"tramadol",
			"cryptobiolin",
			"dermaline",
			"dexalin",
			"phoron",
			"synaptizine",
			"impedrezene",
			"hyronalin",
			"peridaxon",
			"toxin",
			"rezadone",
			"ethylredoxrazine",
			"slimejelly",
			"cyanide",
			"mindbreaker",
			"stoxin"
			)

		for(var/x=1;x<=additional_chems;x++)
			if(!possible_chems.len)
				break
			var/new_chem = pick(possible_chems)
			possible_chems -= new_chem
			chems[new_chem] = list(rand(1,10),rand(10,20))

	if(prob(90))
		requires_nutrients = 1
		nutrient_consumption = rand(100)*0.1
	else
		requires_nutrients = 0

	if(prob(90))
		requires_water = 1
		water_consumption = rand(10)
	else
		requires_water = 0

	ideal_heat =       rand(100,400)
	heat_tolerance =   rand(10,30)
	ideal_light =      rand(2,10)
	light_tolerance =  rand(2,7)
	toxins_tolerance = rand(2,7)
	pest_tolerance =   rand(2,7)
	weed_tolerance =   rand(2,7)
	lowkpa_tolerance = rand(10,50)
	highkpa_tolerance = rand(100,300)

	if(prob(5))
		alter_temp = rand(-5,5)

	if(prob(1))
		immutable = -1

	var/carnivore_prob = rand(100)
	if(carnivore_prob < 5)
		carnivorous = 2
	else if(carnivore_prob < 10)
		carnivorous = 1

	if(prob(10))
		parasite = 1

	var/vine_prob = rand(100)
	if(vine_prob < 5)
		spread = 2
	else if(vine_prob < 10)
		spread = 1

	if(prob(5))
		biolum = 1
		biolum_colour = "#[pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))]"

	endurance = rand(60,100)
	yield = rand(3,15)
	maturation = rand(5,15)
	production = maturation + rand(2,5)
	lifespan = production + rand(5,10)

//Returns a key corresponding to an entry in the global seed list.
/datum/seed/proc/get_mutant_variant()
	if(!mutants || !mutants.len || immutable > 0) return 0
	return pick(mutants)

//Mutates the plant overall (randomly).
/datum/seed/proc/mutate(var/degree,var/turf/source_turf)

	if(!degree || immutable > 0) return

	source_turf.visible_message("<span class='notice'>\The [display_name] quivers!</span>")

	//This looks like shit, but it's a lot easier to read/change this way.
	var/total_mutations = rand(1,1+degree)
	for(var/i = 0;i<total_mutations;i++)
		switch(rand(0,12))
			if(0) //Plant cancer!
				lifespan = max(0,lifespan-rand(1,5))
				endurance = max(0,endurance-rand(10,20))
				source_turf.visible_message("<span class='danger'>\The [display_name] withers rapidly!</span>")
			if(1)
				nutrient_consumption =      max(0,  min(5,   nutrient_consumption + rand(-(degree*0.1),(degree*0.1))))
				water_consumption =         max(0,  min(50,  water_consumption    + rand(-degree,degree)))
				juicy =  (juicy ? 0 : 1)
				stings = (stings ? 0 : 1)
			if(2)
				ideal_heat =                max(70, min(800, ideal_heat           + (rand(-5,5)   * degree)))
				heat_tolerance =            max(70, min(800, heat_tolerance       + (rand(-5,5)   * degree)))
				lowkpa_tolerance =          max(0,  min(80,  lowkpa_tolerance     + (rand(-5,5)   * degree)))
				highkpa_tolerance =         max(110, min(500,highkpa_tolerance    + (rand(-5,5)   * degree)))
				explosive =                 1
			if(3)
				ideal_light =               max(0,  min(30,  ideal_light          + (rand(-1,1)   * degree)))
				light_tolerance =           max(0,  min(10,  light_tolerance      + (rand(-2,2)   * degree)))
			if(4)
				toxins_tolerance =          max(0,  min(10,  weed_tolerance       + (rand(-2,2)   * degree)))
			if(5)
				weed_tolerance  =           max(0,  min(10,  weed_tolerance       + (rand(-2,2)   * degree)))
				if(prob(degree*5))
					carnivorous =           max(0,  min(2,   carnivorous          + rand(-degree,degree)))
					if(carnivorous)
						source_turf.visible_message("<span class='notice'>\The [display_name] shudders hungrily.</span>")
			if(6)
				weed_tolerance  =           max(0,  min(10,  weed_tolerance       + (rand(-2,2)   * degree)))
				if(prob(degree*5))          parasite = !parasite

			if(7)
				lifespan =                  max(10, min(30,  lifespan             + (rand(-2,2)   * degree)))
				if(yield != -1) yield =     max(0,  min(10,  yield                + (rand(-2,2)   * degree)))
			if(8)
				endurance =                 max(10, min(100, endurance            + (rand(-5,5)   * degree)))
				production =                max(1,  min(10,  production           + (rand(-1,1)   * degree)))
				potency =                   max(0,  min(200, potency              + (rand(-20,20) * degree)))
				if(prob(degree*5))
					spread =                max(0,  min(2,   spread               + rand(-1,1)))
					source_turf.visible_message("<span class='notice'>\The [display_name] spasms visibly, shifting in the tray.</span>")
			if(9)
				maturation =                max(0,  min(30,  maturation      + (rand(-1,1)   * degree)))
				if(prob(degree*5))
					harvest_repeat = !harvest_repeat
			if(10)
				if(prob(degree*2))
					biolum = !biolum
					if(biolum)
						source_turf.visible_message("<span class='notice'>\The [display_name] begins to glow!</span>")
						if(prob(degree*2))
							biolum_colour = "#[pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))]"
							source_turf.visible_message("<span class='notice'>\The [display_name]'s glow </span><font color='[biolum_colour]'>changes colour</font>!")
					else
						source_turf.visible_message("<span class='notice'>\The [display_name]'s glow dims...</span>")
			if(11)
				if(prob(degree*2))
					flowers = !flowers
					if(flowers)
						source_turf.visible_message("<span class='notice'>\The [display_name] sprouts a bevy of flowers!</span>")
						if(prob(degree*2))
							flower_colour = "#[pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))]"
						source_turf.visible_message("<span class='notice'>\The [display_name]'s flowers </span><font=[flower_colour]>changes colour</font>!")
					else
						source_turf.visible_message("<span class='notice'>\The [display_name]'s flowers wither and fall off.</span>")
			if(12)
				teleporting = 1

	return

//Mutates a specific trait/set of traits.
/datum/seed/proc/apply_gene(var/datum/plantgene/gene)

	if(!gene || !gene.values || immutable > 0) return

	switch(gene.genetype)

		//Splicing products has some detrimental effects on yield and lifespan.
		if("products")

			if(gene.values.len < 6) return

			if(yield > 0)     yield =     max(1,round(yield*0.85))
			if(endurance > 0) endurance = max(1,round(endurance*0.85))
			if(lifespan > 0)  lifespan =  max(1,round(lifespan*0.85))

			if(!products) products = list()
			products |= gene.values[1]

			if(!chems) chems = list()

			var/list/gene_value = gene.values[2]
			for(var/rid in gene_value)

				var/list/gene_chem = gene_value[rid]

				if(!chems[rid])
					chems[rid] = gene_chem.Copy()
					continue

				for(var/i=1;i<=gene_chem.len;i++)

					if(isnull(gene_chem[i])) gene_chem[i] = 0

					if(chems[rid][i])
						chems[rid][i] = max(1,round((gene_chem[i] + chems[rid][i])/2))
					else
						chems[rid][i] = gene_chem[i]

			var/list/new_gasses = gene.values[3]
			if(islist(new_gasses))
				if(!exude_gasses) exude_gasses = list()
				exude_gasses |= new_gasses
				for(var/gas in exude_gasses)
					exude_gasses[gas] = max(1,round(exude_gasses[gas]*0.8))

			alter_temp =           gene.values[4]
			potency =              gene.values[5]
			harvest_repeat =       gene.values[6]
			produces_power =       gene.values[7]
			juicy =                gene.values[8]
			product_icon =         gene.values[9]
			plant_icon =           gene.values[10]

		if("consumption")

			if(gene.values.len < 7) return

			consume_gasses =       gene.values[1]
			requires_nutrients =   gene.values[2]
			nutrient_consumption = gene.values[3]
			requires_water =       gene.values[4]
			water_consumption =    gene.values[5]
			carnivorous =          gene.values[6]
			parasite =             gene.values[7]
			stings =               gene.values[8]

		if("environment")

			if(gene.values.len < 6) return

			ideal_heat =           gene.values[1]
			heat_tolerance =       gene.values[2]
			ideal_light =          gene.values[3]
			light_tolerance =      gene.values[4]
			lowkpa_tolerance  =    gene.values[5]
			highkpa_tolerance =    gene.values[6]
			explosive =            gene.values[7]

		if("resistance")

			if(gene.values.len < 3) return

			toxins_tolerance =     gene.values[1]
			pest_tolerance =       gene.values[2]
			weed_tolerance =       gene.values[3]

		if("vigour")

			if(gene.values.len < 6) return

			endurance =            gene.values[1]
			yield =                gene.values[2]
			lifespan =             gene.values[3]
			spread =               gene.values[4]
			maturation =           gene.values[5]
			production =           gene.values[6]
			teleporting =          gene.values[7]

		if("flowers")

			if(gene.values.len < 7) return

			plant_colour =         gene.values[1]
			product_colour =       gene.values[2]
			biolum =               gene.values[3]
			biolum_colour =        gene.values[4]
			flowers =              gene.values[5]
			flower_icon =          gene.values[6]
			flower_colour =        gene.values[7]

	update_growth_stages()

//Returns a list of the desired trait values.
/datum/seed/proc/get_gene(var/genetype)

	if(!genetype) return 0

	var/datum/plantgene/P = new()
	P.genetype = genetype

	switch(genetype)
		if("products")
			P.values = list(
				(products             ? products             : 0),
				(chems                ? chems                : 0),
				(exude_gasses         ? exude_gasses         : 0),
				(alter_temp           ? alter_temp           : 0),
				(potency              ? potency              : 0),
				(harvest_repeat       ? harvest_repeat       : 0),
				(produces_power       ? produces_power       : 0),
				(juicy                ? juicy                : 0),
				(product_icon         ? product_icon         : 0),
				(plant_icon           ? plant_icon           : 0)
				)

		if("consumption")
			P.values = list(
				(consume_gasses       ? consume_gasses       : 0),
				(requires_nutrients   ? requires_nutrients   : 0),
				(nutrient_consumption ? nutrient_consumption : 0),
				(requires_water       ? requires_water       : 0),
				(water_consumption    ? water_consumption    : 0),
				(carnivorous          ? carnivorous          : 0),
				(parasite             ? parasite             : 0),
				(stings               ? stings               : 0)
				)

		if("environment")
			P.values = list(
				(ideal_heat           ? ideal_heat           : 0),
				(heat_tolerance       ? heat_tolerance       : 0),
				(ideal_light          ? ideal_light          : 0),
				(light_tolerance      ? light_tolerance      : 0),
				(lowkpa_tolerance     ? lowkpa_tolerance     : 0),
				(highkpa_tolerance    ? highkpa_tolerance    : 0),
				(explosive            ? explosive            : 0)
				)

		if("resistance")
			P.values = list(
				(toxins_tolerance     ? toxins_tolerance     : 0),
				(pest_tolerance       ? pest_tolerance       : 0),
				(weed_tolerance       ? weed_tolerance       : 0)
				)

		if("vigour")
			P.values = list(
				(endurance            ? endurance            : 0),
				(yield                ? yield                : 0),
				(lifespan             ? lifespan             : 0),
				(spread               ? spread               : 0),
				(maturation           ? maturation           : 0),
				(production           ? production           : 0),
				(teleporting          ? teleporting          : 0),
				)

		if("flowers")
			P.values = list(
				(plant_colour         ? plant_colour         : 0),
				(product_colour       ? product_colour       : 0),
				(biolum               ? biolum               : 0),
				(biolum_colour        ? biolum_colour        : 0),
				(flowers              ? flowers              : 0),
				(flower_icon          ? flower_icon          : 0),
				(flower_colour        ? flower_colour        : 0)
				)

	return (P ? P : 0)

//Place the plant products at the feet of the user.
/datum/seed/proc/harvest(var/mob/user,var/yield_mod,var/harvest_sample,var/force_amount)

	if(!user)
		return

	var/got_product
	if(!isnull(products) && products.len && yield > 0)
		got_product = 1

	if(!force_amount && !got_product && !harvest_sample)
		user << "<span class='danger'>You fail to harvest anything useful.</span>"
	else
		user << "You [harvest_sample ? "take a sample" : "harvest"] from the [display_name]."

		//This may be a new line. Update the global if it is.
		if(name == "new line" || !(name in seed_types))
			uid = seed_types.len + 1
			name = "[uid]"
			seed_types[name] = src

		if(harvest_sample)
			var/obj/item/seeds/seeds = new(get_turf(user))
			seeds.seed_type = name
			seeds.update_seed()
			return

		var/total_yield = 0
		if(!isnull(force_amount))
			total_yield = force_amount
		else
			if(yield > -1)
				if(isnull(yield_mod) || yield_mod < 1)
					yield_mod = 0
					total_yield = yield
				else
					total_yield = yield + rand(yield_mod)
				total_yield = max(1,total_yield)

		currently_querying = list()
		for(var/i = 0;i<total_yield;i++)
			var/product_type = pick(products)
			var/obj/item/product = new product_type(get_turf(user),name)

			if(product_colour)
				product.color = product_colour
				if(istype(product,/obj/item/weapon/reagent_containers/food))
					var/obj/item/weapon/reagent_containers/food/food = product
					food.filling_color = product_colour

			if(mysterious)
				product.name += "?"
				product.desc += " On second thought, something about this one looks strange."

			if(biolum)
				if(biolum_colour)
					product.l_color = biolum_colour
				product.SetLuminosity(biolum)

			//Handle spawning in living, mobile products (like dionaea).
			if(istype(product,/mob/living))

				product.visible_message("<span class='notice'>The pod disgorges [product]!</span>")
				handle_living_product(product)

// When the seed in this machine mutates/is modified, the tray seed value
// is set to a new datum copied from the original. This datum won't actually
// be put into the global datum list until the product is harvested, though.
/datum/seed/proc/diverge(var/modified)

	if(immutable > 0) return

	//Set up some basic information.
	var/datum/seed/new_seed = new
	new_seed.name = "new line"
	new_seed.uid = 0
	new_seed.roundstart = 0

	//Copy over everything else.
	if(products)       new_seed.products = products.Copy()
	if(mutants)        new_seed.mutants = mutants.Copy()
	if(chems)          new_seed.chems = chems.Copy()
	if(consume_gasses) new_seed.consume_gasses = consume_gasses.Copy()
	if(exude_gasses)   new_seed.exude_gasses = exude_gasses.Copy()

	new_seed.seed_name =            "[(roundstart ? "[(modified ? "modified" : "mutant")] " : "")][seed_name]"
	new_seed.display_name =         "[(roundstart ? "[(modified ? "modified" : "mutant")] " : "")][display_name]"
	new_seed.seed_noun =            seed_noun

	new_seed.requires_nutrients =   requires_nutrients
	new_seed.nutrient_consumption = nutrient_consumption
	new_seed.requires_water =       requires_water
	new_seed.water_consumption =    water_consumption
	new_seed.ideal_heat =           ideal_heat
	new_seed.heat_tolerance =       heat_tolerance
	new_seed.ideal_light =          ideal_light
	new_seed.light_tolerance =      light_tolerance
	new_seed.toxins_tolerance =     toxins_tolerance
	new_seed.lowkpa_tolerance =     lowkpa_tolerance
	new_seed.highkpa_tolerance =    highkpa_tolerance
	new_seed.pest_tolerance =       pest_tolerance
	new_seed.weed_tolerance =       weed_tolerance
	new_seed.endurance =            endurance
	new_seed.yield =                yield
	new_seed.lifespan =             lifespan
	new_seed.maturation =           maturation
	new_seed.production =           production
	new_seed.harvest_repeat =       harvest_repeat
	new_seed.potency =              potency
	new_seed.spread =               spread
	new_seed.carnivorous =          carnivorous
	new_seed.parasite =             parasite
	new_seed.plant_icon =           plant_icon
	new_seed.plant_colour =         plant_colour
	new_seed.product_icon =         product_icon
	new_seed.product_colour =       product_colour
	new_seed.packet_icon =          packet_icon
	new_seed.biolum =               biolum
	new_seed.biolum_colour =        biolum_colour
	new_seed.flowers =              flowers
	new_seed.flower_icon =          flower_icon
	new_seed.alter_temp = 			alter_temp
	new_seed.update_growth_stages()
	return new_seed

/datum/seed/proc/update_growth_stages()
	if(plant_icon)
		growth_stages = plant_sprites[plant_icon]
	else
		growth_stages = 0

/datum/seed/New()
	..()
	spawn(5)
		sleep(-1)
		update_growth_stages()

// Actual roundstart seed types after this point.
// Chili plants/variants.
/datum/seed/chili
	name = "chili"
	seed_name = "chili"
	display_name = "chili plants"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/chili)
	chems = list("capsaicin" = list(3,5), "nutriment" = list(1,25))
	mutants = list("icechili")
	harvest_repeat = 1
	lifespan = 20
	maturation = 5
	production = 5
	yield = 4
	potency = 20
	packet_icon =    "seed-chili"
	product_icon =   "chili"
	product_colour = "#ED3300"
	plant_icon =     "bush2"

/datum/seed/chili/ice
	name = "icechili"
	seed_name = "ice pepper"
	display_name = "ice-pepper plants"
	mutants = null
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/icepepper)
	chems = list("frostoil" = list(3,5), "nutriment" = list(1,50))
	maturation = 4
	production = 4
	packet_icon =    "seed-icepepper"
	product_colour = "#00EDC6"

// Berry plants/variants.
/datum/seed/berry
	name = "berries"
	seed_name = "berry"
	display_name = "berry bush"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/berries)
	mutants = list("glowberries","poisonberries")
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	juicy = 1
	lifespan = 20
	maturation = 5
	production = 5
	yield = 2
	potency = 10
	packet_icon =    "seed-berry"
	product_icon =   "berry"
	product_colour = "#FA1616"
	plant_icon =     "bush"

/datum/seed/berry/glow
	name = "glowberries"
	seed_name = "glowberry"
	display_name = "glowberry bush"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/glowberries)
	mutants = null
	chems = list("nutriment" = list(1,10), "uranium" = list(3,5))
	spread = 1
	biolum = 1
	biolum_colour = "#006622"
	lifespan = 30
	maturation = 5
	production = 5
	yield = 2
	potency = 10
	packet_icon =    "seed-glowberry"
	product_colour = "C9FA16"
	biolum

/datum/seed/berry/poison
	name = "poisonberries"
	seed_name = "poison berry"
	display_name = "poison berry bush"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/poisonberries)
	mutants = list("deathberries")
	chems = list("nutriment" = list(1), "toxin" = list(3,5))
	packet_icon =    "seed-poisonberry"
	product_colour = "#6DC961"

/datum/seed/berry/poison/death
	name = "deathberries"
	seed_name = "death berry"
	display_name = "death berry bush"
	mutants = null
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/deathberries)
	chems = list("nutriment" = list(1), "toxin" = list(3,3), "lexorin" = list(1,5))
	yield = 3
	potency = 50
	packet_icon =    "seed-deathberry"
	product_colour = "#7A5454"

// Nettles/variants.
/datum/seed/nettle
	name = "nettle"
	seed_name = "nettle"
	display_name = "nettles"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/nettle)
	mutants = list("deathnettle")
	harvest_repeat = 1
	chems = list("nutriment" = list(1,50), "sacid" = list(0,1))
	lifespan = 30
	maturation = 6
	production = 6
	yield = 4
	potency = 10
	stings = 1
	packet_icon =    "seed-nettle"
	plant_icon =     "bush5"
	product_icon =   "nettles"
	product_colour = "#728A54"

/datum/seed/nettle/death
	name = "deathnettle"
	seed_name = "death nettle"
	display_name = "death nettles"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/nettle/death)
	mutants = null
	chems = list("nutriment" = list(1,50), "pacid" = list(0,1))
	maturation = 8
	yield = 2
	packet_icon =    "seed-deathnettle"
	product_colour = "#8C5030"
	plant_colour =   "#634941"

//Tomatoes/variants.
/datum/seed/tomato
	name = "tomato"
	seed_name = "tomato"
	display_name = "tomato plant"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/tomato)
	mutants = list("bluetomato","bloodtomato")
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	juicy = 1
	lifespan = 25
	maturation = 8
	production = 6
	yield = 2
	potency = 10

	packet_icon =    "seed-tomato"
	product_icon =   "tomato"
	product_colour = "#D10000"
	plant_icon =     "bush3"

/datum/seed/tomato/blood
	name = "bloodtomato"
	seed_name = "blood tomato"
	display_name = "blood tomato plant"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/bloodtomato)
	mutants = list("killer")
	chems = list("nutriment" = list(1,10), "blood" = list(1,5))
	splat_type = /obj/effect/decal/cleanable/blood/splatter
	yield = 3
	packet_icon =    "seed-bloodtomato"
	product_colour = "#FF0000"

/datum/seed/tomato/killer
	name = "killertomato"
	seed_name = "killer tomato"
	display_name = "killer tomato plant"
	products = list(/mob/living/simple_animal/tomato)
	mutants = null
	yield = 2
	packet_icon =    "seed-killertomato"
	product_colour = "#A86747"

/datum/seed/tomato/blue
	name = "bluetomato"
	seed_name = "blue tomato"
	display_name = "blue tomato plant"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/bluetomato)
	mutants = list("bluespacetomato")
	chems = list("nutriment" = list(1,20), "lube" = list(1,5))
	packet_icon =    "seed-bluetomato"
	product_colour = "#4D86E8"
	plant_colour =   "#070AAD"

/datum/seed/tomato/blue/teleport
	name = "bluespacetomato"
	seed_name = "bluespace tomato"
	display_name = "bluespace tomato plant"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/bluespacetomato)
	mutants = null
	packet_icon = "seed-bluespacetomato"
	chems = list("nutriment" = list(1,20), "singulo" = list(1,5))
	teleporting = 1
	packet_icon =    "seed-bluespacetomato"
	product_colour = "#00E5FF"
	biolum = 1
	biolum_colour = "#4DA4A8"

//Eggplants/varieties.
/datum/seed/eggplant
	name = "eggplant"
	seed_name = "eggplant"
	display_name = "eggplants"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/eggplant)
	mutants = list("realeggplant")
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	lifespan = 25
	maturation = 6
	production = 6
	yield = 2
	potency = 20
	packet_icon =    "seed-eggplant"
	product_icon =   "eggplant"
	product_colour = "#892694"
	plant_icon =     "bush4"

/datum/seed/eggplant/eggs
	name = "realeggplant"
	seed_name = "egg-plant"
	display_name = "egg-plants"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/egg)
	mutants = null
	lifespan = 75
	production = 12
	packet_icon =    "seed-eggy"
	product_colour = "#E7EDD1"

//Apples/varieties.
/datum/seed/apple
	name = "apple"
	seed_name = "apple"
	display_name = "apple tree"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/apple)
	mutants = list("poisonapple","goldapple")
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	lifespan = 55
	maturation = 6
	production = 6
	yield = 5
	potency = 10
	packet_icon =    "seed-apple"
	product_icon =   "treefruit"
	product_colour = "#FF540A"
	plant_icon =     "tree2"

/datum/seed/apple/poison
	name = "poisonapple"
	mutants = null
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/apple/poisoned)
	chems = list("cyanide" = list(1,5))

/datum/seed/apple/gold
	name = "goldapple"
	seed_name = "golden apple"
	display_name = "gold apple tree"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/goldapple)
	mutants = null
	chems = list("nutriment" = list(1,10), "gold" = list(1,5))
	maturation = 10
	production = 10
	yield = 3
	packet_icon =    "seed-goldapple"
	product_colour = "#FFDD00"
	plant_colour =   "#D6B44D"

//Ambrosia/varieties.
/datum/seed/ambrosia
	name = "ambrosia"
	seed_name = "ambrosia vulgaris"
	display_name = "ambrosia vulgaris"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/ambrosiavulgaris)
	mutants = list("ambrosiadeus")
	harvest_repeat = 1
	chems = list("nutriment" = list(1), "space_drugs" = list(1,8), "kelotane" = list(1,8,1), "bicaridine" = list(1,10,1), "toxin" = list(1,10))
	lifespan = 60
	maturation = 6
	production = 6
	yield = 6
	potency = 5
	packet_icon =    "seed-ambrosiavulgaris"
	product_icon =   "ambrosia"
	product_colour = "#9FAD55"
	plant_icon =     "ambrosia"

/datum/seed/ambrosia/deus
	name = "ambrosiadeus"
	seed_name = "ambrosia deus"
	display_name = "ambrosia deus"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/ambrosiadeus)
	mutants = null
	chems = list("nutriment" = list(1), "bicaridine" = list(1,8), "synaptizine" = list(1,8,1), "hyperzine" = list(1,10,1), "space_drugs" = list(1,10))
	packet_icon =    "seed-ambrosiadeus"
	product_colour = "#A3F0AD"
	plant_colour =   "#2A9C61"

//Mushrooms/varieties.
/datum/seed/mushroom
	name = "mushrooms"
	seed_name = "chanterelle"
	seed_noun = "spores"
	display_name = "chanterelle mushrooms"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/chanterelle)
	mutants = list("reishi","amanita","plumphelmet")
	chems = list("nutriment" = list(1,25))
	lifespan = 35
	maturation = 7
	production = 1
	yield = 5
	potency = 1
	packet_icon =    "mycelium-chanter"
	product_icon =   "mushroom4"
	product_colour = "#DBDA72"
	plant_colour =   "#D9C94E"
	plant_icon =     "mushroom"

/datum/seed/mushroom/mold
	name = "mold"
	seed_name = "brown mold"
	display_name = "brown mold"
	products = null
	mutants = null
	spread = 1
	lifespan = 50
	maturation = 10
	yield = -1
	product_icon =   "mushroom5"
	product_colour = "#7A5F20"
	plant_colour =   "#7A5F20"
	plant_icon =     "mushroom9"

/datum/seed/mushroom/plump
	name = "plumphelmet"
	seed_name = "plump helmet"
	display_name = "plump helmet mushrooms"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/plumphelmet)
	mutants = list("walkingmushroom","towercap")
	chems = list("nutriment" = list(2,10))
	lifespan = 25
	maturation = 8
	yield = 4
	potency = 0
	packet_icon =    "mycelium-plump"
	product_icon =   "mushroom10"
	product_colour = "#B57BB0"
	plant_colour =   "#9E4F9D"
	plant_icon =     "mushroom2"

/datum/seed/mushroom/plump/walking
	name = "walkingmushroom"
	seed_name = "walking mushroom"
	display_name = "walking mushrooms"
	products = list(/mob/living/simple_animal/mushroom)
	mutants = null
	maturation = 5
	yield = 1
	packet_icon =    "mycelium-walkingmushroom"
	product_colour = "#FAC0F2"
	plant_colour =   "#C4B1C2"

/datum/seed/mushroom/hallucinogenic
	name = "reishi"
	seed_name = "reishi"
	display_name = "reishi"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/reishi)
	mutants = list("libertycap","glowshroom")
	chems = list("nutriment" = list(1,50), "psilocybin" = list(3,5))
	maturation = 10
	production = 5
	yield = 4
	potency = 15
	packet_icon =    "mycelium-reishi"
	product_icon =   "mushroom11"
	product_colour = "#FFB70F"
	plant_colour =   "#F58A18"
	plant_icon =     "mushroom6"

/datum/seed/mushroom/hallucinogenic/strong
	name = "libertycap"
	seed_name = "liberty cap"
	display_name = "liberty cap mushrooms"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/libertycap)
	mutants = null
	chems = list("nutriment" = list(1), "stoxin" = list(3,3), "space_drugs" = list(1,25))
	lifespan = 25
	production = 1
	potency = 15
	packet_icon =    "mycelium-liberty"
	product_icon =   "mushroom8"
	product_colour = "#F2E550"
	plant_colour =   "#D1CA82"
	plant_icon =     "mushroom3"

/datum/seed/mushroom/poison
	name = "amanita"
	seed_name = "fly amanita"
	display_name = "fly amanita mushrooms"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/amanita)
	mutants = list("destroyingangel","plastic")
	chems = list("nutriment" = list(1), "amatoxin" = list(3,3), "psilocybin" = list(1,25))
	lifespan = 50
	maturation = 10
	production = 5
	yield = 4
	potency = 10
	packet_icon =    "mycelium-amanita"
	product_icon =   "mushroom"
	product_colour = "#FF4545"
	plant_colour =   "#F5F2D0"
	plant_icon =     "mushroom4"

/datum/seed/mushroom/poison/death
	name = "destroyingangel"
	seed_name = "destroying angel"
	display_name = "destroying angel mushrooms"
	mutants = null
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/angel)
	chems = list("nutriment" = list(1,50), "amatoxin" = list(13,3), "psilocybin" = list(1,25))
	maturation = 12
	yield = 2
	potency = 35
	packet_icon =    "mycelium-angel"
	product_icon =   "mushroom3"
	product_colour = "#EDE8EA"
	plant_colour =   "#E6D8DD"
	plant_icon =     "mushroom5"

/datum/seed/mushroom/towercap
	name = "towercap"
	seed_name = "tower cap"
	display_name = "tower caps"
	mutants = null
	products = list(/obj/item/weapon/grown/log)
	packet_icon = "mycelium-tower"
	lifespan = 80
	maturation = 15

	product_icon =   "mushroom7"
	product_colour = "#79A36D"
	plant_colour =   "#857F41"
	plant_icon =     "mushroom8"

/datum/seed/mushroom/glowshroom
	name = "glowshroom"
	seed_name = "glowshroom"
	display_name = "glowshrooms"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom/glowshroom)
	mutants = null
	chems = list("radium" = list(1,20))
	spread = 1
	lifespan = 120
	maturation = 15
	yield = 3
	explosive = 1
	splat_type = /obj/effect/glowshroom
	potency = 30
	biolum = 1
	biolum_colour = "#006622"
	packet_icon =    "mycelium-glowshroom"
	product_icon =   "mushroom2"
	product_colour = "#DDFAB6"
	plant_colour =   "#EFFF8A"
	plant_icon =     "mushroom7"

/datum/seed/mushroom/plastic
	name = "plastic"
	seed_name = "plastellium"
	display_name = "plastellium"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/plastellium)
	mutants = null
	chems = list("plasticide" = list(1,10))
	lifespan = 15
	maturation = 5
	production = 6
	yield = 6
	potency = 20
	packet_icon =    "mycelium-plast"
	product_icon =   "mushroom6"
	product_colour = "#E6E6E6"
	plant_colour =   "#E6E6E6"
	plant_icon =     "mushroom10"

//Flowers/varieties
/datum/seed/flower
	name = "harebells"
	seed_name = "harebell"
	display_name = "harebells"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/harebell)
	chems = list("nutriment" = list(1,20))
	lifespan = 100
	maturation = 7
	production = 1
	yield = 2
	packet_icon =    "seed-harebell"
	product_icon =   "flower5"
	product_colour = "#C492D6"
	plant_colour =   "#6B8C5E"
	plant_icon =     "flower"

/datum/seed/flower/poppy
	name = "poppies"
	seed_name = "poppy"
	display_name = "poppies"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/poppy)
	chems = list("nutriment" = list(1,20), "bicaridine" = list(1,10))
	lifespan = 25
	potency = 20
	maturation = 8
	production = 6
	yield = 6
	packet_icon =    "seed-poppy"
	product_icon =   "flower3"
	product_colour = "#B33715"
	plant_icon =     "flower3"

/datum/seed/flower/sunflower
	name = "sunflowers"
	seed_name = "sunflower"
	display_name = "sunflowers"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower)
	lifespan = 25
	maturation = 6
	packet_icon =    "seed-sunflower"
	product_icon =   "flower2"
	product_colour = "#FFF700"
	plant_icon =     "flower2"

//Grapes/varieties
/datum/seed/grapes
	name = "grapes"
	seed_name = "grape"
	display_name = "grapevines"
	mutants = list("greengrapes")
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/grapes)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10), "sugar" = list(1,5))
	lifespan = 50
	maturation = 3
	production = 5
	yield = 4
	potency = 10
	packet_icon =    "seed-grapes"
	product_icon =   "grapes"
	product_colour = "#BB6AC4"
	plant_colour =   "#378F2E"
	plant_icon =     "vine"

/datum/seed/grapes/green
	name = "greengrapes"
	seed_name = "green grape"
	display_name = "green grapevines"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/greengrapes)
	mutants = null
	chems = list("nutriment" = list(1,10), "kelotane" = list(3,5))
	packet_icon = "seed-greengrapes"
	product_colour = "42ED2F"

//Everything else
/datum/seed/peanuts
	name = "peanut"
	seed_name = "peanut"
	display_name = "peanut vines"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/peanut)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	lifespan = 55
	maturation = 6
	production = 6
	yield = 6
	potency = 10
	packet_icon =    "seed-peanut"
	product_icon =   "potato"
	product_colour = "#96855D"
	plant_icon =     "bush2"

/datum/seed/cabbage
	name = "cabbage"
	seed_name = "cabbage"
	display_name = "cabbages"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10))
	lifespan = 50
	maturation = 3
	production = 5
	yield = 4
	potency = 10
	packet_icon =    "seed-cabbage"
	product_icon =   "cabbage"
	product_colour = "#84BD82"
	plant_colour =   "#6D9C6B"
	plant_icon =     "vine2"

/datum/seed/banana
	name = "banana"
	seed_name = "banana"
	display_name = "banana tree"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/banana)
	harvest_repeat = 1
	chems = list("banana" = list(1,10))
	lifespan = 50
	maturation = 6
	production = 6
	yield = 3
	packet_icon =    "seed-banana"
	product_icon =   "bananas"
	product_colour = "#FFEC1F"
	plant_colour =   "#69AD50"
	plant_icon =     "tree4"

/datum/seed/corn
	name = "corn"
	seed_name = "corn"
	display_name = "ears of corn"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/corn)
	chems = list("nutriment" = list(1,10))
	lifespan = 25
	maturation = 8
	production = 6
	yield = 3
	potency = 20
	packet_icon =    "seed-corn"
	product_icon =   "corn"
	product_colour = "#FFF23B"
	plant_colour =   "#87C969"
	plant_icon =     "corn"

/datum/seed/potato
	name = "potato"
	seed_name = "potato"
	display_name = "potatoes"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/potato)
	chems = list("nutriment" = list(1,10))
	produces_power = 1
	lifespan = 30
	maturation = 10
	production = 1
	yield = 4
	potency = 10
	packet_icon =    "seed-potato"
	product_icon =   "potato"
	product_colour = "#D4CAB4"
	plant_icon =     "bush2"

/datum/seed/soybean
	name = "soybean"
	seed_name = "soybean"
	display_name = "soybeans"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/soybeans)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,20))
	lifespan = 25
	maturation = 4
	production = 4
	yield = 3
	potency = 5
	packet_icon =    "seed-soybean"
	product_icon =   "bean"
	product_colour = "#EBE7C0"
	plant_icon =     "stalk"

/datum/seed/wheat
	name = "wheat"
	seed_name = "wheat"
	display_name = "wheat stalks"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/wheat)
	chems = list("nutriment" = list(1,25))
	lifespan = 25
	maturation = 6
	production = 1
	yield = 4
	potency = 5
	packet_icon =    "seed-wheat"
	product_icon =   "wheat"
	product_colour = "#DBD37D"
	plant_colour =   "#BFAF82"
	plant_icon =     "stalk2"

/datum/seed/rice
	name = "rice"
	seed_name = "rice"
	display_name = "rice stalks"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/ricestalk)
	chems = list("nutriment" = list(1,25))
	lifespan = 25
	maturation = 6
	production = 1
	yield = 4
	potency = 5
	packet_icon =    "seed-rice"
	product_icon =   "rice"
	product_colour = "#D5E6D1"
	plant_colour =   "#8ED17D"
	plant_icon =     "stalk2"

/datum/seed/carrots
	name = "carrot"
	seed_name = "carrot"
	display_name = "carrots"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/carrot)
	chems = list("nutriment" = list(1,20), "imidazoline" = list(3,5))
	lifespan = 25
	maturation = 10
	production = 1
	yield = 5
	potency = 10
	packet_icon =    "seed-carrot"
	product_icon =   "carrot"
	product_colour = "#FFDB4A"
	plant_icon =     "carrot"

/datum/seed/weeds
	name = "weeds"
	seed_name = "weed"
	display_name = "weeds"
	lifespan = 100
	maturation = 5
	production = 1
	yield = -1
	potency = -1
	immutable = -1
	packet_icon =    "seed-ambrosiavulgaris"
	product_icon =   "flower4"
	product_colour = "#FCEB2B"
	plant_colour =   "#59945A"
	plant_icon =     "bush6"

/datum/seed/whitebeets
	name = "whitebeet"
	seed_name = "white-beet"
	display_name = "white-beets"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/whitebeet)
	chems = list("nutriment" = list(0,20), "sugar" = list(1,5))
	lifespan = 60
	maturation = 6
	production = 6
	yield = 6
	potency = 10
	packet_icon =    "seed-whitebeet"
	product_icon =   "carrot2"
	product_colour = "#EEF5B0"
	plant_colour =   "#4D8F53"
	plant_icon =     "carrot2"

/datum/seed/sugarcane
	name = "sugarcane"
	seed_name = "sugarcane"
	display_name = "sugarcanes"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/sugarcane)
	harvest_repeat = 1
	chems = list("sugar" = list(4,5))
	lifespan = 60
	maturation = 3
	production = 6
	yield = 4
	potency = 10
	packet_icon =    "seed-sugarcane"
	product_icon =   "stalk"
	product_colour = "#B4D6BD"
	plant_colour =   "#6BBD68"
	plant_icon =     "stalk3"

/datum/seed/watermelon
	name = "watermelon"
	seed_name = "watermelon"
	display_name = "watermelon vine"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/watermelon)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,6))
	juicy = 1
	lifespan = 50
	maturation = 6
	production = 6
	yield = 3
	potency = 1
	packet_icon =    "seed-watermelon"
	product_icon =   "vine"
	product_colour = "#326B30"
	plant_colour =   "#257522"
	plant_icon =     "vine2"

/datum/seed/pumpkin
	name = "pumpkin"
	seed_name = "pumpkin"
	display_name = "pumpkin vine"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/pumpkin)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,6))
	lifespan = 50
	maturation = 6
	production = 6
	yield = 3
	potency = 10
	packet_icon =    "seed-pumpkin"
	product_icon =   "vine"
	product_colour = "#B4D4B9"
	plant_colour =   "#BAE8C1"
	plant_icon =     "vine2"

/datum/seed/citrus
	name = "lime"
	seed_name = "lime"
	display_name = "lime trees"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,20))
	juicy = 1
	lifespan = 55
	maturation = 6
	production = 6
	yield = 4
	potency = 15
	packet_icon =    "seed-lime"
	product_icon =   "treefruit"
	product_colour = "#3AF026"
	plant_icon =     "tree"

/datum/seed/citrus/lemon
	name = "lemon"
	seed_name = "lemon"
	display_name = "lemon trees"
	produces_power = 1
	packet_icon =    "seed-lemon"
	product_colour = "#F0E226"

/datum/seed/citrus/orange
	name = "orange"
	seed_name = "orange"
	display_name = "orange trees"
	packet_icon = "seed-orange"
	product_colour = "#FFC20A"

/datum/seed/grass
	name = "grass"
	seed_name = "grass"
	display_name = "grass"
	products = list(/obj/item/stack/tile/grass)
	harvest_repeat = 1
	lifespan = 60
	maturation = 2
	production = 5
	yield = 5
	packet_icon =    "seed-grass"
	product_icon =   "grass"
	product_colour = "#09FF00"
	plant_colour =   "#07D900"
	plant_icon =     "grass"

/datum/seed/cocoa
	name = "cocoa"
	seed_name = "cacao"
	display_name = "cacao tree"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/cocoapod)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,10), "coco" = list(4,5))
	lifespan = 20
	maturation = 5
	production = 5
	yield = 2
	potency = 10
	packet_icon =    "seed-cocoapod"
	product_icon =   "treefruit"
	product_colour = "#CCA935"
	plant_icon =     "tree2"

/datum/seed/cherries
	name = "cherry"
	seed_name = "cherry"
	seed_noun = "pits"
	display_name = "cherry tree"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/cherries)
	harvest_repeat = 1
	chems = list("nutriment" = list(1,15), "sugar" = list(1,15))
	juicy = 1
	lifespan = 35
	maturation = 5
	production = 5
	yield = 3
	potency = 10
	packet_icon =    "seed-cherry"
	product_icon =   "treefruit"
	product_colour = "#8C0101"
	plant_icon =     "tree2"

/datum/seed/kudzu
	name = "kudzu"
	seed_name = "kudzu"
	display_name = "kudzu vines"
	products = list(/obj/item/weapon/reagent_containers/food/snacks/grown/kudzupod)
	chems = list("nutriment" = list(1,50), "anti_toxin" = list(1,25))
	lifespan = 20
	maturation = 6
	production = 6
	yield = 4
	potency = 10
	spread = 2
	packet_icon =    "seed-kudzu"
	product_icon =   "treefruit"
	product_colour = "#96D278"
	plant_colour =   "#6F7A63"
	plant_icon =     "vine2"

/datum/seed/diona
	name = "diona"
	seed_name = "diona"
	seed_noun = "nodes"
	display_name = "replicant pods"
	products = list(/mob/living/carbon/alien/diona)
	product_requires_player = 1
	immutable = 1
	lifespan = 50
	endurance = 8
	maturation = 5
	production = 10
	yield = 1
	potency = 30
	packet_icon =    "seed-replicapod"
	product_icon =   "diona"
	product_colour = "#799957"
	plant_colour =   "#66804B"
	plant_icon =     "alien4"

/datum/seed/shand
	name = "shand"
	seed_name = "S'randar's hand"
	display_name = "S'randar's hand leaves"
	products = list(/obj/item/stack/medical/bruise_pack/tajaran)
	chems = list("bicaridine" = list(0,10))
	lifespan = 50
	maturation = 3
	production = 5
	yield = 4
	potency = 10
	packet_icon =    "seed-shand"
	product_icon =   "alien3"
	product_colour = "#378C61"
	plant_colour =   "#378C61"
	plant_icon =     "tree5"

/datum/seed/mtear
	name = "mtear"
	seed_name = "Messa's tear"
	display_name = "Messa's tear leaves"
	products = list(/obj/item/stack/medical/ointment/tajaran)
	chems = list("honey" = list(1,10), "kelotane" = list(3,5))
	lifespan = 50
	maturation = 3
	production = 5
	yield = 4
	potency = 10
	packet_icon =    "seed-mtear"
	product_icon =   "alien4"
	product_colour = "#4CC5C7"
	plant_colour =   "#4CC789"
	plant_icon =     "bush7"