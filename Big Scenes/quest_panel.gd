extends VBoxContainer

signal panel_ready
@onready var toggle_button = $ToggleButton
var quest_list  # Don't assign here yet!
var is_updating = false  # ✅ Prevent multiple simultaneous updates

func _ready():
    await get_tree().process_frame
    quest_list = $QuestListContainer
    
    toggle_button.pressed.connect(_on_toggle_pressed)
    update_button_text()
    update_quest_list()
    GameState.quest_data_changed.connect(_on_quest_data_changed)  # ✅ Use debounced function
    emit_signal("panel_ready")

# ✅ NEW: Debounced quest data change handler
func _on_quest_data_changed():
    if is_updating:
        return
    call_deferred("update_quest_list")

func _on_toggle_pressed():
    if quest_list:
        quest_list.visible = !quest_list.visible
        update_button_text()

func update_button_text():
    toggle_button.text = "Quests " + ("▼" if quest_list and quest_list.visible else "▲")

func update_quest_list():
    if quest_list == null:
        print("❌ Still null: quest_list. Can't update UI.")
        return
    
    if is_updating:
        print("🔄 Already updating quest list, skipping...")
        return
    
    is_updating = true
    print("📋 === UPDATING QUEST LIST ===")
    
    quest_list.clear()  # 🧹 Clear previous items
    
    # ✅ Update collection quest progress before displaying
    GameState.update_collection_quest_progress()
    
    var quest_count = 0
    for npc_id in GameState.active_quests.keys():
        # ✅ Use the new progress-aware display text
        var display_text = GameState.generate_quest_display_text(npc_id)
        quest_list.add_item(display_text)  # ✅ Proper ItemList usage
        quest_count += 1
        print("📋 Added quest ", quest_count, ": ", display_text)
    
    print("📋 === QUEST LIST UPDATE COMPLETE (", quest_count, " quests) ===")
    is_updating = false
