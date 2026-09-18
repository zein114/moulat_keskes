import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_service.dart';

class OrderRepository {
  OrderRepository(this.client);

  final SupabaseClient client;

  Future<List<FoodOrder>> fetchOrders() async {
    final rows = await client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map((row) => FoodOrder.fromJson(DbEncoding.decodeRow(row)))
        .toList();
  }

  Future<List<FoodOrder>> placeOrder({
    required List<Map<String, dynamic>> items,
    required String fulfillment,
    required String address,
    required String customerName,
  }) async {
    final rows = await client.rpc(
      'place_order',
      params: {
        'p_items': items
            .map(
              (item) => {
                'meal_id': item['meal_id'],
                'quantity': item['quantity'] as int,
                'price': item['price'] as int,
              },
            )
            .toList(),
        'p_fulfillment': fulfillment,
        'p_address': address,
        'p_customer_name': customerName,
      },
    );
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => FoodOrder.fromJson(DbEncoding.decodeRow(row)))
        .toList();
  }

  Future<FoodOrder> advanceOrder(String orderId) async {
    final row = await client.rpc(
      'advance_order',
      params: {'p_order_id': orderId},
    );
    return FoodOrder.fromJson(DbEncoding.decodeRow(row));
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String orderId) async {
    final rows = await client
        .from('messages')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
    return rows.map((row) => DbEncoding.decodeRow(row)).toList();
  }

  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String body,
  }) => client.from('messages').insert({
    'order_id': orderId,
    'sender_id': senderId,
    'body': body,
  });

  Future<bool> hasReview(String orderId) async =>
      (await client.from('reviews').select('id').eq('order_id', orderId))
          .isNotEmpty;

  Future<void> createReview({
    required String orderId,
    required String customerId,
    required String sellerId,
    required int rating,
    required String comment,
  }) => client.from('reviews').insert({
    'order_id': orderId,
    'customer_id': customerId,
    'seller_id': sellerId,
    'rating': rating,
    'comment': comment.trim(),
  });
}
