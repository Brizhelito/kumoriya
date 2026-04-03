import 'package:kumoriya_auth/src/models/oauth_provider.dart';
import 'package:kumoriya_auth/src/models/token_pair.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/auth_state.dart';
import '../models/user.dart';

abstract interface class AuthService {
  Future<Result<Uri, KumoriyaError>> beginOAuthLogin({
    required OAuthProvider provider,
    required Uri callbackUri,
    String? deviceName,
  });

  Future<Result<AuthState, KumoriyaError>> completeOAuthLogin(Uri callbackUri);

  Future<Result<TokenPair, KumoriyaError>> refreshToken({
    required String userId,
    required String refreshToken,
  });

  Future<Result<void, KumoriyaError>> beginPasskeyRegistration();

  Future<Result<void, KumoriyaError>> finishPasskeyRegistration(Object payload);

  Future<Result<void, KumoriyaError>> beginPasskeyAuthentication({
    required String userId,
  });

  Future<Result<AuthState, KumoriyaError>> finishPasskeyAuthentication({
    required String userId,
    required Object payload,
    String? deviceName,
  });

  Future<Result<AuthUser?, KumoriyaError>> getCurrentUser();

  Future<Result<void, KumoriyaError>> logout({required String refreshToken});
}
