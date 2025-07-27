extends Node

var item_list := {}  # name : ItemData

func register_item(item: ItemData):
    item_list[item.name] = item

func get_item_by_name(name: String) -> ItemData:
    if item_list.has(name):
        return item_list[name]
    return null
