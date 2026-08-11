extends Node
## GameStateManager — Autoload placeholder, ADR-0001 slot 8.
## Core: turn authority, faith power, village win/loss; exclusive NPC-lifecycle
## caller. Listed AFTER DialogueConversionSystem (GSM Rule 10 / ADR-0001);
## subscribes to DCS signals via call_deferred so no session signal is missed.
## Real logic lands at M3; the deferred _connect_signals verification is
## completed in task 1-6.
