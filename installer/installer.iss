; TonoMusic Windows Installer (manual Inno Setup script)
; Requires: Inno Setup 6 (Unicode)

#define AppName "TonoMusic"
#ifndef AppVersion
	#if GetEnv("APP_VERSION") != ""
		#define AppVersion GetEnv("APP_VERSION")
	#else
		#define AppVersion "1.0.0"
	#endif
#endif
#define AppExe "tono_music.exe"
#define AppIdGuid "9F5A6C72-3B1D-4E8C-8D9C-1F2A3B4C5D6E" ; Reserved for reference

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
; 注意：AppId 中的花括号需要成对转义为 {{ }}（这里直接写死，避免预处理器和常量冲突）
AppId={{9F5A6C72-3B1D-4E8C-8D9C-1F2A3B4C5D6E}}
AppPublisher=enten0103
DefaultDirName={commonpf}\{#AppName}
DefaultGroupName={#AppName}
DisableDirPage=no
DisableProgramGroupPage=yes
; 允许用户选择安装为“仅当前用户/所有用户”
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir=..\build\installer
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
; 安装器程序图标
SetupIconFile="{#SourcePath}\..\assets\icons\app_icon.ico"
; 根据系统 UI 语言自动选择语言（若中文可用将自动使用中文）
LanguageDetectionMethod=uilanguage

[Languages]
; 英文（内置）
Name: "english"; MessagesFile: "compiler:Default.isl"
; 简体中文（使用本地翻译，位于与本脚本同目录）
Name: "chinesesimplified"; MessagesFile: "{#SourcePath}\\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 从 Flutter Release 产物目录复制全部文件到 {app}
Source: "..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; 开始菜单快捷方式
Name: "{autoprograms}\\{#AppName}"; Filename: "{app}\\{#AppExe}"
; 桌面快捷方式（可选任务）
Name: "{autodesktop}\\{#AppName}"; Filename: "{app}\\{#AppExe}"; Tasks: desktopicon

[Run]
; 安装完成后可选启动（默认不勾选）
Filename: "{app}\\{#AppExe}"; Description: "{cm:LaunchProgram,{#StringChange(AppName,'&','&&')}}"; Flags: nowait postinstall skipifsilent unchecked
