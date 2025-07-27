extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var interact_area = $InteractArea
@onready var prompt_label = $PromptLabel  # ✅ Add this

var player_nearby := false

func _ready():
    anim.play("burning")
    prompt_label.visible = false

    interact_area.connect("body_entered", _on_body_entered)
    interact_area.connect("body_exited", _on_body_exited)

    var test = get_parent().get_node("CampfireMenu")
    print("🧪 CampfireMenu found? ", test != null)


func _on_body_entered(body):
    if body.name == "Player":
        player_nearby = true
        prompt_label.visible = true

func _on_body_exited(body):
    if body.name == "Player":
        player_nearby = false
        prompt_label.visible = false

        var menu = get_tree().get_first_node_in_group("campfire_menu")
        if menu:
            menu.hide()


func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        print("✅ E pressed while near campfire")
        open_campfire_menu()


func open_campfire_menu():
    print("🔥 Opening campfire menu")
    var menu = get_tree().get_first_node_in_group("campfire_menu")
    print("🧪 CampfireMenu found?", menu != null)

    if menu:
        menu.visible = true
        menu.show()  # Ensure it's not collapsed or hidden
