# DEBUG UI.gd - This will show you exactly what's happening
extends CanvasLayer

@onready var all_slots = [
    $HotbarUI/HotbarSlots/Slot1,
    $HotbarUI/HotbarSlots/Slot2,
    $HotbarUI/HotbarSlots/Slot3,
    $HotbarUI/HotbarSlots/Slot4,
    $HotbarUI/HotbarSlots/Slot5,
    $HotbarUI/HotbarSlots/Slot6,
    $InventoryUI/InventorySlots/Slot7,
    $InventoryUI/InventorySlots/Slot8,
    $InventoryUI/InventorySlots/Slot9,
    $InventoryUI/InventorySlots/Slot10,
    $InventoryUI/InventorySlots/Slot11,
    $InventoryUI/InventorySlots/Slot12,
    $InventoryUI/InventorySlots/Slot13,
    $InventoryUI/InventorySlots/Slot14,
    $InventoryUI/InventorySlots/Slot15,
    $InventoryUI/InventorySlots/Slot16,
    $InventoryUI/InventorySlots/Slot17,
    $InventoryUI/InventorySlots/Slot18,
    $InventoryUI/InventorySlots/Slot19,
    $InventoryUI/InventorySlots/Slot20,
    $InventoryUI/InventorySlots/Slot21,
    $InventoryUI/InventorySlots/Slot22,
    $InventoryUI/InventorySlots/Slot23,
    $InventoryUI/InventorySlots/Slot24,
    $InventoryUI/InventorySlots/Slot25,
    $InventoryUI/InventorySlots/Slot26,
    $InventoryUI/InventorySlots/Slot27,
    $InventoryUI/InventorySlots/Slot28,
    $InventoryUI/InventorySlots/Slot29,
    $InventoryUI/InventorySlots/Slot30
]


var is_inventory := true
var selected_hotbar_index := 0

# Preload all 6 images at the top for performance
var hotbar_images = [
    preload("res://Assets/UI Images/quickbar1.png"),
    preload("res://Assets/UI Images/quickbar2.png"),
    preload("res://Assets/UI Images/quickbar3.png"),
    preload("res://Assets/UI Images/quickbar4.png"),
    preload("res://Assets/UI Images/quickbar5.png"),
    preload("res://Assets/UI Images/quickbar6.png")
]

# ✅ Load directly from JSON file with LOTS of debug info
func load_inventory_from_game_state():
    print("🔄 === LOADING INVENTORY DEBUG ===")
    var save_path = "user://%s.json" % GameState.current_save_name
    print("🔄 Loading from path: ", save_path)
    
    if not FileAccess.file_exists(save_path):
        print("❌ No save file found at: ", save_path)
        return
        
    var file = FileAccess.open(save_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    print("📄 Raw file content: ", content)
    
    if content == "":
        print("❌ Save file is empty")
        return
        
    var save_data = JSON.parse_string(content)
    if not save_data:
        print("❌ Failed to parse JSON")
        return
        
    print("📋 Parsed save_data keys: ", save_data.keys())
    
    if not save_data.has("inventory"):
        print("❌ No inventory key in save data")
        return
        
    var inventory_data = save_data["inventory"]
    print("🎒 Inventory data from file: ", inventory_data)

    # Clear all slots first
    for slot in all_slots:
        slot.clear_item()
        print("🧹 Cleared slot: ", slot.name)

    # Load items into slots
    for slot in all_slots:
        var slot_name = slot.name  # e.g. "Slot1", "Slot2"
        if inventory_data.has(slot_name):
            var item_info = inventory_data[slot_name]
            print("📦 Found item for ", slot_name, ": ", item_info)
            var item = GameDatabase.get_item_by_name(item_info["item_name"])
            if item != null:
                var item_copy = item.duplicate()
                item_copy.amount = item_info["amount"]
                slot.set_item(item_copy, item_copy.amount)
                print("✅ Successfully loaded into ", slot_name, ": ", item_info["item_name"], " x", item_info["amount"])
            else:
                print("❌ Could not find item in database: ", item_info["item_name"])
        else:
            print("⭕ No data for slot: ", slot_name)
    
    print("🔄 === LOADING COMPLETE ===")

func _ready():
    await get_tree().process_frame
    print("🎮 UI _ready() called in scene: ", get_tree().current_scene.name)

    if get_tree().current_scene.name == "StartScreen":
        visible = false
    else:
        visible = true

    # Set up slots first
    for slot in all_slots:
        slot.owner_ui = self
    
    # Add self to inventory_ui group for easy access
    add_to_group("inventory_ui")
    
    print("🔧 UI setup complete, waiting for manual load call")

func save_inventory_to_json():
    print("💾 === SAVING INVENTORY DEBUG ===")
    var save_path = "user://%s.json" % GameState.current_save_name
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
        var slot_name = slot.name  # Like "Slot1", "Slot2"
        if slot.item != null:
            inventory_data[slot_name] = {
                "item_name": slot.item.name,
                "amount": slot.amount
            }
            print("💾 Saving ", slot_name, ": ", slot.item.name, " x", slot.amount)

    save_data["inventory"] = inventory_data
    print("💾 Final inventory data to save: ", inventory_data)

    if save_data.has("slots"):
        save_data.erase("slots")

    # Write to file
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    var json_string = JSON.stringify(save_data, "\t")
    file.store_string(json_string)
    file.close()
    
    print("💾 Saved to file: ", json_string)

    # Update in-memory state AFTER successful save
    GameState.inventory = inventory_data
    print("💾 === SAVING COMPLETE ===")

func add_item(item: ItemData):
    print("➕ Adding item: ", item.name)
    
    # Try to stack with existing items first
    for slot in all_slots:
        slot.owner_ui = self
        if slot.item != null and slot.item.name == item.name and slot.amount < slot.MAX_STACK:
            slot.amount += 1
            slot.update_display()
            print("📚 Stacked item in ", slot.name, ", new amount: ", slot.amount)
            save_inventory_to_json()  # Save immediately after change
            return

    # Find empty slot for new item
    for slot in all_slots:
        slot.owner_ui = self
        if slot.item == null:
            slot.set_item(item, 1)
            print("📦 Added new item to ", slot.name)
            save_inventory_to_json()  # Save immediately after change
            return

    print("❌ Inventory full!")

func _input(event):
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

func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        print("🚪 App closing, force saving inventory")
        save_inventory_to_json()
