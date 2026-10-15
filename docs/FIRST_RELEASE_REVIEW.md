# v0.1.0 首发记录 / First release record

## 版本与范围

首个公开版本为 **Balatro Lucky Hand v0.1.0**，对外版本从 `0.1.0` 开始。此前 `0.8.x` 是开发编号，不是 GitHub 发行系列。本次基于开发版 `0.8.1`，统一 metadata、入口版本、安装器显示和包名；游戏功能、Mod ID、安装文件夹及存档结构保持原实现。

发布标题：**Balatro Lucky Hand v0.1.0 — 首次公开发布 / First Public Release**。

## 发布材料

| 项目 | 内容 |
| --- | --- |
| 首页 | [README](../README.md)：功能、安装、使用和固定版本范围 |
| 发布正文 | [RELEASE_NOTES](RELEASE_NOTES.md)：简洁中英双语说明与当前功能 |
| 安装指南 | [INSTALLER](INSTALLER.md) |
| Git 标签 | `v0.1.0`，指向包含本次修改的提交 |
| 附件 | `Balatro-Lucky-Hand-0.1.0-windows-x64.zip` 与同名 `.zip.sha256` |
| 包内清单 | `MANIFEST.sha256`，覆盖全部公开文件，清单自身除外 |
| 许可 | Mod / 安装器 MIT；Lovely MIT；SMODS GPLv3 |

发行附件按清单打包，排除 Git 历史、个人数据、原版游戏文件和临时产物。发布使用同一份已核验 ZIP；标签与 main 同步推送，附件上传完成后公开 Release，并回读核对远程标签、发布状态和附件哈希。

## 检查预算

本次只执行两次测试，不反复追加测试轮次：

1. `tools/check_project.py`：结构、清单、隐私模式、依赖哈希、Lua 语法和 8 项预览回归。
2. 从最终 ZIP 解压后执行 `tests/test_installer.py`：10 项隔离安装检查，包含冲突拒绝、取消、包损坏和回滚。

此前通过的 13 项保护回归保留为历史依据，本次不重复运行。完整实机功能和跨电脑验收尚未完成；公开首个版本不代表这些验证已经完成。

## 尚待实机确认

- [ ] 安装后正常加载，F8 能打开和关闭面板。
- [ ] 搜索、筛选、下拉、悬停、页面记忆及中英文显示正常。
- [ ] 空队列原生行为、真实实例补牌及临时牌完整生命周期符合说明。
- [ ] Boss、商店、补充包预约和小丑牌版本编辑符合原生规则。
- [ ] 预览、自然发现、本局保护与保存/载入正常。
- [ ] 返回主菜单、重开和载入时待执行队列清空。

## English summary

Public versioning starts at `v0.1.0`, based on development build `0.8.1`. Version identifiers and release materials are synchronized without gameplay changes. Publish the exact checked commit and assets. Checking is limited to two executions; complete live and cross-machine acceptance remain pending and are disclosed in the release notes.
