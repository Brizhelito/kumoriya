import 'package:kumoriya_auth/src/models/token_pair.dart';
import 'package:kumoriya_auth/src/models/user.dart';

sealed class AuthState {
  const AuthState();

  T when<T>({
    required T Function() unauthenticated,
    required T Function(AuthUser user, TokenPair tokens) authenticated,
  }) {
    final self = this;
    if (self is UnauthenticatedAuthState) {
      return unauthenticated();
    }
    final authenticatedState = self as AuthenticatedAuthState;
    return authenticated(authenticatedState.user, authenticatedState.tokens);
  }
}

final class UnauthenticatedAuthState extends AuthState {
  const UnauthenticatedAuthState();
}

final class AuthenticatedAuthState extends AuthState {
  const AuthenticatedAuthState({required this.user, required this.tokens});

  final AuthUser user;
  final TokenPair tokens;
}
