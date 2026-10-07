# macOS、Linux、WSL 与无界面环境

附带自动执行脚本针对 Windows；本包发布时没有在 macOS/Linux 完整执行。其他系统由接收者的 Codex 按相同阶段生成当地脚本，并明确标注待验证部分。不能只是改扩展名后声称兼容。

## 应保持的设计

- 独立项目目录和 OpenClaw HOME/STATE/CONFIG/WORKSPACE 环境变量，原生 Codex homeScope=agent；不覆盖已有 ~/.openclaw 或 ~/.codex。
- npm global prefix 指向项目 runtime，npm cache、临时目录、日志指向项目。Unix global 包的 CLI 通常位于 runtime/lib/node_modules/openclaw/openclaw.mjs，与 Windows runtime/node_modules 不同；检查实际 npm 安装结果。
- 检查 Node 和 npm 版本、原生插件 schema，保留固定版本基线或有依据地适配；不把当前 Windows 可执行路径复制过去。
- 原生配置中的 workspace 和 logging.file 生成当地绝对路径，随机令牌本机生成，网关仅监听回环地址。
- 仅继承用户已有且适用的 HTTP(S) 代理；macOS 系统代理/PAC 不一定被 Node 继承。核对现有配置和进程环境，不修改系统路由。本地 readiness 应明确直连。
- 保留 deny=["*"]、只读沙箱、禁审批提权、关闭电脑操作/插件/MCP 继承的受限模式，并用真实报告核对。
- 后台进程使用 PID、启动时间和命令身份校验；不能 pkill node 或 killall openclaw。默认不安装 systemd、launchd 或计划任务，除非用户另行要求。

## 登录、扫码与可见性

有图形界面时用系统实际可用的浏览器打开 OpenAI 官方授权页面。无界面服务器或 localhost 回调不可达时，核对官方设备码支持；可适用时让用户在自己的设备登录，不传送密码或令牌。

微信 QR 生成依旧应从真实运行中的官方 CLI 取得。Linux 可生成 PNG 并通过 Codex 的本地图片展示功能显示；若临时页面运行在远端，127.0.0.1 链接不会自动指向用户的手机或电脑。优先直接显示二维码图片，或按已授权的转发能力访问，不为扫码开放公网目录服务。

WSL 的 localhost 转发、默认浏览器启动、路径转换和进程管理均需在实际环境验证。首次搭建 Windows 用户通常可直接使用 Windows 脚本，避免无需求地多加 WSL 一层。

最后仍需用户扫码确认、手机发送两轮消息。只有完成该目标环境的真实收发后，才能报告当地接入成功。
