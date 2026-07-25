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
