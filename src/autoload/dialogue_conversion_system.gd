extends Node
## DialogueConversionSystem — Autoload placeholder, ADR-0001 slot 7.
## Feature: session orchestrator (resolve -> apply finally guarantee).
## Boots BEFORE GameStateManager (GSM Rule 10 / ADR-0001). Real logic lands
## at M3; ADR-0001 dependency assertions are completed in task 1-6.
