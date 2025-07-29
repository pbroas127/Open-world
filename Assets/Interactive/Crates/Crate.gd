extends Area2D

@export var crate_id: String = ""

enum CrateType { NORMAL, RARE, LEGENDARY }
var crate_type: int


var items: Array[ItemData] = []
var player_nearby := false
var is_animating := false
var crate_opened := false

func _ready():
    GameState.save_game()

    if crate_id.strip_edges() == "":
        crate_id = name  # fallback

    connect("body_entered", _on_body_entered)
    connect("body_exited", _on_body_exited)

    if GameState.crate_types.has(crate_id):
        crate_type = GameState.crate_types[crate_id]
    else:
        assign_crate_type()
        GameState.crate_types[crate_id] = crate_type  # 💾 Save the assigned crate type

    print("📦 Crate", crate_id, "spawned as:", get_crate_type_name(crate_type))

    set_idle_animation()
    $Label.visible = false

    # 🧠 Preload saved items into this crate if availabl
    
    

func get_crate_type_name(t: int) -> String:
    match t:
        CrateType.NORMAL: return "Normal"
        CrateType.RARE: return "Rare"
        CrateType.LEGENDARY: return "Legendary"
        _: return "Unknown"


func assign_crate_type():
    var roll = randi() % 100
    if roll < 5:
        crate_type = CrateType.LEGENDARY
    elif roll < 25:
        crate_type = CrateType.RARE
    else:
        crate_type = CrateType.NORMAL

func set_idle_animation():
    match crate_type:
        CrateType.NORMAL:
            $Sprite.play("closed")
        CrateType.RARE:
            $Sprite.play("rareclosed")
        CrateType.LEGENDARY:
            $Sprite.play("legendaryclosed")


func _on_body_entered(body):
    GameState.save_game()

    if body.name == "Player":
        player_nearby = true
        $Label.visible = true

func _on_body_exited(body):
    GameState.save_game()

    if body.name == "Player":
        player_nearby = false
        $Label.visible = false

        var crate_ui = get_tree().get_first_node_in_group("crate_ui")
        if crate_ui:
            crate_ui.visible = false

        # 🔄 Restore correct "closed" animation based on crate type
        match crate_type:
            CrateType.NORMAL:
                $Sprite.play("closed")
            CrateType.RARE:
                $Sprite.play("rareclosed")
            CrateType.LEGENDARY:
                $Sprite.play("legendaryclosed")

func _process(_delta):
    if player_nearby and not is_animating and Input.is_action_just_pressed("interact"):
        open_crate()

func open_crate():
    GameState.save_game()
    print("🔍 Opening crate:", crate_id)
    print("🎲 Crate Type:", get_crate_type_name(crate_type))

    is_animating = true
    $Label.visible = false

    # 🎞️ Play animation based on crate type
    match crate_type:
        CrateType.NORMAL:
            $Sprite.play("open")
        CrateType.RARE:
            $Sprite.play("rareopen")
        CrateType.LEGENDARY:
            $Sprite.play("legendaryopen")

    await $Sprite.animation_finished

    items.clear()

    var crate_data_exists = GameState.chests.has(crate_id)
    if crate_data_exists:
        var saved_crate_dict = GameState.chests.get(crate_id, {})
        for key in saved_crate_dict:
            var slot_info = saved_crate_dict[key]
            var item_name = slot_info.get("item_name", "")
            var amount = int(slot_info.get("amount", 1))
            var item = GameDatabase.get_item_by_name(item_name)
            if item:
                var item_copy = item.duplicate()
                item_copy.amount = amount
                items.append(item_copy)
        print("📦 Loaded saved crate contents:", crate_id)
    else:
        # Generate random loot
        var item_count = randi_range(4, 6)
        for i in range(item_count):
            var item = LootTable.get_random_loot_item_by_crate_type(crate_type)
            if item == null:
                continue
            var stacked = false
            for existing in items:
                if existing.name == item.name:
                    existing.amount += randi_range(1, 3)
                    stacked = true
                    break
            if not stacked:
                item.amount = randi_range(1, 3)
                items.append(item)

        # Save to GameState in crate format
        var crate_save_data = {}
        for i in range(min(items.size(), 6)):
            var item = items[i]
            crate_save_data["CSlot%d" % (i + 1)] = {
                "item_name": item.name,
                "amount": item.amount
            }
        GameState.chests[crate_id] = crate_save_data
        print("✨ Generated and saved new loot for:", crate_id)

    # Open crate UI with actual item data
    var crate_ui = get_tree().get_first_node_in_group("crate_ui")
    if crate_ui:
        crate_ui.open_with_items(items, crate_id)

    is_animating = false
