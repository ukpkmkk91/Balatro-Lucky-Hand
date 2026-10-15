# Third-party dependencies / 第三方依赖

The controller and installer are provided under the repository's MIT license. That license does **not** replace the licenses of the independent dependencies below. The bundle is an aggregate of separately licensed components.

本 Mod 与安装脚本采用 MIT。第三方依赖保留各自许可证、版权声明及附带库的许可；请勿将整个合集表述为“所有文件均为 MIT”。

| Component | Version / source | License | Included material |
| --- | --- | --- | --- |
| Lovely Injector | [v0.10.0](https://github.com/ethangreen-dev/lovely-injector/tree/v0.10.0) | MIT | Unmodified official Windows x64 ZIP and [license](vendor/LICENSE-Lovely-MIT.txt) |
| Steamodded / SMODS | [commit 39182f0](https://github.com/Steamodded/smods/tree/39182f0cc7b1af86d3d3d6afc5422661a07b4312), version 26.829.0 | GPLv3 | Complete unmodified source ZIP, containing its own notices and library licenses; [GPL text](vendor/LICENSE-SMODS-GPL-3.0.txt) |

The SMODS archive is source code, not a compiled substitute. Keep the full archive, its LICENSE, and notices when redistributing it. Its `libs/nativefs/LICENSE` and other embedded library headers remain intact. Lovely's copyright and permission notice is also installed alongside its DLL.

The exact upstream URLs and SHA-256 digests are recorded in [vendor/DEPENDENCIES.record](vendor/DEPENDENCIES.record). No Balatro executable, original game Lua, game sprites, soundtrack, player saves or private credentials are included. Balatro must be legally installed separately.

依赖存放为 ZIP，安装时分别解压到正确位置，不与控制器源文件混为一个许可范围。安装器不会从网络下载或改写这些依赖。
