class_name Inventory
extends RefCounted
## Fixed-size bag. Each slot is null or {"item": ItemResource, "count": int}.

signal changed

var size: int
var slots: Array = []


func _init(p_size: int = 24) -> void:
	size = p_size
	slots.resize(size)


## Adds items, stacking first. Returns how many did not fit.
func add(item: ItemResource, count: int = 1, emit: bool = true) -> int:
	if item == null or count <= 0:
		return count
	var left := count
	for i in size:
		if left == 0:
			break
		var s = slots[i]
		if s != null and s["item"] == item and int(s["count"]) < item.max_stack:
			var n := mini(left, item.max_stack - int(s["count"]))
			s["count"] = int(s["count"]) + n
			left -= n
	for i in size:
		if left == 0:
			break
		if slots[i] == null:
			var n := mini(left, item.max_stack)
			slots[i] = {"item": item, "count": n}
			left -= n
	if emit and left != count:
		changed.emit()
	return left


## Removes up to `count` from slot `index`. Returns how many were removed.
func remove_at(index: int, count: int = 1) -> int:
	if index < 0 or index >= size or slots[index] == null:
		return 0
	var have: int = slots[index]["count"]
	var n := mini(count, have)
	if n >= have:
		slots[index] = null
	else:
		slots[index]["count"] = have - n
	if n > 0:
		changed.emit()
	return n


func item_at(index: int) -> ItemResource:
	if index < 0 or index >= size or slots[index] == null:
		return null
	return slots[index]["item"] as ItemResource


func count_at(index: int) -> int:
	if index < 0 or index >= size or slots[index] == null:
		return 0
	return int(slots[index]["count"])


func count_of(item: ItemResource) -> int:
	var total := 0
	for s in slots:
		if s != null and s["item"] == item:
			total += int(s["count"])
	return total


func total_items() -> int:
	var total := 0
	for s in slots:
		if s != null:
			total += int(s["count"])
	return total


func used_slots() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func is_full() -> bool:
	return used_slots() >= size


## Slot of the healing item that best covers `missing_hp`: the smallest heal
## that covers it, else the biggest heal. -1 if none.
func find_best_potion(missing_hp: int) -> int:
	var best := -1
	var best_heal := 0
	for i in size:
		var item := item_at(i)
		if item == null or item.kind != ItemResource.Kind.CONSUMABLE or item.heal <= 0:
			continue
		if best == -1:
			best = i
			best_heal = item.heal
			continue
		var covers := item.heal >= missing_hp
		var best_covers := best_heal >= missing_hp
		if (covers and (not best_covers or item.heal < best_heal)) or (not covers and not best_covers and item.heal > best_heal):
			best = i
			best_heal = item.heal
	return best


## Merges stacks and orders by kind, then rarity (best first), then name.
func sort() -> void:
	var entries: Array = []
	for s in slots:
		if s != null:
			entries.append(s)
	entries.sort_custom(_compare_entries)
	slots.fill(null)
	for e in entries:
		add(e["item"] as ItemResource, int(e["count"]), false)
	changed.emit()


func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var ia: ItemResource = a["item"]
	var ib: ItemResource = b["item"]
	if ia.kind != ib.kind:
		return ia.kind < ib.kind
	if ia.rarity != ib.rarity:
		return ia.rarity > ib.rarity
	return ia.display_name < ib.display_name


func clear() -> void:
	slots.fill(null)
	changed.emit()


func to_array() -> Array:
	var out: Array = []
	for i in size:
		var s = slots[i]
		if s != null:
			out.append({"slot": i, "id": (s["item"] as ItemResource).id, "count": int(s["count"])})
	return out


func from_array(data: Array) -> void:
	slots.fill(null)
	for e in data:
		if not (e is Dictionary):
			continue
		var item := GameDB.item(str(e.get("id", "")))
		var count := int(e.get("count", 0))
		if item == null or count <= 0:
			continue
		var index := int(e.get("slot", -1))
		if index >= 0 and index < size and slots[index] == null:
			slots[index] = {"item": item, "count": mini(count, item.max_stack)}
			count -= mini(count, item.max_stack)
		if count > 0:
			add(item, count, false)
	changed.emit()
