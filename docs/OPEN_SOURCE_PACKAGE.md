# Public source package / 公开源码包

## Contents

```text
BalatroDrawController/
├─ BalatroDrawController.json
├─ main.lua
├─ config.lua
├─ src/
├─ localization/
├─ README.md
├─ LICENSE
├─ CHANGELOG.md
├─ MANIFEST.sha256
├─ docs/
│  ├─ OPEN_SOURCE_PACKAGE.md
│  └─ VERIFICATION.md
├─ tests/
└─ tools/
```

This folder is independent of the game installation and can serve as the repository root. Its runtime metadata and main entry remain directly at the root, preserving normal SMODS installation layout. Tests and tools are development resources, not additional in-game Mods.

保留的公开内容：本 Mod 自编 Lua、双语本地化、原 MIT 署名、入门说明、修改记录、可移植测试与文件哈希清单。

排除的内容：游戏 EXE/DLL、游戏 Lua 抽取结果、图像与音频资源、Lovely/SMODS 副本、个人存档和配置、原始日志、截图、聊天与私人调查记录、旧版本备份、临时测试驱动、缓存和开发机路径。

`LICENSE` and metadata retain the original public author attribution. Copyright belongs to the respective owners; this Mod's license does not relicense Balatro or its loaders. Game assets are referenced at runtime and are not included.

## Publication boundary

- This is a local source archive; creating it does not create a Git repository or upload anything.
- Publish only this isolated folder, not its parent game/development directory.
- Keep the repair-candidate status visible until complete live acceptance is finished.
- `.gitignore` helps prevent accidental additions; the manifest and scanner check actual included files independently of ignore rules.
- Readme installation steps, candidate status and testing scope are included in Chinese and English. More UI languages and a visual redesign remain future work.

## Integrity

`MANIFEST.sha256` contains the SHA-256 of every public file except itself. The archive has a separate `.zip.sha256` checksum. Checksums verify byte integrity, not author identity or a cryptographic signature.
