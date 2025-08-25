import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _userId;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<Map<String, bool>> tableStatuses = ValueNotifier({});
  final ValueNotifier<Map<String, String>> tableOwners = ValueNotifier({});
  final ValueNotifier<Map<String, List<dynamic>>> tableOrders = ValueNotifier({});

  void init({String? userId}) {
    _userId = userId;

    if (_socket != null) {
      _socket?.dispose();
      _socket = null;
    }

    debugPrint("🔌 Initializing socket for userId: $userId");

    _socket = IO.io(
      "https://7f661wm9-5009.euw.devtunnels.ms/",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setReconnectionAttempts(10) // Qo'shimcha urinishlar
          .setReconnectionDelay(1000) // Tezroq qayta ulanish
          .setTimeout(5000)
          .setExtraHeaders({
        if (userId != null) 'user-id': userId,
      })
          .build(),
    );

    _setupSocketListeners();
    _socket?.connect();
  }

  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      debugPrint("✅ Socket connected!");
      isConnected.value = true;

      // Notify server of waiter connection
      if (_userId != null) {
        _socket?.emit('waiter_connected', {
          'userId': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Request all table statuses
      requestAllTableStatuses();
    });

    _socket?.onDisconnect((_) {
      debugPrint("🔌 Socket disconnected!");
      isConnected.value = false;
    });

    _socket?.onConnectError((err) {
      debugPrint("❌ Socket connection error: $err");
      isConnected.value = false;
    });

    _socket?.onError((err) {
      debugPrint("❌ Socket error: $err");
    });

    _socket?.onReconnect((_) {
      debugPrint("🔄 Socket reconnected!");
      isConnected.value = true;

      // Re-authenticate and request data
      if (_userId != null) {
        _socket?.emit('waiter_connected', {
          'userId': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      requestAllTableStatuses();
    });

    // Table status update (includes ownerId for completeness)
    _socket?.on('tableStatusUpdate', (data) {
      debugPrint("📡 Socket: Table status update - $data");
      if (data is Map<String, dynamic>) {
        final tableId = data['tableId']?.toString();
        final isOccupied = data['isOccupied'] as bool?;
        final ownerId = data['ownerId']?.toString();

        if (tableId != null && isOccupied != null) {
          final currentStatuses = Map<String, bool>.from(tableStatuses.value);
          currentStatuses[tableId] = isOccupied;
          tableStatuses.value = currentStatuses;

          final currentOwners = Map<String, String>.from(tableOwners.value);
          if (isOccupied && ownerId != null) {
            currentOwners[tableId] = ownerId;
          } else {
            currentOwners.remove(tableId);
          }
          tableOwners.value = currentOwners;
        }
      }
    });

    // All table statuses (handles both status and owners)
    _socket?.on('allTableStatuses', (data) {
      debugPrint("📡 Socket: All table statuses - $data");
      if (data is Map<String, dynamic>) {
        final statuses = <String, bool>{};
        final owners = <String, String>{};
        data.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            statuses[key] = value['isOccupied'] as bool? ?? false;
            if (value['ownerId'] != null) {
              owners[key] = value['ownerId'].toString();
            }
          } else if (value is bool) {
            statuses[key] = value;
          }
        });
        tableStatuses.value = statuses;
        tableOwners.value = owners;
      }
    });

    // Order update
    _socket?.on('orderUpdate', (data) {
      debugPrint("📡 Socket: Order updated - $data");
      if (data is Map<String, dynamic>) {
        final tableId = data['tableId']?.toString();
        final orders = data['orders'] as List<dynamic>?;

        if (tableId != null && orders != null) {
          final currentOrders = Map<String, List<dynamic>>.from(tableOrders.value);
          currentOrders[tableId] = orders;
          tableOrders.value = currentOrders;
        }
      }
    });

    // New order created
    _socket?.on('newOrderCreated', (data) {
      debugPrint("📡 Socket: New order created - $data");
      if (data is Map<String, dynamic>) {
        final tableId = data['tableId']?.toString();
        final ownerId = data['waiterId']?.toString();
        if (tableId != null) {
          final currentStatuses = Map<String, bool>.from(tableStatuses.value);
          currentStatuses[tableId] = true;
          tableStatuses.value = currentStatuses;

          // Request updated orders for this table
          requestTableOrders(tableId);

          // Update owner if provided
          if (ownerId != null) {
            final currentOwners = Map<String, String>.from(tableOwners.value);
            currentOwners[tableId] = ownerId;
            tableOwners.value = currentOwners;
          }
        }
      }
    });

    // Order closed
    _socket?.on('orderClosed', (data) {
      debugPrint("📡 Socket: Order closed - $data");
      if (data is Map<String, dynamic>) {
        final tableId = data['tableId']?.toString();
        if (tableId != null) {
          final currentStatuses = Map<String, bool>.from(tableStatuses.value);
          currentStatuses[tableId] = false;
          tableStatuses.value = currentStatuses;

          final currentOrders = Map<String, List<dynamic>>.from(tableOrders.value);
          currentOrders[tableId] = [];
          tableOrders.value = currentOrders;

          // Clear owner
          final currentOwners = Map<String, String>.from(tableOwners.value);
          currentOwners.remove(tableId);
          tableOwners.value = currentOwners;
        }
      }
    });

    // Order item cancelled
    _socket?.on('orderItemCancelled', (data) {
      debugPrint("📡 Socket: Order item cancelled - $data");
      if (data is Map<String, dynamic>) {
        final tableId = data['tableId']?.toString();
        if (tableId != null) {
          requestTableOrders(tableId);
        }
      }
    });

    // General error handling
    _socket?.on('error', (data) {
      debugPrint("❌ Socket error: $data");
    });
  }

  // Stol holatini yangilash
  void updateTableStatus(String tableId, bool isOccupied, {String? ownerId}) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting updateTableStatus: $tableId, isOccupied: $isOccupied, ownerId: $ownerId");
      _socket?.emit('updateTableStatus', {
        'tableId': tableId,
        'isOccupied': isOccupied,
        'ownerId': ownerId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit updateTableStatus");
    }
  }

  // Yangi zakaz yaratish xabari
  void notifyNewOrder(String tableId, Map<String, dynamic> orderData) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting newOrder: $tableId");
      _socket?.emit('newOrder', {
        'tableId': tableId,
        'orderData': orderData,
        'waiterId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit newOrder");
    }
  }

  // Zakaz yangilash xabari
  void notifyOrderUpdate(String tableId, String orderId, List<dynamic> items) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting orderUpdated: $tableId, orderId: $orderId");
      _socket?.emit('orderUpdated', {
        'tableId': tableId,
        'orderId': orderId,
        'items': items,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit orderUpdated");
    }
  }

  // Zakaz yopish xabari
  void notifyOrderClosed(String tableId, String orderId) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting orderClosed: $tableId, orderId: $orderId");
      _socket?.emit('orderClosed', {
        'tableId': tableId,
        'orderId': orderId,
        'waiterId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit orderClosed");
    }
  }

  // Mahsulot bekor qilish xabari
  void notifyItemCancelled(String tableId, String orderId, String foodId, int cancelQuantity) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting itemCancelled: $tableId, orderId: $orderId, foodId: $foodId");
      _socket?.emit('itemCancelled', {
        'tableId': tableId,
        'orderId': orderId,
        'foodId': foodId,
        'cancelQuantity': cancelQuantity,
        'waiterId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit itemCancelled");
    }
  }

  // Ma'lum stol uchun zakazlarni so'rash
  void requestTableOrders(String tableId) {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting request_table_orders: $tableId");
      _socket?.emit('request_table_orders', {
        'tableId': tableId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit request_table_orders");
    }
  }

  // Barcha stollar holatini so'rash
  void requestAllTableStatuses() {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting request_all_table_statuses");
      _socket?.emit('request_all_table_statuses', {
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit request_all_table_statuses");
    }
  }

  // Ofitsiant faolligini bildirish
  void notifyWaiterActivity() {
    if (_socket?.connected == true) {
      debugPrint("📡 Emitting waiter_activity: $_userId");
      _socket?.emit('waiter_activity', {
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      debugPrint("⚠️ Socket not connected, cannot emit waiter_activity");
    }
  }

  IO.Socket? get socket => _socket;

  void dispose() {
    debugPrint("🗑️ Disposing SocketService");
    _socket?.dispose();
    _socket = null;
    isConnected.value = false;
    tableStatuses.value = {};
    tableOwners.value = {};
    tableOrders.value = {};
  }
}