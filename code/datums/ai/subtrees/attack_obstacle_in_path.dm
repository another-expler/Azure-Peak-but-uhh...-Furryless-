/// If there's something between us and our target then we need to queue a behaviour to make it not be there
/datum/ai_planning_subtree/attack_obstacle_in_path
	/// Blackboard key containing current target
	var/target_key = BB_BASIC_MOB_CURRENT_TARGET
	/// The action to execute, extend to add a different cooldown or something
	var/attack_behaviour = /datum/ai_behavior/attack_obstructions

/datum/ai_planning_subtree/attack_obstacle_in_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return

	var/turf/next_step = get_step_towards(controller.pawn, target)
	if (!next_step.is_blocked_turf(exclude_mobs = TRUE, source_atom = controller.pawn))
		return

	controller.queue_behavior(attack_behaviour, target_key)
	// Don't cancel future planning, maybe we can move now

/// Something is in our way, get it outta here
/datum/ai_behavior/attack_obstructions
	action_cooldown = 2 SECONDS
	/// If we should attack walls, be prepared for complaints about breaches
	var/can_attack_turfs = FALSE
	/// For if you want your mob to be able to attack dense objects
	var/can_attack_dense_objects = FALSE

/datum/ai_behavior/attack_obstructions/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	. = ..()
	var/mob/living/simple_animal/basic_mob = controller.pawn
	var/atom/target = controller.blackboard[target_key]

	if (QDELETED(target))
		finish_action(controller, succeeded = FALSE)
		return

	var/turf/next_step = get_step_towards(basic_mob, target)
	var/dir_to_next_step = get_dir(basic_mob, next_step)
	// If moving diagonally we need to punch both ways, or more accurately the one we are blocked in
	var/list/dirs_to_move = list()
	if (ISDIAGONALDIR(dir_to_next_step))
		for(var/direction in GLOB.cardinals)
			if(direction & dir_to_next_step)
				dirs_to_move += direction
	else
		dirs_to_move += dir_to_next_step

	for (var/direction in dirs_to_move)
		if (attack_in_direction(controller, basic_mob, direction))
			return
	finish_action(controller, succeeded = TRUE)

/datum/ai_behavior/attack_obstructions/proc/attack_in_direction(datum/ai_controller/controller, mob/living/simple_animal/basic_mob, direction)
	var/turf/next_step = get_step(basic_mob, direction)
	if (!next_step.is_blocked_turf(exclude_mobs = TRUE, source_atom = controller.pawn))
		return FALSE

	for (var/obj/object as anything in next_step.contents)
		if (!can_smash_object(basic_mob, object))
			continue
		basic_mob.ClickOn(object, list())
		return TRUE

	if (can_attack_turfs)
		basic_mob.ClickOn(next_step)
		return TRUE
	return FALSE

/datum/ai_behavior/attack_obstructions/proc/can_smash_object(mob/living/simple_animal/basic_mob, obj/object)
	if (!object.density && !can_attack_dense_objects)
		return FALSE
	if (object.IsObscured())
		return FALSE
	if (basic_mob.see_invisible < object.invisibility)
		return FALSE
	var/list/whitelist = basic_mob.ai_controller.blackboard[BB_OBSTACLE_TARGETING_WHITELIST]
	if(whitelist && !is_type_in_typecache(object, whitelist))
		return FALSE

	return TRUE // It's in our way, let's get it out of our way
