# UPDATED CrateUI.gd - No longer manages crate types
extends Control

@onready var crate_slots := [
    $CrateSlots/CSlot1,
    $CrateSlots/CSlot2,
    $CrateSlots/CSlot3,
    $CrateSlots/CSlot4,
    $CrateSlots/CSlot5,
    $CrateSlots/CSlot6
]

var sync_enabled := true
var bound_items: Array[ItemData] = []
var bound_crate_id: String = ""

func _ready():
    GameState.save_game()

    for i in range(crate_slots.size()):
        crate_slots[i].index = i
        crate_slots[i].owner_ui = self
        crate_slots[i].connect("item_amount_changed", Callable(self, "_on_item_amount_changed"))

func _on_item_amount_changed():
    update_crate_data_from_slots()

func open_with_items(items: Array[ItemData], crate_id: String = "", crate_type: String = ""):
    visible = true
    bound_items = items
    bound_crate_id = crate_id
    sync_enabled = false

    for slot in crate_slots:
        slot.clear_item()

    var slot_index := 0

    # ✅ SIMPLIFIED: Only handle crate contents, not types
    var crate_save_path = "user://%s.json" % GameState.current_save_name
    var crate_json = {}

    if FileAccess.file_exists(crate_save_path):
        var file = FileAccess.open(crate_save_path, FileAccess.READ)
        var text = file.get_as_text()
        if text != "":
            crate_json = JSON.parse_string(text)
        file.close()

    if not crate_json.has("crates"):
        crate_json["crates"] = {}

    if not crate_json["crates"].has(crate_id):
        crate_json["crates"][crate_id] = {}

    # ✅ REMOVED: No longer save type here - it's managed by GameState.crate_types

    var clean_console_log := []

    for item in items:
        if item == null:
            continue
        while slot_index < crate_slots.size() and crate_slots[slot_index].item != null:
            slot_index += 1
        if slot_index >= crate_slots.size():
            break
        var item_copy = item.duplicate()
        item_copy.amount = item.amount
        crate_slots[slot_index].set_item(item_copy, item_copy.amount)

        var slot_name = crate_slots[slot_index].name
        clean_console_log.append("%s -> %s x%d" % [crate_id, item_copy.name, item_copy.amount])
        crate_json["crates"][crate_id][slot_name] = {
            "item_name": item_copy.name,
            "amount": item_copy.amount
        }

        slot_index += 1

    print("🧾 Contents of crate:", crate_id, "(Type: ", crate_type, ")")
    for line in clean_console_log:
        print(line)

    var file = FileAccess.open(crate_save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(crate_json, "\t"))
    file.close()

    sync_enabled = true

func update_crate_data_from_slots():
    var crate_data = {}
    var updated_items = []

    for slot in crate_slots:
        var slot_name = slot.name
        if slot.item:
            var item_copy = slot.item.duplicate()
            item_copy.amount = slot.amount
            crate_data[slot_name] = {
                "item_name": item_copy.name,
                "amount": item_copy.amount
            }
            updated_items.append(item_copy)
        else:
            updated_items.append(null)

    var save_path = "user://%s.json" % GameState.current_save_name
    var save_data = {}

    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            save_data = JSON.parse_string(content)
        file.close()

    if not save_data.has("crates"):
        save_data["crates"] = {}

    if not save_data["crates"].has(bound_crate_id):
        save_data["crates"][bound_crate_id] = {}

    # Clear old crate slot data
    for key in save_data["crates"][bound_crate_id].keys():
        if key.begins_with("CSlot"):
            save_data["crates"][bound_crate_id].erase(key)

    # Add new crate slot data
    for slot_key in crate_data:
        save_data["crates"][bound_crate_id][slot_key] = crate_data[slot_key]

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()
    
    GameState.chests[bound_crate_id] = save_data["crates"][bound_crate_id]

    if not sync_enabled:
        return

    for i in range(crate_slots.size()):
        if i < bound_items.size():
            bound_items[i] = updated_items[i]
        else:
            bound_items.append(updated_items[i])

    print("🔄 Updated crate contents:", bound_crate_id)
    for slot_key in crate_data.keys():
        var info = crate_data[slot_key]
        print("%s -> %s x%d" % [bound_crate_id, info["item_name"], int(info["amount"])])

func _on_CloseButton_pressed():
    update_crate_data_from_slots()
    visible = false

func _input(event):
    if visible and event.is_action_pressed("ui_cancel"):
        update_crate_data_from_slots()
        visible = false
