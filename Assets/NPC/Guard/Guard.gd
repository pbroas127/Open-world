extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel
@onready var collision = $CollisionShape2D  # ⛔ Will be disabled when guard lets you pass

@export var npc_id: String = "bridge_guard"

var stage: int = 0
var dialogue_active := false
var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var original_exclamation_pos := Vector2.ZERO
var required_item: String = ""  # Will hold random legendary item name

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

    if GameState.ship_npc_stage.has(npc_id):
        stage = GameState.ship_npc_stage[npc_id]
    else:
        GameState.ship_npc_stage[npc_id] = stage

    if required_item == "":
        required_item = get_random_legendary_item_name()

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
        stage += 1
        GameState.ship_npc_stage[npc_id] = stage
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
            await show_text("Bring me 1 " + required_item + " and I’ll move.\n\n[Space] to continue")
        4:
            if has_required_item():
                await show_text("Ah! You brought the " + required_item + ". You may pass.\n\n[Space] to continue")
                remove_required_item()
                collision.disabled = true  # ⛔ Unlock the path
            else:
                await show_text("You don’t have the " + required_item + " yet.\nCome back when you do.\n\n[Space] to continue")
                stage = 3  # Retry this stage
        _:
            await show_text("I’m already letting you through.\nMove along!\n\n[Space] to continue")

func has_required_item() -> bool:
    var inventory = GameState.inventory
    for slot_data in inventory.values():
        if typeof(slot_data) == TYPE_DICTIONARY and slot_data.get("item_name", "") == required_item:
            return true
    return false

func remove_required_item():
    var inventory = GameState.inventory
    for slot in inventory.keys():
        var data = inventory[slot]
        if typeof(data) == TYPE_DICTIONARY and data.get("item_name", "") == required_item:
            data["amount"] -= 1
            if data["amount"] <= 0:
                inventory.erase(slot)  # Remove slot if empty
            else:
                inventory[slot] = data  # Save updated amount
            GameState.inventory = inventory
            UI.save_inventory_to_json()
            break


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
