import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the server address and login token on the device.
class SessionStore {
  static const _serverKey = 'server_url';
  static const _tokenKey = 'auth_token';

  /// This PC's address on the local Wi‑Fi; editable on the login screen.
  static const defaultServer = 'http://192.168.0.117:4000';

  Future<({String server, String? token})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      server: prefs.getString(_serverKey) ?? defaultServer,
      token: prefs.getString(_tokenKey),
    );
  }

  Future<void> save({required String server, String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, server);
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }
}
