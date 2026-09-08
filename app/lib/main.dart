import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_repository.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_store.dart';
import 'core/storage/account_cache.dart';
import 'core/push/push_client.dart';
import 'features/anniversary/anniversary_repository.dart';
import 'features/album/album_repository.dart';
import 'features/core_loop/core_loop_repository.dart';
import 'features/together/together_repository.dart';
import 'features/memories/memories_repository.dart';
import 'features/wellness/wellness_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokenStore = TokenStore();
  final cache = AccountCache();
  final apiClient = ApiClient(tokenStore: tokenStore);
  final authController = AuthController(
    repository: AuthRepository(apiClient: apiClient, tokenStore: tokenStore),
  );

  runApp(
    LoveSpaceApp(
      authController: authController,
      anniversaryRepository: AnniversaryRepository(apiClient: apiClient),
      albumRepository: AlbumRepository(apiClient: apiClient),
      coreLoopRepository: CoreLoopRepository(
        apiClient: apiClient,
        cache: cache,
      ),
      togetherRepository: TogetherRepository(apiClient: apiClient),
      memoriesRepository: MemoriesRepository(apiClient: apiClient),
      wellnessRepository: WellnessRepository(apiClient: apiClient),
      accountCache: cache,
      pushClient: createPushClient(),
    ),
  );
  await authController.initialize();
}
