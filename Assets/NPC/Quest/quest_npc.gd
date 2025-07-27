extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var alert_area = $AlertArea
@onready var interact_area = $InteractArea
@onready var prompt_label = $Label
@onready var exclamation = $ExclamationMark
@onready var chat_bubble = $ChatBubble
@onready var chat_label = $ChatBubble/ChatLabel

@export var npc_id: String = ""

@export var quest_lines: Array[String] = [
    "Hunt down 5 scrap wolves\n in the canyon.",
    "Bring me 10 energy cells\n from the ruins.",
    "Find the lost beacon\n near the ridge.",
    "Deliver this message to\n the shipyard NPC.",
    "Recover 3 rare parts from any crate.",
    "Scan the strange signal\n in the eastern cave.",
    "Clear out the raider camp\n east of here.",
    "Bring back proof the temple\n doors are open."
]

var current_quest: String = ""
var quest_state := 0  # 0 = not accepted, 1 = accepted
var player_nearby := false
var player_in_alert_zone := false
var bob_time := 0.0
var dialogue_active := false
var original_exclamation_pos := Vector2.ZERO

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

    if GameState.quests.has(npc_id):
        current_quest = GameState.quests[npc_id]
    else:
        current_quest = quest_lines[randi() % quest_lines.size()]
        GameState.quests[npc_id] = current_quest

    quest_state = GameState.quests_accepted.get(npc_id, 0)

    alert_area.connect("body_entered", _on_alert_entered)
    alert_area.connect("body_exited", _on_alert_exited)
    interact_area.connect("body_entered", _on_interact_entered)
    interact_area.connect("body_exited", _on_interact_exited)

func _process(delta):
    if player_in_alert_zone and not player_nearby:
        bob_time += delta
        exclamation.position = original_exclamation_pos + Vector2(0, sin(bob_time * 4.0) * 4.0)

    if player_nearby and Input.is_action_just_pressed("interact") and not dialogue_active:
        start_quest_dialogue()

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

func start_quest_dialogue():
    dialogue_active = true
    prompt_label.visible = false
    chat_label.text = ""
    chat_label.visible = true
    chat_bubble.visible = true

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_in_for_convo()

    await advance_quest_dialogue()

func advance_quest_dialogue():
    if quest_state == 0:
        await type_text(chat_label, "Quest:\n" + current_quest + "\n\nPress [Space] to Accept")

        while get_tree() and not Input.is_action_just_pressed("ui_accept"):
            await get_tree().process_frame

        if get_tree():
            await accept_quest()
    else:
        await type_text(chat_label, "Have you been able to complete\n the task we talked about?\n\n[Space] Yes, I've completed it.")

        while get_tree() and not Input.is_action_just_pressed("ui_accept"):
            await get_tree().process_frame

        if get_tree():
            await attempt_complete_quest()

func accept_quest():
    quest_state = 1
    GameState.quests_accepted[npc_id] = quest_state
    GameState.active_quests[npc_id] = current_quest
    GameState.quest_log_text[npc_id] = GameState.generate_list_text(current_quest)

    GameState.save_game()

    # ✅ Ensure the Quest UI exists (in case it was removed)
    await GameState.ensure_quest_ui_loaded()



    await type_text(chat_label, "Quest accepted!\nGood luck out there.")
    await get_tree().create_timer(0.5).timeout
    end_dialogue()


func attempt_complete_quest():
    await type_text(chat_label, "Let me see... (quest logic coming soon!)")

    if get_tree():
        await get_tree().create_timer(0.5).timeout
    end_dialogue()

func end_dialogue():
    chat_bubble.visible = false
    dialogue_active = false

    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.zoom_out_after_convo()

func type_text(label: RichTextLabel, full_text: String, speed := 0.04) -> void:
    if not get_tree(): return

    label.bbcode_enabled = true
    label.clear()
    var current_text := ""

    for i in full_text.length():
        current_text += full_text[i]
        label.bbcode_text = current_text

        if i % 3 == 0 or full_text[i] == "\n" or full_text[i] == " ":
            if get_tree(): await get_tree().process_frame

            var label_size = label.get_minimum_size()
            var padding = Vector2(150, 150)
            var new_size = label_size + padding
            chat_bubble.size = new_size
            chat_bubble.pivot_offset = new_size / 2

            if get_tree():
                var bubble_tween = get_tree().create_tween()
                bubble_tween.tween_property(chat_bubble, "size", new_size, 0.1)
                bubble_tween.tween_property(chat_bubble, "pivot_offset", new_size / 2, 0.1)

        if get_tree():
            await get_tree().create_timer(speed).timeout
