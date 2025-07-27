extends CanvasLayer

@onready var sleep_btn = $Panel/VBoxContainer/Sleep
@onready var heal_btn = $Panel/VBoxContainer/Heal
@onready var burn_btn = $Panel/VBoxContainer/BurnItems
@onready var xp_btn = $Panel/VBoxContainer/SpendXP
@onready var leave_btn = $Panel/VBoxContainer/LeaveCampfire

func _ready():
    self.visible = false  # ❗ Start hidden

    if sleep_btn:
        sleep_btn.pressed.connect(_on_sleep_pressed)
    if heal_btn:
        heal_btn.pressed.connect(_on_heal_pressed)
    if burn_btn:
        burn_btn.pressed.connect(_on_burn_pressed)
    if xp_btn:
        xp_btn.pressed.connect(_on_xp_pressed)
    if leave_btn:
        leave_btn.pressed.connect(_on_leave_pressed)



func show_menu():
    self.visible = true

func hide_menu():
    self.visible = false

# Button callbacks (still placeholders)
func _on_sleep_pressed():
    print("💤 Sleep not implemented yet!")

func _on_heal_pressed():
    print("❤️ Heal pressed")
    HealthManager.set_health(100)  # This updates the internal value + JSON

    if HealthUI.has_method("update_health"):
        HealthUI.update_health(100)  # 💥 Instant bar update


func _on_burn_pressed():
    print("🔥 Burn items pressed")

func _on_xp_pressed():
    print("✨ Spend XP pressed")

func _on_leave_pressed():
    hide_menu()
