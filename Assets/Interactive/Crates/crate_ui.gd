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
    for i in range(crate_slots.size()):
        crate_slots[i].index = i
        crate_slots[i].owner_ui = self

func open_with_items(items: Array[ItemData], crate_id: String = ""):
    visible = true
    bound_items = items
    bound_crate_id = crate_id
    sync_enabled = false

    for slot in crate_slots:
        slot.clear_item()

    var slot_index := 0
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
        slot_index += 1

    sync_enabled = true

func update_crate_data_from_slots():
    var crate_data = {}
    var updated_items = []

    for slot in crate_slots:
        var slot_name = slot.name  # e.g., "CSlot1", "CSlot2"
        if slot.item != null:
            var item_copy = slot.item.duplicate()
            item_copy.amount = slot.amount
            crate_data[slot_name] = {
                "item_name": item_copy.name,
                "amount": item_copy.amount
            }
            updated_items.append(item_copy)
        else:
            updated_items.append(null)

    # Update GameState
    GameState.chests[bound_crate_id] = updated_items

    # If sync is disabled, skip updating bound_items or saving
    if not sync_enabled:
        return

    # Update bound_items in-place to preserve reference
    for i in range(crate_slots.size()):
        if i < bound_items.size():
            bound_items[i] = updated_items[i]
        else:
            bound_items.append(updated_items[i])

    # Save to JSON
    var save_path = "user://save_data.json"
    var save_data = {}

    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        save_data = JSON.parse_string(file.get_as_text())
        file.close()

    save_data[bound_crate_id] = crate_data

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

func _on_CloseButton_pressed():
    update_crate_data_from_slots()
    visible = false

func _input(event):
    if visible and event.is_action_pressed("ui_cancel"):
        update_crate_data_from_slots()
        visible = false
