# UU 远程 SNI 阻断修复（便携版）

一键解决「UU 远程登录不上 / 设备列表刷不出来 / 连不上远控」，专治校园网或局域网出口防火墙对 `*.nrd.nie.163.com` 做 TLS SNI 阻断。

本包基于 [yunyancuo/uu-remote-tls-fix](https://github.com/yunyancuo/uu-remote-tls-fix)（MIT）改造：换成预编译程序（目标机无需 .NET 编译环境），并自动识别 UU 的非标准安装路径。2026-11-04 在本机实测通过。

---

## 一、先判断：是不是这个问题

连不上 UU 远程有好几种原因，先按三层取证，别急着修：

| 层 | 命令 | 正常结果 | 异常结果 |
|---|---|---|---|
| DNS | `nslookup api.nrd.nie.163.com` | 能解析出 IP | 解析失败 → 是 DNS 问题，不是本工具 |
| TCP | `Test-NetConnection api.nrd.nie.163.com -Port 443` | `TcpTestSucceeded: True` | 连接失败 → 是网络/代理问题 |
| TLS | `curl.exe -sS -o NUL --max-time 8 https://api.nrd.nie.163.com/` | 返回 HTTP 状态码 | **报 `Connection was reset`（exit 35）** → 就是 SNI 阻断，用本工具 |

本次本机实测的典型症状：DNS 正常解析、TCP 0.05 秒连上、**TLS 握手 0 毫秒就被 RST**，六个域名全军覆没。这属于「TCP 能通、一发 ClientHello 就被重置」，正是明文 SNI 被识别后阻断。

---

## 二、它怎么绕过

防火墙看的是 TLS 握手第一个包（ClientHello）里明文的 SNI 字段。这个工具在本机开一个透明代理，把这个首包**按 SNI 字段中间切成两个标准 TLS Record 帧**再发出去——目标服务器能正常重组，中间设备却看不到完整域名，于是放行。

链路：

```
UU 客户端 -> hosts/代理配置 -> 127.0.0.1:443 / 17899
        -> UUTlsFragmenter.exe（拆帧）-> 物理网卡 -> 网易服务器
```

因为是透明转发、不终止 TLS，所以证书校验、证书固定都不受影响。

---

## 三、工序（本次实际执行的六步）

1. **定位安装**：自动找到 UU 远程的真实安装目录（可能在任意盘符，不一定在默认的 Program Files），定位 `GameViewerLauncher.exe` 与 `GameViewerService`。
2. **分层取证**：DNS → TCP → TLS 逐层测，确认是 SNI 阻断而不是 DNS 或断网。
3. **装分片器**：把 `bin\UUTlsFragmenter.exe` 复制到 `%LOCALAPPDATA%\UURemoteTlsFix\` 并启动，监听 `17899`（SOCKS5）、`443`（透明分片）、`53`（局域网 DNS，可选）。
4. **挂两条通道**：① 写 UU 自带的 `C:\ProgramData\Netease\GameViewer\proxy_config.ini` 指向 `127.0.0.1:17899`；② 管理员权限下改 hosts，把 6 个 `nrd` 域名指向 `127.0.0.1`。本机实测**第一条通道对 UU 4.22 无效**，真正起作用的是 hosts。
5. **重启生效**：刷 DNS 缓存，重启 `GameViewerService` 和客户端。客户端重启后重新解析域名，才会走到 127.0.0.1。
6. **回读验证**：看分片器日志是否出现 `[DIRECT+TLS-FRAG] api.nrd.nie.163.com` 记录——出现才说明流量真的经过它，而不是「装好了就当成功」。

---

## 四、怎么用

1. 把整个文件夹拷到目标电脑（U 盘、网盘都行，不用安装）。
2. 双击 **`一键修复UU远程.bat`**，UAC 弹窗点「是」。
3. 等脚本跑完，看到 6 个端点全部 `握手成功` 即可。
4. 手动打开 UU 远程，登录、刷新设备列表。

> 首次修复后建议重启一次 UU 客户端，让它重新解析域名。

---

## 五、它在系统里改了什么（都可回滚）

| 位置 | 内容 |
|---|---|
| `%LOCALAPPDATA%\UURemoteTlsFix\` | 分片程序、源码、运行日志 |
| `HKCU\...\Run\UURemoteTLSFragmenter` | 开机自启（当前用户） |
| `C:\ProgramData\Netease\GameViewer\proxy_config.ini` | UU 代理配置（指向本机 17899） |
| `C:\Windows\System32\drivers\etc\hosts` | 6 行 `127.0.0.1 xxx.nrd.nie.163.com # UU_REMOTE_TLS_FIX` |
| 防火墙 | 入站放行 `TCP 443/17899`、`UDP 53`（仅管理员模式） |

**卸载**：双击 `一键卸载恢复.bat`，会停进程、删自启、重置 `proxy_config.ini`、清掉 hosts 里带 `UU_REMOTE_TLS_FIX` 的行、删安装目录。

> 逐步操作、常见问题、验证与更新，见 **[使用说明.md](使用说明.md)**。

---

## 六、边界（别指望它包治百病）

- 只对程序里硬编码的域名生效：6 个 `*.nrd.nie.163.com` + `uuyc.163.com` 等。UU 换域名就要改 `bin\UUTlsFragmenter.cs` 重编译。
- 只管 TLS/TCP 443。如果出口把 QUIC（UDP 443）也封了，或直接封 IP，它没用。
- 如果学校用「深度包检测 + 主动探测」而不是只看 SNI，分片也可能被识别。
- 这是绕过网络管控的手段，用之前先确认自己学校的网络使用规定，别拿它干违规的事。
- 修复后 UU 的所有 `nrd` 流量都走本机，分片器进程必须常驻（已设开机自启）。

---

## 七、目录结构

```
UU远程SNI修复-Portable/
├── 一键修复UU远程.bat      # 双击修复（自动提权）
├── 一键卸载恢复.bat        # 双击卸载（自动提权）
├── install.ps1             # 修复主脚本（已改为优先用包内 exe）
├── uninstall.ps1           # 卸载脚本
├── bin/
│   ├── UUTlsFragmenter.exe # 预编译分片程序（.NET 4.x，Win10/11 自带）
│   └── UUTlsFragmenter.cs  # 源码，要加域名就改它
└── README.md
```

---

## 八、来源与许可

- 原始项目：https://github.com/yunyancuo/uu-remote-tls-fix （MIT License）
- 本包改动：预编译 exe 优先、自动探测 UU 安装路径、中文启动器与文档。
- 原理与域名列表来自原项目，未做改动。
