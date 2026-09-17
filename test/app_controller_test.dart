import 'package:flutter_test/flutter_test.dart';
import 'package:moulat_keskes/controllers/app_controller.dart';
import 'package:moulat_keskes/models/models.dart';

void main() {
  test('demo starts with independent inventory and no orders or cart', () {
    final first = AppController();
    final second = AppController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    expect(first.demo, isTrue);
    expect(first.signedIn, isTrue);
    expect(first.sellers, demoSellers);
    expect(first.meals, demoMeals);
    expect(first.meals.where((meal) => meal.category == 'الكسكس'), hasLength(3));
    expect(first.orders, isEmpty);
    expect(first.cart, isEmpty);
    first.meals.removeLast();
    expect(second.meals.length, demoMeals.length);
  });

  group('ordering', () {
    late AppController store;

    setUp(() {
      store = AppController();
      store.sellers = List<Seller>.of(const [
        Seller(id: 'khadija', name: 'Nearby kitchen', area: 'Centre'),
        Seller(
          id: 'far',
          name: 'Further kitchen',
          area: 'North',
          lat: 18.12,
          lng: -15.98,
        ),
        Seller(id: 'closed', name: 'Closed kitchen', area: 'Centre', open: false),
      ]);
      store.meals = List<Meal>.of(const [
        Meal(
          id: 'near1', sellerId: 'khadija', name: 'Vegetable couscous',
          category: 'couscous', price: 250, stock: 3,
        ),
        Meal(
          id: 'near2', sellerId: 'khadija', name: 'Family couscous',
          category: 'couscous', price: 200, stock: 2,
        ),
        Meal(
          id: 'far1', sellerId: 'far', name: 'House couscous',
          category: 'couscous', price: 230, stock: 5,
        ),
        Meal(
          id: 'closed1', sellerId: 'closed', name: 'Unavailable couscous',
          category: 'couscous', price: 100, stock: 9,
        ),
        Meal(
          id: 'rice', sellerId: 'far', name: 'Rice',
          category: 'rice', price: 150, stock: 10,
        ),
      ]);
    });
    tearDown(() => store.dispose());

    test('cart totals quantities without consuming inventory before checkout', () {
      store.add(store.meal('near1'), 2);
      store.add(store.meal('far1'));

      expect(store.cartCount, 3);
      expect(store.cartTotal, 730);
      expect(store.meal('near1').stock, 3);
      expect(store.meal('far1').stock, 5);

      store.add(store.meal('near1'), -1);
      expect(store.cartCount, 2);
      expect(store.cartTotal, 480);
      store.add(store.meal('near1'), -1);
      expect(store.cart.containsKey('near1'), isFalse);
      expect(store.cartCount, 1);
    });

    test('exceeding stock preserves an existing cart', () {
      store.add(store.meal('near1'), 2);
      expect(() => store.add(store.meal('near1'), 2), throwsStateError);
      expect(store.cart, {'near1': 2});
    });

    test('closed kitchens cannot be added to the cart', () {
      expect(() => store.add(store.meal('closed1')), throwsStateError);
      expect(store.cart, isEmpty);
    });

    test('cart can be reduced after kitchen closes and inventory shrinks', () {
      store.add(store.meal('near1'), 3);
      store.sellers[0] = const Seller(
        id: 'khadija', name: 'Nearby kitchen', area: 'Centre', open: false,
      );
      store.meals[0] = store.meal('near1').withStock(0);

      store.add(store.meal('near1'), -1);
      expect(store.cart, {'near1': 2});
      store.add(store.meal('near1'), -2);
      expect(store.cart, isEmpty);
    });

    test('family order fills nearby kitchens before further kitchens', () {
      store.familyOrder('couscous', 7);

      expect(store.cart, {'near1': 3, 'near2': 2, 'far1': 2});
      expect(store.cartCount, 7);
      expect(store.cartTotal, 1610);
      expect(store.meal('near1').stock, 3);
    });

    test('family order accounts for quantities already in the cart', () {
      store.add(store.meal('near1'), 2);
      store.familyOrder('couscous', 7);

      expect(store.cart, {'near1': 3, 'near2': 2, 'far1': 4});
      expect(store.cartCount, 9);
    });

    test('family order rejects insufficient open stock atomically', () {
      store.add(store.meal('rice'), 2);
      store.add(store.meal('near1'));
      final before = Map<String, int>.of(store.cart);

      // Open kitchens have 9 remaining couscous portions; a closed kitchen
      // cannot supply the missing portion even though it has stock.
      expect(() => store.familyOrder('couscous', 10), throwsStateError);
      expect(store.cart, before);
      expect(store.orders, isEmpty);
    });

    test('zero, negative, and unavailable family requests do not change cart', () {
      store.add(store.meal('rice'));
      expect(() => store.familyOrder('couscous', 0), throwsStateError);
      expect(() => store.familyOrder('couscous', -2), throwsStateError);
      expect(() => store.familyOrder('unknown', 1), throwsStateError);
      expect(store.cart, {'rice': 1});
    });

    test('checkout creates one order per kitchen and exact inventory changes', () async {
      store.add(store.meal('near1'), 2);
      store.add(store.meal('near2'));
      store.add(store.meal('far1'), 3);

      await store.checkout('delivery', 'House 12, Centre', 'Customer');

      expect(store.cart, isEmpty);
      expect(store.orders, hasLength(2));
      final nearby = store.orders.singleWhere((o) => o.sellerId == 'khadija');
      final further = store.orders.singleWhere((o) => o.sellerId == 'far');
      expect(nearby.total, 700);
      expect(further.total, 690);
      expect(nearby.items, [
        {'meal_id': 'near1', 'name': 'Vegetable couscous', 'quantity': 2, 'price': 250},
        {'meal_id': 'near2', 'name': 'Family couscous', 'quantity': 1, 'price': 200},
      ]);
      expect(nearby.id, isNot(further.id));
      for (final order in store.orders) {
        expect(order.status, 'pending');
        expect(order.fulfillment, 'delivery');
        expect(order.address, 'House 12, Centre');
        expect(order.customerName, 'Customer');
      }
      expect(store.meal('near1').stock, 1);
      expect(store.meal('near2').stock, 1);
      expect(store.meal('far1').stock, 2);
      expect(store.meal('closed1').stock, 9);
    });

    test('stock change before checkout preserves all inventory, cart, and orders', () async {
      store.add(store.meal('near1'), 2);
      store.add(store.meal('far1'), 3);
      store.meals[2] = store.meal('far1').withStock(1);
      final inventory = {for (final meal in store.meals) meal.id: meal.stock};

      await expectLater(store.checkout('pickup', '', 'Customer'), throwsStateError);

      expect(store.orders, isEmpty);
      expect(store.cart, {'near1': 2, 'far1': 3});
      expect({for (final meal in store.meals) meal.id: meal.stock}, inventory);
    });

    test('kitchen closing before checkout rejects all orders atomically', () async {
      store.add(store.meal('near1'));
      store.add(store.meal('far1'));
      store.sellers[1] = const Seller(
        id: 'far', name: 'Further kitchen', area: 'North', open: false,
      );

      await expectLater(store.checkout('pickup', '', 'Customer'), throwsStateError);
      expect(store.cart, {'near1': 1, 'far1': 1});
      expect(store.meal('near1').stock, 3);
      expect(store.meal('far1').stock, 5);
      expect(store.orders, isEmpty);
    });

    test('empty cart cannot create an order', () async {
      await expectLater(store.checkout('pickup', '', 'Customer'), throwsStateError);
      expect(store.orders, isEmpty);
    });

    test('invalid checkout details preserve cart and inventory', () async {
      store.add(store.meal('near1'));
      await expectLater(store.checkout('delivery', '', 'Customer'), throwsStateError);
      await expectLater(store.checkout('pickup', '', '  '), throwsStateError);
      await expectLater(store.checkout('unknown', '', 'Customer'), throwsStateError);
      expect(store.cart, {'near1': 1});
      expect(store.meal('near1').stock, 3);
      expect(store.orders, isEmpty);
    });

    test('seller mode shows only its kitchen orders', () async {
      store.familyOrder('couscous', 7);
      await store.checkout('pickup', '', 'Customer');
      expect(store.visibleOrders, hasLength(2));
      store.switchMode();
      expect(store.visibleOrders, hasLength(1));
      expect(store.visibleOrders.single.sellerId, store.userId);
      expect(store.ownMeals.map((m) => m.id), ['near1', 'near2']);
    });

    test('order progresses through each stage and delivered is terminal', () async {
      store.add(store.meal('near1'));
      await store.checkout('pickup', '', 'Customer');
      final order = store.orders.single;
      for (final status in orderStates.skip(1)) {
        await store.advance(order);
        expect(order.status, status);
      }
      await store.advance(order);
      expect(order.status, 'delivered');
      expect(store.meal('near1').stock, 2);
    });

    test('cancelled order is never advanced', () async {
      final cancelled = FoodOrder(
        id: 'cancelled', sellerId: 'khadija', total: 250,
        items: [], status: 'cancelled',
      );
      await store.advance(cancelled);
      expect(cancelled.status, 'cancelled');
    });

    test('seller cannot advance another kitchen order', () async {
      store.add(store.meal('far1'));
      await store.checkout('pickup', '', 'Customer');
      final order = store.orders.single;
      store.switchMode();

      await expectLater(store.advance(order), throwsStateError);
      expect(order.status, 'pending');
      expect(store.visibleOrders, isEmpty);
    });

    test('sign out clears cart, favorites, and seller mode', () async {
      store.add(store.meal('near1'));
      store.favorite('khadija');
      store.switchMode();
      await store.signOut();
      expect(store.cart, isEmpty);
      expect(store.favorites, isEmpty);
      expect(store.sellerMode, isFalse);
    });
  });
}
