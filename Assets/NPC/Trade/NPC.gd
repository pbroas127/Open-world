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

    # 🧠 Load or generate trade
    if GameState.trade_offers.has(npc_id):
        current_offer = GameState.trade_offers[npc_id]
        has_active_offer = true
    else:
        current_offer = preload("res://Assets/NPC/Trade/TradeOffer.gd").new()
        current_offer.generate_offer()
        has_active_offer = true
        GameState.trade_offers[npc_id] = current_offer  # 💾 Save it

    # Area connections
    alert_area.connect("body_entered", _on_alert_entered)
    alert_area.connect("body_exited", _on_alert_exited)
    interact_area.connect("body_entered", _on_interact_entered)
    interact_area.connect("body_exited", _on_interact_exited)


func _process(delta):
    if player_in_alert_zone and not player_nearby:
        bob_time += delta
        exclamation.position = original_exclamation_pos + Vector2(0, sin(bob_time * 4.0) * 4.0)

    if player_nearby and Input.is_action_just_pressed("interact"):
        open_trade()

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
        if player_in_alert_zone:
            exclamation.visible = true

        var player = get_tree().get_first_node_in_group("player")
        if player:
            player.zoom_out_after_convo()

func type_text(label: RichTextLabel, full_text: String, speed := 0.05) -> void:
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

func open_trade():
    if not has_active_offer:
        current_offer = preload("res://Assets/NPC/Trade/TradeOffer.gd").new()
        current_offer.generate_offer()
        has_active_offer = true

    chat_label.text = ""
    chat_label.visible = true
    chat_bubble.visible = true
    prompt_label.visible = false

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_in_for_convo()

    var sentence = current_offer.get_offer_sentence()
    await type_text(chat_label, sentence)

    await get_tree().process_frame
    var label_size = chat_label.get_minimum_size()
    var padding = Vector2(150, 150)
    chat_bubble.size = label_size + padding

    # ✅ Simulate slot UI for trade requirement
    var required_items = current_offer.cost_items
    var slot_count = required_items.size()

    print("🛒 Trade requires ", slot_count, " item(s) from the player.")
    match slot_count:
        1:
            print("→ Show SINGLE trade slot UI")
        2:
            print("→ Show DOUBLE trade slot UI")
        3:
            print("→ Show TRIPLE trade slot UI")
        _:
            print("⚠️ Unexpected trade size. Max 3 cost items supported.")
