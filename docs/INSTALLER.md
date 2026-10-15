# 一体安装 / Bundled Windows installation

## 中文

1. 在 GitHub 仓库点击 **Code → Download ZIP**，或使用 README 的完整包下载链接，然后解压。请勿只下载 `install.cmd`；`vendor`、`install`、`src`、`localization` 和校验清单必须一并保留。
2. 退出小丑牌，双击解压目录中的 **install.cmd**。
3. 选择包含 `Balatro.exe` 的游戏安装目录，核对显示的游戏目录与 Mods 目录。
4. 阅读组件和版本说明，输入 **INSTALL** 确认。完成后正常启动游戏，在牌局中松开 **F8**。

包含固定版本 Lovely `0.10.0`、SMODS `26.829.0` / commit `39182f0cc7b1af86d3d3d6afc5422661a07b4312` 和本控制器。安装过程无需网络、Python、Git 或编译。PowerShell 使用 Windows 自带版本；执行策略选项只作用于此次进程，不修改系统执行策略。

仅面向当前验证基线 Windows 11 x64、Steam Balatro `1.0.1o-FULL`。安装器读取 EXE 中的版本和身份特征，目标不匹配就停止，不修改游戏。完整跨电脑与 0.8.1 实机功能验收仍待完成。

安装前会校验全部清单和依赖哈希。不同的 `winmm.dll`、旧 `version.dll`、不同版本/重复 SMODS、重复或未知控制器目录会导致停止，提示用户自行处理；不会盲目覆盖或删除。

同版本、同内容的前置依赖会直接复用。已有本控制器目录会先移动到 `%AppData%\Balatro\BDCBackups`，安装失败时尝试恢复。失败输出也会保留供排查。备份不放在 Mods 中，避免重复加载。不要把个人备份上传到项目中。

安装器只写 Lovely DLL 与许可文件、Mods 下的 SMODS 和本控制器，以及必要备份目录。不会修改 Profile、存档、Steam 设置、注册表、PATH 或杀毒设置，也不会自动提权。如果目录不可写，请自行决定授权方式；安装器会停止并报告错误。

卸载本控制器时，将 `BalatroDrawController` 移出 Mods 即可。Lovely 与 SMODS 是共享依赖；如需移除，请先确认其他 Mod 不再依赖它们。完整许可见 [第三方声明](../THIRD_PARTY_NOTICES.md)。

## English

Use **Code → Download ZIP** on GitHub or the README download link and extract the **complete bundle**, close Balatro, double-click `install.cmd`, select the folder containing `Balatro.exe`, and type **INSTALL** after reviewing the targets. Start the game normally and release F8 during a run.

The bundle includes the pinned Lovely and SMODS versions; installation needs no internet, Python, Git or compilation. It targets the tested Windows 11 x64 / Steam Balatro 1.0.1o-FULL combination only. Version detection is a guard, not proof of complete cross-machine functional acceptance.

All manifest and archive hashes are checked. Matching dependencies are reused; differing DLLs, old injectors, changed or duplicate loaders and unknown Mod folders are refused. An existing controller is retained outside Mods and rollback is attempted if installation fails. Keep backups private.

The installer does not edit player saves, Steam settings, registry, PATH or antivirus settings and does not elevate itself. If access is denied, decide yourself how to grant access. Third-party components retain their own licenses; see [notices](../THIRD_PARTY_NOTICES.md).

## Command-line checks

Use `-GameDir` to supply your own game folder instead of choosing it interactively; `-DryRun` checks without installing. `-DataDir` selects a Balatro data directory and is mainly useful for isolated verification. `-Yes` is an explicit automation opt-in that skips the final confirmation; the double-click flow always asks first.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/Install.ps1 -GameDir "$env:BALATRO_DIR" -DryRun
```

`BALATRO_DIR` must first be set to your own installation directory. No developer-specific path is embedded.
