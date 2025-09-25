import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- MUHIM O'ZGARISH
import 'package:sora/Global/my_pkg.dart';
import 'Global/Global_token.dart';
import 'Kirish.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  Get.put(TokenController());
  WidgetsFlutterBinding.ensureInitialized(); // <-- MUHIM O'ZGARISH
  // if (Platform.isWindows) {
  //   // Window manager sozlash
  //   await windowManager.ensureInitialized();
  //
  //   // Full screen qilish
  //   WindowOptions windowOptions = const WindowOptions(fullScreen: true);
  //   windowManager.waitUntilReadyToShow(windowOptions, () async {
  //     await windowManager.setFullScreen(true); // Doimiy fullscreen
  //     await windowManager.show();
  //     await windowManager.focus();
  //   });
  // }
  // if (Platform.isAndroid) {
  //   // ✅ Faqat Android qurilmalarda doimiy LANDSCAPE yo‘nalish
  //   await SystemChrome.setPreferredOrientations([
  //     DeviceOrientation.landscapeRight,
  //     DeviceOrientation.landscapeLeft,
  //   ]);
  // }
  await initializeDateFormatting('uz', null); // <-- MUHIM O'ZGARISH
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
      home: WelcomeScreen(),
    );
  }
}
