# AI Reply 中文说明

AI Reply 是一个面向 Android 的 Flutter 智能回复助手，用来把“不会回、懒得回、来不及回”的聊天场景变成一个可配置、可复用、可持续优化的工作流。

它的核心思路不是只做一个简单的 AI 输入框，而是把截图识别后的回复生成、复制文字后的快捷改写、人物画像沉淀、聊天历史管理、个性化表达风格、朋友圈/人物分析，以及对话模拟训练整合到同一个应用里。

## 产品定位

这个项目适合几类典型场景：

- 经常需要处理微信、QQ、社交平台、工作沟通消息的人
- 想提高聊天效率，又希望回复不要太机械的人
- 需要根据不同对象、关系、语气生成不同说法的人
- 想把“回复生成”从一次性工具变成长期可迭代能力的人

一句话概括：它不是单纯“帮你写一句回复”，而是在做一个 Android 侧的聊天表达辅助系统。

## 功能亮点

- 截图生成回复：从相册、剪贴板、系统分享、悬浮截图等入口快速拿图并生成建议回复
- 文字生成回复：支持粘贴文本、系统分享文本，以及 Android `PROCESS_TEXT` 文本处理入口
- 快捷回复工作流：支持悬浮球、快捷入口、深链和原生 Android 场景联动
- 人物画像与历史：沉淀联系人画像、关系特征、历史记录和复制痕迹，方便后续复用
- 个性化表达：支持默认风格、自定义风格、目标导向和表达偏好
- OpenAI 风格接口兼容：支持模型拉取、能力标记、失败回退、多种响应解析兼容
- 进阶能力：支持朋友圈/人物分析，以及聊天模拟训练与反馈

## Android 侧能力

这个项目不是纯 Flutter 页面壳，还包含一层比较完整的 Android 原生桥接能力：

- 悬浮截图与快捷回复服务
- MediaProjection 截图路径
- AccessibilityService 一键截图路径
- Android 分享意图接入
- Deep Link 接入
- 应用快捷方式接入

所以它既有 Flutter 主业务代码，也有 Android 原生层来承接系统级入口和权限能力。

## 仓库结构

```text
gaoqingshangapk/
|- lib/                  Flutter 业务代码
|- android/              Android 原生宿主工程与桥接代码
|- assets/               图片与图标资源
|- test/                 Dart / Flutter 测试
|- docs/                 迁移审计与补充说明
|- scripts/              辅助脚本
|- pubspec.yaml          Flutter 依赖定义
|- README.md             主 README（英文为主，含中文导读）
|- README.zh-CN.md       中文说明
|- README-WINDOWS.md     Windows 环境接手说明
```

## 快速开始

环境要求：

- Flutter stable
- Android Studio 或 Android 命令行 SDK
- Android SDK Platform 36+

运行方式：

```bash
flutter pub get
flutter run
```

如果 Gradle 提示 `flutter.sdk not set in local.properties`，把 `android/local.properties.example` 复制为 `android/local.properties`，再填入你本机的 Flutter 和 Android SDK 路径。

## 关键文档

- [README.md](README.md)：主项目说明与英文技术概览
- [README-WINDOWS.md](README-WINDOWS.md)：Windows 环境接手说明
- [PROJECT_MANIFEST.md](PROJECT_MANIFEST.md)：项目文件与模块清单
- [docs/MIGRATION_AUDIT.md](docs/MIGRATION_AUDIT.md)：迁移清单与设备侧验证矩阵

## 隐私与权限说明

这个应用里，截图相关能力依赖两条用户主动授权的路径：

- 应用内 MediaProjection 截图
- 悬浮一键截图使用的 AccessibilityService

项目本身不会静默读取其他 App 内容，不会自动替用户发送消息，也不会把原始截图作为长期历史记录保存。若启用可选的两阶段视觉流程，截图文字会通过你配置的视觉模型接口参与当前生成流程，而不是在本地做长期缓存。

## 当前仓库的价值

从仓库角度看，这个项目已经不只是“一个 Flutter Demo”，而是一套相对完整的 Android 智能回复产品原型，具备：

- 明确的聊天场景切入点
- 多入口接入能力
- 模型接口抽象与兼容策略
- 人物/历史/风格等长期记忆能力
- 原生权限、服务、深链和分享流程整合

如果后续要继续对外展示，建议围绕这几个方向继续补充：

- 产品截图或演示 GIF
- 使用场景示例
- API 配置示例
- 常见问题与权限说明
- 版本更新记录
