extends Node2D
@onready var inventory_ui = $Ui
@onready var player = $A2OutsideYslot/Player

func _ready():
    GameState.ensure_quest_ui_loaded()
    inventory_ui.load_inventory_from_game_state()
   
