# Smart Price AI 客户端

Flutter 客户端，复用现有拍照识物、多目标识别、AI 导购、商品对比和报告页面。
商品、报价及趋势均为样例数据，不提供真实电商实时价格。

## 本地启动

1. 按项目根目录 README 启动 FastAPI 服务并配置模型。
2. 在 `lib/utils/constants.dart` 配置手机可访问的后端地址。
3. 在本目录执行：

```sh
flutter pub get
flutter run
```

## 静态检查

```sh
flutter analyze --no-pub
```

按用户要求，仓库不保留测试源码和测试专用依赖；静态检查不能替代运行时验证。
升级前已有版本及仓库外备份保留旧验证材料。模块改动和真实验证结果见
`../docs/modules/00-cleanup.md`，完整索引见 `../docs/modules/README.md`。
