import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class UserProfile {
  const UserProfile({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: DbEncoding.text(json['name']),
    role: json['role'] as String? ?? 'customer',
  );
}

class AuthRepository {
  AuthRepository(this.client);

  final SupabaseClient client;

  String get email => client.auth.currentUser?.email ?? '';

  String get redirectUrl {
    const configured = String.fromEnvironment('AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb) return 'moulatkeskes://auth-callback/';
    return Uri(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: Uri.base.hasPort ? Uri.base.port : null,
      path: Uri.base.path,
    ).toString();
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) => client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    required bool isSeller,
  }) => client.auth.signUp(
    email: email.trim(),
    password: password,
    emailRedirectTo: redirectUrl,
    data: {'name': name.trim(), 'role': isSeller ? 'seller' : 'customer'},
  );

  Future<void> requestPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);

  Future<void> updatePassword(String password) =>
      client.auth.updateUser(UserAttributes(password: password));

  Future<void> signOut() => client.auth.signOut();
}

class ProfileRepository {
  ProfileRepository(this.client);

  final SupabaseClient client;

  Future<UserProfile> currentProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before loading profile.');
    final row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserProfile.fromJson(row);
  }

  Future<UserProfile> updateName(String name) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before updating profile.');
    final row = await client
        .from('profiles')
        .update({'name': name.trim()})
        .eq('id', userId)
        .select()
        .single();
    return UserProfile.fromJson(row);
  }
}
