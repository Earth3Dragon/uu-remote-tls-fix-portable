# 更新日志

## v1.1.1 — 2026-11-06

### 修复：自愈任务产生网络抖动 + 每 5 分钟闪一次 CMD 黑框

**现象**

- 装好自愈之后，网络时不时抖一下，UU 偶发掉线
- 每 5 分钟屏幕上闪一次黑色命令行窗口

**根因**

1. v1.1.0 的检查方式是「TCP 连一下 `127.0.0.1:17899`」，每次检查都建立并断开一次连接；超时只有 1.5 秒，系统繁忙时会误判成「端口死了」，直接杀掉分片器重启 —— 这一下所有连接全断，就是能感觉到的抖动。
2. 计划任务直接调用 `powershell.exe`（控制台程序），即使加了 `-WindowStyle Hidden`，任务启动时仍会闪一下窗口。

**修复**

- 检查改为读取系统 TCP 表（`Get-NetTCPConnection`），**不建立任何连接**，零网络交互
- 端口异常时先等 3 秒二次确认，仍异常才重启，避免瞬时抖动误杀
- 新增 `WatchdogLauncher.exe`（winexe 编译），任务调用它，内部以 `CreateNoWindow` 启动 PowerShell，全程无窗口
- 健康时脚本静默退出，不写日志、不做多余动作

**实测**

- 正常状态运行任务：`watchdog.log` 大小不变、`conhost` 进程数不变（无窗口）
- 手动杀掉分片器再运行任务：3 秒内拉起，同样无窗口
- 任务动作已确认为 `WatchdogLauncher.exe`，Last Result = 0

### 升级方式

下载新包解压，双击 `一键修复UU远程.bat` 覆盖安装。它会重写 watchdog、重新注册任务、把任务动作指向无窗口启动器。

验证：

```powershell
schtasks /query /tn UUTlsFragmenterWatchdog /v /fo LIST | findstr "Task To Run"
```

应该显示 `...\WatchdogLauncher.exe`，而不是 `powershell.exe`。

### 文件变化

| 文件 | 变化 |
|---|---|
| `install.ps1` | 自愈段重写（TCP 表检查 + 启动器） |
| `bin/WatchdogLauncher.exe` | 新增，预编译无窗口启动器 |
| `bin/WatchdogLauncher.cs` | 新增，源码 |
| `README.md` / `使用说明.md` | 更新自愈描述 |

---

## v1.1.0 — 2026-11-06

### 修复：分片器静默退出导致 UU 远程整段掉线

**现象**

11-05 晚上开始，UU 远程突然掉线、重连不上，客户端一直转圈。检查发现系统没重启、hosts 映射还在、proxy 配置还在，但 `UUTlsFragmenter.exe` 已经不在了。

**根因**

分片器进程在 11-05 20:16 之后静默退出，没有任何崩溃记录（Application 1000/1001 为空）、没有被 Defender 拦截的记录。但 hosts 里 6 条 `127.0.0.1` 映射仍然生效，客户端把请求发到本机 443，端口没有监听，全部失败。

一句话：**v1.0.0 只有开机自启，没有运行时看护**。进程一死，hosts 就从「修复」变成「断网」。

**修复**

安装包新增自愈看护：

- 安装时写入 `watchdog.ps1` 到安装目录
- 注册计划任务 `UUTlsFragmenterWatchdog`，每 5 分钟运行一次
- 检查 `127.0.0.1:17899` 是否可连接；连不上就先结束残留进程，再重启分片器
- 每次动作写 `watchdog.log`（超过 512 KB 自动重建，不会无限增长）
- 卸载脚本同步删除该计划任务

**实测**

手动结束分片器进程，再触发计划任务：3 秒内恢复监听，`curl` 走 hosts 正常返回。

### 升级方式

下载新版压缩包解压，直接双击 `一键修复UU远程.bat` 覆盖安装即可。脚本会重建分片器、重写 hosts、补上自愈任务，不需要先卸载。

如果你是从 v1.0.0 升级，建议装完之后验证一下自愈任务：

```powershell
schtasks /query /tn UUTlsFragmenterWatchdog
```

能查到任务、下次运行时间在 5 分钟内，就算装上了。

### 文件变化

| 文件 | 变化 |
|---|---|
| `install.ps1` | 新增 watchdog 写入 + 计划任务创建 |
| `uninstall.ps1` | 新增计划任务删除 |
| `README.md` | 补充自愈说明与风险提示 |
| `使用说明.md` | 补充自愈说明 |
| `CHANGELOG.md` | 新增（本文件） |

### 仍然存在的边界

- 自愈粒度是 5 分钟，极端情况下仍会有最多 5 分钟断线
- 如果分片器是被安全软件反复查杀，自愈会变成「拉起来又被杀」的循环，需要把安装目录加白名单
- 只对程序内硬编码的域名生效，UU 换域名仍需改源码重编译

---

## v1.0.0 — 2026-11-04

- 首个便携版：预编译分片器、自动探测 UU 安装路径、hosts + 本地 443 双通道
- 基于 [yunyancuo/uu-remote-tls-fix](https://github.com/yunyancuo/uu-remote-tls-fix)（MIT）改造
