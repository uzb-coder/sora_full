import 'package:shared_preferences/shared_preferences.dart';

class UserDatas {
  final Future<SharedPreferences> _loginda = SharedPreferences.getInstance();
  String _token = "";
  String _api = "";
  String get token => _token;
  String get api => _api;

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

  void saveApi(String api) async {
    SharedPreferences value = await _loginda;
    value.setString("api", api);
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

  Future<String> getApi() async {
    SharedPreferences value = await _loginda;
    if (value.containsKey('api')) {
      String data = value.getString("api")!;
      _api = data;

      return api;
    } else {
      _api = '';

      return "";
    }
  }
}
