extends Resource
class_name ItemData

@export var name: String
@export var icon: Texture
@export var stack_size: int = 24  # Max per slot
var amount: int = 1  # How many of this item (for stacking)
