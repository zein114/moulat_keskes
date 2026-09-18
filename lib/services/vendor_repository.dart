import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_service.dart';

class MealDraft {
  const MealDraft({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.description,
    required this.imageUrl,
  });

  final String name;
  final String category;
  final int price;
  final int stock;
  final String description;
  final String imageUrl;

  Map<String, dynamic> toInsert(String vendorId) => {
    'seller_id': vendorId,
    ...toUpdate(),
  };

  Map<String, dynamic> toUpdate() => {
    'name': name.trim(),
    'category': DbEncoding.categoryToDb(category),
    'price': price,
    'stock': stock,
    'description': description.trim(),
    'image_url': imageUrl.trim(),
  };
}

class VendorRepository {
  VendorRepository(this.client);

  final SupabaseClient client;

  Future<List<Seller>> fetchSellers() async {
    final rows = await client.from('sellers').select().order('name');
    return rows
        .map((row) => Seller.fromJson(DbEncoding.decodeRow(row)))
        .toList();
  }

  Future<List<Meal>> fetchMeals() async {
    final rows = await client.from('meals').select().order('name');
    return rows.map((row) => Meal.fromJson(DbEncoding.decodeRow(row))).toList();
  }

  Future<List<Meal>> fetchMealsForVendor(String vendorId) async {
    final rows = await client
        .from('meals')
        .select()
        .eq('seller_id', vendorId)
        .order('name');
    return rows.map((row) => Meal.fromJson(DbEncoding.decodeRow(row))).toList();
  }

  Future<Meal> addMeal(String vendorId, MealDraft draft) async {
    final row = await client
        .from('meals')
        .insert(draft.toInsert(vendorId))
        .select()
        .single();
    return Meal.fromJson(DbEncoding.decodeRow(row));
  }

  Future<Meal> editMeal(String mealId, MealDraft draft) async {
    final row = await client
        .from('meals')
        .update(draft.toUpdate())
        .eq('id', mealId)
        .select()
        .single();
    return Meal.fromJson(DbEncoding.decodeRow(row));
  }

  Future<List<FoodOrder>> fetchIncomingOrders(String vendorId) async {
    final rows = await client
        .from('orders')
        .select()
        .eq('seller_id', vendorId)
        .order('created_at', ascending: false);
    return rows
        .map((row) => FoodOrder.fromJson(DbEncoding.decodeRow(row)))
        .toList();
  }

  Future<Seller> upsertSeller(
    Map<String, dynamic> values,
    String userId,
  ) async {
    final existing = await client
        .from('sellers')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    final row = existing == null
        ? await client
              .from('sellers')
              .insert({'id': userId, ...values})
              .select()
              .single()
        : await client
              .from('sellers')
              .update(values)
              .eq('id', userId)
              .select()
              .single();
    return Seller.fromJson(DbEncoding.decodeRow(row));
  }
}
