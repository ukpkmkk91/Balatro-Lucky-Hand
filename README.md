# Balatro Draw Controller

**小丑牌游戏内控制面板 · In-game control panel for Balatro**

自由选择下一次抽牌、Boss、商店与补充包内容，通过卡牌预览、悬停介绍和一次性随机结果控制，体验更多策略与组合。

Choose your next draw, Boss Blind, shop offers, and booster pack contents. Explore strategies and combinations with card previews, hover descriptions, and one-shot outcome controls.

[中文说明](#中文说明) · [English](#english)

**源码包入口 / Source package:** [MIT License](LICENSE) · [修改记录 / Changelog](CHANGELOG.md) · [公开包范围 / Package contents](docs/OPEN_SOURCE_PACKAGE.md) · [验证与测试 / Testing](docs/VERIFICATION.md)

当前包为 **0.8.1 修复候选一体包**，包含 Mod、Lovely 和 SMODS 的固定依赖原包。解压后双击 **install.cmd**，选择游戏目录并确认即可安装，无需另找前置文件。游戏本体须自行合法安装，完整实机及跨电脑验收仍待完成。

**[下载完整安装包 / Download the complete bundle](https://github.com/ukpkmkk91/Balatro-Lucky-Hand/archive/refs/heads/main.zip)**（也可在本仓库点击 Code → Download ZIP）。

**Bundled setup:** extract the complete ZIP, run **install.cmd**, select your Balatro folder and confirm. Pinned Lovely and SMODS archives are included; no separate dependency downloads are needed. The game itself is not included. This remains a repair candidate, not a claim of complete cross-machine acceptance. [安装说明 / Installer guide](docs/INSTALLER.md)

## 中文说明

### 1. 解决什么问题

想测试某个牌型，却一直抽不到需要的牌？想体验一种小丑牌组合，却反复遇不到目标商店或补充包？

本 Mod 将部分原生随机选择变成可操作的游戏内选项，适合个人单机降低难度、练习策略和体验官方内容。你可以指定下一次合格事件的结果，随后继续正常游戏；抽牌数量、手牌与小丑牌容量、价格、包内选择次数及官方来源限制仍然生效。

本项目使用 **Balatro → Lovely → Steamodded / SMODS → 本 Mod** 的技术路线。候选仅包含官方游戏内容；没有待执行指定时，抽牌和随机选择沿用原流程。主动指定结果可能改变后续随机数消耗，因此不保证之后的随机结果与未操作时完全相同。

### 2. 主要功能

| 功能 | 能做什么 |
| --- | --- |
| 下一次抽牌队列 | 从当前抽牌堆选择真实卡牌实例，调整顺序、删除或清空；支持初始发牌、弃牌补牌和出牌后补牌。 |
| 临时官方扑克牌 | 选择花色、点数及可用属性；优先使用匹配的现有实例。抽牌堆没有时，经确认生成仅用于这一手的临时牌。 |
| 一次性随机选择 | 指定下一次合格的 Boss、商店商品、包类型、包内候选、优惠券、标签及部分效果生成结果。 |
| 属性与基础概率选择 | 指定下一次合格的增强、版本、蜡封轮询；基础概率选项可选择下一次非必然判定成功或失败。 |
| 已有小丑牌版本编辑 | 为持有的小丑牌设置普通、闪箔、镭射、多彩或负片；互相替换，取消负片受原生容量限制。 |
| 当前牌组与官方图鉴 | 搜索、筛选和查看卡牌图片、属性及悬停说明；独立图鉴只读，浏览不授予卡牌。 |
| 操作与界面记忆 | 鼠标操作、点击下拉列表、队列预览；F8 关闭再打开保留本次进程中的页面和搜索条件。 |
| 双语与快捷键 | 简体中文 / English 随游戏语言；设置中可将面板键改为 F6–F12 中的可用键。 |

### 兼容的版本：仅限本机已验证的版本组合

目前仅在作者本机的下列环境中开发和验证，尚未完成其他电脑的兼容性验收。同样的版本组合可作为其他用户的安装目标，但不代表已经在其他电脑验证过全部功能。

| 组件 | 当前验证基线 |
| --- | --- |
| 系统 | Windows 11 x64 本机；Windows 10 和其他系统尚未验收 |
| 游戏 | Steam Balatro `1.0.1o-FULL`，App ID `2379780` |
| Lovely | `0.10.0`，Windows x64 |
| Steamodded / SMODS | `26.829.0`，commit `39182f0cc7b1af86d3d3d6afc5422661a07b4312` |
| 界面语言 | 简体中文、English |

截至 2026-10-15，`0.8.1` 为修复候选版：开发阶段已通过 137 项分组检查及 M3/M4 旧回归；本源码包包含并通过 21 项定向测试。源码包已完成结构、完整性与隐私检查，0.8.1 的完整实机功能验收仍未完成。它针对 `0.8.0` 的图鉴发现保护与卡牌预览问题进行了修复。

这些是固定验证版本，不代表任意最新版均兼容。运行时检测到未支持的版本会关闭修改功能，可用时保留只读界面。第三方内容 Mod 兼容、UI 美化及更多语言尚未纳入当前已完成功能。

### 3. 安装方法

**推荐：一体离线安装。** 下载完整 ZIP → 解压 → 退出游戏 → 双击 **install.cmd** → 选择包含 `Balatro.exe` 的目录 → 输入 **INSTALL** 确认 → 正常启动游戏，松开 **F8**。

包中已包含 Lovely 和 SMODS，无需联网下载、Python 或编译；安装器使用 Windows 自带 PowerShell，不自动提权，不修改永久执行策略。已有不同版本依赖时会先停止提示。详细备份、权限和冲突说明见[安装器文档](docs/INSTALLER.md)。

下列步骤保留为手动安装方式，已安装正确版本 Lovely 和 SMODS 时可直接进行第 3 步。普通玩家使用面板不需要运行开发测试。包内运行模块完整，可用功能仍受上面的版本检查、游戏状态和官方规则限制。

1. **安装 Lovely。** 退出游戏，从 [Lovely 0.10.0 官方发行页](https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.10.0) 下载 Windows x64 包，将其中的 `winmm.dll` 放到 `Balatro.exe` 同一目录。
2. **安装 SMODS。** 下载[固定 commit 源码包](https://github.com/Steamodded/smods/archive/39182f0cc7b1af86d3d3d6afc5422661a07b4312.zip)，将实际包含 SMODS 文件的文件夹放到 `%AppData%\Balatro\Mods\smods`。路径说明可参考 [SMODS 官方 Windows 安装文档](https://docs.smods.dev/Installation/Installing%20Steamodded%20windows/)；本项目仍使用上表固定版本。
3. **安装本 Mod。** 解压 `BalatroDrawController-0.8.1-source.zip`，将其中的 `BalatroDrawController` 文件夹放到 `%AppData%\Balatro\Mods`。确认该文件夹内直接包含 `main.lua` 和 `BalatroDrawController.json`；保留 `src`、`localization` 和 `config.lua`。`tests`、`tools` 与说明文档可以随包保留，正常游戏不会要求执行它们。
4. **启动并检查。** 启动 Balatro，确认 Mods / 模组列表中出现 **Balatro Draw Controller**；进入牌局，松开 **F8** 打开面板。

正确目录结构：

```text
游戏安装目录/
├─ Balatro.exe
└─ winmm.dll                    ← Lovely 0.10.0

%AppData%/Balatro/Mods/
├─ smods/
└─ BalatroDrawController/
   ├─ BalatroDrawController.json
   ├─ main.lua
   ├─ config.lua
   ├─ src/
   └─ localization/
```

不要重复嵌套成 `BalatroDrawController/BalatroDrawController/main.lua`，也不要把整个游戏目录作为 Mod 安装或上传。游戏本体、存档和私人日志不随包提供；依赖以未修改原包独立提供，许可见[第三方声明](THIRD_PARTY_NOTICES.md)。

**更新 / 卸载：** 退出游戏，将旧 Mod 文件夹移到 Mods 目录外，再放入新版本；移出本 Mod 即可卸载。保留自己的存档和配置，共享的 Lovely / SMODS 无需随之卸载。

### 4. 使用方法

**让指定的现有牌优先补入手牌**

1. 进入牌局，在等待玩家操作时松开 **F8**。
2. 打开「当前牌组」，搜索或筛选所需卡牌，选择仍位于抽牌堆的实例并点击「加入」。同一实例只能加入一次。
3. 打开「抽牌队列」，用上下按钮调整顺序，然后开启抽牌控制。
4. 关闭面板，正常弃牌或出牌。下一次真正补牌时，按容量允许的数量优先抽取队列中的牌；未消费项等待后续补牌。

**指定其他随机内容**

打开「随机选择」→ 点击下拉列表选择事件类别 → 搜索并选择候选 → 检查待执行队列及随机控制开关 → 关闭面板并正常触发对应事件。每项指定成功生效一次后移出队列。已显示的 Boss、商店库存及已经打开的包不会立即被替换；官方保底和来源条件仍会检查。

**编辑已有小丑牌 / 查看图鉴**

在「已有小丑牌」中选择持有实例和版本，点击「应用」；在「官方图鉴」中浏览图片和悬停介绍。设置页可修改面板快捷键。计分、转场、开包或其他不安全状态下，等待游戏完成后再编辑。

**保存边界**

- 待抽队列、随机预约和页面记忆不写入存档；返回主菜单、重开或载入会清空待执行队列。
- 正常获得的卡牌和已应用的小丑牌版本由游戏保存。临时扑克牌离开手牌并完成原生处理后移除，存档会排除它；载入时手牌可能少一张，后续按原生流程补牌。
- `0.8.1` 将明确由 Mod 指定的未解锁 / 未发现对象来源记录随当前战局保存，用于续局后继续保护永久图鉴记录。它不保存待执行队列；同一对象 key 的保护作用于本局。
- `0.8.0` 旧存档缺少可靠来源信息，无法追溯区分此前指定的对象。验证新保护行为时，建议从新牌局开始。

**常见问题：** 没有 Mods 按钮时检查加载器和目录层级；F8 无响应时检查是否已改键，或通过本 Mod 的 Config 鼠标入口打开；选择未生效时检查是否正在等待下一次合格事件。日志位于 `%AppData%\Balatro\Mods\lovely\log`。

### 5. 输入输出示例

这里的「输入」是面板中的选择和点击操作，不是命令行参数；「输出」是下一次原生事件的实际结果。

| 场景 | 输入 / 操作 | 预期输出 |
| --- | --- | --- |
| 按顺序补牌 | 抽牌堆确有 A♥ 和 K♠；按此顺序入队并启用控制；下一次可补两张 | 两个原实例依次进入手牌，原有增强、版本和蜡封保留。 |
| 找不到目标扑克牌 | 在临时扑克牌选择 A♥；抽牌堆没有匹配实例 | 先显示确认弹窗；确认后在下一次合格补牌生成一张本手临时牌。 |
| 选择下一 Boss | 将当前符合官方条件的 Boss 加入对应队列 | 已显示 Boss 保持原样；下一次合格的 Boss 随机生成采用该指定。 |
| 指定天体包候选 | 在对应包内容类别中将木星加入队列，再正常生成该类包 | 条件允许且未被官方保底占用的匹配候选采用木星，包的费用和选择次数照常。 |
| 为已有 Joker 加负片 | 在「已有小丑牌」中选中原实例，选择负片并应用 | 原实例获得官方负片效果，槽位按原生规则更新；不创建新 Joker。 |
| 只读搜索 | 在当前牌组搜索 `Glass Gold` 并提交 | 显示同时匹配两个词的实例及其属性；搜索不改变牌序或生成卡牌。 |

## English

### 1. What problem does it solve?

Balatro Draw Controller helps you try a poker hand, explore a Joker combination, or experience official content without repeatedly waiting for a particular random offer. Select an outcome through the in-game panel, then continue playing normally.

It uses **Balatro → Lovely → Steamodded / SMODS → this Mod**. Draw counts, capacity, costs, pack selection limits, and official source restrictions still apply. Empty or disabled controls delegate to the original flow. Applying an override may change subsequent RNG consumption.

### 2. Main features

- **Next-draw queue:** prioritize real draw-pile instances during initial dealing and replenishment after playing or discarding. Reorder, remove, or clear entries.
- **Temporary official playing cards:** use a matching existing instance first; otherwise request confirmation to create a card for this hand only.
- **One-shot choices:** select eligible Boss generation, shop offers, booster types and contents, vouchers, tags, and supported effect-generated cards.
- **Attributes and basic probability:** control eligible enhancement, edition, seal, and non-certain probability rolls. Existing Jokers can receive native editions, including Negative, subject to capacity rules.
- **Inspector and read-only catalog:** search, filter, preview cards, and read hover descriptions.
- **Panel controls:** click-to-open selectors, remembered views within the current process, Simplified Chinese / English, and a configurable F6–F12 panel key.

**Validation baseline:** Windows 11 x64, Steam Balatro `1.0.1o-FULL`, Lovely `0.10.0`, and SMODS `26.829.0` at commit `39182f0cc7b1af86d3d3d6afc5422661a07b4312`. Other versions may disable modification features. Third-party content compatibility is outside the current tested scope.

**Compatible versions: the author's locally validated combination only.** Development and validation currently cover the author's own PC. The same version combination is the installation target for other users, but full functionality has not been verified on other computers. This is a testing boundary, not a username or installation-drive lock.

As of 2026-10-15, **0.8.1 is a repair candidate** with 137 development grouped checks plus legacy M3/M4 regressions passing. This source package includes 21 passing targeted tests and has passed structure, integrity and privacy checks; complete live functional acceptance of 0.8.1 remains pending. It addresses discovery protection and preview defects found in 0.8.0. UI redesign and additional languages are planned work.

### 3. Installation

**Recommended offline setup:** download and extract the full bundle → close Balatro → run **install.cmd** → select the game folder → type **INSTALL** → launch normally and release F8. Lovely and SMODS are already included. No internet, Python or compilation is required. The installer does not elevate itself or change the permanent execution policy; conflicting dependencies are refused. See the [installer guide](docs/INSTALLER.md).

The steps below remain available for manual setup. Python is required only for optional developer checks. No runtime modules were removed; available features still depend on the version guards, game state and official rules above.

1. Exit Balatro. Download the Windows x64 archive from the [Lovely 0.10.0 release](https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.10.0) and place `winmm.dll` beside `Balatro.exe`.
2. Extract the [pinned SMODS source](https://github.com/Steamodded/smods/archive/39182f0cc7b1af86d3d3d6afc5422661a07b4312.zip) into `%AppData%\Balatro\Mods\smods`. See the [official Windows guide](https://docs.smods.dev/Installation/Installing%20Steamodded%20windows/) for folder placement; retain the pinned version above.
3. Extract `BalatroDrawController-0.8.1-source.zip` and place its `BalatroDrawController` folder in `%AppData%\Balatro\Mods`. Its `main.lua` and `BalatroDrawController.json` must be directly inside that folder. Keep `src`, `localization` and `config.lua`. Tests, tools and documentation may remain in the folder; normal gameplay does not require running them.
4. Launch Balatro, check the Mods list, enter a run, and release **F8** to open the panel.

Avoid nested or duplicate Mod folders. To update or uninstall, exit the game and move the old Mod folder outside Mods. Keep your saves and preferences. Game binaries, saves and private logs are excluded. Bundled loader archives retain their independent licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).

### 4. Usage

**Draw existing cards:** open Current Deck → select instances still in the draw pile → arrange Draw Queue → enable draw control → close the panel → play or discard normally. The next replenishment consumes as many queued cards as the native capacity permits.

**Choose random content:** open Random Choices → choose an event category from the dropdown → search and select eligible candidates → check the pending list and control toggle → trigger the corresponding event normally. Each successful entry is consumed once. Displayed Bosses, existing shop stock, and already-open packs are not immediately replaced; guarantees and source rules remain effective.

**Other tools:** use Owned Jokers to apply an edition to an existing instance, Official Catalog to browse descriptions, and Settings to change the panel key. Edit only while the game is waiting for input in a safe state.

Queues and view memory are not saved; run loading or restarting clears pending choices. Native outcomes and edited Joker editions remain part of the run save. Temporary playing cards are omitted from saves and removed after native hand processing; loading may leave one fewer card until the next replenishment.

Version 0.8.1 persists only explicit run-only protection provenance alongside the current run, including selected undiscovered editions; it never persists pending queues or writes permanent unlock records for those selections. Protection is per object key for that run. Old 0.8.0 saves lack reliable provenance, so previous selections cannot be reconstructed; use a new run to verify the repaired behavior.

If the panel is unavailable, check loader installation, folder nesting, and the configured key. The Mod's Config button provides a mouse entry point. Logs are in `%AppData%\Balatro\Mods\lovely\log`.

### 5. Input / output examples

Inputs are panel actions, not CLI commands. Outputs are results of subsequent native game events.

| Input / action | Expected result |
| --- | --- |
| Queue existing A♥, then K♠; enable control and replenish two cards | Those original instances enter the hand in order, retaining their attributes. |
| Request an official A♥ with no matching draw-pile instance | A confirmation appears; acceptance requests one temporary card at the next eligible draw. |
| Queue an eligible Boss | The displayed Boss stays unchanged; the next eligible Boss generation uses the selection. |
| Queue Jupiter for a Celestial Pack | An eligible matching candidate uses Jupiter, subject to native guarantees; cost and selection count are unchanged. |
| Apply Negative to an owned Joker | The same instance receives Negative and native slot handling; no Joker is cloned. |
| Search `Glass Gold` in Current Deck | Rows matching both terms are shown without changing the deck. |

## 许可证 / License

本 Mod 与安装脚本采用 **MIT License**，完整条款见 [LICENSE](LICENSE)。使用、修改或分发时，请保留原版权声明和许可证文本。随包独立提供的 Lovely 为 MIT、SMODS 为 GPLv3，完整源码和各自许可均保留，详见[第三方声明](THIRD_PARTY_NOTICES.md)。Balatro 游戏本体不在包中。

The controller and installer use the **MIT License**; see [LICENSE](LICENSE). Retain the original copyright and license notice. Independently bundled Lovely uses MIT and SMODS uses GPLv3; their notices and SMODS source remain intact. See [third-party notices](THIRD_PARTY_NOTICES.md). Balatro itself is not included.
