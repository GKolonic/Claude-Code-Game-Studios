extends GutTest
## VillageDefinition resource + village_01.tres suite — Sprint 2 task 2-4
## (QA plan VDEF-1..5). Consumes the ADR-0002 schema confirmed by the
## Creative Director ruling (2026-08-18) and the approved roster from
## decision #5 (2026-08-18): 1 ELDER / 2 LABORER / 1 MERCHANT / 1 SOLDIER /
## 1 SCHOLAR / 1 WIDOW / 1 NOBLE (8 NPCs), NOBLE access-gated behind ELDER.
## NOTE: VDEF-6 (initialize_village() yields 8 NpcRecords) lands with
## task 2-6 (NPCRegistry) — by design here.

const VILLAGE_PATH := "res://assets/data/villages/village_01.tres"
const ARCHETYPE_SLUGS := [
	"laborer", "elder", "merchant", "soldier", "scholar", "widow", "noble",
]
const ID_PATTERN := "^village_01_(laborer|elder|merchant|soldier|scholar|widow|noble)_([0-9]+)$"

# Approved roster — decision #5: archetype -> expected count.
const APPROVED_ROSTER := {
	GameEnums.NPCArchetype.ELDER: 1,
	GameEnums.NPCArchetype.LABORER: 2,
	GameEnums.NPCArchetype.MERCHANT: 1,
	GameEnums.NPCArchetype.SOLDIER: 1,
	GameEnums.NPCArchetype.SCHOLAR: 1,
	GameEnums.NPCArchetype.WIDOW: 1,
	GameEnums.NPCArchetype.NOBLE: 1,
}


func test_vdef_1_parses_as_village_definition_with_expected_fields() -> void:
	# VDEF-1: village_01.tres parses as VillageDefinition with the approved
	# schema fields (village_id, npc_definitions, map_art_path, rng_seed).
	var village: VillageDefinition = load(VILLAGE_PATH)
	assert_not_null(village, "village_01.tres must load")
	assert_true(village is VillageDefinition,
		"village_01.tres must parse as VillageDefinition")
	assert_eq(village.village_id, "village_01")
	assert_eq(village.map_art_path, "res://assets/maps/village_01/village_map.png")
	assert_true(FileAccess.file_exists(village.map_art_path),
		"map_art_path must resolve (1-23 asset): %s" % village.map_art_path)
	assert_true(village.rng_seed is int and village.rng_seed > 0,
		"rng_seed must be a fixed positive int, got %s" % str(village.rng_seed))


func test_vdef_2_roster_matches_approved_decision5() -> void:
	# VDEF-2: exactly 8 npc_definitions matching the CD-approved profile
	# (decision #5). ANY deviation fails loudly.
	var village: VillageDefinition = load(VILLAGE_PATH)
	assert_eq(village.npc_definitions.size(), 8,
		"village_01 must contain exactly 8 NPCs (decision #5)")
	var counts := {}
	for entry in village.npc_definitions:
		var archetype: int = entry["archetype"]
		counts[archetype] = counts.get(archetype, 0) + 1
	assert_eq(counts.size(), APPROVED_ROSTER.size(),
		"roster must use exactly the 7 MVP archetypes")
	for archetype in APPROVED_ROSTER:
		assert_eq(counts.get(archetype, 0), APPROVED_ROSTER[archetype],
			"archetype %s count must match decision #5" %
			GameEnums.NPCArchetype.keys()[archetype])
	# Total re-check (1+2+1+1+1+1+1 = 8).
	var total := 0
	for archetype in counts:
		total += counts[archetype]
	assert_eq(total, 8, "roster counts must sum to 8")


func test_vdef_3_ids_archetypes_and_display_names_validate() -> void:
	# VDEF-3: npc_id format regex, archetype in GameEnums.NPCArchetype,
	# display_name non-empty (NPC CS OQ-4 hand-authored names).
	var village: VillageDefinition = load(VILLAGE_PATH)
	var id_regex := RegEx.create_from_string(ID_PATTERN)
	for entry in village.npc_definitions:
		var npc_id: String = entry["npc_id"]
		var archetype: int = entry["archetype"]
		var result := id_regex.search(npc_id)
		assert_not_null(result,
			"npc_id '%s' must match %s" % [npc_id, ID_PATTERN])
		if result == null:
			continue
		var slug: String = result.get_string(1)
		var index := int(result.get_string(2))
		assert_eq(slug, ARCHETYPE_SLUGS[archetype],
			"npc_id '%s' slug must match its archetype" % npc_id)
		assert_true(index >= 1,
			"npc_id '%s' index must be >= 1" % npc_id)
		assert_true(archetype in GameEnums.NPCArchetype.values(),
			"npc_id '%s' archetype %s must be a valid enum value" %
			[npc_id, str(archetype)])
		var display_name: String = entry["display_name"]
		assert_false(display_name.strip_edges().is_empty(),
			"npc_id '%s' must have a non-empty display_name (OQ-4)" % npc_id)


func test_vdef_4_map_positions_within_village_map_grid() -> void:
	# VDEF-4: every map_position within the VillageMapConfig 4x6 grid
	# (default: cols 4 x rows 6 — 0..3 x 0..5), and no duplicates (F2
	# defensive fallback should never be needed for hand-authored content).
	var village: VillageDefinition = load(VILLAGE_PATH)
	var cols: int = GameConfig.map.map_grid_columns
	var rows: int = GameConfig.map.map_grid_rows
	assert_eq([cols, rows], [4, 6],
		"VillageMapConfig defaults must be 4x6 for this authoring")
	var seen := {}
	for entry in village.npc_definitions:
		var pos: Vector2i = entry["map_position"]
		assert_true(pos.x >= 0 and pos.x < cols,
			"'%s' map_position.x %s must be in 0..%d" %
			[entry["npc_id"], str(pos.x), cols - 1])
		assert_true(pos.y >= 0 and pos.y < rows,
			"'%s' map_position.y %s must be in 0..%d" %
			[entry["npc_id"], str(pos.y), rows - 1])
		assert_false(seen.has(pos),
			"map_position %s must be unique (no duplicate cells)" % str(pos))
		seen[pos] = true


func test_vdef_5_connections_and_gates_resolve_with_no_dead_refs() -> void:
	# VDEF-5: every social_connection target id and every access_gate
	# required id resolves to a listed npc_id (E2/E3 no dead refs); the
	# NOBLE is access-gated behind the ELDER (decision #5); all other NPCs
	# have no gate; at least one NPC is ungated (E8 unplayable guard).
	var village: VillageDefinition = load(VILLAGE_PATH)
	var ids: Array[String] = []
	for entry in village.npc_definitions:
		ids.append(entry["npc_id"])

	for entry in village.npc_definitions:
		var npc_id: String = entry["npc_id"]
		for conn in entry.get("social_connections", []):
			var target: String = conn["target_npc_id"]
			assert_has(ids, target,
				"'%s' connection target '%s' must resolve to a listed id" %
				[npc_id, target])
			var rel: int = conn["relationship_type"]
			assert_true(rel in GameEnums.RelationshipType.values(),
				"'%s' relationship_type %s must be a valid enum value" %
				[npc_id, str(rel)])
			var weight: float = conn["influence_weight"]
			assert_between(weight, 0.0, 1.0,
				"'%s' influence_weight %s must be in [0.0, 1.0]" %
				[npc_id, str(weight)])

		if entry.has("access_gate"):
			var gate: Dictionary = entry["access_gate"]
			var gate_ids: Array = gate["required_npc_ids"]
			assert_false(gate_ids.is_empty(),
				"'%s' access gate must name at least one required NPC" % npc_id)
			for required in gate_ids:
				assert_has(ids, required,
					"'%s' gate requires unknown id '%s'" % [npc_id, required])

	# NOBLE gate: exactly one gated NPC (Vessica Moreland), locked behind
	# ELDER at CONVERTED — "convert the Elder first" (VMV gate example).
	var gated: Array[Dictionary] = []
	for entry in village.npc_definitions:
		if entry.has("access_gate"):
			gated.append(entry)
	assert_eq(gated.size(), 1,
		"exactly one NPC must carry an access gate (the NOBLE)")
	var noble := gated[0]
	assert_eq(noble["npc_id"], "village_01_noble_1",
		"the gated NPC must be the NOBLE")
	assert_eq(noble["archetype"], GameEnums.NPCArchetype.NOBLE)
	assert_eq(noble["access_gate"]["required_belief_state"],
		GameEnums.BeliefState.CONVERTED,
		"NOBLE gate must require belief_state >= CONVERTED")
	assert_eq(noble["access_gate"]["required_npc_ids"], ["village_01_elder_1"],
		"NOBLE gate must require the ELDER (convert the Elder first)")
	# E8 guard: at least one NPC is ungated at game start (7 of 8 are).
	assert_eq(gated.size(), 1, "E8 unplayable-village guard satisfied: 7 ungated")