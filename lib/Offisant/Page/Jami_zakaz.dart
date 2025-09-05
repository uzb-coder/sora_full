import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:sora/Global/Api_global.dart';
import 'package:win32/win32.dart';

class OrderResponse {
  final bool success;
  final List<Order> orders;
  final int totalCount;
  final int totalAmount;
  final PaymentStats paymentStats;
  final String timestamp;

  OrderResponse({
    required this.success,
    required this.orders,
    required this.totalCount,
    required this.totalAmount,
    required this.paymentStats,
    required this.timestamp,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json['success'] ?? false,
      orders: (json['orders'] as List<dynamic>?)
          ?.map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalCount: json['total_count'] ?? 0,
      totalAmount: json['total_amount'] ?? 0,
      paymentStats: PaymentStats.fromJson(json['payment_stats'] ?? {}),
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final String waiterName;
  final int itemsCount;
  final int subtotal;
  final int serviceAmount;
  final int taxAmount;
  final int finalTotal;
  final String completedAt;
  final String paidAt;
  final String status;
  final bool receiptPrinted;
  final String paymentMethod;
  final String paidBy;
  final String completedBy;
  final List<OrderItem> items;
  final String orderDate;

  Order({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.waiterName,
    required this.itemsCount,
    required this.subtotal,
    required this.serviceAmount,
    required this.taxAmount,
    required this.finalTotal,
    required this.completedAt,
    required this.paidAt,
    required this.status,
    required this.receiptPrinted,
    required this.paymentMethod,
    required this.paidBy,
    required this.completedBy,
    required this.items,
    required this.orderDate,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      tableNumber: json['tableNumber'] ?? '',
      waiterName: json['waiterName'] ?? '',
      itemsCount: json['itemsCount'] ?? 0,
      subtotal: json['subtotal'] ?? 0,
      serviceAmount: json['serviceAmount'] ?? 0,
      taxAmount: json['taxAmount'] ?? 0,
      finalTotal: json['finalTotal'] ?? 0,
      completedAt: json['completedAt'] ?? '',
      paidAt: json['paidAt'] ?? '',
      status: json['status'] ?? '',
      receiptPrinted: json['receiptPrinted'] ?? false,
      paymentMethod: json['paymentMethod'] ?? '',
      paidBy: json['paidBy'] ?? '',
      completedBy: json['completedBy'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      orderDate: json['order_date'] ?? '',
    );
  }
}

class OrderItem {
  final String foodId;
  final String name;
  final int price;
  final int quantity;
  final String categoryName;
  final String? printerId;

  OrderItem({
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.categoryName,
    this.printerId,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      foodId: json['food_id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      quantity: json['quantity'] ?? 0,
      categoryName: json['category_name'] ?? '',
      printerId: json['printer_id'],
    );
  }
}

class PaymentStats {
  final Map<String, int> byMethod;
  final int totalCash;
  final int totalCard;
  final int totalClick;
  final int totalMixed;

  PaymentStats({
    required this.byMethod,
    required this.totalCash,
    required this.totalCard,
    required this.totalClick,
    required this.totalMixed,
  });

  factory PaymentStats.fromJson(Map<String, dynamic> json) {
    return PaymentStats(
      byMethod: (json['by_method'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as int),
      ) ??
          {},
      totalCash: json['total_cash'] ?? 0,
      totalCard: json['total_card'] ?? 0,
      totalClick: json['total_click'] ?? 0,
      totalMixed: json['total_mixed'] ?? 0,
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;

  ApiResponse({required this.success, this.data, required this.message});
}

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
          final printerName = printerInfo.elementAt(i).ref.pPrinterName.toDartString();
          final portName = printerInfo.elementAt(i).ref.pPortName.toDartString();

          print("🖨️ Printer: $printerName, Port: $portName");

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

  Future<ApiResponse<bool>> printOrderReceipt(Order order) async {
    print("🖨️ Chek chop etish boshlandi: ${order.orderNumber}");

    try {
      final printers = await getConnectedPrinters();
      if (printers.isEmpty) {
        print("❌ Hech qanday printer topilmadi");
        final defaultPrinters = [
          'POS-58',
          'POS-80',
          'Generic / Text Only',
          'Thermal Printer',
        ];
        for (String printerName in defaultPrinters) {
          try {
            final result = await _printToSpecificPrinter(order, printerName);
            if (result.success) return result;
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

      for (String printerName in printers) {
        try {
          final result = await _printToSpecificPrinter(order, printerName);
          if (result.success) return result;
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

  Future<ApiResponse<bool>> _printToSpecificPrinter(Order order, String printerName) async {
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

      final escPosData = await _buildReceiptData(order);
      print("📋 Chek ma'lumotlari tayyor: ${escPosData.length} bayt");

      final bytesPointer = calloc<Uint8>(escPosData.length);
      final bytesList = bytesPointer.asTypedList(escPosData.length);
      bytesList.setAll(0, escPosData);

      final bytesWritten = calloc<DWORD>();
      final success = WritePrinter(hPrinter.value, bytesPointer, escPosData.length, bytesWritten);

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
        return ApiResponse(success: false, message: 'Ma\'lumot yuborishda xatolik');
      } else {
        print('✅ Chek muvaffaqiyatli chop etildi: $printerName');
        return ApiResponse(success: true, data: true, message: 'Chek muvaffaqiyatli chop etildi');
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
              if (luminance < 128) byte |= (1 << (7 - bit));
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

  Future<List<int>> _buildReceiptData(Order order) async {
    final logoBytes = await loadLogoBytes();

    List<int> centeredLogo = [];
    if (logoBytes.isNotEmpty) {
      centeredLogo.addAll([0x1B, 0x61, 0x01]);
      centeredLogo.addAll(logoBytes);
      centeredLogo.addAll([0x1B, 0x61, 0x00]);
    }

    final now = DateTime.now();
    final printDateTime = DateFormat('dd.MM.yyyy HH:mm').format(now);

    return <int>[
      0x1B, 0x40, // Printer init
      ...centeredLogo,
      ...centerText("Namangan shahri, Namangan tumani"),
      ...centerText("Tel: +998 90 123 45 67"),
      ...centerText("----------------------------------"),
      0x1B, 0x21, 0x20,
      0x1B, 0x45, 0x01,
      ...centerText("BUYURTMA CHEKI"),
      0x1B, 0x45, 0x00,
      0x1B, 0x21, 0x00,
      0x0A,
      ...centerText(printDateTime),
      ...centerText("----------------------------------"),
      0x1B, 0x45, 0x01,
      ...leftAlignText("       Buyurtma: ${order.orderNumber}"),
      ...leftAlignText("       Stol: ${order.tableNumber}"),
      ...leftAlignText("       Ofitsiant: ${order.waiterName}"),
      0x1B, 0x45, 0x00,
      ...centerText("----------------------------------"),
      0x1B, 0x21, 0x10,
      0x1B, 0x45, 0x01,
      ...centerText("MAHSULOTLAR"),
      0x1B, 0x45, 0x00,
      0x1B, 0x21, 0x00,
      ...centerText("----------------------------------"),
      ...buildItemsList(order.items),
      ...centerText("----------------------------------"),
      0x1B, 0x21, 0x00,
      ...centerText("Mahsulotlar: ${formatNumber(order.subtotal)} so'm"),
      ...centerText("Xizmat haqi: ${formatNumber(order.serviceAmount)} so'm"),
      0x0A,
      0x0A,
      0x1B, 0x21, 0x20,
      0x1B, 0x45, 0x01,
      ...centerText("JAMI: ${formatNumber(order.finalTotal)} so'm"),
      0x1B, 0x45, 0x00,
      0x1B, 0x21, 0x00,
      ...centerText("----------------------------------"),
      0x1B, 0x21, 0x20,
      0x1B, 0x45, 0x01,
      ...centerText("TASHRIFINGIZ UCHUN"),
      ...centerText("RAHMAT!"),
      0x1B, 0x45, 0x00,
      0x1B, 0x21, 0x00,
      0x0A,
      0x0A,
      0x1B, 0x64, 0x06,
      0x1D, 0x56, 0x00,
    ];
  }

  List<int> buildItemsList(List<OrderItem> items) {
    List<int> result = [];
    int itemNum = 1;

    for (var item in items) {
      final namePart = '$itemNum. ${item.name}';
      final qtyTotal = '${item.quantity}x  ${formatNumber(item.price * item.quantity)}';

      const int lineLength = 32;
      String line = namePart;
      int spaceCount = lineLength - utf8.encode(namePart).length - utf8.encode(qtyTotal).length;
      if (spaceCount < 1) spaceCount = 1;

      line += ' ' * spaceCount + qtyTotal;
      result.addAll(centerText(line));
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
        result.addAll([0x1B, 0x61, 0x01]);
        result.addAll(utf8.encode(line));
        result.add(0x0A);
        result.addAll([0x1B, 0x61, 0x00]);
      }
    }
    return result;
  }

  List<int> leftAlignText(String text) {
    List<int> result = [];
    result.addAll([0x1B, 0x61, 0x00]);
    result.addAll(utf8.encode(text));
    result.add(0x0A);
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

class OrderTablePage1 extends StatefulWidget {
  final String waiterName;
  final String token;

  const OrderTablePage1({required this.waiterName, required this.token});

  @override
  _OrderTablePageState createState() => _OrderTablePageState();
}

class _OrderTablePageState extends State<OrderTablePage1> {
  OrderResponse? orderResponse;
  String responseText = "Ma'lumot yuklanmadi";
  final UsbPrinterService printerService = UsbPrinterService();
  List<Order> filteredOrders = [];
  bool isLoading = false;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _checkAndLoadDailyData();
  }

  void _checkAndLoadDailyData() {
    setState(() {
      filteredOrders = [];
      responseText = "${DateFormat('dd.MM.yyyy').format(selectedDate ?? DateTime.now())} uchun ma'lumotlar yuklanmoqda...";
    });
    fetchZakaz();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0d5720),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        responseText = "${DateFormat('dd.MM.yyyy').format(picked)} uchun ma'lumotlar yuklanmoqda...";
      });
      fetchZakaz(forceRefresh: true);
    }
  }

  Future<void> fetchZakaz({bool forceRefresh = false}) async {
    setState(() => isLoading = true);
    try {
      var url = Uri.parse("${ApiConfig.baseUrl}/orders/completed");

      var res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          orderResponse = OrderResponse.fromJson(data);
          _filterOrdersByDate();
          responseText = filteredOrders.isEmpty
              ? "${DateFormat('dd.MM.yyyy').format(selectedDate ?? DateTime.now())} da sizning buyurtmalaringiz yo'q"
              : "Ma'lumotlar muvaffaqiyatli yuklandi";
        });
      } else {
        setState(() {
          responseText = "Xato: ${res.statusCode}\n${res.body}";
        });
      }
    } catch (e) {
      setState(() {
        responseText = "Xatolik: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterOrdersByDate() {
    if (orderResponse == null) return;

    filteredOrders = orderResponse!.orders.where((order) {
      bool waiterMatch = order.waiterName.toLowerCase() == widget.waiterName.toLowerCase();
      bool dateMatch = false;

      DateTime? paidDate = DateTime.tryParse(order.paidAt);
      if (paidDate != null && selectedDate != null) {
        dateMatch = paidDate.year == selectedDate!.year &&
            paidDate.month == selectedDate!.month &&
            paidDate.day == selectedDate!.day;
      }

      return waiterMatch && dateMatch;
    }).toList();
  }

  Future<void> _printOrder(Order order, int index) async {
    try {
      final result = await printerService.printOrderReceipt(order);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xatolik: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalService = filteredOrders.fold(0, (sum, order) => sum + order.serviceAmount);
    final displayDate = DateFormat('dd.MM.yyyy').format(selectedDate ?? DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        title: Column(
          children: [
            Text(
              "Ofitsiant: ${widget.waiterName}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "${displayDate} xizmat haqi: ${_formatNumber(totalService)} so'm",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              onPressed: () => _selectDate(context),
              icon: Icon(Icons.calendar_today_rounded, color: Colors.white, size: 24),
              tooltip: 'Sana tanlash',
              splashRadius: 24,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              onPressed: () => fetchZakaz(forceRefresh: true),
              icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
              tooltip: 'Yangilash',
              splashRadius: 24,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0d5720), Color(0xFF1a7a32)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0d5720).withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.today_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  "Sana: $displayDate",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF0d5720),
                    ),
                    SizedBox(height: 16),
                    Text(
                      responseText,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : filteredOrders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      responseText,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : _buildDataTable(),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 8,
              headingRowHeight: 50,
              dataRowHeight: 55,
              headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Color(0xFF0d5720).withOpacity(0.1),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              columns: const [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Buyurtma",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Stol",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Soni",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Narx",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Xizmat",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Jami",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Vaqt",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // DataColumn(
                //   label: Expanded(
                //     child: Text(
                //       "Chop",
                //       style: TextStyle(
                //         fontSize: 13,
                //         fontWeight: FontWeight.bold,
                //         color: Color(0xFF0d5720),
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //   ),
                // ),
              ],
              rows: filteredOrders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final isEven = index % 2 == 0;

                return DataRow(
                  color: MaterialStateColor.resolveWith(
                        (states) => isEven ? Colors.grey.withOpacity(0.05) : Colors.white,
                  ),
                  cells: [
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          order.orderNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0d5720),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF0d5720).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.tableNumber,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0d5720),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "${order.itemsCount}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "${_formatNumber(order.subtotal)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "${_formatNumber(order.serviceAmount)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "${_formatNumber(order.finalTotal)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0d5720),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              order.completedAt.isNotEmpty
                                  ? DateFormat('HH:mm').format(DateTime.parse(order.completedAt))
                                  : "-",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              order.completedAt.isNotEmpty
                                  ? DateFormat('dd.MM').format(DateTime.parse(order.completedAt))
                                  : "-",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // DataCell(
                    //   Container(
                    //     width: double.infinity,
                    //     padding: EdgeInsets.symmetric(vertical: 8),
                    //     child: Center(
                    //       child: Container(
                    //         width: 70,
                    //         height: 32,
                    //         child: ElevatedButton(
                    //           onPressed: order.receiptPrinted ? null : () => _printOrder(order, index),
                    //           style: ElevatedButton.styleFrom(
                    //             backgroundColor: order.receiptPrinted
                    //                 ? Colors.grey[300]
                    //                 : Color(0xFF0d5720),
                    //             foregroundColor: order.receiptPrinted
                    //                 ? Colors.grey[600]
                    //                 : Colors.white,
                    //             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    //             shape: RoundedRectangleBorder(
                    //               borderRadius: BorderRadius.circular(8),
                    //             ),
                    //             elevation: order.receiptPrinted ? 0 : 2,
                    //           ),
                    //           child: Text(
                    //             order.receiptPrinted ? '✓' : 'Chop',
                    //             style: TextStyle(
                    //               fontSize: 11,
                    //               fontWeight: FontWeight.w600,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(dynamic number) {
    final numStr = number.toString().split('.');
    return numStr[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
    );
  }
}
