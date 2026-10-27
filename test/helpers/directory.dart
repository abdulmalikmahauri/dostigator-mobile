import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/state/directory_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class _NoStorage extends TokenStorage {
  _NoStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

/// Хаб «Клуба», который никуда не ходит. Для экранов, которым он нужен
/// лишь как зависимость: карта резидента, профиль.
class SilentDirectoryController extends DirectoryController {
  SilentDirectoryController()
    : super(
        ApiClient(
          tokens: _NoStorage(),
          dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
        ),
      );

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<void> ensureLoaded() async {}
}

SingleChildWidget directoryProvider([DirectoryController? controller]) =>
    ChangeNotifierProvider<DirectoryController>.value(
      value: controller ?? SilentDirectoryController(),
    );
