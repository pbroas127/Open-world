extends Node2D

@onready var player = $Outside/Player
@onready var entrance_from_a2 = $Outside/b2toa2
@onready var inventory_ui = $Ui


func _ready():
    GameState.ensure_quest_ui_loaded()
    GameState.load_game()
    # Handle spawn position if coming from A2
    if GameState.last_entry_point == "a2_to_b2" and player and entrance_from_a2:
        player.global_position = entrance_from_a2.global_position + Vector2(220, -175)
        print("✅ Spawned from A2 at:", player.global_position)
        GameState.last_entry_point = ""  # Reset

    inventory_ui.load_inventory_from_game_state()
