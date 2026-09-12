extends CanvasLayer

## SkyMerchant.gd - In-flight supply zeppelin with independent co-op stalls and escalating reroll terminal.

signal undocked()

@onready var panel: Control = $Panel
@onready var p1_stall: VBoxContainer = $Panel/VBox/HBoxStalls/P1Stall
@onready var p2_stall: VBoxContainer = $Panel/VBox/HBoxStalls/P2Stall
@onready var p1_wallet_lbl: Label = $Panel/VBox/HBoxStalls/P1Stall/P1Wallet
@onready var p2_wallet_lbl: Label = $Panel/VBox/HBoxStalls/P2Stall/P2Wallet
@onready var p1_reroll_btn: Button = $Panel/VBox/HBoxStalls/P1Stall/P1RerollBtn
@onready var p2_reroll_btn: Button = $Panel/VBox/HBoxStalls/P2Stall/P2RerollBtn
@onready var p1_repair_btn: Button = $Panel/VBox/HBoxStalls/P1Stall/P1RepairBtn
@onready var p2_repair_btn: Button = $Panel/VBox/HBoxStalls/P2Stall/P2RepairBtn
@onready var p1_items_grid: GridContainer = $Panel/VBox/HBoxStalls/P1Stall/P1ItemsGrid
@onready var p2_items_grid: GridContainer = $Panel/VBox/HBoxStalls/P2Stall/P2ItemsGrid
@onready var undock_btn: Button = $Panel/VBox/UndockBtn

var p1_shop_items: Array[ItemModifier] = []
var p2_shop_items: Array[ItemModifier] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	undock_btn.pressed.connect(_on_undock_pressed)
	p1_reroll_btn.pressed.connect(func(): _reroll_stall(1))
	p2_reroll_btn.pressed.connect(func(): _reroll_stall(2))
	p1_repair_btn.pressed.connect(func(): _buy_repair(1))
	p2_repair_btn.pressed.connect(func(): _buy_repair(2))
	GameManager.joules_changed.connect(_update_wallets)

func open_shop() -> void:
	panel.visible = true
	get_tree().paused = true
	
	# Show/hide P2 stall depending on Co-Op mode
	p2_stall.visible = GameManager.is_coop_mode
	
	_generate_stall_items(1)
	if GameManager.is_coop_mode:
		_generate_stall_items(2)
	
	_update_wallets(GameManager.p1_joules, GameManager.p2_joules)
	SoundEffects.play_sfx("bonus", 0.05, 3.0)

func _generate_stall_items(player_id: int) -> void:
	var items = ItemDatabase.get_random_choice([], 3)
	if player_id == 1:
		p1_shop_items = items
		_populate_items_grid(p1_items_grid, p1_shop_items, 1)
	else:
		p2_shop_items = items
		_populate_items_grid(p2_items_grid, p2_shop_items, 2)

func _populate_items_grid(grid: GridContainer, items: Array[ItemModifier], player_id: int) -> void:
	for c in grid.get_children():
		c.queue_free()
	
	for it in items:
		var card = PanelContainer.new()
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)
		
		var title = Label.new()
		title.text = it.display_name
		title.add_theme_color_override("font_color", it.icon_color)
		title.add_theme_font_size_override("font_size", 12)
		card_vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = it.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 10)
		desc.custom_minimum_size = Vector2(160, 48)
		card_vbox.add_child(desc)
		
		var discount = _get_player_discount(player_id)
		var cost = int(25 * discount)
		var buy_btn = Button.new()
		buy_btn.text = "BUY - %d J" % cost
		buy_btn.focus_mode = Control.FOCUS_NONE
		buy_btn.pressed.connect(func(): _buy_item(it, card, player_id, cost))
		card_vbox.add_child(buy_btn)
		
		grid.add_child(card)

func _get_player_discount(player_id: int) -> float:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.player_id == player_id:
			if p.get("has_carnot_efficiency") == true:
				return 0.5
	return 1.0

func _buy_item(item: ItemModifier, card_node: Node, player_id: int, cost: int = 25) -> void:
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("bonus", 0.08, 4.0)
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.player_id == player_id:
				p.add_modifier(item)
		card_node.queue_free()

func _buy_repair(player_id: int) -> void:
	var cost = int(15 * _get_player_discount(player_id))
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("bonus", 0.05, 1.0)
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.player_id == player_id:
				p.hull = mini(p.max_hull, p.hull + 2)
				p._emit_health()

func _reroll_stall(player_id: int) -> void:
	var base_cost = GameManager.p1_reroll_cost if player_id == 1 else GameManager.p2_reroll_cost
	var cost = int(base_cost * _get_player_discount(player_id))
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("roll", 0.08, 2.0)
		_generate_stall_items(player_id)
		
		# Escalate reroll cost: 5 -> 10 -> 20 -> 35
		if player_id == 1:
			GameManager.p1_reroll_cost = _next_cost(GameManager.p1_reroll_cost)
		else:
			GameManager.p2_reroll_cost = _next_cost(GameManager.p2_reroll_cost)
		_update_wallets(GameManager.p1_joules, GameManager.p2_joules)

func _next_cost(current: int) -> int:
	match current:
		5: return 10
		10: return 20
		20: return 35
		_: return current + 15

func _update_wallets(p1_j: int, p2_j: int) -> void:
	p1_wallet_lbl.text = "P1 WALLET: %d J" % p1_j
	p1_reroll_btn.text = "REROLL WARES - %d J" % GameManager.p1_reroll_cost
	p1_repair_btn.text = "NANO REPAIR (+2 HULL) - 15 J"
	
	if GameManager.is_coop_mode:
		p2_wallet_lbl.text = "P2 WALLET: %d J" % p2_j
		p2_reroll_btn.text = "REROLL WARES - %d J" % GameManager.p2_reroll_cost
		p2_repair_btn.text = "NANO REPAIR (+2 HULL) - 15 J"

func _on_undock_pressed() -> void:
	panel.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	
	undocked.emit()
	GameManager.current_phase = GameManager.RunPhase.COMBAT_WAVES
