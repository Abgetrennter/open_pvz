# Minimal Chaos Pack

这是第五阶段最小扩展包 smoke test。

当前包只演示三件事：

- 扩展目录下的 `EntityTemplate` 与 `TriggerBinding` 可以被 `SceneRegistry` 自动扫描。
- 扩展目录下的验证场景可以通过现有验证入口直接运行。
- 扩展内容仍然复用主仓的投射物、效果和验证主链，而不是复制运行时代码。
