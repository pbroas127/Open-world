extends Node

var max_health := 100
var current_health := 100

func set_health(value: int):
    current_health = clamp(value, 0, max_health)  # Ensures health stays between 0 and 100
    save_health()                                 # Saves the new health to JSON


func _ready():
    load_health()
    save_health()  # <-- optional but ensures health is written on first launch

func save_health():
    var save_path = "user://%s.json" % GameState.current_save_name

    var save_data = {}

    # Load existing JSON if it exists
    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        if content != "":
            save_data = JSON.parse_string(content)
        file.close()

    # Write current health
    save_data["player_health"] = current_health

    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

func load_health():
    var save_path = "user://%s.json" % GameState.current_save_name
    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var content = file.get_as_text()
        var data = JSON.parse_string(content)
        file.close()

        if data and "player_health" in data:
            current_health = data["player_health"]
        else:
            current_health = max_health
