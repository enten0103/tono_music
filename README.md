# TnonMusic

TonoMusic是一个基于flutter的LxMusic插件兼容项目，其通过flutter_js项目实现了一个最小的LxMusic插件运行时。

# Features

音源
- [x]  wy
- [x]  tx
- [ ]  local

核心

- [x] 基础插件运行时
- [ ] 完整插件运行时
- [x] 流式API

插件运行时

- [x] on
- [x] send
- [x] request
- [x] uiils.buffer.from
- [x] uiils.buffer.bufToString
- [x] uiils.crypto.aesEncrypt
- [x] uiils.crypto.md5
- [x] uiils.crypto.randomBytes
- [ ] uiils.crypto.rsaEncrypt
- [ ] uiils.zlib.inflate
- [ ] uiils.zlib.deflate


功能

- [x] 广场
- [ ] 榜单 
- [x] 音乐播放
- [x] 收藏
- [ ] 音轨微调
- [x] 逐句歌词
- [ ] 逐词歌词
- [x] 歌曲搜索
- [x] 歌单搜索
- [ ] 评论
- [x] 歌单管理
    - [x] 歌单导入
    - [x] 歌单订阅
- [ ] 其它功能

平台相关

- [ ] windows
    - [x] 标准控制
    - [x] 托盘
    - [ ] 桌面歌词
- [ ] andorid
    - [ ] 通知栏
    - [ ] 标准控制
    - [ ] 桌面歌词
- [ ] ios
    - [ ] 通知栏
    - [ ] 标准控制
    - [ ] 桌面歌词
- [ ] mac
    - [ ] 标准控制
    - [ ] 托盘
    - [ ] 桌面歌词

缓存相关
- [x] 封面缓存
- [ ] 歌词缓存
- [ ] url缓存
- [ ] 歌曲缓存


# Q&A

Q:为什么在LXmusic中可以正常工作的插件无法运行  
A:项目仍处在开发中，目前仅实现了最小的兼容。已知处于被混淆状态的脚本会出现严重的运行问题。

Q:为什么只有两个在线音源支持  
A:部分平台SDK强依赖于js运行时，难以复刻为dart代码  

Q:为什么没有鸿蒙相关支持计划  
A:插件运行时依赖于quickjs或其它js运行时，目前未见移植

## 打包发布（Windows / Inno Setup）

仅发行 Windows，使用 Inno Setup 生成安装包：

1. 先构建 Release 可执行文件（PowerShell）
    - flutter build windows
2. 安装 Inno Setup 6（https://jrsoftware.org/isinfo.php）
3. 生成安装包
    - 用 Inno Setup 打开 `installer/installer.iss` 并点击编译
    - 或命令行编译：
      - "C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe" installer\\installer.iss
4. 安装包输出位置：`build/installer/TonoMusic-Setup-1.0.0.exe`

提示：
- `installer/installer.iss` 会将 `build/windows/x64/runner/Release` 目录整体打入安装包；请在每次打包前先执行 `flutter build windows`。
- 如需修改安装目录、应用名、版本号等，可编辑 `installer/installer.iss` 顶部的常量定义。



