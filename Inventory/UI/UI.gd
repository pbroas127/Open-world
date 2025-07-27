extends CanvasLayer

@onready var all_slots = [
    $HotbarUI/HotbarSlots/Slot1,
    $HotbarUI/HotbarSlots/Slot2,
    $HotbarUI/HotbarSlots/Slot3,
    $HotbarUI/HotbarSlots/Slot4,
    $HotbarUI/HotbarSlots/Slot5,
    $HotbarUI/HotbarSlots/Slot6,
    $InventoryUI/InventorySlots/Slot7
]


var is_inventory := true
var selected_hotbar_index := 0


func load_inventory_from_game_state():
    if not GameState.inventory:
        return

    var inventory_data = GameState.inventory

    for slot in all_slots:
        var slot_name = slot.name  # e.g. "Slot1", "Slot2"
        if inventory_data.has(slot_name):
            var item_info = inventory_data[slot_name]
            var item = GameDatabase.get_item_by_name(item_info["item_name"])
            if item != null:
                var item_copy = item.duplicate()
                item_copy.amount = item_info["amount"]
                slot.set_item(item_copy, item_copy.amount)
        else:
            slot.clear_item()

func _ready():
    for slot in all_slots:
        slot.owner_ui = self  # ✅ THIS is the missing piece!


# Preload all 6 images at the top forF performance
var hotbar_images = [
    preload("res://Assets/UI Images/quickbar1.png"),
    preload("res://Assets/UI Images/quickbar2.png"),
    preload("res://Assets/UI Images/quickbar3.png"),
    preload("res://Assets/UI Images/quickbar4.png"),
    preload("res://Assets/UI Images/quickbar5.png"),
    preload("res://Assets/UI Images/quickbar6.png")
]

func save_inventory_to_json():
    var save_path = "user://save_data.json"
    var save_data = {}

    # Load existing data
    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            save_data = JSON.parse_string(content)
        file.close()

    # Save inventory using slot names
    var inventory_data = {}
    for slot in all_slots:
        slot.owner_ui = self
        print(slot.name, ": ", slot.item.name if slot.item else "empty", " x", slot.amount)
        var slot_name = slot.name  # Like "Slot1", "Slot2"
        if slot.item != null:
            inventory_data[slot_name] = {
                "item_name": slot.item.name,
                "amount": slot.amount
            }

    # Save under "inventory" key
    save_data["inventory"] = inventory_data

    # Remove old "slots" key if needed
    if save_data.has("slots"):
        save_data.erase("slots")

    # Write to file
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()


func add_item(item: ItemData):
    for slot in all_slots:
        slot.owner_ui = self
        if slot.item != null and slot.item.name == item.name and slot.amount < slot.MAX_STACK:
            slot.amount += 1
            slot.update_display()
            save_inventory_to_json()  # ✅ Save stacked item change
            return

    for slot in all_slots:
        slot.owner_ui = self
        if slot.item == null:
            slot.set_item(item, 1)
            save_inventory_to_json()  # ✅ Save newly added item
            return


    print("Inventory full!")






func _input(event):
    if event.is_action_pressed("ui_tab"):
        $InventoryUI.visible = true
    elif event.is_action_pressed("ui_cancel"):
        $InventoryUI.visible = false

    # Hotbar selection
    for i in range(6):
        if event.is_action_pressed("hotbar_slot_%d" % (i + 1)):
            selected_hotbar_index = i
            update_hotbar_image()
            break

  

    if event.is_action_pressed("ui_tab"):
        $InventoryUI.visible = true
    elif event.is_action_pressed("ui_cancel"):
        $InventoryUI.visible = false
    
    # Handle hotbar key presses (1–6)
    for i in range(6):
        if event.is_action_pressed("hotbar_slot_%d" % (i + 1)):
            selected_hotbar_index = i
            update_hotbar_image()
            break

func update_hotbar_image():
    $HotbarUI/HotbarBackground.texture = hotbar_images[selected_hotbar_index]
