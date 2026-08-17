import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.role,
  });

  final int id;
  final String name;
  final String email;
  final String? mobile;
  final String? role;

  bool get isAdmin => (role ?? '').toLowerCase() == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String?,
      role: json['role'] as String?,
    );
  }
}

class AdminStore extends ChangeNotifier {
  AdminStore(this.api);

  final ApiClient api;

  AdminUser? user;
  bool booting = true;

  bool sessionReady = false;

  bool get isLoggedIn => user != null && user!.isAdmin;

  void finishBoot() {
    if (!booting) return;
    booting = false;
    notifyListeners();
  }

  Future<void> init() async {
    sessionReady = false;
    booting = true;
    notifyListeners();
    try {
      final token = await api.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await refreshMe(maxAttempts: 1);
          if (!isLoggedIn) {
            await api.clearToken();
            user = null;
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) {
            await api.clearToken();
            user = null;
          }
        } catch (_) {}
      }
    } finally {
      sessionReady = true;
      notifyListeners();
    }
  }

  Future<void> refreshMe({int maxAttempts = 2}) async {
    final res = await api.get('/auth/me', maxAttempts: maxAttempts);
    final data = res.data;
    final userJson = data is Map ? (data['user'] ?? data['data'] ?? data) : null;
    if (userJson is Map) {
      user = AdminUser.fromJson(Map<String, dynamic>.from(userJson));
    }
    notifyListeners();
  }

  Future<void> login({
    required String login,
    required String password,
  }) async {
    final res = await api.post('/auth/login', data: {
      'login': login,
      'password': password,
      'portal': 'admin',
      'device_name': ApiConfig.deviceName,
    });
    final token = res.data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Login succeeded but no token returned.');
    }
    await api.saveToken(token);
    final userJson = res.data['user'];
    if (userJson is Map) {
      user = AdminUser.fromJson(Map<String, dynamic>.from(userJson));
    } else {
      await refreshMe();
    }
    if (!isLoggedIn) {
      await api.clearToken();
      user = null;
      throw ApiException('This account is not an administrator.');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout', maxAttempts: 1);
    } catch (_) {}
    await api.clearToken();
    user = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await api.get(path, query: query);
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? data}) async {
    final res = await api.post(path, data: data);
    final body = res.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? data}) async {
    final res = await api.patch(path, data: data);
    final body = res.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? data}) async {
    final res = await api.put(path, data: data);
    final body = res.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }

  Future<Map<String, dynamic>> deleteJson(String path, {Object? data}) async {
    final res = await api.delete(path, data: data);
    final body = res.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }

  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, dynamic> fields, {
    String? fileField,
    String? filePath,
  }) async {
    final res = await api.postForm(path, fields, fileField: fileField, filePath: filePath);
    final body = res.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {'data': body};
  }
}
