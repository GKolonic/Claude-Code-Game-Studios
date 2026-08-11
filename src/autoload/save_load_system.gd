extends Node
## SaveLoadSystem — Autoload placeholder, ADR-0001 slot 10.
## Feature: JSON v1 persistence; boot calls load_game() once. Boots after
## NPCRegistry + GSM (its load_game() touches both). Real logic lands at M4;
## ADR-0001 dependency assertions are completed in task 1-6.
