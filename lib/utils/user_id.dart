import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserIdHelper {
  static const _key = 'userId';

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_key);

    if (userId == null) {
      // Generate a new UUID
      userId = const Uuid().v4();
      await prefs.setString(_key, userId);
    }

    return userId;
  }
}
