class_name GameEnums
extends RefCounted
## Single compiled home for every shared enum (ADR-0002, architecture §4.2).
## GDDs author the enum *values*; this class is the one resolvable source for
## .tres authoring and typed signal payloads. Values only — no behaviour.

## NPC belief state (NPC Character System GDD).
enum BeliefState {
	STEADFAST,  ## Immovable — never approachable.
	OPEN,       ## Approachable; conversion attempts allowed.
	WAVERING,   ## Approachable; converted state is within reach.
	CONVERTED,  ## Won to the faith.
}

## Dialogue approaches (Dialogue & Conversion System GDD).
enum DialogueApproach {
	GRIEF,     ## Address loss and sorrow.
	AMBITION,  ## Address hope and worldly drive.
	DOUBT,     ## Address uncertainty and questioning.
	FEAR,      ## Address fear and dread.
}

## Conversion attempt outcome (Dialogue & Conversion System GDD).
## PERSUADED — renamed from CONVERTED (NPC CS Rule 9 / ADR-0002) to remove the
## collision with BeliefState.CONVERTED. No CONVERTED member exists here.
enum ConversionOutcome {
	PERSUADED,  ## Belief state advanced (OPEN/WAVERING -> CONVERTED).
	SOFTENED,   ## Belief state advanced one step but not converted.
	RESISTED,   ## No change; repeat penalty accrues.
	HARDENED,   ## Belief regressed; rehardened.
}

## Trait rarity band (NPC Trait Database GDD).
enum TraitRarity {
	COMMON,    ## weight 60
	UNCOMMON,  ## weight 30
	RARE,      ## weight 10
}

## Social relationship type between NPCs (NPC Character System GDD).
## +5 types post-MVP.
enum RelationshipType {
	SPOUSE,
	MENTOR,
	CLOSE_FRIEND,
	NEIGHBOR,
	KIN,
	RIVAL,
	EMPLOYER,
}

## NPC archetype (NPC Character System GDD; 7 MVP archetypes).
enum NPCArchetype {
	LABORER,
	ELDER,
	MERCHANT,
	SOLDIER,
	SCHOLAR,
	WIDOW,
	NOBLE,
}

## Caller identity for conversion-outcome mutation (architecture §3.2).
enum OutcomeCaller {
	PLAYER,        ## DCS — the player's conversion attempt.
	RIVAL,         ## RFS — rival-faith challenge.
	FAITH_SPREAD,  ## FaithSpreadSystem — passive spread (no MVP consumer).
}

## Alignment signal shown to the player before committing an approach
## (Dialogue & Conversion System GDD).
enum AlignmentSignal {
	POSITIVE,
	NEUTRAL,
	NEGATIVE,
}

## Game State Manager lifecycle state (Game State Manager GDD).
enum GSMState {
	UNINITIALIZED,  ## Before a village is loaded.
	IDLE,           ## Village ready; accepting end-turn requests.
	IN_SESSION,     ## A DCS conversation session is open.
	TURN_ADVANCING, ## Turn sequence in progress (Steps 1-10).
	VILLAGE_WON,    ## Village resolved in the player's favour.
	VILLAGE_LOST,   ## Village resolved against the player.
}

## Cardinal swipe direction (Mobile Touch Framework GDD, F-4 sectors).
enum SwipeDirection {
	RIGHT,
	UP,
	LEFT,
	DOWN,
}
