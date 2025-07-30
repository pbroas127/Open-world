extends Node2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel

@export var npc_id: String = ""


var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var original_exclamation_pos := Vector2.ZERO
var is_typing := false
var dialogue_active := false
var awaiting_confirmation := false
var current_item_index := 0
var stage := 0  # 0 = initial, 1 = in progress, 2 = completed

# Trade state
var has_active_offer := false
var current_offer = null

func _ready():
   

    # Visual setup...
    chat_label.bbcode_enabled = true
    chat_label.scroll_active = false
    chat_label.fit_content = true
    chat_label.set_custom_minimum_size(Vector2(300, 0))
    chat_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    sprite.play("idle")
    prompt_label.visible = false
    exclamation.visible = false
    original_exclamation_pos = exclamation.position

    # Load saved stage and trade
    if GameState.trade_npc_stage.has(npc_id):
        stage = GameState.trade_npc_stage[npc_id]
        current_item_index = GameState.trade_npc_stage.get(npc_id + "_item_index", 0)
    
    # 🧠 Load or generate trade
    if GameState.trade_offers.has(npc_id):
        current_offer = GameState.trade_offers[npc_id]
        has_active_offer = true
    else:
        current_offer = preload("res://Assets/NPC/Trade/TradeOffer.gd").new()
        current_offer.generate_offer()
        has_active_offer = true
        GameState.trade_offers[npc_id] = current_offer  # 💾 Save it
        GameState.save_game()  # Save the generated trade

    # Area connections
    alert_area.connect("body_entered", _on_alert_entered)
    alert_area.connect("body_exited", _on_alert_exited)
    interact_area.connect("body_entered", _on_interact_entered)
    interact_area.connect("body_exited", _on_interact_exited)


func _process(delta):
    if player_in_alert_zone and not player_nearby:
        bob_time += delta
        exclamation.position = original_exclamation_pos + Vector2(0, sin(bob_time * 4.0) * 4.0)

    if player_nearby and Input.is_action_just_pressed("interact") and not dialogue_active:
        start_trade_dialogue()
    elif dialogue_active and Input.is_action_just_pressed("ui_accept") and not is_typing:
        if awaiting_confirmation:
            handle_trade_confirmation()
        else:
            advance_trade_dialogue()

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

func type_text(label: RichTextLabel, full_text: String, speed := 0.05) -> void:
    is_typing = true
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
    
    is_typing = false

func start_trade_dialogue():
    dialogue_active = true
    chat_label.text = ""
    chat_label.visible = true
    chat_bubble.visible = true
    prompt_label.visible = false
    
    # Reset to initial stage if starting fresh
    if stage == 0:
        current_item_index = 0

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_in_for_convo()

    advance_trade_dialogue()

func advance_trade_dialogue():
    if current_item_index == 0:
        # Show initial trade offer
        var sentence = current_offer.get_offer_sentence()
        await type_text(chat_label, sentence + "\n\n[Space] to accept trade")
        current_item_index = 1  # Move to first item check
        stage = 1  # Mark as in progress
        GameState.trade_npc_stage[npc_id] = stage
        GameState.trade_npc_stage[npc_id + "_item_index"] = current_item_index
        GameState.save_game()  # Save progress
        return
    
    if current_item_index > current_offer.cost_items.size():
        # All items confirmed, complete the trade
        complete_trade()
        return

    var current_item = current_offer.cost_items[current_item_index - 1]  # -1 because we start at 1
    var item_count = get_item_count(current_item.name)
    
    if item_count >= current_item.amount:
        # Player has enough of this item
        await type_text(chat_label, "I see you have x" + str(item_count) + " " + current_item.name + ".\nMay I take x" + str(current_item.amount) + "?\n\n[Space] to say: Yes, take it")
        awaiting_confirmation = true
    else:
        # Player doesn't have enough - stop the trade
        await type_text(chat_label, "You don't have enough " + current_item.name + ".\nYou need x" + str(current_item.amount) + " but only have x" + str(item_count) + ".\nCome back when you have enough.\n\n[Space] to close")
        dialogue_active = false
        return

func handle_trade_confirmation():
    awaiting_confirmation = false
    var current_item = current_offer.cost_items[current_item_index - 1]  # -1 because we start at 1
    
    if remove_item_from_inventory(current_item.name, current_item.amount):
        current_item_index += 1
        GameState.trade_npc_stage[npc_id + "_item_index"] = current_item_index
        GameState.save_game()  # Save progress
        await type_text(chat_label, "Perfect! Thank you.\n\n[Space] to continue")
        advance_trade_dialogue()
    else:
        await type_text(chat_label, "Hmm, seems like you don't have it anymore.\n\n[Space] to continue")

func complete_trade():
    # Give the reward
    give_reward()
    
    # Reset stage and generate new trade offer
    stage = 0
    current_item_index = 0
    GameState.trade_npc_stage[npc_id] = stage
    GameState.trade_npc_stage[npc_id + "_item_index"] = current_item_index
    
    current_offer = preload("res://Assets/NPC/Trade/TradeOffer.gd").new()
    current_offer.generate_offer()
    GameState.trade_offers[npc_id] = current_offer
    GameState.save_game()  # Save the new trade
    
    await type_text(chat_label, "Excellent! Here's your " + current_offer.offer.name + ".\n\n[Space] to close")
    dialogue_active = false

func give_reward():
    # Find the inventory UI and add the reward
    var inventory_ui = get_tree().current_scene.get_node_or_null("Ui")
    if inventory_ui and inventory_ui.has_method("add_item"):
        # Add the full amount of the reward
        for i in range(current_offer.offer.amount):
            inventory_ui.add_item(current_offer.offer)
        print("🎁 Gave reward: " + current_offer.offer.name + " x" + str(current_offer.offer.amount))

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

func remove_item_from_inventory(item_name: String, amount: int) -> bool:
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
    var remaining_to_remove = amount
    
    # Find slots with this item and remove the required amount
    for slot_name in inventory_data.keys():
        if remaining_to_remove <= 0:
            break
            
        var slot_data = inventory_data[slot_name]
        if slot_data.get("item_name", "") == item_name and slot_data.get("amount", 0) > 0:
            var available_in_slot = slot_data.get("amount", 0)
            var to_remove_from_slot = min(available_in_slot, remaining_to_remove)
            
            slot_data["amount"] -= to_remove_from_slot
            remaining_to_remove -= to_remove_from_slot
            
            # If amount reaches 0, clear the slot
            if slot_data["amount"] <= 0:
                inventory_data[slot_name] = {
                    "item_name": "",
                    "amount": 0,
                    "texture_path": ""
                }
    
    if remaining_to_remove > 0:
        return false  # Couldn't remove all items
    
    # Save the updated inventory
    var save_file = FileAccess.open(save_path, FileAccess.WRITE)
    save_file.store_string(JSON.stringify(save_data, "\t"))
    save_file.close()
    
    # Update the UI to reflect the change
    update_inventory_ui()
    
    return true

func update_inventory_ui():
    # Find the inventory UI and refresh it
    var inventory_ui = get_tree().current_scene.get_node_or_null("Ui")
    if inventory_ui and inventory_ui.has_method("load_inventory_from_game_state"):
        inventory_ui.load_inventory_from_game_state()
        print("🔄 Updated inventory UI after trade")
