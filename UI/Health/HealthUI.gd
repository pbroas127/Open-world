extends CanvasLayer


@onready var health_bar = $HealthBar
@onready var health_label = $HealthValueLabel

func _ready():
    # Hide the bar until we load the actual health
    health_bar.visible = false
    await get_tree().process_frame  # Wait one frame to avoid flash

    update_health(HealthManager.current_health)
    health_bar.visible = true

var last_displayed_health := -1

func _process(_delta):
    if HealthManager.current_health != last_displayed_health:
        update_health(HealthManager.current_health)
        last_displayed_health = HealthManager.current_health

func update_health(current):
    health_bar.max_value = HealthManager.max_health
    health_bar.value = current
    $HealthValueLabel.text = str(current) + "❤️"
