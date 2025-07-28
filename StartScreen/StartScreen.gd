extends Control

@onready var new_game_btn = $VBoxContainer/NewGame
@onready var load_game_btn = $VBoxContainer/LoadGame
@onready var settings_btn = $VBoxContainer/Settings
@onready var quit_btn = $VBoxContainer/Quit
@onready var save_name_input = $SaveNameInput
@onready var submit_button = $SubmitButton
@onready var load_list = $LoadListContainer

func _ready():
    new_game_btn.pressed.connect(_on_new_game_pressed)
    load_game_btn.pressed.connect(_on_load_game_pressed)
    settings_btn.pressed.connect(_on_settings_pressed)
    quit_btn.pressed.connect(_on_quit_pressed)
    submit_button.pressed.connect(_on_submit_pressed)
    

    # Hide name input & submit button initially
    save_name_input.visible = false
    submit_button.visible = false
    load_list.visible = false  # Hide save list at first




func _on_new_game_pressed():
    print("🆕 New Game pressed")

    # Hide all main menu buttons
    new_game_btn.visible = false
    load_game_btn.visible = false
    settings_btn.visible = false
    quit_btn.visible = false

    # Show input and submit button
    save_name_input.visible = true
    submit_button.visible = true
    
func _on_load_game_pressed():
    print("📂 Load Game pressed")

    # Hide all main buttons
    new_game_btn.visible = false
    load_game_btn.visible = false
    settings_btn.visible = false
    quit_btn.visible = false

    # Show save file list
    load_list.visible = true
    _populate_save_list()


func _populate_save_list():
    # Clear any existing buttons
    for child in load_list.get_children():
        child.queue_free()

    var dir = DirAccess.open("user://")
    if dir:
        var files = dir.get_files()
        for file in files:
            if file.ends_with(".json"):
                var name = file.get_basename()
                var btn = Button.new()
                btn.text = name
                btn.pressed.connect(func(): _load_selected_save(name))
                load_list.add_child(btn)


func _load_selected_save(file_name: String):
    GameState.current_save_name = file_name
    GameState.load_game()
    get_tree().change_scene_to_file("res://Big Scenes/Main.tscn")


func _on_submit_pressed():
    var file_name = save_name_input.text.strip_edges()
    if file_name == "":
        return

    var save_path = "user://%s.json" % file_name
    GameState.current_save_name = file_name

    # Create blank file
    var save_data = {}
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

    GameState.initialize_new_game_data()  # set default data
    GameState.load_game()  # ✅ Now safe to load!
    get_tree().change_scene_to_file("res://Big Scenes/Main.tscn")



func _on_settings_pressed():
    print("⚙️ Settings pressed")

func _on_quit_pressed():
    get_tree().quit()
