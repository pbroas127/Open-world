extends TextureButton

var item: ItemData = null
var amount: int = 0

const MAX_STACK = 64

var index: int = -1
var owner_ui = null  # crate_ui or inventory_ui

func set_item(new_item: ItemData, count: int = 1):
    item = new_item.duplicate()
    amount = count
    update_display()
    save_slot_to_json()

    if owner_ui and owner_ui.has_method("update_crate_data_from_slots"):
        owner_ui.update_crate_data_from_slots()


func clear_item():
    item = null
    amount = 0
    update_display()
    save_slot_to_json()

    if owner_ui and owner_ui.has_method("update_crate_data_from_slots"):
        owner_ui.update_crate_data_from_slots()


func save_slot_to_json():
    print("Saving slot:", name, " | Owner UI is inventory:", owner_ui.is_inventory if owner_ui and "is_inventory" in owner_ui else "N/A")
    if owner_ui == null or not ("is_inventory" in owner_ui) or not owner_ui.is_inventory:
        return  # ✅ Do not save if not inventory

    var save_path = "user://%s.json" % GameState.current_save_name
    var save_data = {}

    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            save_data = JSON.parse_string(content)
        file.close()

    if not save_data.has("inventory"):
        save_data["inventory"] = {}

    if item != null:
        save_data["inventory"][name] = {
            "item_name": item.name,
            "amount": amount
        }
    else:
        save_data["inventory"].erase(name)

    if "slots" in save_data:
        save_data.erase("slots")  # ✅ Remove outdated structure

    

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()


func update_display():
    if has_node("Icon"):
        $Icon.texture = item.icon if item else null

    if has_node("AmountLabel"):
        $AmountLabel.text = "x" + str(amount) if amount > 1 and item != null else ""

func _get_drag_data(_pos):
    if item == null:
        return null

    var drag_data = {
        "item": item,
        "amount": amount,
        "from": self
    }

    var preview = TextureRect.new()
    preview.texture = item.icon
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.custom_minimum_size = Vector2(48, 48)
    preview.z_index = 1000
    set_drag_preview(preview)

    return drag_data

func _can_drop_data(_pos, data):
    return data.has("item")

func _drop_data(_pos, data):
    var from_slot = data["from"]
    var incoming_item = data["item"]
    var incoming_amount = data["amount"]

    if item == null:
        set_item(incoming_item, incoming_amount)
        from_slot.clear_item()
    elif item.name == incoming_item.name:
        amount += incoming_amount
        update_display()
        save_slot_to_json()
        from_slot.clear_item()
        if from_slot.has_method("save_slot_to_json"):
            from_slot.save_slot_to_json()

    else:
        var temp_item = item
        var temp_amount = amount
        set_item(incoming_item, incoming_amount)
        from_slot.set_item(temp_item, temp_amount)
