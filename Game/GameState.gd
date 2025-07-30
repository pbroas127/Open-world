# UPDATED GameState.gd - Added Quest Progress System
extends Node

var current_save_name: String = "save_data"

func initialize_new_game_data():
    HealthManager.set_health(100)

    var save_path = "user://%s.json" % GameState.current_save_name
    var save_data = {
        "player_health": 100,
        "inventory": {},
        "crate_types": {},
        "crates": {},
        "quest_progress": {}  # ✅ NEW: Quest progress tracking
    }

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

    print("🆕 New game data initialized with quest progress!")

func _ready():
    ensure_quest_ui_loaded()
    GameDatabase.register_item(preload("res://Assets/Resources/Items/Orb.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/scrap_metal.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/copper_wire.tres"))
    GameDatabase.register_item(preload("res://Assets/Resources/Items/Plate.tres"))

signal quest_data_changed

# ✅ NEW: Quest progress tracking
var quest_progress: Dictionary = {}
var is_updating_quest_progress: bool = false  # Prevent infinite recursion

func save_game():
    var save_path = "user://%s.json" % GameState.current_save_name

    var existing_data = {}
    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            existing_data = JSON.parse_string(content)
        file.close()

    var data = existing_data
    data["quests"] = active_quests
    data["quest_log_text"] = quest_log_text
    data["quest_progress"] = quest_progress  # ✅ Save quest progress
    data["player_health"] = HealthManager.current_health
    data["crates"] = chests

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))
    file.close()

    emit_signal("quest_data_changed")

func save_crate_types():
    var save_path = "user://%s.json" % GameState.current_save_name
    var existing_data = {}

    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            existing_data = JSON.parse_string(content)
        file.close()

    existing_data["crate_types"] = crate_types

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(existing_data, "\t"))
    file.close()

    print("💾 Saved crate types:", crate_types)

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
        if result.has("quest_progress"):  # ✅ Load quest progress
            quest_progress = result["quest_progress"]
        if result.has("player_health"):
            HealthManager.set_health(result["player_health"])
        if result.has("crates"):
            chests = result["crates"]
        if result.has("crate_types"):
            crate_types = result["crate_types"]
            print("🎲 Loaded crate types:", crate_types)
        
        print("🔁 GameState loaded (inventory handled by UI)")

# ✅ NEW: Initialize quest progress when quest is accepted
func initialize_quest_progress(npc_id: String, quest_text: String):
    var quest_type = get_quest_type_from_text(quest_text)
    var target = get_quest_target_from_text(quest_text)
    
    quest_progress[npc_id] = {
        "current": 0,
        "target": target,
        "type": quest_type
    }
    
    print("🎯 Initialized quest progress for ", npc_id, ": ", quest_progress[npc_id])
    save_game()

# ✅ NEW: Determine quest type from quest text
func get_quest_type_from_text(quest_text: String) -> String:
    var lower_text = quest_text.to_lower()
    
    if "scrap wolves" in lower_text:
        return "kill_scrap_wolves"
    elif "energy cells" in lower_text:
        return "collect_energy_cells"
    elif "scrap metal" in lower_text:
        return "collect_scrap_metal"
    elif "beacon" in lower_text:
        return "find_beacon"
    elif "shipyard npc" in lower_text:
        return "deliver_message"
    elif "rare parts" in lower_text:
        return "collect_rare_parts"
    elif "strange signal" in lower_text:
        return "scan_signal"
    elif "raider camp" in lower_text:
        return "clear_raiders"
    elif "temple doors" in lower_text:
        return "confirm_temple"
    
    return "unknown"

# ✅ NEW: Extract target number from quest text
func get_quest_target_from_text(quest_text: String) -> int:
    var regex = RegEx.new()
    regex.compile("\\d+")
    var result = regex.search(quest_text)
    
    if result:
        return result.get_string().to_int()
    
    return 1  # Default to 1 if no number found

# ✅ NEW: Update quest progress based on inventory for collection quests
func update_collection_quest_progress():
    if is_updating_quest_progress:
        return  # Prevent infinite recursion
    
    is_updating_quest_progress = true
    print("🔄 Updating collection quest progress...")
    
    for npc_id in quest_progress.keys():
        var progress = quest_progress[npc_id]
        var quest_type = progress["type"]
        
        # Handle collection quests by checking inventory
        if quest_type == "collect_scrap_metal":
            var scrap_count = count_item_in_inventory("scrap_metal")
            progress["current"] = min(scrap_count, progress["target"])
            print("🔩 Updated scrap metal quest for ", npc_id, ": ", progress["current"], "/", progress["target"])
        
        elif quest_type == "collect_energy_cells":
            var energy_count = count_item_in_inventory("energy_cell")
            progress["current"] = min(energy_count, progress["target"])
            print("⚡ Updated energy cells quest for ", npc_id, ": ", progress["current"], "/", progress["target"])
    
    save_game()
    emit_signal("quest_data_changed")
    is_updating_quest_progress = false

# ✅ NEW: Count specific items in inventory from JSON
func count_item_in_inventory(item_name: String) -> int:
    var save_path = "user://%s.json" % current_save_name
    
    if not FileAccess.file_exists(save_path):
        return 0
    
    var file = FileAccess.open(save_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    if content == "":
        return 0
    
    var save_data = JSON.parse_string(content)
    if not save_data or not save_data.has("inventory"):
        return 0
    
    var inventory_data = save_data["inventory"]
    var total_count = 0
    
    # ✅ Define item name mappings to handle different formats
    var item_mappings = {
        "scrap_metal": ["Scrap Metal", "scrap_metal", "scrap metal"],
        "energy_cell": ["Energy Cell", "energy_cell", "energy cell"]
    }
    
    var search_names = []
    if item_mappings.has(item_name):
        search_names = item_mappings[item_name]
    else:
        search_names = [item_name]
    
    # Check all inventory slots for any of the possible item names
    for slot_name in inventory_data.keys():
        var slot_data = inventory_data[slot_name]
        var slot_item_name = slot_data["item_name"]
        
        for search_name in search_names:
            if slot_item_name == search_name:
                total_count += slot_data["amount"]
                break
    
    print("📊 Found ", total_count, " of ", item_name, " (searched for: ", search_names, ") in inventory")
    return total_count

func generate_list_text(full_text: String) -> String:
    var cleaned = full_text.strip_edges()
    cleaned = cleaned.replace("\n", " ")
    cleaned = cleaned.capitalize()

    if "scrap wolves" in cleaned.to_lower():
        return "Eliminate Scrap Wolves 0/5"
    elif "energy cells" in cleaned.to_lower():
        return "Collect Energy Cells 0/10"
    elif "scrap metal" in cleaned.to_lower():  # ✅ NEW quest type
        return "Collect Scrap Metal 0/10"
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

    return cleaned

# ✅ NEW: Generate quest text with current progress
func generate_quest_display_text(npc_id: String) -> String:
    if not quest_progress.has(npc_id):
        return quest_log_text.get(npc_id, "Unknown Quest")
    
    var progress = quest_progress[npc_id]
    var quest_type = progress["type"]
    var current = progress["current"]
    var target = progress["target"]
    
    match quest_type:
        "kill_scrap_wolves":
            return "Eliminate Scrap Wolves %d/%d" % [current, target]
        "collect_energy_cells":
            return "Collect Energy Cells %d/%d" % [current, target]
        "collect_scrap_metal":
            return "Collect Scrap Metal %d/%d" % [current, target]
        "find_beacon":
            return "Find Lost Beacon %d/%d" % [current, target]
        "deliver_message":
            return "Bring Message to Shipyard %d/%d" % [current, target]
        "collect_rare_parts":
            return "Recover Rare Parts %d/%d" % [current, target]
        "scan_signal":
            return "Scan Strange Signal %d/%d" % [current, target]
        "clear_raiders":
            return "Clear Raider Camp %d/%d" % [current, target]
        "confirm_temple":
            return "Confirm Temple Access %d/%d" % [current, target]
        _:
            return "Unknown Quest %d/%d" % [current, target]

var ship_npc_stage := {}
var last_entry_point := ""
var last_door_position := Vector2.ZERO
var inventory: Dictionary = {}
var stories = {}
var trade_offers := {}
var crate_types: Dictionary = {}
var quests = {}
var quests_accepted = {}
var active_quests = {}
var quest_log_text = {}
var chests := {}

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
        quest_ui.owner = null

        await get_tree().process_frame

        var panel = quest_ui.get_node("QuestPanel")
        if panel:
            panel.connect("panel_ready", func():
                print("✅ QuestPanel emitted ready signal")
                panel.update_quest_list()
            )
        else:
            print("❌ QuestPanel still not found after load!")
