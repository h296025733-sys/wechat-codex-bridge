# 来源、版本和适用边界

技能包版本：1.0.0。整理日期：2026-09-07。此包包含自编排流程、脚本和模板，不包含 OpenClaw/Codex/微信运行时、任何人的凭据或聊天数据。第三方组件由接收者的 Codex 从官方包源安装，并受各自条款约束。

## 已测来源环境基线

| 项目 | 基线 |
| --- | --- |
| 系统 | Windows，PowerShell 5.1/7 分别验证适用脚本 |
| Node.js / npm | 24.19.0 / 11.17.0 |
| OpenClaw | 2026.9.2 |
| Codex 插件 | @openclaw/codex@2026.9.2 |
| 微信插件 | @tencent-weixin/openclaw-weixin@2.4.8 |
| 插件管理的 Codex | 0.153.4 |
| 实际模型 | openai/gpt-6-astra，ChatGPT 登录，medium |

来源环境已完成：真实模型请求、同会话回忆、一次文件权限探针、微信扫码绑定、手机两轮文字收发及上下文回忆。它证明该组合在这次环境可用，不保证接收者账号有相同权限或未来版本行为不变。

新目录测试发现：实装 OpenClaw 的 external-cli-sync 可用本机现有 Codex OAuth 初始化 OpenAI profile。新项目在没有重新网页登录的情况下成功完成真实模型调用；核对运行记录为 OAuth profile、实际项目路径正确。不要沿用旧文档中“必须重新授权”或“新目录必为空授权”的假定；识别本人已有授权与登录新账号是两个分支。

重新打包的通用脚本属于新版本，测试范围见压缩包根目录 VALIDATION.md，不能把来源环境的测试自动算作每个新脚本已端到端执行。

## 维护时的依据优先级

当前安装版本的原生命令/schema/实现和实际运行证据 → 当前官方文档 → 本包记录的旧基线。发生差异时保存差异和证据，保留权限边界，不能用旧说明强行盖过新错误。

- [OpenAI：技能格式与发现方式](https://learn.chatgpt.com/docs/build-skills)：技能目录以 SKILL.md 为入口，可含 scripts/references/assets 和 agents/openai.yaml。自动发现目录可能随产品版本变化；显式让 Codex 读取解压后的 SKILL.md 最直接。
- [OpenAI：身份验证](https://learn.chatgpt.com/docs/auth)：ChatGPT 登录与 API key 登录是不同路径；登录文件包含敏感凭据。设备码可用性应按账号和当前文档核对。
- [OpenClaw：OpenAI 接入](https://docs.openclaw.ai/providers/openai)：本方案采用 openai provider 的 ChatGPT 登录与 Codex 路由。
- [OpenClaw：Codex harness](https://docs.openclaw.ai/plugins/codex-harness-reference)：agent homeScope 与受限工具面是本方案隔离的重要依据。单纯 profile 缩窄不能替代明确工具策略。
- [腾讯微信官方 npm 包](https://www.npmjs.com/package/@tencent-weixin/openclaw-weixin)：安装时核对精确包名、来源及版本。用户自己的微信 ClawBot 页面也是入口与扫码步骤的直接依据。
- [腾讯云微信 ClawBot 通道说明](https://cloud.tencent.com/document/product/1831/137055)：作为微信通道的补充官方说明，不能推断个人账号永久免费或不限量。

本包没有实现“ClawBot 直接连接当前 Codex 桌面会话”。它部署独立 OpenClaw，由 Codex harness 提供模型能力；桌面任务历史不会自动进入微信。
