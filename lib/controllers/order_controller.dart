import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_controller.dart';
import '../services/order_repository.dart';

/// Owns order communication and reviews; views never access Supabase directly.
class OrderController extends ChangeNotifier {
  OrderController(this.app, this.orderId) {
    unawaited(load());
  }
  final AppController app;
  final String orderId;
  late final OrderRepository? _orders = app.client == null
      ? null
      : OrderRepository(app.client!);
  static final Map<String, List<Map<String, dynamic>>> _demoMessages = {};
  static final Set<String> _demoReviews = {};
  List<Map<String, dynamic>> messages = [];
  bool loading = false, reviewed = false;
  String? error;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (app.demo) {
        messages = List.of(_demoMessages[orderId] ?? []);
        reviewed = _demoReviews.contains(orderId);
      } else {
        final orders = _orders!;
        messages = await orders.fetchMessages(orderId);
        reviewed = await orders.hasReview(orderId);
      }
    } catch (_) {
      error = 'تعذر تحميل المحادثة';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 1000) {
      throw StateError('اكتب رسالة من 1 إلى 1000 حرف');
    }
    if (app.demo) {
      _demoMessages.putIfAbsent(orderId, () => []).add({
        'sender_id': app.userId,
        'body': trimmed,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await _orders!.sendMessage(
        orderId: orderId,
        senderId: app.userId,
        body: trimmed,
      );
    }
    await load();
  }

  Future<void> review(int rating, String comment, String sellerId) async {
    if (rating < 1 || rating > 5) throw StateError('اختر تقييماً');
    if (app.demo) {
      _demoReviews.add(orderId);
    } else {
      await _orders!.createReview(
        orderId: orderId,
        customerId: app.userId,
        sellerId: sellerId,
        rating: rating,
        comment: comment,
      );
    }
    reviewed = true;
    notifyListeners();
    await app.refresh();
  }
}
