# FIXED Crate.gd - Types are saved permanently
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
        crate_id = name
    if crate_id.strip_edges() == "":
        push_error("🚫 Crate has no valid crate_id! This will break saving.")

    connect("body_entered", _on_body_entered)
    connect("body_exited", _on_body_exited)

    # ✅ Load crate type from saved data or assign new one
    load_or_assign_crate_type()
    set_idle_animation()
    $Label.visible = false

func get_crate_type_name(t: int) -> String:
    match t:
        CrateType.NORMAL: return "Normal"
        CrateType.RARE: return "Rare"
        CrateType.LEGENDARY: return "Legendary"
        _: return "Unknown"

func get_crate_type_from_name(type_name: String) -> int:
    match type_name:
        "Normal": return CrateType.NORMAL
        "Rare": return CrateType.RARE
        "Legendary": return CrateType.LEGENDARY
        _: return CrateType.NORMAL

# ✅ NEW: Load existing type or assign new one permanently
func load_or_assign_crate_type():
    # Check if this crate type is already saved
    if GameState.crate_types.has(crate_id):
        var saved_type_name = GameState.crate_types[crate_id]
        crate_type = get_crate_type_from_name(saved_type_name)
        print("🔄 Loaded existing crate type for ", crate_id, ": ", saved_type_name)
    else:
        # Assign new type and save it permanently
        assign_new_crate_type()
        var type_name = get_crate_type_name(crate_type)
        GameState.crate_types[crate_id] = type_name
        GameState.save_crate_types()
        print("✨ Assigned new crate type for ", crate_id, ": ", type_name)

func assign_new_crate_type():
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

        set_idle_animation()

func _process(_delta):
    if player_nearby:
        if Input.is_action_just_pressed("interact"):
            print("🟢 Interact pressed near crate:", crate_id)
            if is_animating:
                print("⛔ Crate is still animating, skipping open.")
            else:
                open_crate()

func open_crate():
    if is_animating:
        print("⛔ Crate is still animating, skipping open.")
        return

    is_animating = true
    print("🔍 Opening crate:", crate_id)
    print("🎲 Crate Type:", get_crate_type_name(crate_type))
    $Label.visible = false

    match crate_type:
        CrateType.NORMAL:
            $Sprite.play("open")
        CrateType.RARE:
            $Sprite.play("rareopen")
        CrateType.LEGENDARY:
            $Sprite.play("legendaryopen")

    if $Sprite.is_playing():
        await $Sprite.animation_finished

    if not crate_opened:
        items.clear()
        var crate_data_exists = GameState.chests.has(crate_id)
        if crate_data_exists:
            var saved_crate_dict = GameState.chests.get(crate_id, {})
            for key in saved_crate_dict:
                if key.begins_with("CSlot"):
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

            # ✅ Save crate contents (type is already saved separately)
            var crate_save_data = {}
            for i in range(min(items.size(), 6)):
                var item = items[i]
                crate_save_data["CSlot%d" % (i + 1)] = {
                    "item_name": item.name,
                    "amount": item.amount
                }
            GameState.chests[crate_id] = crate_save_data
            print("✨ Generated and saved new loot for:", crate_id)

        crate_opened = true

    var crate_ui = get_tree().get_first_node_in_group("crate_ui")
    if crate_ui:
        crate_ui.open_with_items(items, crate_id, get_crate_type_name(crate_type))

    is_animating = false
    crate_opened = true
