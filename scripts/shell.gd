extends Control
## The bridge is a menu, not another world: all pages work with the same profile.
var music: AudioStreamPlayer
var font: SystemFont
var content: VBoxContainer
var header: Label
var footer: Label
var page := "bridge"
var ui_notice := ""
var mission_index := 1
var selected: Array = [0]
var selected_module := ""
var story_choice := "crew"
var expedition_hard := false
var confirm_action: Callable

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "sans-serif"])
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 10
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("152932")
	normal.border_color = Color("36515a")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 9
	normal.content_margin_right = 9
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	theme_data.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color("80e4c8")
	hover.bg_color = Color("264650")
	theme_data.set_stylebox("hover", "Button", hover)
	theme_data.set_stylebox("pressed", "Button", hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("101a21")
	theme_data.set_stylebox("disabled", "Button", disabled)
	theme = theme_data
	header = fixed_label("", Vector2(20, 13), Vector2(600, 32), 20)
	footer = fixed_label("", Vector2(20, 46), Vector2(600, 20), 9)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 76)
	scroll.size = Vector2(600, 232)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	var nav := HBoxContainer.new()
	nav.position = Vector2(20, 323)
	nav.size = Vector2(600, 30)
	nav.add_theme_constant_override("separation", 5)
	add_child(nav)
	for entry in [["舰桥", "bridge"], ["战役", "missions"], ["远征", "expedition"], ["装备", "equipment"], ["档案", "archive"], ["成就", "achievements"], ["外观", "shop"], ["设置", "settings"]]:
		var target: String = entry[1]
		button(nav, entry[0], show_page.bind(target)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music = AudioStreamPlayer.new()
	music.stream = load("res://audio/bridge.wav")
	music.volume_db = -14
	add_child(music)
	show_page("bridge")

func _process(_delta: float) -> void:
	if music != null:
		if Campaign.shared.get("music", true) and not music.playing: music.play()
		elif not Campaign.shared.get("music", true) and music.playing: music.stop()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("080f18"))
	for i in 48:
		var point := Vector2(posmod(i * 137, 640), posmod(i * 83, 320))
		draw_rect(Rect2(point, Vector2.ONE), Color("2c4d5b"))
	draw_line(Vector2(20, 69), Vector2(620, 69), Color("385d65"))
	draw_line(Vector2(20, 315), Vector2(620, 315), Color("385d65"))
	draw_arc(Vector2(585, 20), 140, 0, TAU, 48, Color("122a33"), 1)

func fixed_label(text: String, point: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func text(value: String, heading := false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13 if heading else 10)
	label.add_theme_color_override("font_color", Color("84dfca") if heading else Color("c3d3dd"))
	content.add_child(label)
	return label

func row() -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	content.add_child(result)
	return result

func button(parent: Node, title: String, action: Callable, disabled := false) -> Button:
	var result := Button.new()
	result.text = title
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size.y = 27
	result.disabled = disabled
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func show_page(next: String) -> void:
	page = next
	if page != "brief": ui_notice = ""
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	header.text = "渡鸦号 / " + {"bridge": "防务舰桥", "missions": "任务星图", "brief": "出战配置", "expedition": "随机远征", "equipment": "装备库", "archive": "通讯档案", "achievements": "成就", "shop": "外观目录", "settings": "设置", "confirm": "确认操作"}.get(page, "指挥终端")
	footer.text = "v0.4.1 · 档案 %d · 战役 %d/6 · 已入库徽记 %d%s" % [Campaign.slot, Campaign.profile.records.size(), Campaign.profile.badges, " · ◆渡鸦" if Campaign.profile.cosmetics.get("badge", "") == "bridge_raven" else ""]
	match page:
		"bridge": bridge_page()
		"missions": mission_page()
		"brief": brief_page()
		"expedition": expedition_page()
		"equipment": equipment_page()
		"archive": archive_page()
		"achievements": achievements_page()
		"shop": shop_page()
		"settings": settings_page()
		"confirm":
			text("放弃当前未完成的行动，开始新的任务？", true)
			text("已有长期成果不变；当前任务的准备进度和未带回的远征徽记将失去。")
			button(content, "确认放弃并出发", confirm_action)
			button(content, "返回配置", show_page.bind("brief"))
	if not Campaign.notice.is_empty(): text(Campaign.notice)
	if not ui_notice.is_empty(): text(ui_notice)

func bridge_page() -> void:
	text("渡鸦号 · 地面链路在线", true)
	text("我们在一颗被标记为‘无人居住’的星球坠落。建立前哨、带回幸存者，查清地下信号的来源。\n轮机长：无人机可以重造，船上等着的人没有第二次机会。")
	var profiles := row()
	for i in range(1, 4): button(profiles, "档案 %d%s" % [i, " · 当前" if i == Campaign.slot else ""], switch_profile.bind(i))
	var actions := row()
	button(actions, "继续任务", continue_game, Campaign.profile.active_request.is_empty() and Campaign.profile.expedition.is_empty())
	button(actions, "剧情战役", show_page.bind("missions"))
	button(actions, "随机远征", show_page.bind("expedition"), not Campaign.profile.records.has("3"))
	text("原型纪录：最高 %d 波（不转换为战役解锁）\n本关合金只用于本关；探索徽记只有撤回或远征完成后才入库。" % int(Campaign.profile.prototype_best))
	if Campaign.profile.records.has("6"):
		text("结局回看", true)
		text(ending())

func switch_profile(index: int) -> void:
	Campaign.load_profile(index)
	show_page("bridge")

func continue_game() -> void:
	if not Campaign.profile.active_request.is_empty():
		if Campaign.continue_battle(): get_tree().change_scene_to_file("res://scenes/main.tscn")
	else: show_page("expedition")

func mission_page() -> void:
	text("六个信号 · 一条撤离航线", true)
	var map = load("res://scripts/star_map.gd").new()
	map.mission_selected.connect(prepare)
	content.add_child(map)
	for i in range(1, 7):
		var data := GameCatalog.mission(i)
		var record: Dictionary = Campaign.profile.records.get(str(i), {})
		var medals := 0
		for value in record.get("medals", []): medals += int(value)
		button(content, "%02d  %s  ·  %d波  ·  %s" % [i, data.title, data.waves.size(), "勋章%d/3" % medals if not record.is_empty() else ("未完成" if Campaign.unlocked(i) else "尚未解锁")], prepare.bind(i), not Campaign.unlocked(i))

func prepare(index: int) -> void:
	mission_index = index
	selected = []
	for value in Campaign.profile.loadout:
		if GameCatalog.unlocked_towers(Campaign.profile).has(int(value)): selected.append(int(value))
	if selected.is_empty(): selected = [0]
	selected_module = Campaign.profile.module
	if not GameCatalog.unlocked_modules(Campaign.profile).has(selected_module): selected_module = ""
	story_choice = "crew"
	show_page("brief")

func brief_page() -> void:
	var data := GameCatalog.mission(maxi(1, mission_index))
	text(data.title if mission_index > 0 else "远征配置", true)
	text(data.briefing if mission_index > 0 else "三场独立战斗，固定携带配置，战后获得临时强化。每站重新建造；未带回徽记失败会丢失。")
	text("固定携带围墙和采矿机；最多选择三种炮塔，至少一种。")
	var options := row()
	for id in GameCatalog.TOWER_IDS:
		button(options, ("✓ " if selected.has(id) else "") + GameCatalog.TOWER_NAMES[id], toggle_tower.bind(id), not GameCatalog.unlocked_towers(Campaign.profile).has(id))
	text("核心模块（仅选一种）")
	for key in GameCatalog.unlocked_modules(Campaign.profile): button(content, ("✓ " if selected_module == key else "") + GameCatalog.MODULES[key], module_pick.bind(key))
	if mission_index == 5:
		text("资料只能保住一类。首次通关后，本档案的选择固定。")
		var choices := row()
		button(choices, ("✓ " if story_choice == "crew" else "") + "优先人员名单", choose_story.bind("crew"))
		button(choices, ("✓ " if story_choice == "evidence" else "") + "优先实验证据", choose_story.bind("evidence"))
	if expedition_hard or page == "brief":
		button(content, "出发", request_launch, selected.is_empty())
	text("第一关奖励：火炮；第二关：减速；第三关：电弧与侦察；第四关：狙击与工业；第五关：应急。")

func toggle_tower(id: int) -> void:
	ui_notice = ""
	if selected.has(id): selected.erase(id)
	elif selected.size() < 3: selected.append(id)
	else: ui_notice = "最多携带三种炮塔，请先取消一项。"
	show_page("brief")

func module_pick(key: String) -> void:
	selected_module = key
	show_page("brief")

func choose_story(key: String) -> void:
	story_choice = key
	show_page("brief")

func request_launch() -> void:
	if not Campaign.profile.active_request.is_empty() or not Campaign.profile.expedition.is_empty():
		confirm_action = launch_new
		show_page("confirm")
	else: launch_new()

func launch_new() -> void:
	Campaign.profile.expedition = {}
	if mission_index == 0:
		if Campaign.start_expedition(selected, selected_module, expedition_hard): show_page("expedition")
	elif Campaign.begin_mission(mission_index, selected, selected_module, story_choice):
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func expedition_page() -> void:
	if not Campaign.profile.records.has("3"):
		text("完成第三关后开放随机远征。", true)
		text("每次三场战斗，临时强化与未带回徽记沿途累积。失败丢失本次未带回收益，不影响永久装备。")
		return
	var run: Dictionary = Campaign.profile.expedition
	if run.is_empty():
		text("三段航程 · 25—35分钟目标", true)
		text("10 / 15 / 25 枚基础徽记；前两站战后可撤回。任务中可保存准备阶段，安全节点会自动保存。")
		button(content, "配置普通远征", prepare_expedition.bind(false))
		button(content, "配置困难远征", prepare_expedition.bind(true), not Campaign.profile.records.has("6"))
		return
	text("%s远征 · 已通过%d/3站 · 未带回 %d 徽记" % ["困难" if run.hard else "普通", run.cleared, run.stash], true)
	if run.status == "battle":
		text("任务尚未结束；继续将从最近准备阶段恢复。")
		button(content, "继续地面任务", continue_game)
		return
	if run.status == "safe":
		button(content, "主动撤回并带走 %d 枚徽记" % run.stash, extract)
		var step := str(int(run.cleared))
		var decision: Dictionary = run.decisions.get(step, {})
		var offer: Dictionary = run.offers[int(run.cleared) - 1]
		text("选择一项临时强化", true)
		for key in offer.boons:
			var card := GameCatalog.card(key)
			button(content, ("✓ " if decision.get("boon", "") == key else "") + card.title + " · " + card.description, choose_boon.bind(key), decision.has("boon") or run.boons.has(key))
		var event := GameCatalog.card(offer.event)
		text(event.title + "：" + event.description, true)
		for i in 2: button(content, event.choices[i], choose_event.bind(i), decision.has("event"))
		text("选择下一站（只影响本次远征）", true)
		for i in 2:
			var route: Dictionary = offer.routes[i]
			button(content, "%s · %s · 胜利基础收益 %d" % [GameCatalog.mission(int(route.map)).title, GameCatalog.MODIFIERS[route.modifier], [10, 15, 25][int(run.cleared)]], choose_route.bind(i), decision.has("route"))
		if decision.size() != 3:
			text("强化、事件与路线各选一次后才能继续；现在可以直接关闭游戏，选择会保留。")
			return
	button(content, "开始下一站", launch_expedition)

func prepare_expedition(hard: bool) -> void:
	prepare(1)
	mission_index = 0
	expedition_hard = hard
	show_page("brief")

func launch_expedition() -> void:
	if Campaign.launch_expedition(): get_tree().change_scene_to_file("res://scenes/main.tscn")

func extract() -> void:
	Campaign.extract()
	show_page("expedition")

func choose_boon(key: String) -> void:
	Campaign.choose_boon(key)
	show_page("expedition")

func choose_event(index: int) -> void:
	Campaign.choose_event(index)
	show_page("expedition")

func choose_route(index: int) -> void:
	Campaign.choose_route(index)
	show_page("expedition")

func equipment_page() -> void:
	text("战术选择，不是永久伤害升级", true)
	for id in GameCatalog.TOWER_IDS: text(GameCatalog.TOWER_NAMES[id] + (" · 已解锁" if GameCatalog.unlocked_towers(Campaign.profile).has(id) else " · 通过战役解锁"))
	for key in GameCatalog.unlocked_modules(Campaign.profile): text(GameCatalog.MODULES[key])
	text("装备在出发前配置，战斗中不能更换携带种类。围墙与采矿机始终可用。")

func archive_page() -> void:
	text("通讯档案 %d/12" % Campaign.profile.logs.size(), true)
	for i in range(1, 7):
		var data := GameCatalog.mission(i)
		for suffix in ["a", "b"]:
			if Campaign.profile.logs.has(str(i) + suffix):
				text(data.log_main if suffix == "a" else data.log_optional)
			else: text("%02d-%s · 未回收" % [i, suffix.to_upper()])
	if Campaign.profile.records.has("6"): text(ending())

func achievements_page() -> void:
	text("本地成就 %d/12" % Campaign.profile.achievements.size(), true)
	for key in GameCatalog.ACHIEVEMENTS:
		var definition := GameCatalog.achievement(key)
		var label: String = definition.title + "｜" + definition.description
		if key == "rail": label += " %d/10" % mini(10, int(Campaign.profile.counters.rail))
		if key == "boons": label += " %d/3" % mini(3, Campaign.profile.counters.boons.size())
		text(("◆ " if Campaign.profile.achievements.has(key) else "◇ ") + label)
	text("成就不会赋予战力，已解锁成果不会因失败丢失。")

func shop_page() -> void:
	text("已入库 %d 徽记 · 外观不改变战斗数值" % Campaign.profile.badges, true)
	for key in GameCatalog.SHOP:
		var item: Dictionary = GameCatalog.SHOP[key]
		var owned: bool = Campaign.profile.owned.has(key)
		button(content, "%s · %s" % [item.title, "已拥有 / 点击装备" if owned else "%d 徽记" % item.price], cosmetic.bind(key), not owned and Campaign.profile.badges < item.price)
	if Campaign.profile.owned.has("ending_core"): button(content, "黎明纪念核心 · 装备", equip_skin.bind("core", "ending_core"))
	button(content, "恢复默认外观", reset_skins)

func cosmetic(key: String) -> void:
	if Campaign.profile.owned.has(key): equip_skin(GameCatalog.SHOP[key].slot, key)
	else: Campaign.buy(key); show_page("shop")

func equip_skin(slot_name: String, key: String) -> void:
	Campaign.profile.cosmetics[slot_name] = key
	Campaign.save()
	show_page("shop")

func reset_skins() -> void:
	Campaign.profile.cosmetics = {}
	Campaign.save()
	show_page("shop")

func settings_page() -> void:
	text("共享设置 · 不随档案切换", true)
	for key in ["sound", "music", "shake", "fullscreen"]:
		button(content, "%s：%s" % [{"sound": "射击音效", "music": "背景音乐", "shake": "屏幕震动", "fullscreen": "全屏"}[key], "开" if Campaign.shared[key] else "关"], toggle_setting.bind(key))
	text("主音量 %d%%" % roundi(float(Campaign.shared.volume) * 100))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = Campaign.shared.volume
	slider.custom_minimum_size.y = 24
	slider.value_changed.connect(func(value: float): Campaign.shared.volume = value; Campaign.save_settings())
	content.add_child(slider)
	text("快捷键：1—7选择携带建筑；左键建造/选中；右键/Esc取消；空格暂停；Enter提前迎战。\n准备阶段点‘舰桥’保存退出；战斗中返回会回到本波准备。旧版十波纪录只保留为历史。")

func toggle_setting(key: String) -> void:
	Campaign.shared[key] = not Campaign.shared[key]
	Campaign.save_settings()
	show_page("settings")

func ending() -> String:
	return "渡鸦号已离开。信标与地面网络一同沉默。\n" + ("最后一组幸存者也在船上。" if Campaign.profile.choices.get("2", {}).get("optional", false) else "最后一组呼叫没有得到回答。") + "\n" + ("人员名单被保存，失踪者终于有了名字。" if Campaign.profile.choices.get("5", {}).get("choice", "crew") == "crew" else "实验资料被公开，公司无法再否认这一切。")

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
