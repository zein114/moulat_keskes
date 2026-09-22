import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/auth_repository.dart';
import '../services/order_repository.dart';
import '../services/vendor_repository.dart';

class AppController extends ChangeNotifier {
  AppController({this.client}) {
    if (demo) {
      sellers = List.of(demoSellers);
      meals = List.of(demoMeals);
    }
    _auth = client?.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) recovering = true;
      if (event.event == AuthChangeEvent.signedOut) {
        orders = [];
        cart.clear();
        favorites.clear();
        sellerMode = false;
        role = 'customer';
        name = 'ضيفنا العزيز';
      }
      unawaited(refresh());
    });
  }
  final SupabaseClient? client;
  late final ProfileRepository? profiles = client == null
      ? null
      : ProfileRepository(client!);
  late final AuthRepository? authRepository = client == null
      ? null
      : AuthRepository(client!);
  late final VendorRepository? vendors = client == null
      ? null
      : VendorRepository(client!);
  late final OrderRepository? orderRepository = client == null
      ? null
      : OrderRepository(client!);
  StreamSubscription<AuthState>? _auth;
  bool get demo => client == null;
  bool get signedIn => demo || client!.auth.currentUser != null;
  String get userId => demo ? 'khadija' : client!.auth.currentUser!.id;
  String name = 'ضيفنا العزيز', role = 'customer', area = 'تفرغ زينة، نواكشوط';
  bool sellerMode = false, recovering = false;
  double latitude = 18.0735, longitude = -15.9582;
  bool hasLocation = false;
  List<Seller> sellers = [];
  List<Meal> meals = [];
  List<FoodOrder> orders = [];
  final Map<String, int> cart = {};
  final Set<String> favorites = {};
  String? error;
  bool loading = false;
  int _refreshVersion = 0;
  bool _disposed = false;
  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartTotal =>
      cart.entries.fold(0, (sum, e) => sum + meal(e.key).price * e.value);
  Meal meal(String id) => meals.firstWhere((m) => m.id == id);
  Seller seller(String id) => sellers.firstWhere((s) => s.id == id);
  List<Meal> get ownMeals => meals.where((m) => m.sellerId == userId).toList();
  List<FoodOrder> get visibleOrders => sellerMode
      ? orders.where((o) => o.sellerId == userId).toList()
      : demo
      ? orders
      : orders
            .where((o) => o.customerId == client?.auth.currentUser?.id)
            .toList();
  double distance(Seller s) =>
      Geolocator.distanceBetween(latitude, longitude, s.lat, s.lng) / 1000;

  Future<void> refresh() async {
    if (demo) {
      notifyListeners();
      return;
    }
    loading = true;
    final version = ++_refreshVersion;
    final refreshUser = client?.auth.currentUser?.id;
    error = null;
    notifyListeners();
    try {
      final s = await vendors!.fetchSellers();
      final m = await vendors!.fetchMeals();
      // Keep the public catalog usable even if the signed-in profile or
      // orders query fails. Those queries have stricter RLS than sellers/meals.
      sellers = s;
      meals = m;
      UserProfile? profile;
      List<FoodOrder> nextOrders = [];
      if (refreshUser != null) {
        profile = await profiles!.currentProfile();
        nextOrders = await orderRepository!.fetchOrders();
      }
      if (version != _refreshVersion ||
          _disposed ||
          client?.auth.currentUser?.id != refreshUser) {
        return;
      }
      final removedMeals = cart.keys
          .where((id) => !meals.any((meal) => meal.id == id))
          .toList();
      for (final id in removedMeals) {
        cart.remove(id);
      }
      if (removedMeals.isNotEmpty) {
        error =
            'بعض الوجبات لم تعد متاحة وتمت إزالتها. راجع السلة قبل التأكيد.';
      }
      if (profile != null) {
        name = profile.name;
        role = profile.role;
        orders = nextOrders;
      } else {
        orders = [];
        role = 'customer';
        name = 'ضيفنا العزيز';
        sellerMode = false;
      }
    } catch (e) {
      if (version != _refreshVersion || _disposed) return;
      error = _refreshError(e);
    }
    loading = false;
    notifyListeners();
  }

  String _refreshError(Object error) {
    final text = error.toString();
    if (text.contains('PGRST116')) {
      return 'تم الاتصال بقاعدة البيانات، لكن ملف الحساب غير موجود. أعد إنشاء الحساب بعد تشغيل migration قاعدة البيانات.';
    }
    if (text.contains('42501') || text.toLowerCase().contains('permission denied')) {
      return 'تم الاتصال بقاعدة البيانات، لكن صلاحيات RLS تمنع هذه العملية. طبّق migration قاعدة البيانات كاملة.';
    }
    if (text.contains('42P01') || text.contains('PGRST205')) {
      return 'جداول قاعدة البيانات غير موجودة. شغّل migration Supabase ثم أعد تشغيل التطبيق.';
    }
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'تعذر الوصول إلى Supabase من الجهاز. تحقق من الإنترنت أو DNS.';
    }
    return 'تعذر تحميل البيانات من قاعدة البيانات: $text';
  }

  void switchMode() {
    if (!demo && role != 'seller') return;
    sellerMode = !sellerMode;
    notifyListeners();
  }

  void favorite(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    notifyListeners();
  }

  void add(Meal m, [int count = 1]) {
    if (!demo && signedIn && m.sellerId == userId && count > 0) {
      throw StateError('لا يمكنك طلب وجبتك الخاصة');
    }
    if (count > 0 && !seller(m.sellerId).open) {
      throw StateError('البائعة غير متاحة للطلبات الآن');
    }
    final next = (cart[m.id] ?? 0) + count;
    if (count > 0 && next > m.stock) {
      throw StateError('الكمية المطلوبة غير متوفرة');
    }
    if (next <= 0) {
      cart.remove(m.id);
    } else {
      cart[m.id] = next;
    }
    notifyListeners();
  }

  Future<void> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('فعّل خدمة الموقع أو أدخل الحي يدوياً');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('لم يتم السماح بالموقع. يمكنك اختيار الحي يدوياً.');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 15),
      ),
    );
    latitude = p.latitude;
    longitude = p.longitude;
    hasLocation = true;
    area = 'موقعي الحالي';
    notifyListeners();
  }

  void selectArea(String value) {
    area = value;
    final coords = {
      'تفرغ زينة، نواكشوط': [18.0735, -15.9582],
      'لكصر، نواكشوط': [18.098, -15.974],
      'تيارت، نواكشوط': [18.113, -15.946],
    };
    latitude = coords[value]![0];
    longitude = coords[value]![1];
    hasLocation = false;
    notifyListeners();
  }

  Future<void> checkout(
    String fulfillment,
    String address,
    String customerName,
  ) async {
    if (cart.isEmpty) throw StateError('السلة فارغة');
    if (!signedIn) throw StateError('سجل الدخول لإرسال الطلب');
    if (!['pickup', 'delivery'].contains(fulfillment) ||
        customerName.trim().isEmpty ||
        customerName.length > 100 ||
        address.length > 1000) {
      throw StateError('تحقق من اسم المستلم وطريقة الاستلام');
    }
    if (fulfillment == 'delivery' && address.trim().isEmpty) {
      throw StateError('أدخل عنوان التوصيل');
    }
    if (demo) {
      // Validate every line before mutating inventory.
      for (final e in cart.entries) {
        if (e.value > meal(e.key).stock || !seller(meal(e.key).sellerId).open) {
          throw StateError('تغير التوفر، راجع سلتك');
        }
      }
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final e in cart.entries) {
        final m = meal(e.key);
        groups.putIfAbsent(m.sellerId, () => []).add({
          'meal_id': m.id,
          'name': m.name,
          'quantity': e.value,
          'price': m.price,
        });
        meals[meals.indexOf(m)] = m.withStock(m.stock - e.value);
      }
      for (final e in groups.entries) {
        orders.insert(
          0,
          FoodOrder(
            id: 'D${DateTime.now().microsecondsSinceEpoch}${e.key}',
            sellerId: e.key,
            total: e.value.fold<int>(
              0,
              (v, i) => v + (i['price'] as int) * (i['quantity'] as int),
            ),
            items: e.value,
            fulfillment: fulfillment,
            address: address,
            customerName: customerName,
          ),
        );
      }
    } else {
      await orderRepository!.placeOrder(
        items: cart.entries
            .map(
              (e) => {
                'meal_id': e.key,
                'quantity': e.value,
                'price': meal(e.key).price,
              },
            )
            .toList(),
        fulfillment: fulfillment,
        address: address,
        customerName: customerName,
      );
    }
    cart.clear();
    await refresh();
  }

  Future<void> advance(FoodOrder order) async {
    if (!signedIn || order.sellerId != userId) {
      throw StateError('هذا الطلب تابع لبائعة أخرى');
    }
    final i = orderStates.indexOf(order.status);
    if (i < 0 || i >= 3) return;
    if (!demo) {
      await orderRepository!.advanceOrder(order.id);
      await refresh();
    } else {
      order.status = orderStates[i + 1];
      notifyListeners();
    }
  }

  Future<void> saveMeal({
    String? id,
    required String title,
    required String category,
    required int price,
    required int stock,
    required String description,
    required String imageUrl,
  }) async {
    final draft = MealDraft(
      name: title,
      category: category,
      price: price,
      stock: stock,
      description: description,
      imageUrl: imageUrl,
    );
    if (demo) {
      final m = Meal(
        id: id ?? 'm${DateTime.now().microsecondsSinceEpoch}',
        sellerId: userId,
        name: title,
        category: category,
        price: price,
        stock: stock,
        description: description,
        imageUrl: imageUrl,
      );
      if (id == null) {
        meals.add(m);
      } else {
        meals[meals.indexWhere((v) => v.id == id)] = m;
      }
      notifyListeners();
    } else {
      if (id == null) {
        await vendors!.addMeal(userId, draft);
      } else {
        await vendors!.editMeal(id, draft);
      }
      await refresh();
    }
  }

  Future<void> saveSeller(Map<String, dynamic> values) async {
    if (demo) {
      final i = sellers.indexWhere((s) => s.id == userId);
      final s = Seller.fromJson({
        'id': userId,
        'rating': i < 0 ? 0 : sellers[i].rating,
        ...values,
      });
      if (i < 0) {
        sellers.add(s);
      } else {
        sellers[i] = s;
      }
      notifyListeners();
    } else {
      await vendors!.upsertSeller(values, userId);
      await refresh();
    }
  }

  Future<void> signOut() async {
    if (!demo) await authRepository!.signOut();
    cart.clear();
    favorites.clear();
    sellerMode = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth?.cancel();
    super.dispose();
  }
}
