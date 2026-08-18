extends RefCounted
## Test-local Rival Faith System-shaped caller stub (CLE AC-8.3).
## NOT an autoload and NOT collected by GUT (no _test.gd suffix): a minimal
## stand-in for the real RFS autoload, proving the CLE is callable from the
## rival's side with the identical interface. Owns its own RNG instance per
## ADR-0007 and keeps its own resolution log — the CLE itself is stateless, so
## nothing can leak between this stub and the DCS-shaped stub in the same run.

## Outcomes this stub has resolved (its own log — independent per instance).
var resolutions: Array = []

## Rival-side resolve + apply pair (RFS Rule 9 grace-window caller flag).
## Returns the ConversionOutcome the CLE produced.
func resolve_for_caller(p_approach: GameEnums.DialogueApproach, p_npc_id: String,
		p_rng: RandomNumberGenerator) -> GameEnums.ConversionOutcome:
	var outcome := ConversionLogicEngine.resolve(p_approach, p_npc_id, p_rng)
	resolutions.append(outcome)
	NPCRegistry.apply_conversion_outcome(p_npc_id, outcome, p_approach,
		GameEnums.OutcomeCaller.RIVAL)
	return outcome