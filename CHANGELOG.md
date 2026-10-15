# Changelog

## 0.8.1 — repair candidate / 修复候选

- Distinguish explicit Mod selections from ordinary native discovery bypass flags. Normal shop purchases after loading can record discoveries normally.
- Persist explicit run-only provenance in the current run save, including selected undiscovered editions and redeemed vouchers. Pending queues remain runtime-only.
- Exclude native deck-view display copies from temporary-card cleanup, retaining cleanup for real gameplay copies.
- Hide rank/suit faces in Stone Card and replacement-enhancement candidate/queue previews.
- 为公开源码保留明确文件白名单；移除私人环境记录、存档、日志、游戏源码抽取结果和测试驱动。保留原 MIT 许可证。

The private development baseline passed 137 grouped checks plus M3/M4 regressions. This source package includes 21 portable targeted checks; full live verification of 0.8.1 is still pending. See [verification scope](docs/VERIFICATION.md).

旧 0.8.0 战局缺少可靠来源信息，无法追溯先前指定的对象。请在新牌局验证修复后的保护行为。此版本不是完整实机验收完成的声明。

## 0.8.0

- Remember the panel view during the current process.
- Replace type-selection arrows with click-to-open choice lists.
- Add pending-choice previews and owned Joker edition editing.
- 面板视图记忆、点击下拉选择、预约队列预览与已有小丑牌版本编辑。

## Earlier development

Implemented existing-instance draw queues, official one-shot random choices, confirmed temporary playing cards, state safety, a read-only official catalog, Simplified Chinese / English, and configurable panel keys.
