extends Node2D

@onready var player = $Interior/Player
@onready var door_to_outside = $Interior/B2Building/DoorToOutside
@onready var inventory_ui = $Ui

func _ready():
    GameState.ensure_quest_ui_loaded()
    
    # ✅ USE A2's WORKING ORDER: Load inventory FIRST, then GameState  
    inventory_ui.load_inventory_from_game_state()
    GameState.load_game()
    
    # Handle spawn position from door
    if GameState.last_door_position != Vector2.ZERO:
        player.global_position = door_to_outside.global_position + Vector2(0, -100)
        
