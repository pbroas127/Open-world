extends Node

var current_save_name: String = "save_data"  # default fallback


func initialize_new_game_data():
    HealthManager.set_health(100)

    var save_path = "user://%s.json" % GameState.current_save_name
    var save_data = {
        "player_health": 100,
        "inventory": {},
        # add more default values if needed
    }

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

    print("🆕 New game data initialized!")


func _ready():
    
    ensure_quest_ui_loaded()
    GameDatabase.register_item(preload("res://Assets/Resources/Items/Orb.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/scrap_metal.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/copper_wire.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/Plate.tres"))

signal quest_data_changed  # 🔔 Tell UI when to update



func save_game():
    var save_path = "user://%s.json" % GameState.current_save_name

    var data = {
        "quests": active_quests,
        "quest_log_text": quest_log_text,
        "inventory": inventory,
        "player_health": HealthManager.current_health  # ✅ Save player health
    }

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))
    file.close()

    emit_signal("quest_data_changed")



func load_game():
    var save_path = "user://%s.json" % current_save_name
    print("🔁 Loading from: ", save_path)

    if not FileAccess.file_exists(save_path):
        return

    var file = FileAccess.open(save_path, FileAccess.READ)
    var text = file.get_as_text()
    var result = JSON.parse_string(text)
    file.close()

    if result:
        if result.has("quests"):
            active_quests = result["quests"]
        if result.has("quest_log_text"):
            quest_log_text = result["quest_log_text"]
        if result.has("inventory"):
            inventory = result["inventory"]
        if result.has("chests"):
            chests = result["chests"]
        if result.has("player_health"):
            HealthManager.set_health(result["player_health"])  # ✅ Set loaded health



func generate_list_text(full_text: String) -> String:
    var cleaned = full_text.strip_edges()
    cleaned = cleaned.replace("\n", " ")
    cleaned = cleaned.capitalize()
    
    # Example custom mappings:
    if "scrap wolves" in cleaned.to_lower():
        return "Eliminate Scrap Wolves 0/5"
    elif "energy cells" in cleaned.to_lower():
        return "Collect Energy Cells 0/10"
    elif "beacon" in cleaned.to_lower():
        return "Find Lost Beacon 0/1"
    elif "shipyard npc" in cleaned.to_lower():
        return "Bring Message to Shipyard 0/1"
    elif "rare parts" in cleaned.to_lower():
        return "Recover Rare Parts 0/3"
    elif "strange signal" in cleaned.to_lower():
        return "Scan Strange Signal 0/1"
    elif "raider camp" in cleaned.to_lower():
        return "Clear Raider Camp 0/1"
    elif "temple doors" in cleaned.to_lower():
        return "Confirm Temple Access 0/1"

    # Fallback if no match
    return cleaned



var ship_npc_stage := {}  # Stores ship NPC progress by ID
var last_entry_point := ""
var last_door_position := Vector2.ZERO

# Player inventory: array of ItemData
var inventory: Dictionary = {}


var stories = {}  # npc_id : selected_story_line
var chests := {}  # { "chest_1": [ItemData, ItemData], ... }
var trade_offers := {}  # { "jawa_1": OfferData, ... }
var crate_types: Dictionary = {}

# Quests
var quests = {}  # NPC_ID : full quest text
var quests_accepted = {}  # NPC_ID : 0 or 1
var active_quests = {}  # NPC_ID : full quest text
var quest_log_text = {}  # NPC_ID : short-form "Eliminate X" string





# Utility: get item by name
func get_item_from_inventory(item_name: String) -> ItemData:
    for item in inventory:
        if item.name == item_name:
            return item
    return null

func has_item(item_name: String) -> bool:
    return get_item_from_inventory(item_name) != null

var quest_ui: CanvasLayer = null

func ensure_quest_ui_loaded():
    if quest_ui == null:
        var quest_ui_scene = preload("res://UI/QuestUI.tscn")
        quest_ui = quest_ui_scene.instantiate()
        get_tree().get_root().add_child(quest_ui)
        quest_ui.owner = null  # Don’t delete on scene change

        await get_tree().process_frame  # Let it add children

        var panel = quest_ui.get_node("QuestPanel")
        if panel:
            panel.connect("panel_ready", func():
                print("✅ QuestPanel emitted ready signal")
                panel.update_quest_list()
            )
        else:
            print("❌ QuestPanel still not found after load!")
