extends CharacterBody2D

@export var move_speed := 150.0
@export var roll_speed := 400.0
@export var roll_duration := 0.3
@export var roll_cooldown := 0.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var is_rolling := false
var roll_timer := 0.0
var roll_cooldown_timer := 0.0
var roll_dir := Vector2.ZERO

var camera_limits = {
    "main": Rect2(-160, -288, 1375, 1250),
    "B2BigInterior": Rect2(-160, -288, 1375, 1250),
    "A2": Rect2(205, -959, 1500, 1500 ),
}

func _ready():
    set_camera_limits()



func _physics_process(delta):
    handle_input()
    handle_roll(delta)
    move_and_slide()

func handle_input():
    if is_rolling:
        return

    direction = Vector2.ZERO

    if Input.is_action_pressed("move_right"):
        direction.x += 1
    if Input.is_action_pressed("move_left"):
        direction.x -= 1
    if Input.is_action_pressed("move_down"):
        direction.y += 1
    if Input.is_action_pressed("move_up"):
        direction.y -= 1

    direction = direction.normalized()
    if direction != Vector2.ZERO:
        last_direction = direction

    velocity = direction * move_speed

    if direction != Vector2.ZERO:
        if direction.y > 0:
            sprite.play("walk_down")
            sprite.flip_h = false
        elif direction.y < 0:
            sprite.play("walk_up")
            sprite.flip_h = false
        elif direction.x > 0:
            sprite.play("walk_right")
            sprite.flip_h = false
        elif direction.x < 0:
            sprite.play("walk_right")
            sprite.flip_h = true
    else:
        sprite.stop()

    if Input.is_action_just_pressed("roll") and roll_cooldown_timer <= 0.0:
        start_roll()

func start_roll():
    is_rolling = true
    roll_timer = roll_duration
    roll_cooldown_timer = roll_cooldown
    roll_dir = last_direction
    velocity = roll_dir * roll_speed

    if roll_dir.y > 0:
        sprite.play("roll_down")
    elif roll_dir.y < 0:
        sprite.play("roll_up")
    elif roll_dir.x > 0:
        sprite.play("roll_right")
        sprite.flip_h = false
    elif roll_dir.x < 0:
        sprite.play("roll_right")
        sprite.flip_h = true

func handle_roll(delta):
    if is_rolling:
        roll_timer -= delta
        if roll_timer <= 0:
            is_rolling = false
            velocity = Vector2.ZERO

    if roll_cooldown_timer > 0:
        roll_cooldown_timer -= delta

# ✅ New Camera Zoom Functions

func zoom_in_for_convo():
    create_tween().tween_property(camera, "zoom", Vector2(2, 2), 0.3)  # Zoom IN

func zoom_out_after_convo():
    create_tween().tween_property(camera, "zoom", Vector2(1, 1), 0.3)  # Zoom OUT (reset)

func set_camera_limits():
    await get_tree().process_frame  # Wait one frame to ensure scene is ready
    var scene = get_tree().current_scene
    if scene == null:
        return
    var current_scene = scene.name

    if camera_limits.has(current_scene):
        var rect = camera_limits[current_scene]
        camera.limit_left = rect.position.x
        camera.limit_top = rect.position.y
        camera.limit_right = rect.position.x + rect.size.x
        camera.limit_bottom = rect.position.y + rect.size.y


func _on_door_to_interior_body_entered(body: Node) -> void:
    if body != self:
        return
    GameState.last_door_position = global_position
    get_tree().change_scene_to_file("res://Big Scenes/B2InteriorBig/B2BigInterior.tscn")

func _on_door_to_outside_body_entered(body: Node) -> void:
    if body != self:
        return
    get_tree().change_scene_to_file("res://Big Scenes/main.tscn")



func _on_b_2_toa_2_body_entered(body: Node2D) -> void:
      if body != self:
        return
      get_tree().change_scene_to_file("res://Big Scenes/A2/A2.tscn")
      



func _on_a_2_tob_2_body_entered(body: Node2D) -> void:
     if body != self:
        return
     GameState.last_entry_point = "a2_to_b2"
     get_tree().change_scene_to_file("res://Big Scenes/main.tscn")

    
