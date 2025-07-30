extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel
@onready var collision = $CollisionShape2D

@export var npc_id: String = "bridge_guard"

var stage: int = 0
var dialogue_active := false
var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var original_exclamation_pos := Vector2.ZERO
var required_item: String = ""
var awaiting_confirmation := false

func _ready():
    sprite.play("idle")
    prompt_label.text = "Press [E] to Talk"
    prompt_label.visible = false
    exclamation.visible = false
    original_exclamation_pos = exclamation.position

    chat_label.bbcode_enabled = true
    chat_label.scroll_active = false
    chat_label.fit_content = true
    chat_label.set_custom_minimum_size(Vector2(300, 0))
    chat_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # Load saved stage and required item
    if GameState.ship_npc_stage.has(npc_id):
        stage = GameState.ship_npc_stage[npc_id]
        if GameState.ship_npc_stage.has(npc_id + "_item"):
            required_item = GameState.ship_npc_stage[npc_id + "_item"]
    else:
        GameState.ship_npc_stage[npc_id] = stage

    if required_item == "":
        required_item = get_random_legendary_item_name()
        GameState.ship_npc_stage[npc_id + "_item"] = required_item

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
    match stage:
        0:
            await show_text("Hello there.\n\n[Space] to continue")
        1:
            await show_text("Sadly I can't let you pass.\n\n[Space] to continue")
        2:
            await show_text("I'm gonna need something in return.\n\n[Space] to continue")
        3:
            await show_text("Bring me 1 " + required_item + " and I'll move.\n\n[Space] to continue")
        4:
            var item_count = get_item_count(required_item)
            if item_count > 0:
                await show_text("I see you have x" + str(item_count) + " " + required_item + ".\nMay I have one? You can pass after.\n\n[Space] to say: Yes, take it")
                awaiting_confirmation = true
                return
            else:
                await show_text("You don't have the " + required_item + " yet.\nCome back when you do.\n\n[Space] to continue")
                stage = 3  # Go back to asking for item
        _:
            await show_text("Thanks for the item. You may pass!\n\n[Space] to continue")

    if stage < 4:
        stage += 1
        GameState.ship_npc_stage[npc_id] = stage

func handle_item_confirmation():
    awaiting_confirmation = false
    
    if remove_item_from_inventory(required_item):
        stage = 5  # Mark as completed
        GameState.ship_npc_stage[npc_id] = stage
        collision.disabled = true  # Allow passage
        await show_text("Perfect! You may now pass through.\n\n[Space] to continue")
    else:
        await show_text("Hmm, seems like you don't have it anymore.\n\n[Space] to continue")
        stage = 3  # Go back to asking

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

func get_random_legendary_item_name() -> String:
    var item = LootTable.get_random_loot_item_by_rarity(LootTable.Rarity.LEGENDARY)
    return item.name if item else "Legendary Item"

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
