extends RefCounted
## Test-local Dialogue & Conversion System-shaped caller stub (CLE AC-8.3).
## NOT an autoload and NOT collected by GUT (no _test.gd suffix): a minimal
## stand-in for the real DCS autoload, proving the CLE is callable from a
## downstream caller. Owns its own RNG instance per ADR-0007 and keeps its own
## resolution log — the CLE itself is stateless, so nothing can leak between
## this stub and the RFS-shaped stub in the same test run.

## Outcomes this stub has resolved (its own log — independent per instance).
var resolutions: Array = []

## Player-side resolve + apply pair (the DCS finally-block contract).
## Returns the ConversionOutcome the CLE produced.
func resolve_for_caller(p_approach: GameEnums.DialogueApproach, p_npc_id: String,
		p_rng: RandomNumberGenerator) -> GameEnums.ConversionOutcome:
	var outcome := ConversionLogicEngine.resolve(p_approach, p_npc_id, p_rng)
	resolutions.append(outcome)
	NPCRegistry.apply_conversion_outcome(p_npc_id, outcome, p_approach,
		GameEnums.OutcomeCaller.PLAYER)
	return outcome