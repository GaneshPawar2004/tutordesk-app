import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the server address and login token on the device.
class SessionStore {
  static const _serverKey = 'server_url';
  static const _tokenKey = 'auth_token';

  /// Live backend; editable on the login screen. Override at build time with
  /// `--dart-define=API_URL=http://192.168.0.117:4000` for a local server.
  static const defaultServer = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://tutordesk-backend.onrender.com',
  );

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
