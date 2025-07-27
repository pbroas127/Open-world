extends Node

const Rarity = LootTable.Rarity

var offer: ItemData
var cost_items: Array[ItemData] = []

func generate_offer():
    offer = null
    cost_items.clear()

    var reward_roll = randi_range(0, 99)

    if reward_roll < 60:
        _generate_uncommon_offer()
    elif reward_roll < 90:
        _generate_rare_offer()
    else:
        _generate_legendary_offer()

    _print_offer()

func get_offer_sentence() -> String:
    var sentence = "Hello! I'll give you %s (x%d)\nfor" % [offer.name, offer.amount]  # 👈 notice the \n
    if cost_items.size() > 0:
        for i in range(cost_items.size()):
            var item = cost_items[i]
            sentence += " %d %s" % [item.amount, item.name]
            if i < cost_items.size() - 1:
                sentence += ","
            else:
                sentence += "."
    return sentence


func _generate_uncommon_offer():
    offer = LootTable.get_random_loot_item_by_rarity(Rarity.UNCOMMON)
    offer.amount = randi_range(1, 3)
    var total_needed = offer.amount * randi_range(7, 15)
    _add_cost_item(Rarity.COMMON, total_needed)

func _generate_rare_offer():
    offer = LootTable.get_random_loot_item_by_rarity(Rarity.RARE)
    offer.amount = 1

    match randi_range(0, 2):
        0:
            _add_cost_item(Rarity.COMMON, randi_range(17, 30))
        1:
            _add_cost_item(Rarity.UNCOMMON, randi_range(5, 10))
        2:
            _add_cost_item(Rarity.COMMON, randi_range(7, 15))
            _add_cost_item(Rarity.UNCOMMON, randi_range(1, 5))

func _generate_legendary_offer():
    offer = LootTable.get_random_loot_item_by_rarity(Rarity.LEGENDARY)
    offer.amount = 1

    match randi_range(0, 2):
        0:
            _add_cost_item(Rarity.COMMON, randi_range(30, 40))
            _add_cost_item(Rarity.UNCOMMON, randi_range(12, 18))
            _add_cost_item(Rarity.RARE, randi_range(1, 3))
        1:
            _add_cost_item(Rarity.UNCOMMON, randi_range(20, 30))
            _add_cost_item(Rarity.RARE, randi_range(5, 10))
        2:
            _add_cost_item(Rarity.RARE, randi_range(10, 20))

func _add_cost_item(rarity: int, amount: int):
    var item = LootTable.get_random_loot_item_by_rarity(rarity)
    if item:
        item.amount = amount
        cost_items.append(item)

func _print_offer():
    print("📦 Trade Offer:")
    for item in cost_items:
        print("→ Give: %s (x%d)" % [item.name, item.amount])
    print("🏆 Receive: %s (x%d)" % [offer.name, offer.amount])
