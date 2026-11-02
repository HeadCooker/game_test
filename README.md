# 异星撤离 / Alien Evacuation

Windows 单机塔防学习项目。固定使用 **Godot 4.7.2 stable / GDScript / Compatibility**。

## 立即试玩

双击根目录的 **开始游戏.cmd**。也可以直接运行 `build/AlienEvacuation.exe`。
分享给朋友时发送 `build/AlienEvacuation-Windows-x64.zip`，让对方先完整解压再运行；不能只发送 exe，旁边的 pck 是游戏资源包。

双击 **打开编辑器.cmd** 进入 Godot，按 **F5** 运行完整游戏，按 **F8** 停止。
便携引擎位于 `.tools/godot/`，不需要管理员权限，也不需要编译引擎。

## 玩法

保护地图中央的蓝色核心，抵挡 10 波虫群，再等待 30 秒撤离。

| 操作 | 功能 |
|---|---|
| 1—5 或右侧按钮 | 选择机枪、火炮、减速、围墙、采矿机 |
| 左键空地 | 建造；绿色可建，红色不可建 |
| 左键建筑 | 查看生命、升级、维修、出售 |
| 右键 / Esc | 取消建造或关闭帮助 |
| 空格 | 暂停或继续；暂停时可以建造 |
| Enter | 提前开始下一波 |
| 右上角帮助 | 查看操作、切换音效与震动 |

初始 180 合金。基础补给每 5 秒 +2，每台采矿机额外 +4；击杀与过波也有奖励。
炮塔可升级两次，升级会恢复生命。出售按已投入费用、当前生命比例返还 65%，残血建筑返还较少。
红色边缘是入口禁建区；敌人所在格和当前移动目标格也禁止建造。
封路不会让游戏停住，虫群会攻击挡路建筑。火炮有范围伤害，减速效果持续 2 秒。

## 已实现的原型范围

- 单张固定网格地图、共享寻路、自由建造与封路拆墙。
- 三种炮塔、围墙、采矿机、升级、维修和出售。
- 十波可配置敌人，普通虫、疾行虫、重甲虫和最终巢母。
- 准备、进攻、撤离、胜负、暂停、帮助、重开与结算。
- 原创程序像素图形、简单合成射击声、爆炸与震动开关。
- 设置和最高过波纪录保存到 Godot 的 `user://settings.cfg`。

这是玩法原型，并非 Steam 发行成品。当前地图完整显示，不需要镜头移动；未实现商业版准备阶段存档、英文翻译、Steam 功能和正式美术。约 20 分钟是设计目标，实际时长受提前迎战与防线强度影响，需要真人试玩校准。

## 第一次学习：五分钟改动

1. 在编辑器左下角 FileSystem 打开 `data/gun.tres`。
2. 右侧 Inspector 中把 Damage 从 12 调到 18，按 Ctrl+S。
3. 按 F5 试玩，观察工虫被击杀的速度。
4. 改回 12，再调整 Interval，比较伤害和射速的区别。

场景是可重复使用的对象模板，脚本决定行为，Resource 存储可调参数。资源改动在下一次运行生效。
更多说明见 `docs/学习路线.md` 和 `docs/开发状态.md`。

## 工程导航

- `scenes/`：主场景、可复用炮塔与敌人场景。
- `scripts/board.gd`：网格、建造合法性与共享寻路。
- `scripts/game.gd`：单局协调、战斗规则与原型界面；后续规模扩大时拆分 UI、经济和波次协调器。
- `scripts/tower.gd`、`enemy.gd`：实体状态与程序像素绘制。
- `data/`：建筑、敌人与十波配置，适合初学者在 Inspector 中修改。
- `tests/`：边界、经济、封路、完整波次、胜败与重开验证。

## 验证与打包

在项目根目录运行 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File tools/check.ps1
powershell -ExecutionPolicy Bypass -File tools/export.ps1
```

`check.ps1` 使用隔离的测试存档目录，不覆盖正式游戏纪录。导出使用 `.tools/export/templates/` 下的匹配模板。项目源码不包含引擎；复制源码到另一台电脑时，需安装同版本 Godot 并调整导出预设的自定义模板路径。

自绘图形与合成音效无外部素材依赖；引擎许可与第三方声明见 `LICENSES/`。本地开发版本记录见 Git 历史。

便携 Git 位于 `.tools/git/cmd/git.exe`。后续完成一个小练习后，可在 PowerShell 保存进度：

```powershell
& .tools/git/cmd/git.exe status
& .tools/git/cmd/git.exe add .
& .tools/git/cmd/git.exe -c user.name="Game Creator" -c user.email="creator@local.invalid" commit -m "Adjust gun balance"
```

这里的作者信息只对该次本地提交生效，不修改系统设置，也不会上传网络。验证范围和性能样本见 `docs/验证记录.md`。
