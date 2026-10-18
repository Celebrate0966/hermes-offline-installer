# Hermes 离线安装工具包

把一台机器上已经装好的 Hermes 安装素材整体打包，搬到另一台没网（或网很差）的机器上，
让**官方安装器**自己跑完 9 个阶段。

> **唯一标准：双击 `Hermes-Setup.exe` → 一路成功 → 首次启动弹出引导（填昵称 + 选主题色）。**
> 任何"在命令行手动编译出一个 Hermes.exe"的做法都不是目标，只是最后兜底。
>
> 装完**不需要准备任何 API key**——Hermes 自带 Nous 免费层，开箱即可对话。
> 急着填 key 反而容易填错字段、把官方通道顶掉，详见「装完之后」一节。

---

## 📦 离线包下载（百度网盘）

> ⚠️ **本 GitHub 仓库只有脚本 + 文档（几 KB）。约 4 GB 的离线二进制包放在百度网盘：**
>
> 🔗 **百度网盘：[在此粘贴你的真实分享链接]**　提取码：`________`
>
> 下载后解压到任意位置（U 盘 / 移动硬盘 / 本地盘均可），里面已自带
> `1-restore.bat`、`2-watch.bat`、`README.md` 等，**直接照下方"30 秒快速开始"操作即可**。
> 如果你已经拿到这份离线包，可跳过本节的网盘说明，直接去「30 秒快速开始」。
>
> （注：本仓库 README 里的这一节，在 `export.ps1` 把文档打进离线包时会被自动替换成
> "这是离线安装包本身" 的说明，所以**离线包里不会出现"下载自己"的循环链接**。）

---

## 这个仓库该放什么（GitHub 仓库只放脚本 + 文档）

**本仓库只放脚本 + 文档（几 KB），离线包那 4 GB 二进制不进 git。** 原因：

- GitHub **单文件硬上限 100 MB**，超过直接被拒；仓库建议 ≤ 1 GB，> 5 GB 会严重变慢。
- 即便走 Git LFS（免费 10 GB 存储 + 10 GB 带宽/月），4 GB 也会让每个 clone 都拉 4 GB、很快吃光带宽。
- 离线包是**可再生的**：任何一台已装好 Hermes 的机器用 `export.ps1` 都能重新生成，没必要集中托管。

所以分工是：**脚本 + 文档进 GitHub 仓库；4 GB 离线包走百度网盘**（见上方下载框）。

| 东西 | 放哪 | 怎么拿 |
|---|---|---|
| 脚本 + README + LICENSE | **GitHub 仓库** | `git clone` |
| 4 GB 离线包 | **百度网盘（见上方链接）** | 浏览器下载，约 4 GB；想自己造也可用 `export.ps1` 从已装好的 Hermes 重新生成 |

`.gitignore` 已经把 `HermesOffline/`、`*.bundle`、各缓存目录都排除了，误提交会被拦下。

---

## 30 秒快速开始

### A. 装

```text
1. 从百度网盘下载离线包（约 4 GB）并解压到本地任意位置
2. 双击离线包里的  1-restore.bat        ← 铺离线资源，看 self-check 是否全 OK
3. 双击离线包里的  2-watch.bat          ← 启动监控，窗口保持开着
4. 双击 Hermes-Setup.exe                ← 认准 .exe，不要用旁边的 .cmd
5. 等 9 个阶段变绿，装完关掉监控窗口
```

### B. 首次启动 —— **什么都别填，直接用官方免费层**

```text
6. 启动 Hermes，什么都不要配置，直接发第一条消息
7. 走完引导（填昵称 + 选主题色）
```

> **关键顺序：先让官方 Nous 免费层把引导跑完，再考虑 API。**
> 这一步急着填 key，一旦填错字段就会把官方通道顶掉，
> 界面直接变成"请输入 API"、引导永远不弹——**看起来像没装好，其实和安装包无关**。
> 详见「装完之后」一节。

### C. 用顺了再决定要不要用自己的 API

```text
8. 需要特定模型 / 更高额度时，再 hermes model 选自己的 provider，或填自己的 key
```

走到 C 说明安装已经成功。**A → B → C 这个顺序别颠倒**，这是整个流程里最容易踩的一步。

---

## 开装前必须确认的三件事

这是整个流程里最容易翻车的地方，逐条确认再动手。

### 1. 离线包在哪

**不需要**把包放到桌面，放哪都行。脚本用自身所在目录定位资源，不依赖固定盘符。

> 早期版本文档里写的是 `cd $env:USERPROFILE\Desktop\HermesOffline`，
> 一旦包放在别的盘，照抄就 `cd` 失败、脚本根本没跑起来。v2 已改成自动定位。

### 2. 本机 electron 哈希 —— **头号坑，务必看懂**

electron 的缓存目录名是**下载地址算出来的哈希**，不同机器用的镜像不同，哈希就不同：

```text
导出机  79ef461d3ddf1554ba071c198d131a4c95f6e1d2db94b8c71c5791ad05fd9660
目标机  f8e28233e6e3c550d71d9c11516cd2922e2e6aae5f2ce70cc7f7c5ff23d6148d
```

安装器会去**两个地方**找，且会从第一个回退到第二个：

| 顺序 | 位置 | 说明 |
|---|---|---|
| (a) | `<仓库>\.cache\desktop-inputs\packager\electron` | 构建脚本用 `--cache` 显式指定 |
| (b) | `%LOCALAPPDATA%\electron\Cache` | 下载器的默认回退位置 |

**换一台全新电脑时，(a)(b) 都是空的，只有离线包带来的 `79ef461d`——
哈希对不上，判定缓存未命中，转去联网，然后 `fetch failed` 挂 10 分钟。**

对策有两条，建议都做：

- `restore.ps1` 会把离线 zip 同时铺进 (a) 和 (b)，并**补齐这两处已存在的每一个哈希目录**
- `watch-electron-cache.ps1` 每 2 秒扫一次这两个位置，**任何新出现的空哈希目录立刻填入 zip**

> 已知限制：我们试过用 md5/sha1/sha256/sha512/sha3 反推各种常见镜像 URL，
> 都没能对上实际哈希，说明哈希来源由安装器内部决定，无法离线预计算。
> 所以"监控兜底"是唯一可靠手段，别省掉第 3 步。

### 3. 装在哪个盘

C 盘会吃掉几 GB。想把仓库放别的盘，`1-restore.bat` 会问你，或者直接用参数：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -RepoRoot D:\HermesData\hermes-agent
```

脚本会校验三件事，不达标会警告：

- 盘符**存在**
- 是**固定磁盘**（`DriveType=3`）—— 移动硬盘拔掉整个安装就废了
- **剩余空间 ≥ 12 GB**（仓库本体 + 构建产物，实测吃掉 4–6 GB）

C 盘只留一个 junction 指针，Hermes 仍按原路径访问，无需改任何配置。

---

## 完整流程

| 步骤 | 做什么 | 验收 |
|---|---|---|
| 1 | 结束残留进程（python / hermes / gateway），关掉占端口的程序 | 无残留进程 |
| 2 | 跑 `1-restore.bat` | self-check **全部 OK** |
| 3 | 有 MISSING 先解决，别硬装 | 无 MISSING |
| 4 | 跑 `2-watch.bat`，窗口保持开着 | 显示 watching |
| 5 | 双击 `Hermes-Setup.exe` | 9 阶段全绿 |
| 6 | 关掉监控窗口 | — |
| 7 | **启动 Hermes，不填任何 key，直接发第一条消息** | AI 真的回了（走官方 Nous 免费层） |
| 8 | 走完引导 | 填昵称 + 选主题色 |
| 9 | *（可选）* 之后才配自己的 provider / key | `hermes model` 自选 |

安装器阶段：

```text
prerequisites → repository → venv → python-deps → config → products → setup → gateway → complete
```

参考耗时：约 23 分钟，其中 `products` 占 20 分钟以上。

---

## 装完之后：引导没弹的真正原因

**这是最容易误判成"没装好"的一件事。** 装出来的程序没问题，问题在凭据。

### 先搞清楚：引导根本不是弹窗

Hermes 的"填昵称 + 选主题色"**不是独立弹窗**，它的机制是
（`agent/onboarding.py`）：

> 在你**发出的第一条消息里注入一段系统指令**，让 AI 在回复时主动问你名字和主题色。

也就是说——**引导要靠 AI 成功回一次话才会出现**。

你发「你好」时，实际发出去的是：

```text
你好
[System note: This is the user's very first message ever...]
```

如果这次 AI 调用失败，**引导就永远不会出现**，你只会看到界面让你填 API ——
然后你会以为是安装少装了什么。实际上 9 个阶段全绿、程序完全正常。

### 先知道：官方本来就自带免费层，不用自备 API

**这是最容易搞反的一点。** Hermes 出厂就带一个 **Nous 免费层**，新装机什么都不配也能聊：

- `hermes_cli/auth.py` 的 `PROVIDER_REGISTRY` **第一行就是 `nous`**，注释明写
  "Registry rows in priority order"——**它就是默认第一优先级**
- `hermes model` 菜单里第 1 项是 `Nous Portal (Everything your agent needs, 300+ models
  with bundled tool use)`
- 首次使用会调 `POST /api/anonymous/create` **自动铸造一个匿名账户**（`anon_` 凭证），
  再用它换短期推理 JWT，全程无感，不用你填任何 key

所以"公司那台没配 API 也能走引导"是正常的——**它走的就是官方免费层**，
不是因为公司机器有什么特殊配置。

### 病根：自己填的 key 把官方通道顶掉了

Hermes 看到 `.env` 里有 key 就会**优先用它**，不再回退免费层。于是一旦填错，
免费层就再也进不去：

| 项 | 值 | 结果 |
|---|---|---|
| 被选中走的通道 | Fireworks（`accounts/fireworks/models/kimi-k2p6`） | 需要 `FIREWORKS_API_KEY` |
| `FIREWORKS_API_KEY` | 39 字符，**前缀 `ms-`** | ❌ 401 无效 |
| `NVIDIA_API_KEY` | 70 字符，`nvapi-` | ✅ 有效 |

`ms-` 是 **Moonshot / Kimi** 的 key 格式，填进 Fireworks 字段，Fireworks 直接回
`401 The API key you provided is invalid`，Hermes 把它表现成了
`404 model not found` —— 于是看起来像"模型不存在"，其实是被拒了。

> **给新装用户的建议：装完先什么都别填，直接用。** 官方免费层够跑通引导和日常对话。
> 等确实需要特定模型时再填自己的 key，而且一定填对字段——填错不是"多一个备份"，
> 是**把能用的官方通道挤掉**。

**判断 key 属于哪家，看前缀最快：**

| 前缀 | 属于 | 该填的字段 |
|---|---|---|
| `fw_` | Fireworks | `FIREWORKS_API_KEY` |
| `ms-` | Moonshot / Kimi | `KIMI_API_KEY`（**不是** FIREWORKS） |
| `nvapi-` | NVIDIA | `NVIDIA_API_KEY` |
| `sk-` | OpenAI | `OPENAI_API_KEY` |
| `sk-ant-` | Anthropic | `ANTHROPIC_API_KEY` |

### 怎么验证 key 到底通不通

别猜，直接问接口（不会打印你的密钥）：

```powershell
# Fireworks
$k = (Select-String -Path "$env:LOCALAPPDATA\hermes\.env" -Pattern '^FIREWORKS_API_KEY=(.+)' ).Matches[0].Groups[1].Value
(Invoke-WebRequest 'https://api.fireworks.ai/inference/v1/models' -Headers @{Authorization="Bearer $k"}).StatusCode

# NVIDIA
$k = (Select-String -Path "$env:LOCALAPPDATA\hermes\.env" -Pattern '^NVIDIA_API_KEY=(.+)' ).Matches[0].Groups[1].Value
(Invoke-WebRequest 'https://integrate.api.nvidia.com/v1/models' -Headers @{Authorization="Bearer $k"}).StatusCode
```

返回 `200` 就是通的，`401` 就是 key 无效或填错地方了。

顺手看一眼模型是不是真在可用列表里（拿到了 200 也别想当然）：

```powershell
(Invoke-RestMethod 'https://integrate.api.nvidia.com/v1/models' -Headers @{Authorization="Bearer $k"}).data.id |
    Select-String 'kimi|deepseek|glm|nemotron'
```

### 想让引导重新走一遍

有两道锁会阻止引导二次触发，**两道都要开**：

| 锁 | 位置 | 处理 |
|---|---|---|
| `onboarding.seen.profile_build_offered: true` | `config.yaml` | 删掉这一行 |
| `state.db` 里已有消息记录 | `%LOCALAPPDATA%\hermes\state.db` | 删库（启动会自动重建空库） |

```powershell
cd "$env:LOCALAPPDATA\hermes"
Copy-Item config.yaml "config.yaml.bak-$(Get-Date -f yyyyMMdd_HHmmss)"   # 先备份
Copy-Item state.db    "state.db.bak-$(Get-Date -f yyyyMMdd_HHmmss)" -EA SilentlyContinue
# 删掉 config.yaml 里 onboarding.seen 下的 profile_build_offered 那一行
Remove-Item state.db -Force
```

改完重启 Hermes，发第一条消息就会重新问名字和主题色。

> `state.db` 常被残留的 gateway 进程锁住删不掉，先结束 python / hermes / gateway 进程再删。
> 别动 `.machine`（内容是 `{"trial":"reserved"}`），它管试用状态，和引导无关。

### 怎么回到官方默认通道

如果已经填错 key、想退回官方免费层，**让官方流程自己处理最稳**：

```powershell
& "$env:LOCALAPPDATA\hermes\bin\hermes.exe" model      # 选 1. Nous Portal
```

选完 Hermes 会自己写 `config.yaml`、自己换推理 JWT，不用你手填模型名。

想先确认免费层在不在，看这几个（**"logged out" 是匿名态的正常显示，不代表坏了**）：

```powershell
& "$env:LOCALAPPDATA\hermes\bin\hermes.exe" auth status nous
```

匿名态下官方的原话是 `You're not signed in. Free inference and connectors are always on.`
——**没登录 ≠ 不能用**。

手动查凭据也行，`auth.json` 里有匿名账户就说明免费层已铸造：

```powershell
python -c "import json;d=json.load(open(r'$env:LOCALAPPDATA\hermes\auth.json'));p=d['providers'].get('nous',{});print('anon_token:',bool(p.get('anon_token')),' welcome_claim:',p.get('welcome_claim'))"
```

| 看到 | 含义 |
|---|---|
| `anon_token` 有、`access_token` 无 | 匿名账户已铸造，但**还没换推理 JWT**——因为一直走别的 provider，没触发过。切到 Nous 就会自动换 |
| `anon_token` 无 | 免费层还没铸造过。切到 Nous 并对话一次即可 |
| 服务不通 | 先确认 `https://portal.nousresearch.com` 和 `https://inference-api.nousresearch.com/v1/models` 能否访问 |

如果确认不再需要某个 key，把 `.env` 里对应行**注释掉**（别直接删，方便恢复），
免得它继续抢占 provider 选择。

---

## 那些文档里没写、但真会绊你一下的事

这一节是实战换来的，按踩坑频率排序。

1. **`setup` 和 `gateway` 显示 Skipped 是正常的。**
   日志会写明 `"reason":"needs user input"`——这两步要你本人交互，安装器主动跳过，
   留到首次启动时做。只要 `complete` 是 Succeeded 就算成功。

2. **打包阶段日志长时间不动，不代表卡死。**
   `products` 里 "Preparing Node dependencies" 实测 18 分钟、"打包桌面端" 3 分钟，
   期间日志基本无输出。判断它死没死，看**输出目录的时间戳和体积**在不在涨：
   ```powershell
   Get-ChildItem <repo>\apps\desktop\release -Recurse -File | Measure-Object -Property Length -Sum
   ```

3. **不需要管理员权限，大概率也不会弹 UAC。**
   安装器 manifest 是 `asInvoker`，装在 `%LOCALAPPDATA%` 用户目录下，当前权限就够。
   直接双击即可，**不要**特意右键"以管理员身份运行"。

4. **"开 Clash"不是重点，重点是让直连流量也能出去。**
   node / electron 的下载器**不读 Windows 系统代理**，它们会直连，直连就死。
   Clash 的 TUN 模式在网卡层劫持所以管用；等价替代是设环境变量：
   ```powershell
   [Environment]::SetEnvironmentVariable('HTTPS_PROXY','http://127.0.0.1:7890','User')
   [Environment]::SetEnvironmentVariable('HTTP_PROXY','http://127.0.0.1:7890','User')
   ```
   端口按你自己的代理改。这属于兜底——**缓存命中就压根不会联网**。

5. **`%LOCALAPPDATA%\electron-builder\Cache` 是空的不用慌。**
   electron-builder 的二进制（winCodeSign / 7zip / icons）走的是
   `--cache <仓库>/.cache/desktop-inputs/packager`，离线包已经铺到那里了，
   默认路径为空不影响。

6. **离线包里的 electron 版本可能和仓库要求的不一致。**
   仓库 `apps/desktop/package.json` 写死 `"electron": "40.10.2"`。
   离线 zip 版本对不上会被静默忽略，然后转去联网。
   v2 脚本会做这个校验并在 self-check 前 WARN。

7. **别把 `installs/` 打进离线包。**
   里面的路径写死了原机器的用户名，搬过去就是死路径。
   虚拟环境会让安装器用离线缓存自动重建，很快。

8. **想强制弹"首次引导"**：跑 `1-restore.bat` 时加 `-ResetOnboarding`
   （或直接 `powershell -ExecutionPolicy Bypass -File .\restore.ps1 -ResetOnboarding`）。
   真正起决定作用的是两道锁——`config.yaml` 里的 `onboarding.seen.profile_build_offered`
   和 `state.db` 里的消息记录，详见上一节。

   它会删 `config.yaml` + `state.db`，并把 `.env`、`auth.json` **只备份不删除**——
   这两个装着你的 API key 和官方免费层凭据，删了就是数据丢失。
   被删的也都留了 `*.bak-<时间戳>` 可回退。
   顺带好处：`config.yaml` 重建后 provider 会回到官方默认（Nous 免费层）。

   `state.db` 常被残留 gateway 进程锁住删不掉，脚本会先结束相关进程。

9. **系统还原（VSS）会吃掉你删掉的空间。**
   删了十几个 G 但 C 盘没涨，多半是影卷还留着旧版本：
   ```powershell
   vssadmin delete shadows /for=C: /all        # 需要管理员
   vssadmin resize shadowstorage /for=C: /on=C: /maxsize=2GB
   ```

---

## 故障排查

先看日志锁定阶段：

```powershell
Get-Content "$env:LOCALAPPDATA\hermes\logs\bootstrap-installer.log" -Tail 40
```

| 卡在 | 现象 | 处理 |
|---|---|---|
| prerequisites | 第一关死循环 | `tools/` 没铺进去，重跑 restore，看 self-check |
| repository | 克隆/拉取超时 | 仓库已用 bundle 快照，可接受；或开代理让它 fetch |
| venv / python-deps | 建环境慢 | `hermes-cache/` 没铺，重跑脚本 |
| electron / products | `fetch failed`、挂 10 分钟 | **确认监控脚本在跑**；确认两个缓存位置都有 zip |
| products | `ENOTEMPTY` | 之前手动往 `apps\desktop\build\packager\win32-x64` 塞过东西，整个删掉再跑脚本 |
| electron 版本 | 静默转联网 | 对比 package.json 与离线 zip 版本，重新导出包 |
| **首次启动不弹引导** | 直接让你填 API | **不是安装问题**——见上一节：AI 首调失败。先验 key 前缀和 401，再清两道引导锁 |

**验证成功**（满足即可）：

- [ ] 9 阶段全绿，`complete` = Succeeded
- [ ] `%LOCALAPPDATA%\hermes\logs\bootstrap-installer.log` 里搜不到 `fetch failed` / `ENOTEMPTY` / `node-gyp`
- [ ] `apps\desktop\release\Hermes.exe` 存在（约 204 MB）
- [ ] **第一条消息 AI 真的回了**，不是 `404 model not found` / `401 invalid`
- [ ] 走的是官方 Nous 免费层（`hermes model` 第 1 项），**没填任何自己的 key 也能聊**
- [ ] 首次启动弹出引导（填昵称 + 选主题色）

---

## 怎么导出离线包给别人

在一台**已经装好**的机器上双击 `3-export.bat`（或手动跑脚本），自动得到一个约 4 GB 的目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\export.ps1                # 默认输出到 ./HermesOffline
powershell -ExecutionPolicy Bypass -File .\export.ps1 -Output D:\HermesOffline
powershell -ExecutionPolicy Bypass -File .\export.ps1 -RepoRoot K:\HermesData\hermes-agent
```

脚本会按 restore.ps1 期望的结构，自动从 `%LOCALAPPDATA%\hermes` 和仓库里拷出
`tools/`、`bootstrap-cache/`、`hermes-cache/`、`npm-cache/`、`prebuilt-mirror/`、`desktop-inputs/`、
`desktop-packager/`，并用 `git bundle create --all` 生成 `repo/hermes-agent.bundle`
（那个 ~1.3 GB 的大文件）。它还会顺手把本工具包的脚本 + README 塞进包根，让离线包自包含。

**不要打包 `installs/`**（路径写死用户名，见上文第 7 条）——export.ps1 已经替你避开了。

> 注意 bundle 是快照。目标机联网时安装器会 `git fetch` 拉到更新提交；
> 完全离线就用快照版本，功能完整但可能不是最新。

> ⚠️ **这个 4 GB 目录不进 GitHub 仓库**——它走百度网盘分发（见顶部下载框）。它只在需要分发时生成，
> 任何一台装好 Hermes 的机器都能用 export.ps1 重新造出来；造好后传到百度网盘并更新链接即可
> （见「怎么更新百度网盘里的离线包」）。

---

## 装完可以回收的空间

确认能正常启动后，这些可以安全删除（都在 `%LOCALAPPDATA%\hermes\` 下）：

| 目录 | 约 |
|---|---|
| `backups\fix-*` | 822 MB |
| `apps\desktop\build\packager.bak-*` | 253 MB |
| `prepared-packaging-tools.bak-*` | 50 MB |
| `*.junk-*` / `.staging-*` / `*.bak-*` | 若干 |
| `hermes-agent.broken-*` | 2.1 GB（旧的坏仓库，确认新仓库 OK 后删） |

不要手动删 C 盘 hermes 目录里的其他东西来"腾空间"——很容易把环境弄坏。

---

## 文件说明

| 文件 | 作用 |
|---|---|
| `1-restore.bat` | 双击入口，铺离线资源 + self-check |
| `restore.ps1` | 核心脚本，支持 `-RepoRoot` / `-ResetOnboarding` / `-SkipMirrorPin` |
| `2-watch.bat` | 双击入口，启动 electron 缓存监控 |
| `watch-electron-cache.ps1` | 每 2 秒扫描两个缓存位置，新哈希目录立即填入 zip |
| `3-export.bat` | 双击入口，从已安装的 Hermes 导出离线包 |
| `export.ps1` | 导出脚本，支持 `-Output` / `-RepoRoot` / `-Force` |
| `README.md` | 本文件 |
| `LICENSE` | MIT |
| `.gitignore` | 排除 4 GB 离线包和各缓存目录，防止误提交 |

脚本只复制、不删除，重复跑幂等，中断了再跑一次会续上。

---

## 发布到 GitHub（只推脚本 + 文档）

仓库里只有脚本 + 文档（几 KB），放心推。**4 GB 离线包不进 git**，它走百度网盘（见上方下载框）。

> ⚠️ 推之前，先把上方「📦 离线包下载（百度网盘）」里的占位链接替换成你**真实的百度网盘分享链接**。
> 这样网友 `git clone` 后一眼就能拿到离线包地址；之后 `export.ps1` 也会把这个带链接的 README 一起打进离线包。

```bash
cd hermes-offline-kit
git init
git add -A                 # .gitignore 会自动拦掉 4 GB 的二进制
git commit -m "Hermes 离线安装工具包 v2"
git branch -M main
# 二选一（没配 SSH 就选 HTTPS）：本仓库地址 https://github.com/Celebrate0966/hermes-offline-installer
git remote add origin git@github.com:Celebrate0966/hermes-offline-installer.git          # SSH
# git remote add origin https://github.com/Celebrate0966/hermes-offline-installer.git   # HTTPS
git push -u origin main
```

> 离线包为什么不进 GitHub：单文件硬上限 100 MB、仓库建议 ≤ 1 GB；4 GB 会让每个 clone 都拉 4 GB。
> 它只放在百度网盘，且**随时可用 `export.ps1` 从任意一台已装好的 Hermes 重新生成**，无需集中托管。
>
> （如果你确实想走 GitHub Release 分发离线包：Release 单文件上限 2 GB，4 GB 需分卷
> `tar -cf - . | split -b 1900m - HermesOffline.part-`，目标机用 `cat HermesOffline.part-* | tar -xf -` 还原。
> 但我们默认推荐百度网盘，更简单。）

---

## 怎么更新百度网盘里的离线包

离线包里的二进制可能随 Hermes 版本变旧（例如 electron 版本、模型列表）。想发一版更新的包：

1. 在一台**已装好且版本较新**的 Hermes 机器上双击 `3-export.bat`（或手跑 `export.ps1`），
   它会从本机导出一份约 4 GB 的新离线包，并自动把本工具包的脚本 + README 塞进包根。
2. 把新目录整个传到百度网盘，**覆盖/更新**之前的分享，并刷新提取码（如有变化）。
3. 回到本仓库，把 README 顶部下载框里的链接更新成新的，再 `git commit` / `git push`。

这样网友始终能拿到"脚本最新 + 二进制可用"的组合。

