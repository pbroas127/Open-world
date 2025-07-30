extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel

@export var npc_id: String = "ship_mechanic"

var part_names: Array[String] = [
    "Plasma Coupler",
    "Thermal Regulator", 
    "Phase Link Core",
    "Ion Drive Unit",
    "Quantum Stabilizer"
]

var stage: int = 0
var dialogue_active := false
var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var original_exclamation_pos := Vector2.ZERO
var awaiting_confirmation := false

func _ready():
    chat_label.bbcode_enabled = true
    chat_label.scroll_active = false
    chat_label.fit_content = true
    chat_label.set_custom_minimum_size(Vector2(300, 0))
    chat_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    sprite.play("idle")
    prompt_label.text = "Press [E] to Talk"
    prompt_label.visible = false
    exclamation.visible = false
    original_exclamation_pos = exclamation.position

    if GameState.ship_npc_stage.has(npc_id):
        stage = GameState.ship_npc_stage[npc_id]
    else:
        GameState.ship_npc_stage[npc_id] = stage

    alert_area.connect("body_entered", _on_alert_entered)
    alert_area.connect("body_exited", _on_alert_exited)
    interact_area.connect("body_entered", _on_interact_entered)
    interact_area.connect("body_exited", _on_interact_exited)

func _process(delta):
    if player_in_alert_zone and not player_nearby:
        bob_time += delta
        exclamation.position = original_exclamation_pos + Vector2(0, sin(bob_time * 4.0) * 4.0)

    if player_nearby and Input.is_action_just_pressed("interact") and not dialogue_active:
        start_conversation()
    elif dialogue_active and Input.is_action_just_pressed("ui_accept"):
        if awaiting_confirmation:
            handle_item_confirmation()
        else:
            advance_conversation()

func _on_alert_entered(body):
    if body.name == "Player":
        player_in_alert_zone = true
        exclamation.visible = true

func _on_alert_exited(body):
    if body.name == "Player":
        player_in_alert_zone = false
        exclamation.visible = false

func _on_interact_entered(body):
    if body.name == "Player":
        player_nearby = true
        prompt_label.visible = true
        exclamation.visible = false

func _on_interact_exited(body):
    if body.name == "Player":
        player_nearby = false
        prompt_label.visible = false
        chat_bubble.visible = false
        dialogue_active = false
        awaiting_confirmation = false
        if player_in_alert_zone:
            exclamation.visible = true

        var player = get_tree().get_first_node_in_group("player")
        if player:
            player.zoom_out_after_convo()

func start_conversation():
    dialogue_active = true
    chat_label.text = ""
    chat_label.visible = true
    chat_bubble.visible = true
    prompt_label.visible = false

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_in_for_convo()

    advance_conversation()

func advance_conversation():
    if stage >= 10:
        await show_text("Thanks again, the ship's fully repaired.\n\n[Space] to close")
        return

    var index := int(stage / 2)
    var part: String = part_names[index]

    match stage:
        0:
            await show_text("Hello. Your ship is in rough shape.\n\n[Space] to continue")
        1:
            await show_text("This is gonna take a bit to fix.\nWe'll need a " + part + " first.\n\n[Space] to continue")
        2, 4, 6, 8:
            # Check if player has the required part
            if has_required_part(part):
                var count = get_item_count(part)
                await show_text("I see you have x" + str(count) + " " + part + ".\nMay I take one to continue repairs?\n\n[Space] to say: Yes, take it")
                awaiting_confirmation = true
            else:
                await show_text("Do you have the " + part + " yet?\n\n[Space] to continue")
                # Don't advance stage, keep asking for the same part
        3, 5, 7, 9:
            await show_text("Great! We're making progress.\nNext we'll need a " + part_names[int((stage + 1) / 2)] + ".\n\n[Space] to continue")
        _:
            await show_text("We're almost done...")

func handle_item_confirmation():
    awaiting_confirmation = false
    var index := int(stage / 2)
    var part: String = part_names[index]
    
    # Remove one item from inventory
    if remove_item_from_inventory(part):
        stage += 1
        GameState.ship_npc_stage[npc_id] = stage
        await show_text("Perfect! I'll get this installed right away.\n\n[Space] to continue")
    else:
        await show_text("Hmm, seems like you don't have it anymore.\n\n[Space] to continue")

func has_required_part(part_name: String) -> bool:
    return get_item_count(part_name) > 0

func get_item_count(item_name: String) -> int:
    var save_path = "user://%s.json" % GameState.current_save_name
    
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
    
    for slot_name in inventory_data.keys():
        var slot_data = inventory_data[slot_name]
        if slot_data.get("item_name", "") == item_name:
            total_count += slot_data.get("amount", 0)
    
    return total_count

func remove_item_from_inventory(item_name: String) -> bool:
    var save_path = "user://%s.json" % GameState.current_save_name
    
    if not FileAccess.file_exists(save_path):
        return false
    
    var file = FileAccess.open(save_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    if content == "":
        return false
    
    var save_data = JSON.parse_string(content)
    if not save_data or not save_data.has("inventory"):
        return false
    
    var inventory_data = save_data["inventory"]
    
    # Find first slot with this item and remove 1
    for slot_name in inventory_data.keys():
        var slot_data = inventory_data[slot_name]
        if slot_data.get("item_name", "") == item_name and slot_data.get("amount", 0) > 0:
            slot_data["amount"] -= 1
            
            # If amount reaches 0, clear the slot
            if slot_data["amount"] <= 0:
                inventory_data[slot_name] = {
                    "item_name": "",
                    "amount": 0,
                    "texture_path": ""
                }
            
            # Save the updated inventory
            var save_file = FileAccess.open(save_path, FileAccess.WRITE)
            save_file.store_string(JSON.stringify(save_data, "\t"))
            save_file.close()
            
            return true
    
    return false

func show_text(line: String) -> void:
    await type_text(chat_label, line)

func type_text(label: RichTextLabel, full_text: String, speed := 0.04) -> void:
    label.bbcode_enabled = true
    label.clear()
    var current_text := ""

    for i in full_text.length():
        current_text += full_text[i]
        label.bbcode_text = current_text

        if i % 3 == 0 or full_text[i] == "\n" or full_text[i] == " ":
            await get_tree().process_frame
            var label_size = label.get_minimum_size()
            var padding = Vector2(150, 150)
            var new_size = label_size + padding
            chat_bubble.size = new_size
            chat_bubble.pivot_offset = new_size / 2

            var bubble_tween := get_tree().create_tween()
            bubble_tween.tween_property(chat_bubble, "size", new_size, 0.1)
            bubble_tween.tween_property(chat_bubble, "pivot_offset", new_size / 2, 0.1)

        await get_tree().create_timer(speed).timeout
