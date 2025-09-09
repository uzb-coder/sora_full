// lib/core/sync_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../Global/Api_global.dart';
import 'db_helper.dart';


class SyncService {
  /// Umumiy sync orchestrator: create -> items -> cancel -> close -> pay
  static Future<void> syncAll(String token) async {
    // 1) localda yaratilgan buyurtmalarni serverga create qilamiz
    final okCreate = await _syncNewOrders(token);
    if (!okCreate) return;

    // 1.1) server bor, lekin itemlari unsynced bo‘lgan buyurtmalar
    final okItems = await _syncUnsyncedItems(token);
    if (!okItems) return;

    // 1.2) cancel queue (bekor qilingan itemlar)
    final okCancel = await _syncCancelQueue(token);
    if (!okCancel) return;

    // 2) yopilgan buyurtmalar (server_id bo‘lishi shart)
    final okClose = await _syncClosedOrders(token);
    if (!okClose) return;

    // 3) to‘langan buyurtmalar (server_id bo‘lishi shart)
    await _syncPaidOrders(token);
  }

  // -------- 1) CREATE --------
  static Future<bool> _syncNewOrders(String token) async {
    try {
      final orders = await DBHelper.getUnsyncedOrders();
      for (final o in orders) {
        final serverId = (o['server_id'] ?? '').toString();
        if (serverId.isNotEmpty && serverId != 'null') continue; // allaqachon serverda bor

        final localId = o['id'].toString();
        final items = await DBHelper.getOrderItems(localId);

        // BACKEND: /orders/create
        final payload = {
          "table_id": o['table_id'],
          "waiterName": o['waiter_name'],
          "items": items.map((it) => {
            "food_id": it['food_id'],
            "quantity": it['quantity'],
            "price": it['price'],
          }).toList(),
          "totalPrice": o['total_price'],
          // agar kerak bo‘lsa qo‘shimcha maydonlarni bu yerda yuboring
        };

        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/orders/create'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          final data = jsonDecode(resp.body);

          // javobdan server id ni himoyalab ajratamiz
          final serverIdFromBody =
              data['_id'] ??
                  data['order']?['_id'] ??
                  data['data']?['_id'] ??
                  data['id'];

          if (serverIdFromBody != null && serverIdFromBody.toString().isNotEmpty) {
            await DBHelper.updateOrderServerId(localId, serverIdFromBody.toString());
            debugPrint('✅ [SYNC CREATE] local=$localId -> server=$serverIdFromBody');
          } else {
            debugPrint('❓ [SYNC CREATE] $localId: javobda _id topilmadi: ${resp.body}');
            return false;
          }
        } else {
          debugPrint('❌ [SYNC CREATE] $localId -> ${resp.statusCode}: ${resp.body}');
          return false;
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('❌ _syncNewOrders xato: $e\n$st');
      return false;
    }
  }

  // -------- 1.1) ADD ITEMS (order_items.is_synced = 0) --------
  static Future<bool> _syncUnsyncedItems(String token) async {
    try {
      // is_synced=0 bo‘lgan order’larni topamiz
      final uns = await DBHelper.getUnsyncedOrders();
      for (final o in uns) {
        final localId  = o['id'].toString();
        final serverId = (o['server_id'] ?? '').toString();
        if (serverId.isEmpty || serverId == 'null') continue; // hali create bo‘lmagan

        final items = await DBHelper.getOrderItems(localId);
        final unsyncedItems = items.where((it) => (it['is_synced'] ?? 0) == 0).toList();
        if (unsyncedItems.isEmpty) continue;

        final payload = {
          "items": unsyncedItems.map((it) => {
            "food_id": it['food_id'],
            "quantity": it['quantity'],
            "price": it['price'],
          }).toList(),
        };

        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/orders/$serverId/add-items'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await DBHelper.markOrderItemsAsSynced(localId);
          debugPrint('✅ [SYNC ADD-ITEMS] local=$localId -> server=$serverId (${unsyncedItems.length} ta)');
        } else {
          debugPrint('❌ [SYNC ADD-ITEMS] $localId -> ${resp.statusCode}: ${resp.body}');
          return false;
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('❌ _syncUnsyncedItems xato: $e\n$st');
      return false;
    }
  }

  // -------- 1.2) CANCEL QUEUE --------
  static Future<bool> _syncCancelQueue(String token) async {
    try {
      final logs = await DBHelper.getUnsyncedCancelLogs();
      for (final r in logs) {
        final id = r['id'] as int; // queue id
        final orderServerId = (r['order_server_id'] ?? '').toString();
        if (orderServerId.isEmpty || orderServerId == 'null') {
          debugPrint('⏭️ [SYNC CANCEL] skip queue#$id: server_id yo‘q');
          continue;
        }

        final payload = {
          "food_id": r['food_id'],
          "cancel_quantity": r['cancel_quantity'],
          "reason": r['reason'] ?? '',
          "notes": r['notes'] ?? '',
        };

        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/orders/$orderServerId/cancel-item'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (resp.statusCode == 200) {
          await DBHelper.markCancelLogSynced(id);
          debugPrint('✅ [SYNC CANCEL] queue#$id -> server=$orderServerId');
        } else {
          debugPrint('❌ [SYNC CANCEL] queue#$id -> ${resp.statusCode}: ${resp.body}');
          return false;
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('❌ _syncCancelQueue xato: $e\n$st');
      return false;
    }
  }

  // -------- 2) CLOSE --------
  static Future<bool> _syncClosedOrders(String token) async {
    try {
      final rows = await DBHelper.getUnsyncedClosedOrders();
      for (final r in rows) {
        final localId  = r['id'].toString();
        final serverId = (r['server_id'] ?? '').toString();
        if (serverId.isEmpty || serverId == 'null') {
          debugPrint('⏭️ [SYNC CLOSE] skip $localId: server_id yo‘q');
          continue;
        }

        final resp = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/orders/close/$serverId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (resp.statusCode == 200) {
          await DBHelper.markOrderCloseSynced(localId);
          debugPrint('✅ [SYNC CLOSE] local=$localId -> server=$serverId');
        } else {
          debugPrint('❌ [SYNC CLOSE] $localId -> ${resp.statusCode}: ${resp.body}');
          return false;
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('❌ _syncClosedOrders xato: $e\n$st');
      return false;
    }
  }

  // -------- 3) PAYMENT --------
  static Future<bool> _syncPaidOrders(String token) async {
    try {
      final rows = await DBHelper.getUnsyncedPaidOrders();
      for (final r in rows) {
        final localId  = r['id'].toString();
        final serverId = (r['server_id'] ?? '').toString();
        if (serverId.isEmpty || serverId == 'null') {
          debugPrint('⏭️ [SYNC PAY] skip $localId: server_id yo‘q');
          continue;
        }

        final body = {
          "paymentMethod": r['payment_method'],
          "paymentAmount": r['payment_amount'],
        };

        // BACKEND: /orders/process-payment/:orderId
        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/orders/process-payment/$serverId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (resp.statusCode == 200) {
          await DBHelper.markOrderPaymentSynced(localId);
          debugPrint('✅ [SYNC PAY] local=$localId -> server=$serverId');
        } else {
          debugPrint('❌ [SYNC PAY] $localId -> ${resp.statusCode}: ${resp.body}');
          return false;
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('❌ _syncPaidOrders xato: $e\n$st');
      return false;
    }
  }
}
