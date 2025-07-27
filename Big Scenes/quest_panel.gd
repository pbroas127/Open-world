extends VBoxContainer

signal panel_ready


@onready var toggle_button = $ToggleButton
var quest_list  # Don't assign here yet!

func _ready():
    await get_tree().process_frame

    quest_list = $QuestListContainer
    print("✅ QuestPanel ready. quest_list =", quest_list)

    toggle_button.pressed.connect(_on_toggle_pressed)
    update_button_text()
    update_quest_list()

    GameState.quest_data_changed.connect(update_quest_list)  # ✅ Listen for live updates

    emit_signal("panel_ready")



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

    print("🔍 Updating quest list:", GameState.active_quests)

    quest_list.clear()  # 🧹 Clear previous items

    for npc_id in GameState.active_quests.keys():
        var full_text = GameState.active_quests[npc_id]
        var short_text = GameState.quest_log_text.get(npc_id, full_text)
        quest_list.add_item(short_text)  # ✅ Proper ItemList usage
