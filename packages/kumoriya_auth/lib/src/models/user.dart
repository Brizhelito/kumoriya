final class AuthUser {
  const AuthUser({required this.id, required this.displayName, this.avatarUrl});

  final String id;
  final String displayName;
  final Uri? avatarUrl;
}
