import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sora/Global/Api_global.dart';
import 'package:win32/win32.dart';

import '../../Gloabal_token.dart';
import 'Jami_zakaz.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final String waiterName;
  final int itemsCount;
  final double subtotal;
  final double serviceAmount;
  final double finalTotal;
  final String status;
  final bool receiptPrinted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<OrderItem> items;
  final int percentage; // 🔥 yangi qo'shildi

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.waiterName,
    required this.itemsCount,
    required this.subtotal,
    required this.serviceAmount,
    required this.finalTotal,
    required this.status,
    required this.receiptPrinted,
    required this.createdAt,
    this.completedAt,
    required this.items,
    required this.percentage, // 🔥 konstruktor

  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'] ?? json['id'] ?? '',
      orderNumber:
      json['orderNumber']?.toString() ??
          json['id']?.substring(18, 24) ??
          'N/A',
      tableNumber: json['tableNumber']?.toString() ?? 'N/A',
      waiterName: json['waiterName']?.toString() ?? 'N/A',
      itemsCount: (json['itemsCount'] ?? 0).toInt(), // double -> int
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      serviceAmount: (json['serviceAmount'] ?? 0).toDouble(),
      finalTotal: (json['finalTotal'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'N/A',
      receiptPrinted: json['receiptPrinted'] ?? false,
      createdAt:
      json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
          DateTime.now()
          : DateTime.now(),
      completedAt:
      json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      items:
      json['items'] != null
          ? (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList()
          : [],
      percentage: json['waiter']?['percentage'] != null
          ? (json['waiter']['percentage'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'orderNumber': orderNumber,
    'tableNumber': tableNumber,
    'waiterName': waiterName,
    'itemsCount': itemsCount,
    'subtotal': subtotal,
    'serviceAmount': serviceAmount,
    'finalTotal': finalTotal,
    'status': status,
    'receiptPrinted': receiptPrinted,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] ?? 1).toInt(); // double -> int
    final itemPrice = (json['price'] ?? 0).toDouble();
    final totalValue = (json['total'] ?? (itemPrice * qty)).toDouble();
    return OrderItem(
      name: json['name']?.toString() ?? '',
      quantity: qty,
      price: itemPrice,
      total: totalValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'price': price,
    'total': total,
  };
}

class AuthResponse {
  final bool success;
  final String token;
  final String message;

  AuthResponse({
    required this.success,
    required this.token,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      token: json['token'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;

  ApiResponse({required this.success, this.data, required this.message});
}

// AuthServices
class AuthServices {
  static const String baseUrl = "${ApiConfig.baseUrl}";
  static const String userCode = "2004";
  static const String password = "2004";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("✅ Token saqlandi: ${token.substring(0, 20)}...");
  }

  static Future<String?> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<ApiResponse<String>> loginAndPrintToken() async {
    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    try {
      print("🔐 Login so'rovi: $loginUrl");
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode, 'password': password}),
      );

      print("📡 Login javob kodi: ${response.statusCode}");
      print("📄 Login javob: ${response.body}");

      if (response.statusCode == 200) {
        final AuthResponse authResponse = AuthResponse.fromJson(
          jsonDecode(response.body),
        );
        await saveToken(authResponse.token);
        return ApiResponse(
          success: true,
          data: authResponse.token,
          message: 'Login muvaffaqiyatli',
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Login xatolik: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("❌ Login xatolik: $e");
      return ApiResponse(success: false, message: 'Login xatolik: $e');
    }
  }
}

// USB Printer Service
class UsbPrinterService {
  Future<List<String>> getConnectedPrinters() async {
    try {
      final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
      final pcbNeeded = calloc<DWORD>();
      final pcReturned = calloc<DWORD>();

      EnumPrinters(flags, nullptr, 2, nullptr, 0, pcbNeeded, pcReturned);

      final cbBuf = pcbNeeded.value;
      if (cbBuf == 0) {
        print("❌ Printerlar topilmadi");
        calloc.free(pcbNeeded);
        calloc.free(pcReturned);
        return [];
      }

      final pPrinterEnum = calloc<BYTE>(cbBuf);

      final result = EnumPrinters(
        flags,
        nullptr,
        2,
        pPrinterEnum,
        cbBuf,
        pcbNeeded,
        pcReturned,
      );

      List<String> printerNames = [];
      if (result != 0) {
        final printerInfo = pPrinterEnum.cast<PRINTER_INFO_2>();
        final count = pcReturned.value;
        print("🖨️ ${count} ta printer topildi");

        for (var i = 0; i < count; i++) {
          final printerName =
          printerInfo.elementAt(i).ref.pPrinterName.toDartString();
          final portName =
          printerInfo.elementAt(i).ref.pPortName.toDartString();

          print("🖨️ Printer: $printerName, Port: $portName");

          // USB va boshqa portlarni qabul qilish
          if (portName.toUpperCase().contains('USB') ||
              portName.toUpperCase().contains('COM') ||
              portName.toUpperCase().contains('LPT') ||
              printerName.toLowerCase().contains('thermal') ||
              printerName.toLowerCase().contains('pos') ||
              printerName.toLowerCase().contains('receipt')) {
            printerNames.add(printerName);
            print("✅ Printer qo'shildi: $printerName");
          }
        }
      }

      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
      calloc.free(pPrinterEnum);

      print("🖨️ Umumiy mos printerlar: ${printerNames.length}");
      return printerNames;
    } catch (e) {
      print("❌ Printerlarni olishda xatolik: $e");
      return [];
    }
  }

  Future<ApiResponse<bool>> printOrderReceipt(OrderModel order) async {
    print("🖨️ Chek chop etish boshlandi: ${order.orderNumber}");

    try {
      final printers = await getConnectedPrinters();
      if (printers.isEmpty) {
        print("❌ Hech qanday printer topilmadi");

        // Fallback: Default printerlarni sinash
        final defaultPrinters = [
          'POS-58',
          'POS-80',
          'Generic / Text Only',
          'Thermal Printer',
        ];
        for (String printerName in defaultPrinters) {
          try {
            final result = await _printToSpecificPrinter(order, printerName);
            if (result.success) {
              return result;
            }
          } catch (e) {
            print("❌ $printerName bilan chop etishda xatolik: $e");
            continue;
          }
        }

        return ApiResponse(
          success: false,
          message: 'Hech qanday printer topilmadi yoki ishlamayapti',
        );
      }

      // Birinchi mavjud printer bilan sinash
      for (String printerName in printers) {
        try {
          final result = await _printToSpecificPrinter(order, printerName);
          if (result.success) {
            return result;
          }
        } catch (e) {
          print("❌ $printerName bilan chop etishda xatolik: $e");
          continue;
        }
      }

      return ApiResponse(
        success: false,
        message: 'Barcha printerlar bilan urinish muvaffaqiyatsiz tugadi',
      );
    } catch (e) {
      print("❌ Umumiy xatolik: $e");
      return ApiResponse(success: false, message: 'Chop etishda xatolik: $e');
    }
  }

  Future<ApiResponse<bool>> _printToSpecificPrinter(
      OrderModel order,
      String printerName,
      ) async {
    final hPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();

    docInfo.ref.pDocName = TEXT('Restaurant Order Receipt');
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = TEXT('RAW');

    try {
      print("🖨️ Printer ochilayotgan: $printerName");
      final openResult = OpenPrinter(TEXT(printerName), hPrinter, nullptr);
      if (openResult == 0) {
        final error = GetLastError();
        print("❌ Printerni ochishda xatolik: $error");
        return ApiResponse(
          success: false,
          message: 'Printerni ochishda xatolik: $printerName',
        );
      }

      print("📄 Print job boshlanayotgan...");
      final jobId = StartDocPrinter(hPrinter.value, 1, docInfo.cast());
      if (jobId == 0) {
        final error = GetLastError();
        print("❌ Print job xatolik: $error");
        ClosePrinter(hPrinter.value);
        return ApiResponse(success: false, message: 'Print Job xatolik');
      }

      final pageResult = StartPagePrinter(hPrinter.value);
      if (pageResult == 0) {
        final error = GetLastError();
        print("❌ Sahifa boshlanishida xatolik: $error");
      }

      // Chek ma'lumotlarini tayyorlash
      final escPosData = await _buildReceiptData(order);
      print("📋 Chek ma'lumotlari tayyor: ${escPosData.length} bayt");

      final bytesPointer = calloc<Uint8>(escPosData.length);
      final bytesList = bytesPointer.asTypedList(escPosData.length);
      bytesList.setAll(0, escPosData);

      final bytesWritten = calloc<DWORD>();
      final success = WritePrinter(
        hPrinter.value,
        bytesPointer,
        escPosData.length,
        bytesWritten,
      );

      print("📝 Yozildi: ${bytesWritten.value} / ${escPosData.length} bayt");

      EndPagePrinter(hPrinter.value);
      EndDocPrinter(hPrinter.value);
      ClosePrinter(hPrinter.value);

      calloc.free(bytesPointer);
      calloc.free(bytesWritten);
      calloc.free(hPrinter);
      calloc.free(docInfo);

      if (success == 0) {
        final error = GetLastError();
        print('❌ WritePrinter xatolik: $error');
        return ApiResponse(
          success: false,
          message: 'Ma\'lumot yuborishda xatolik',
        );
      } else {
        print('✅ Chek muvaffaqiyatli chop etildi: $printerName');
        return ApiResponse(
          success: true,
          data: true,
          message: 'Chek muvaffaqiyatli chop etildi',
        );
      }
    } catch (e) {
      print('❌ Chop etishda xatolik: $e');
      try {
        ClosePrinter(hPrinter.value);
        calloc.free(hPrinter);
        calloc.free(docInfo);
      } catch (_) {}

      return ApiResponse(success: false, message: 'Chop etishda xatolik: $e');
    }
  }

  Future<List<int>> loadLogoBytes() async {
    try {
      ByteData byteData = await rootBundle.load('assets/rasm/sara.png');
      final bytes = byteData.buffer.asUint8List();
      final image = img.decodeImage(bytes)!;

      // Logoni avvalgi o‘lchamiga qaytardik (512 px)
      final resized = img.copyResize(image, width: 512);
      final width = resized.width;
      final height = resized.height;
      final alignedWidth = (width + 7) ~/ 8 * 8;

      List<int> escPosLogo = [];
      escPosLogo.addAll([0x1D, 0x76, 0x30, 0x00]);
      escPosLogo.addAll([
        (alignedWidth ~/ 8) & 0xFF,
        ((alignedWidth ~/ 8) >> 8) & 0xFF,
        height & 0xFF,
        (height >> 8) & 0xFF,
      ]);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < alignedWidth; x += 8) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            int pixelX = x + bit;
            if (pixelX < width) {
              int pixel = resized.getPixel(pixelX, y);
              int luminance = img.getLuminance(pixel);
              if (luminance < 128) {
                byte |= (1 << (7 - bit));
              }
            }
          }
          escPosLogo.add(byte);
        }
      }

      print("🖼️ Logo yuklandi: ${width}x${height}");
      return escPosLogo;
    } catch (e) {
      print('❌ Logo yuklashda xato: $e');
      return [];
    }
  }

  Future<List<int>> _buildReceiptData(OrderModel order) async {
    final logoBytes = await loadLogoBytes();

    List<int> centeredLogo = [];
    if (logoBytes.isNotEmpty) {
      centeredLogo.addAll([0x1B, 0x61, 0x01]); // Markazga tekislash
      centeredLogo.addAll(logoBytes);
      centeredLogo.addAll([0x1B, 0x61, 0x00]); // Tekislashni tiklash
    }

    final now = DateTime.now();
    final printDateTime = DateFormat('dd.MM.yyyy HH:mm').format(now);

    return <int>[
      0x1B, 0x40, // Printer init
      // LOGO (512px, markazda)
      ...centeredLogo,
      // Logo va matn orasida bo'sh joy yo'q
      ...centerText("Namangan shahri, Namangan tumani"),
      ...centerText("Tel: +998 99 003 09 80"),
      ...centerText("----------------------------------"),

      // BUYURTMA CHEKI (katta va qalin shrift)
      0x1B, 0x21, 0x20, // Katta shrift
      0x1B, 0x45, 0x01, // Qalin shrift
      ...centerText("BUYURTMA CHEKI"),
      0x1B, 0x45, 0x00, // Qalin shriftni o'chirish
      0x1B, 0x21, 0x00, // Oddiy shriftga qaytish
      0x0A, // Bo'sh qator
      // Sana va vaqt
      ...centerText(printDateTime),
      ...centerText("----------------------------------"),
      0x1B, 0x45, 0x01, // Qalin shrift
      ...leftAlignText(
        "       Buyurtma: ${order.orderNumber}",
      ), // 4 ta bo'shlik
      ...leftAlignText("       Stol: ${order.tableNumber}"), // 4 ta bo'shlik
      ...leftAlignText(
        "       Ofitsiant: ${order.waiterName}",
      ), // 4 ta bo'shlik
      0x1B, 0x45, 0x00, // Qalin shriftni o'chirish
      ...centerText("----------------------------------"),

      // MAHSULOTLAR SARLAVHASI
      0x1B, 0x21, 0x10, // O'rta shrift
      0x1B, 0x45, 0x01, // Qalin shrift
      ...centerText("MAHSULOTLAR"),
      0x1B, 0x45, 0x00, // Qalin shriftni o'chirish
      0x1B, 0x21, 0x00, // Oddiy shrift
      ...centerText("----------------------------------"),

      // Mahsulotlar ro'yxati (markazda)
      ...buildItemsList(order.items),

      ...centerText("----------------------------------"),

      // Hisob-kitob
      0x1B, 0x21, 0x00, // Oddiy shrift
      ...centerText("Mahsulotlar: ${formatNumber(order.subtotal)} so'm"),
      ...centerText("Xizmat haqi (${order.percentage}%): ${formatNumber(order.serviceAmount)} so'm"
      ),      0x0A, // Xizmat haqi va jami o'rtasida bo'shliq
      0x0A, // Qo'shimcha bo'shliq
      // Yakuniy summa (katta va qalin)
      0x1B, 0x21, 0x20, // Katta shrift
      0x1B, 0x45, 0x01, // Qalin shrift
      ...centerText("JAMI: ${formatNumber(order.finalTotal)} so'm"),
      0x1B, 0x45, 0x00, // Qalin shriftni o'chirish
      0x1B, 0x21, 0x00, // Oddiy shrift
      ...centerText("----------------------------------"),

      // Rahmat xabari
      0x1B, 0x21, 0x20, // Katta shrift
      0x1B, 0x45, 0x01, // Qalin shrift
      ...centerText("TASHRIFINGIZ UCHUN"),
      ...centerText("RAHMAT!"),
      0x1B, 0x45, 0x00, // Qalin shriftni o'chirish
      0x1B, 0x21, 0x00, // Oddiy shrift
      0x0A, // Bo'sh qator
      0x0A, // Bo'sh qator
      // Chekni kesish
      0x1B, 0x64, 0x06, // 6 ta bo'sh qator
      0x1D, 0x56, 0x00, // Kesish
    ];
  }

  List<int> buildItemsList(List<OrderItem> items) {
    List<int> result = [];
    int itemNum = 1;

    for (var item in items) {
      // Har bir mahsulot uchun
      final namePart = '$itemNum. ${item.name}';
      final qtyTotal = '${item.quantity}x  ${formatNumber(item.total)}';

      // Markazlash uchun umumiy uzunlikni hisoblash
      const int lineLength = 32; // Chek kengligi 32 belgiga moslashtirildi
      String line = namePart;

      // Bo'sh joylar sonini hisoblash
      int spaceCount =
          lineLength -
              utf8.encode(namePart).length -
              utf8.encode(qtyTotal).length;
      if (spaceCount < 1) spaceCount = 1;

      line += ' ' * spaceCount + qtyTotal;

      // Markazlash uchun
      result.addAll(centerText(line));

      // Har bir mahsulotdan keyin bo'shliq
      result.add(0x0A);
      itemNum++;
    }
    return result;
  }

  List<int> centerText(String text) {
    List<int> result = [];
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) {
        result.addAll([0x1B, 0x61, 0x01]); // Markazga tekislash
        result.addAll(utf8.encode(line));
        result.add(0x0A); // Yangi qator
        result.addAll([0x1B, 0x61, 0x00]); // Tekislashni tiklash
      }
    }
    return result;
  }

  List<int> leftAlignText(String text) {
    List<int> result = [];
    result.addAll([0x1B, 0x61, 0x00]); // Chapga tekislash
    result.addAll(utf8.encode(text));
    result.add(0x0A); // Yangi qator
    return result;
  }

  String formatNumber(dynamic number) {
    final numStr = number.toString().split('.');
    return numStr[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
    );
  }
}

// Order Table Page
class OrderTablePage extends StatefulWidget {
  final String waiterName;
  final String token;
  const OrderTablePage({required this.waiterName, required this.token});

  @override
  _OrderTablePageState createState() => _OrderTablePageState();
}

class _OrderTablePageState extends State<OrderTablePage> {
  final String baseUrl = "${ApiConfig.baseUrl}";
  String? _token;
  static const String _cacheKey = 'pending_orders_cache';
  static const String _cacheTimestampKey = 'pending_orders_timestamp';
  static const int _cacheDurationMinutes = 2;

  Future<void> _initializeToken() async {
    try {
      // ❗ Avval KassirTokenManager dan tokenni olish
      _token = KassirTokenManager().getKassirToken();

      if (_token != null && _token!.isNotEmpty) {
        print(
          "🔑 Token KassirTokenManager dan olindi: ${_token!.substring(0, 20)}...",
        );
        return;
      }

      // KassirTokenManager da yo'q bo'lsa, SharedPreferences dan olish
      _token = await AuthServices.getTokens();
      print(
        "🔑 Mavjud token SharedPreferences dan: ${_token?.substring(0, 20) ?? 'Yo\'q'}...",
      );

      if (_token == null || _token!.isEmpty) {
        print("🔄 Yangi token olinyapti...");
        final result = await AuthServices.loginAndPrintToken();
        if (result.success) {
          _token = result.data;
          print("✅ Yangi token olindi");
        } else {
          throw Exception(result.message);
        }
      }
    } catch (e) {
      print("❌ Token olishda xatolik: $e");
      throw Exception('Token olishda xatolik: $e');
    }
  }

  Future<ApiResponse<List<OrderModel>>> getPendingPayments({
    DateTime? startDate,
    DateTime? endDate,
    String? waiterName,
    bool forceRefresh = false,
  }) async {
    print("📥 Buyurtmalar so'ralyapti...");
    print("👨‍💼 Ofitsiant: $waiterName");

    await _initializeToken();

    if (_token == null || _token!.isEmpty) {
      return ApiResponse(success: false, message: 'Token topilmadi');
    }

    // Keshdan tekshirish
    if (!forceRefresh) {
      final cachedOrders = await _getFromCache();
      if (cachedOrders != null) {
        List<OrderModel> filteredOrders = _applyFilters(
          cachedOrders,
          startDate,
          endDate,
          waiterName,
        );
        return ApiResponse(
          success: true,
          data: filteredOrders,
          message:
          'Ma\'lumotlar keshdan yuklandi (${filteredOrders.length} ta)',
        );
      }
    }

    // Serverdan ma'lumot olish
    final url = Uri.parse('$baseUrl/orders/pending-payments');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      print("📡 Javob kodi: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['pending_orders'] != null) {
          List<OrderModel> allOrders =
          (data['pending_orders'] as List)
              .map((order) => OrderModel.fromJson(order))
              .toList();

          List<OrderModel> filteredOrders = _applyFilters(
            allOrders,
            startDate,
            endDate,
            waiterName,
          );

          await _saveToCache(allOrders);

          print("✅ ${filteredOrders.length} ta buyurtma topildi");
          return ApiResponse(
            success: true,
            data: filteredOrders,
            message:
            'Ma\'lumotlar serverdan yuklandi (${filteredOrders.length} ta)',
          );
        } else {
          return ApiResponse(
            success: true,
            data: [],
            message: 'Ma\'lumotlar topilmadi',
          );
        }
      } else if (response.statusCode == 401) {
        // Token muddati tugagan
        print("🔄 Token muddati tugagan, yangi token olinayotgan...");
        KassirTokenManager().clearKassirToken(); // Eski tokenni tozalash

        final loginResult = await AuthServices.loginAndPrintToken();
        if (loginResult.success) {
          _token = loginResult.data;
          return await getPendingPayments(
            startDate: startDate,
            endDate: endDate,
            waiterName: waiterName,
            forceRefresh: true,
          );
        } else {
          return ApiResponse(success: false, message: 'Avtorizatsiya xatoligi');
        }
      } else {
        return ApiResponse(
          success: false,
          message: 'Server xatosi: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("❌ API xatoligi: $e");
      return ApiResponse(success: false, message: 'API xatoligi: $e');
    }
  }

  Future<ApiResponse<bool>> updateReceiptPrinted(String orderId) async {
    await _initializeToken();

    if (_token == null || _token!.isEmpty) {
      print('❌ Token topilmadi');
      return ApiResponse(success: false, message: 'Token topilmadi');
    }

    if (orderId.isEmpty) {
      print('⚠️ ID bo\'sh, server update o\'tkazib yuborildi');
      await _clearCache();
      return ApiResponse(
        success: true,
        data: true,
        message: 'Local yangilandi',
      );
    }

    final url = Uri.parse('$baseUrl/orders/$orderId');
    print('📝 Chek holati yangilanayotgan: $orderId');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'receiptPrinted': true}),
      );

      if (response.statusCode == 200) {
        await _clearCache();
        print('✅ Chek holati yangilandi');
        return ApiResponse(
          success: true,
          data: true,
          message: 'Chek holati yangilandi',
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Chek holatini yangilashda xatolik: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'API xatoligi: $e');
    }
  }

  // Cache methodlari (o'zgarishsiz)
  Future<void> _saveToCache(List<OrderModel> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson =
      orders.map((order) => jsonEncode(order.toJson())).toList();
      await prefs.setString(_cacheKey, jsonEncode(ordersJson));
      await prefs.setString(
        _cacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
      print("💾 ${orders.length} ta buyurtma keshga saqlandi");
    } catch (e) {
      print("❌ Keshga saqlashda xatolik: $e");
    }
  }

  Future<List<OrderModel>?> _getFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      final timestamp = prefs.getString(_cacheTimestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.tryParse(timestamp);
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime).inMinutes <
                _cacheDurationMinutes) {
          final ordersJson = jsonDecode(cachedData) as List;
          final orders =
          ordersJson
              .map((json) => OrderModel.fromJson(jsonDecode(json)))
              .toList();
          print("📦 Keshdan ${orders.length} ta buyurtma yuklandi");
          return orders;
        }
      }
      return null;
    } catch (e) {
      print("❌ Keshdan o'qishda xatolik: $e");
      return null;
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      print("🗑️ Kesh tozalandi");
    } catch (e) {
      print("❌ Keshni tozalashda xatolik: $e");
    }
  }

  List<OrderModel> _applyFilters(
      List<OrderModel> orders,
      DateTime? startDate,
      DateTime? endDate,
      String? waiterName,
      ) {
    List<OrderModel> filteredOrders = orders;

    if (waiterName != null &&
        waiterName.isNotEmpty &&
        waiterName != 'Barcha ofitsiantlar') {
      filteredOrders =
          filteredOrders
              .where(
                (order) => order.waiterName.toLowerCase().contains(
              waiterName.toLowerCase(),
            ),
          )
              .toList();
    }

    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      filteredOrders =
          filteredOrders.where((order) {
            return (order.createdAt.isAfter(
              start.subtract(Duration(seconds: 1)),
            ) &&
                order.createdAt.isBefore(end.add(Duration(seconds: 1)))) ||
                (order.completedAt != null &&
                    order.completedAt!.isAfter(
                      start.subtract(Duration(seconds: 1)),
                    ) &&
                    order.completedAt!.isBefore(end.add(Duration(seconds: 1))));
          }).toList();
    }

    return filteredOrders;
  }

  final UsbPrinterService printerService = UsbPrinterService();

  DateTime? startDate;
  DateTime? endDate;
  List<OrderModel> allOrders = [];
  List<OrderModel> filteredOrders = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default bugungi sana filtri
    final today = DateTime.now();
    startDate = DateTime(today.year, today.month, today.day);
    endDate = today;
    _loadOrders();
  }

  Future<void> _loadOrders({bool forceRefresh = false}) async {
    setState(() => isLoading = true);

    try {
      final result = await getPendingPayments(
        startDate: startDate,
        endDate: endDate,
        waiterName: widget.waiterName,
        forceRefresh: forceRefresh,
      );

      if (result.success && result.data != null) {
        // ❗ SharedPreferences’dan chop qilingan orderlarni tekshirish
        List<OrderModel> updatedOrders = [];
        for (var order in result.data!) {
          bool printed = await _isOrderPrinted(order.id);
          updatedOrders.add(
            OrderModel(
              id: order.id,
              orderNumber: order.orderNumber,
              tableNumber: order.tableNumber,
              waiterName: order.waiterName,
              itemsCount: order.itemsCount,
              subtotal: order.subtotal,
              serviceAmount: order.serviceAmount,
              finalTotal: order.finalTotal,
              status: order.status,
              receiptPrinted: printed || order.receiptPrinted, // ✅ doim tekshiramiz
              createdAt: order.createdAt,
              completedAt: order.completedAt,
              items: order.items, percentage: order.percentage,
            ),
          );
        }

        setState(() {
          isLoading = false;
          allOrders = updatedOrders;
          filteredOrders = updatedOrders;
        });

      } else {
        setState(() {
          isLoading = false;
          allOrders = [];
          filteredOrders = [];
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 30)),
      initialDateRange:
      startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0d5720),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadOrders(forceRefresh: true);
    }
  }

  void _clearDateFilter() {
    final today = DateTime.now();
    setState(() {
      startDate = DateTime(today.year, today.month, today.day);
      endDate = today;
    });
    _loadOrders(forceRefresh: true);
  }

  Future<void> _savePrintedOrder(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> printedOrders = prefs.getStringList("printed_orders") ?? [];
    if (!printedOrders.contains(orderId)) {
      printedOrders.add(orderId);
      await prefs.setStringList("printed_orders", printedOrders);
    }
  }

  Future<bool> _isOrderPrinted(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> printedOrders = prefs.getStringList("printed_orders") ?? [];
    return printedOrders.contains(orderId);
  }


  Future<void> _printOrder(OrderModel order, int index) async {
    try {
      // Loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0d5720)),
              SizedBox(height: 20),
              Text('🖨️ Chek chop etilmoqda...'),
              SizedBox(height: 10),
              Text(
                'Buyurtma: ${order.orderNumber}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      print("🖨️ ${order.orderNumber} chop etish boshlandi");
      final printResult = await printerService.printOrderReceipt(order);
      Navigator.of(context).pop(); // Loading dialogni yopish

      if (printResult.success) {
        print("✅ Chek chop etildi, lokal holat yangilanmoqda...");

        // 🔐 SharedPreferences ga saqlash
        await _savePrintedOrder(order.id);

        // ✅ Lokal ravishda yangilash
        setState(() {
          filteredOrders[index] = OrderModel(
            id: order.id,
            orderNumber: order.orderNumber,
            tableNumber: order.tableNumber,
            waiterName: order.waiterName,
            itemsCount: order.itemsCount,
            subtotal: order.subtotal,
            serviceAmount: order.serviceAmount,
            finalTotal: order.finalTotal,
            status: order.status,
            receiptPrinted: true, // ❗ doim true
            createdAt: order.createdAt,
            completedAt: order.completedAt,
            items: order.items, percentage: order.percentage,
          );
        });

        // 🟢 Xabar chiqish
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✅ Chek muvaffaqiyatli chop etildi!\nBuyurtma: ${order.orderNumber}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // ❌ Agar printResult.success false bo‘lsa
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chek chiqarishda xatolik: ${printResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Loading dialogni yopish
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Kutilmagan xatolik: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;

    // Hisoblarni hisoblash
    final totalService = filteredOrders.fold<double>(
      0,
          (sum, order) => sum + order.serviceAmount,
    );
    final totalAmount = filteredOrders.fold<double>(
      0,
          (sum, order) => sum + order.finalTotal,
    );
    final printedCount =
        filteredOrders.where((order) => order.receiptPrinted).length;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.reply_all_outlined, color: Colors.white, size: 30),
          tooltip: 'Qaytish',
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ofitsiant: ${widget.waiterName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Xizmat haqi: ${printerService.formatNumber(totalService)} so\'m',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadOrders(forceRefresh: true),
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yangilash',
          ),
          IconButton(
            onPressed: _selectDateRange,
            icon: Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Sana tanlash',
          ),
          IconButton(
            padding: EdgeInsets.only(right: 20, left: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => OrderTablePage1(
                    waiterName: widget.waiterName,
                    token: widget.token,
                  ),
                ),
              );
            },
            icon: Icon(Icons.save, color: Colors.white, size: 40),
            tooltip: 'Hamma buyurtmalar',
          ),
        ],
      ),

      body: Column(
        children: [
          // Statistika paneli
          Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (startDate != null && endDate != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF0d5720).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: Color(0xFF0d5720),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${DateFormat('dd.MM.yy').format(startDate!)} - ${DateFormat('dd.MM.yy').format(endDate!)}',
                          style: TextStyle(
                            color: Color(0xFF0d5720),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 6),
                        GestureDetector(
                          onTap: _clearDateFilter,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Color(0xFF0d5720),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Buyurtmalar',
                        '${filteredOrders.length}',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Tugagan',
                        '$printedCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Jami',
                        '${printerService.formatNumber(totalAmount)}',
                        Icons.money,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Jadval - Ekranning qolgan qismini to'liq egallaydi
          Expanded(
            child:
            isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0d5720)),
                  SizedBox(height: 16),
                  Text('Ma\'lumotlar yuklanmoqda...'),
                ],
              ),
            )
                : filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ma\'lumotlar topilmadi',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Boshqa sana tanlashga harakat qiling',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : _buildOrdersTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF0d5720).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Table(
                columnWidths: _getColumnWidths(),
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('№'),
                      _buildTableHeaderCell('Sana/Vaqt'),
                      _buildTableHeaderCell('Stol'),
                      _buildTableHeaderCell('Birligi'),
                      _buildTableHeaderCell('Jami'),
                      _buildTableHeaderCell('Xizmat'),
                      _buildTableHeaderCell('Yakuniy'),
                      _buildTableHeaderCell('Chop etish'),
                    ],
                  ),
                ],
              ),
            ),

            // Body - Scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: _getColumnWidths(),
                  children: List<TableRow>.generate(filteredOrders.length, (
                      index,
                      ) {
                    final order = filteredOrders[index];
                    return TableRow(
                      decoration: BoxDecoration(
                        color:
                        order.receiptPrinted
                            ? Colors.green.withOpacity(0.05)
                            : (index % 2 == 0
                            ? Colors.grey.withOpacity(0.02)
                            : Colors.white),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                      ),
                      children: [
                        _buildTableDataCell(
                          _buildOrderNumberCell(order.orderNumber),
                        ),
                        _buildTableDataCell(_buildDateCell(order.createdAt)),
                        _buildTableDataCell(_buildTableCell(order.tableNumber)),
                        _buildTableDataCell(
                          _buildItemsCell(order.itemsCount.toString()),
                        ),
                        _buildTableDataCell(_buildAmountCell(order.subtotal)),
                        _buildTableDataCell(
                          _buildServiceCell(order.serviceAmount),
                        ),
                        _buildTableDataCell(_buildFinalCell(order.finalTotal)),
                        _buildTableDataCell(_buildPrintButton(order, index)),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<int, TableColumnWidth> _getColumnWidths() {
    return {
      0: FlexColumnWidth(0.8), // №
      1: FlexColumnWidth(1.4), // Sana/Vaqt
      2: FlexColumnWidth(0.8), // Stol
      3: FlexColumnWidth(0.7), // Dona
      4: FlexColumnWidth(1.2), // Jami
      5: FlexColumnWidth(1.1), // Xizmat
      6: FlexColumnWidth(1.3), // Yakuniy
      7: FlexColumnWidth(1.6), // Chop etish
    };
  }

  Widget _buildTableHeaderCell(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0d5720),
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableDataCell(Widget child) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      alignment: Alignment.center,
      constraints: BoxConstraints(minHeight: 50),
      child: child,
    );
  }

  Widget _buildColumnHeader(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0d5720),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildOrderNumberCell(String orderNumber) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF0d5720).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        orderNumber,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0d5720),
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDateCell(DateTime date) {
    return Container(
      width: 60, // Widget kengligi, ekranga full emas
      height: 40, // Widget balandligi, ekranga full emas
      alignment: Alignment.center, // Markazga tushadi
      padding: EdgeInsets.all(4), // Ichki bo'shliq
      decoration: BoxDecoration(
        color: Colors.white, // Orqa fon, xohlaysiz o'zgartiring
        borderRadius: BorderRadius.circular(6), // Biroz yumaloq
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd.MM.yy').format(date),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          ),
          SizedBox(height: 2),
          Text(
            DateFormat('HH:mm').format(date),
            style: TextStyle(color: Colors.grey[600], fontSize: 9),
          ),
        ],
      ),
    );
  }


  Widget _buildTableCell(String tableNumber) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tableNumber,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildItemsCell(String count) {
    return Text(
      count,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAmountCell(double amount) {
    return Text(
      '${printerService.formatNumber(amount)}',
      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildServiceCell(double amount) {
    return Text(
      '${printerService.formatNumber(amount)}',
      style: TextStyle(
        color: Colors.orange[700],
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFinalCell(double amount) {
    return Text(
      '${printerService.formatNumber(amount)}',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF0d5720),
        fontSize: 10,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPrintButton(OrderModel order, int index) {
    return Container(
      alignment: Alignment.center,
      child: SizedBox(
        width: 80, // Kichikroq width
        height: 32,
        child: ElevatedButton(
          onPressed:
          order.receiptPrinted ? null : () => _printOrder(order, index),
          style: ElevatedButton.styleFrom(
            backgroundColor:
            order.receiptPrinted ? Colors.grey[300] : Color(0xFF0d5720),
            foregroundColor:
            order.receiptPrinted ? Colors.grey[600] : Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: order.receiptPrinted ? 0 : 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                order.receiptPrinted ? Icons.check_circle : Icons.print,
                size: 12,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.receiptPrinted ? 'Tugagan' : 'Chop et',
                  style: TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
