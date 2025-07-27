extends Node

# Rarity categories
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

var loot_table := {
    Rarity.COMMON: [
        preload("res://Assets/Resources/Items/scrap_metal.tres")
    ],
    Rarity.UNCOMMON: [
        preload("res://Assets/Resources/Items/copper_wire.tres"),
        preload("res://Assets/Resources/Items/Orb.tres"),
        preload("res://Assets/Resources/Items/Plate.tres")
    ],
    Rarity.RARE: [
        preload("res://Assets/Resources/Items/scrap_metal.tres")
    ],
    Rarity.LEGENDARY: [
        preload("res://Assets/Resources/Items/copper_wire.tres")
    ]
}

var rarity_weights := {
    Rarity.COMMON: 60,
    Rarity.UNCOMMON: 25,
    Rarity.RARE: 10,
    Rarity.LEGENDARY: 5
}

func get_random_loot_item_by_crate_type(crate_type: int) -> ItemData:
    var temp_weights = rarity_weights.duplicate()

    match crate_type:
        0:  # Normal
            temp_weights = { Rarity.COMMON: 40, Rarity.UNCOMMON: 30, Rarity.RARE: 20, Rarity.LEGENDARY: 10 }
        1:  # Rare
            temp_weights = { Rarity.COMMON: 15, Rarity.UNCOMMON: 30, Rarity.RARE: 40, Rarity.LEGENDARY: 15 }
        2:  # Legendary
            temp_weights = { Rarity.COMMON: 5, Rarity.UNCOMMON: 20, Rarity.RARE: 40, Rarity.LEGENDARY: 35 }

    var total = 0
    var valid = []
    for rarity in temp_weights:
        if loot_table[rarity].size() > 0:
            valid.append(rarity)
            total += temp_weights[rarity]

    if total == 0:
        return null

    var pick = randi() % total
    var sum = 0
    for rarity in valid:
        sum += temp_weights[rarity]
        if pick < sum:
            var pool = loot_table[rarity]
            return pool[randi() % pool.size()].duplicate()

    return null



func get_random_loot_item_by_rarity(rarity: int) -> ItemData:
    var pool = loot_table.get(rarity, [])
    if pool.size() == 0:
        return null
    return pool[randi() % pool.size()].duplicate()

func get_random_loot_item() -> ItemData:
    var valid_rarities = []
    var total_weight = 0

    for rarity in rarity_weights:
        var pool = loot_table[rarity]
        if pool.size() > 0:
            valid_rarities.append(rarity)
            total_weight += rarity_weights[rarity]

    if total_weight == 0:
        push_error("Loot table is completely empty!")
        return null

    var pick = randi() % total_weight
    var current = 0
    for rarity in valid_rarities:
        current += rarity_weights[rarity]
        if pick < current:
            var options = loot_table[rarity]
            var chosen_index = randi() % options.size()
            return options[chosen_index].duplicate()

    return null
