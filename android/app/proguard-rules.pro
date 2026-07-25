# Flutter 默认使用 AOT 编译，Dart 代码不受 Java 混淆影响，
# 但需保留 Flutter 引擎及原生插件的相关类，避免反射调用被移除。

# 保留 Flutter 引擎入口
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 保留应用原生层（如有 Kotlin/Java 插件代码用到反射）
-keep class com.example.c001apk_flutter.** { *; }

# 保留所有带 native 方法的类
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留序列化相关的构造器（部分插件用反射 fromJson）
-keepclassmembers class * {
    public <init>(...);
}

# Flutter 引擎引用了 Play Core（动态分发）相关类，但本项目未引入
# play core 依赖，R8 报缺失类错误。按 R8 missing_rules.txt 推荐格式添加
# missing 类的 keep 规则（仅声明存在，不会因找不到而报错）。
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication {
    <init>();
}
-keep class com.google.android.play.core.splitinstall.SplitInstallException {
    <init>(...);
}
-keep class com.google.android.play.core.tasks.OnFailureListener {
    <init>();
}
-dontwarn com.google.android.play.core.**

