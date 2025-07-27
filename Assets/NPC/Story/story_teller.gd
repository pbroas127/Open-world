extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel

@export var npc_id: String = ""
@export var story_lines: Array[String] = [
    "Long ago, before the scrap dunes...",
    "Legends speak of a temple buried in sand.",
    "Some say the orbs control time itself.",
    "I’ve seen machines move on their own...",
    "Not everything on this planet is dead.",
    "Stay off the ridge at night. Trust me.",
    "A storm’s coming — not just of sand.",
    "They found a vault. They never came back.",
    "Everything changed when the signal hit.",
    "You’re not the first to ask these questions..."
]

var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var original_exclamation_pos := Vector2.ZERO

var current_story = []

var current_index := 0
var dialogue_active := false

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

    alert_area.connect("body_entered", _on_alert_entered)
    alert_area.connect("body_exited", _on_alert_exited)
    interact_area.connect("body_entered", _on_interact_entered)
    interact_area.connect("body_exited", _on_interact_exited)


func _process(delta):
    if player_in_alert_zone and not player_nearby:
        bob_time += delta
        exclamation.position = original_exclamation_pos + Vector2(0, sin(bob_time * 4.0) * 4.0)

    if player_nearby and Input.is_action_just_pressed("interact") and not dialogue_active:
        start_story()
    elif dialogue_active and Input.is_action_just_pressed("ui_accept"):
        advance_story()


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


func start_story():
    dialogue_active = true
    current_index = 0
    #
    if GameState.stories.has(npc_id):
        current_story = [GameState.stories[npc_id]]
    else:
        var picked = get_random_story()
        current_story = [picked]
        GameState.stories[npc_id] = picked  # 💾 Save story for this NPC

    chat_label.text = ""
    chat_label.visible = true
    chat_bubble.visible = true
    prompt_label.visible = false

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_in_for_convo()

    advance_story()


func advance_story():
    if current_index >= current_story.size():
        chat_bubble.visible = false
        dialogue_active = false
        var player = get_tree().get_first_node_in_group("player")
        if player:
            player.zoom_out_after_convo()
        return

    var line = current_story[current_index]
    current_index += 1
    await type_text(chat_label, line)

func get_random_story() -> String:
    var picked = story_lines[randi() % story_lines.size()]
    return picked.replace(". ", ".\n")  # Split sentences for wrapping


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
