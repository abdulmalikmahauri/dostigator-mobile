import 'package:dostigator/state/theme_controller.dart';
import 'package:provider/single_child_widget.dart';
import 'package:provider/provider.dart';

/// Хранилище темы в памяти: настоящее лезет в SharedPreferences,
/// которых в тестах нет.
class MemoryThemeStorage implements ThemeStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;
}

/// Провайдер темы для обёрток экранов: шапка читает его на каждой вкладке.
SingleChildWidget themeProvider([ThemeController? controller]) =>
    ChangeNotifierProvider<ThemeController>.value(
      value: controller ?? ThemeController(MemoryThemeStorage()),
    );
