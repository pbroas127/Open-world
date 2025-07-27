extends Area2D

@export var item_data: ItemData


func _ready():
    print("Pickup Ready")
    if has_node("Icon"):
        $Icon.texture = preload("res://Assets/Resources/Icons/metal.png")  # Use known texture


func _on_body_entered(body):
    if body.name == "Player":
        print("Player touched pickup!")
        var ui = get_tree().get_first_node_in_group("ui")
        if ui:
            print("Found UI. Adding item:", item_data.name)
            ui.add_item(item_data.duplicate())
        else:
            print("UI not found in scene.")
        queue_free()
