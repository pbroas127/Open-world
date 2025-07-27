extends Area2D

@export var crate_id: String = ""

enum CrateType { NORMAL, RARE, LEGENDARY }
var crate_type: int


var items: Array[ItemData] = []
var player_nearby := false
var is_animating := false
var crate_opened := false

func _ready():
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
    if body.name == "Player":
        player_nearby = true
        $Label.visible = true

func _on_body_exited(body):
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

    if not crate_opened:
        if GameState.chests.has(crate_id):
            var raw_items = GameState.chests[crate_id]
            items.clear()
            for i in raw_items:
                if i is ItemData:
                    items.append(i)
        else:
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
            GameState.chests[crate_id] = items
        crate_opened = true

    var crate_ui = get_tree().get_first_node_in_group("crate_ui")
    if crate_ui:
        crate_ui.open_with_items(items, crate_id)

    is_animating = false
