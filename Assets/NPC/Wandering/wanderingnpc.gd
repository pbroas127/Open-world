extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var move_timer = $MoveTimer
@onready var pause_timer = $PauseTimer

var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
var move_dir = Vector2.ZERO
var speed = 40
var last_move_dir := Vector2.DOWN  # Default facing direction


func _ready():
    move_timer.one_shot = true
    pause_timer.one_shot = true

    pause_timer.connect("timeout", _on_pause_timer_timeout)
    move_timer.connect("timeout", _on_move_timer_timeout)

    _start_pausing()

func _physics_process(delta):
    if move_timer.time_left > 0:
        if move_dir != Vector2.ZERO:
            last_move_dir = move_dir
        velocity = move_dir * speed
        var old_position = position
        move_and_slide()
        
        # Check for collision by seeing if position changed
        if position == old_position:
            _reverse_direction()
            move_timer.start(2.0)  # Restart timer with new direction
    else:
        velocity = Vector2.ZERO
        move_dir = Vector2.ZERO

    _update_animation()
    




func _reverse_direction():
    move_dir = -move_dir
    last_move_dir = move_dir



func _on_pause_timer_timeout():
    move_dir = directions.pick_random()
    _update_animation()

    move_timer.start(2.0)  # Walk for 2 seconds

func _on_move_timer_timeout():
    _start_pausing()

func _start_pausing():
    move_dir = Vector2.ZERO
    _update_animation()
    pause_timer.start(randf_range(1.0, 2.0))  # Random pause time

func _update_animation():
    if move_dir == Vector2.ZERO:
        # Standing
        if last_move_dir.y > 0:
            sprite.play("stand_down")
        elif last_move_dir.y < 0:
            sprite.play("stand_up")
        elif last_move_dir.x > 0:
            sprite.play("stand_right")
        elif last_move_dir.x < 0:
            sprite.play("stand_right")
            sprite.flip_h = true
    else:
        # Moving
        if move_dir.y > 0:
            sprite.play("walk_down")
        elif move_dir.y < 0:
            sprite.play("walk_up")
        elif move_dir.x > 0:
            sprite.play("walk_right")
            sprite.flip_h = false
        elif move_dir.x < 0:
            sprite.play("walk_right")
            sprite.flip_h = true
