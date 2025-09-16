import 'package:shared_preferences/shared_preferences.dart';

class UserDatas {
  final Future<SharedPreferences> _loginda = SharedPreferences.getInstance();
  String _token = "";
  String get token => _token;

  // Future<void> saveLoginUser(UserAuthModel model) async {
  //   savedUser(true);
  //   saveUserId(model.user?.id ?? 0);
  //   savePhoneNumber(model.user?.phoneNumber ?? "");
  //   saveRefreshToken(model.refresh ?? "");
  //   saveAccessToken(model.access ?? "");
  // }

  void saveToken(String token) async {
    SharedPreferences value = await _loginda;
    value.setString("token", token);
  }

  void deleteUserDatas() async {
    SharedPreferences value = await _loginda;
    value.clear();
  }

  Future<String> getToken() async {
    SharedPreferences value = await _loginda;
    if (value.containsKey('token')) {
      String data = value.getString("token")!;
      _token = data;

      return data;
    } else {
      _token = '';

      return "";
    }
  }
}
