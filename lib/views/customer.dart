import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/app_controller.dart';
import '../controllers/order_controller.dart';
import '../models/models.dart';
import 'shared.dart';
import 'auth.dart';

Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('تعذر فتح الرابط');
    }
  } catch (_) {
    if (context.mounted) toast(context, 'تعذر فتح الرابط على هذا الجهاز');
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key, required this.store, this.seller});
  final AppController store;
  final Seller? seller;
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store;
      final target = widget.seller;
      final point = LatLng(
        target?.lat ?? s.latitude,
        target?.lng ?? s.longitude,
      );
      return PageFrame(
        title: target == null ? 'حدد موقعك' : 'موقع المطبخ',
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Heading(
              target?.name ?? 'لقمة قريبة من بيتك',
              subtitle: target?.area ?? 'اختر الحي أو استخدم موقعك الحالي',
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 330,
                child: FlutterMap(
                  key: ValueKey('${point.latitude}:${point.longitude}'),
                  options: MapOptions(initialCenter: point, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate: const String.fromEnvironment(
                        'MAP_TILE_URL',
                        defaultValue:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      userAgentPackageName: 'com.moulatkeskes.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_pin,
                            size: 55,
                            color: green,
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => openExternal(
                            context,
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (target == null) ...[
              DropdownButtonFormField<String>(
                initialValue: s.hasLocation ? null : s.area,
                decoration: const InputDecoration(labelText: 'الحي'),
                items: ['تفرغ زينة، نواكشوط', 'لكصر، نواكشوط', 'تيارت، نواكشوط']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) s.selectArea(v);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await s.locate();
                        } catch (e) {
                          if (context.mounted) toast(context, friendlyError(e));
                        }
                        if (mounted) setState(() => busy = false);
                      },
                icon: const Icon(Icons.my_location),
                label: Text(
                  busy ? 'جارٍ تحديد الموقع...' : 'استخدم موقعي الحالي',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'اختيار الحي يستخدم مركزه لحساب مسافة تقريبية. الموقع الدقيق يحتاج موافقتك.',
                style: TextStyle(color: muted, height: 1.7),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تأكيد الموقع'),
              ),
            ] else ...[
              Panel(
                child: Row(
                  children: [
                    Avatar(target.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${target.name}\n${target.area}',
                        style: const TextStyle(height: 1.8),
                      ),
                    ),
                    Pill('${s.distance(target).toStringAsFixed(1)} كم'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openExternal(
                  context,
                  Uri.https('www.google.com', '/maps/dir/', {
                    'api': '1',
                    'destination': '${target.lat},${target.lng}',
                  }),
                ),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('عرض الاتجاهات'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class SellerPage extends StatelessWidget {
  const SellerPage({super.key, required this.store, required this.sellerId});
  final AppController store;
  final String sellerId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final availableSellers = store.sellers.where((s) => s.id == sellerId);
      if (availableSellers.isEmpty) {
        return const PageFrame(
          title: 'المطبخ',
          child: EmptyState(
            'المطبخ غير متاح',
            'ارجع لقائمة المطابخ لاختيار وجبة أخرى.',
          ),
        );
      }
      final seller = availableSellers.first;
      final meals = store.meals.where((m) => m.sellerId == sellerId).toList();
      return PageFrame(
        title: seller.name,
        bottom: FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CartPage(store: store)),
          ),
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(
            'عرض السلة (${store.cartCount}) • ${store.cartTotal} أوقية',
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const FoodPhoto(height: 230),
            const SizedBox(height: 20),
            Row(
              children: [
                Avatar(seller.name, radius: 33),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.name,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: green,
                        ),
                      ),
                      Text(seller.area, style: const TextStyle(color: muted)),
                    ],
                  ),
                ),
                Pill(seller.open ? 'متاح الآن' : 'مغلق'),
              ],
            ),
            const SizedBox(height: 18),
            Text(seller.bio, style: const TextStyle(height: 1.8)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Pill(
                  '★ ${seller.rating == 0 ? 'مطبخ جديد' : seller.rating.toStringAsFixed(1)}',
                  color: gold,
                ),
                Pill(seller.hours),
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 17),
                  label: const Text('موقع المطبخ'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationPage(store: store, seller: seller),
                    ),
                  ),
                ),
              ],
            ),
            const Heading(
              'من مطبخنا اليوم',
              subtitle: 'وجبات طازجة، والكمية محدودة',
            ),
            if (meals.isEmpty)
              const EmptyState(
                'القائمة قيد التحضير',
                'ستظهر الوجبات هنا عندما يضيفها المطبخ.',
              ),
            for (final meal in meals)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MealTile(
                    meal: meal,
                    onTap: () {
                      try {
                        store.add(meal);
                        toast(context, 'أضيفت ${meal.name} للسلة');
                      } catch (e) {
                        toast(context, friendlyError(e));
                      }
                    },
                  ),
                  if (meal.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      child: Text(
                        meal.description,
                        style: const TextStyle(color: muted),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: seller.phone.isEmpty
                  ? () => toast(context, 'يمكنك مراسلة المطبخ بعد إرسال الطلب')
                  : () => openExternal(
                      context,
                      Uri(scheme: 'tel', path: seller.phone),
                    ),
              icon: const Icon(Icons.call_outlined),
              label: const Text('تواصل مع المطبخ'),
            ),
          ],
        ),
      );
    },
  );
}

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.store});
  final AppController store;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final form = GlobalKey<FormState>();
  final address = TextEditingController(), name = TextEditingController();
  bool busy = false, delivery = false;
  @override
  void initState() {
    super.initState();
    if (widget.store.name != 'ضيفنا العزيز') name.text = widget.store.name;
  }

  @override
  void dispose() {
    address.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final s = widget.store;
    if (!s.signedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AuthPage(store: s)),
      );
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await s.checkout(
        delivery ? 'delivery' : 'pickup',
        address.text.trim(),
        name.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuccessPage(store: s)),
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store;
      return PageFrame(
        title: 'سلة الخير',
        bottom: s.cart.isEmpty
            ? null
            : FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'جارٍ إرسال الطلب...'
                      : 'تأكيد الطلب • ${s.cartTotal} أوقية',
                ),
              ),
        child: s.cart.isEmpty
            ? const EmptyState(
                'سلتك بانتظار لقمة هنية',
                'اكتشف المطابخ وأضف وجبتك المفضلة.',
                icon: Icons.shopping_bag_outlined,
              )
            : Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Heading(
                      'وجباتك المختارة',
                      subtitle: 'كل حصة تحكي حكاية بيت',
                      trailing: IconButton(
                        tooltip: 'تحديث الأسعار والتوفر',
                        onPressed: s.loading ? null : s.refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    for (final entry in s.cart.entries.toList())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.meal(entry.key).name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                s.seller(s.meal(entry.key).sellerId).name,
                                style: const TextStyle(color: muted),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${s.meal(entry.key).price * entry.value} أوقية',
                                    style: const TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'تقليل الكمية',
                                    onPressed: () =>
                                        s.add(s.meal(entry.key), -1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'زيادة الكمية',
                                    onPressed: () {
                                      try {
                                        s.add(s.meal(entry.key));
                                      } catch (e) {
                                        toast(context, friendlyError(e));
                                      }
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Heading('كيف تستلم طلبك؟'),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('استلام من المطبخ'),
                          icon: Icon(Icons.storefront),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('طلب توصيل'),
                          icon: Icon(Icons.delivery_dining),
                        ),
                      ],
                      selected: {delivery},
                      onSelectionChanged: (v) =>
                          setState(() => delivery = v.first),
                    ),
                    if (delivery)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'التوصيل بالتنسيق مع البائعة، وتكلفته غير مشمولة. لا يتم حجز مندوب تلقائياً.',
                          style: TextStyle(color: muted, height: 1.7),
                        ),
                      ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستلم',
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'أدخل اسم المستلم'
                          : null,
                    ),
                    if (delivery)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextFormField(
                          controller: address,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'العنوان ورقم الهاتف للتنسيق',
                          ),
                          validator: (v) =>
                              delivery && (v == null || v.trim().length < 8)
                              ? 'أدخل العنوان ورقم التواصل'
                              : null,
                        ),
                      ),
                    const Heading('طريقة الدفع'),
                    const Panel(
                      color: sage,
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, color: green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'الدفع عند الاستلام',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.check_circle, color: green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill('بنكيلي • قريباً', color: muted),
                        Pill('سداد • قريباً', color: muted),
                        Pill('مصرفي • قريباً', color: muted),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Panel(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('إجمالي الوجبات'),
                              const Spacer(),
                              Text(
                                '${s.cartTotal} أوقية',
                                style: const TextStyle(
                                  fontSize: 23,
                                  color: green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          const Text(
                            'سيصل طلب منفصل لكل مطبخ. تُحجز الكمية عند التأكيد، ولا يتم خصم أي مبلغ إلكترونياً.',
                            style: TextStyle(color: muted, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    if (s.demo)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'طلب تجريبي داخل التطبيق فقط.',
                          style: TextStyle(color: gold),
                        ),
                      ),
                  ],
                ),
              ),
      );
    },
  );
}

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key, required this.store});
  final AppController store;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'طلبك وصل',
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 58,
              backgroundColor: green,
              child: Icon(Icons.check_rounded, size: 72, color: Colors.white),
            ),
            const SizedBox(height: 30),
            const Text(
              'تم إرسال طلبك!',
              style: TextStyle(
                color: green,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              store.demo
                  ? 'هذه تجربة توضيحية. يمكنك متابعة الطلب\nوتجربة التحضير من لوحة البائعة.'
                  : 'سيتابع المطبخ طلبك قريباً.\nبالهنا والشفا!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 18, height: 1.8),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PageFrame(
                    title: 'طلباتي',
                    child: OrdersView(store: store),
                  ),
                ),
              ),
              child: const Text('متابعة الطلب'),
            ),
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
}

class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.store});
  final AppController store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Heading(
            store.sellerMode ? 'طلبات المطبخ' : 'طلباتك، بكل حب',
            subtitle: 'تابع رحلتها من التحضير إلى الاستلام',
          ),
          if (store.visibleOrders.isEmpty)
            const EmptyState(
              'لا توجد طلبات بعد',
              'ستجد تفاصيل طلباتك هنا.',
              icon: Icons.receipt_long_outlined,
            ),
          for (final order in store.visibleOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderPage(store: store, orderId: order.id),
                  ),
                ),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'طلب #${order.id.substring(0, 6).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Pill(order.label),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        order.items
                            .map((i) => '${i['quantity']} × ${i['name']}')
                            .join('، '),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            '${order.total} أوقية',
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${order.createdAt.toLocal().day}/${order.createdAt.toLocal().month} • ${order.fulfillment == 'pickup' ? 'استلام' : 'طلب توصيل'}',
                            style: const TextStyle(color: muted),
                          ),
                          const Icon(Icons.chevron_left, color: green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.store, required this.orderId});
  final AppController store;
  final String orderId;
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final OrderController controller;
  final message = TextEditingController(), comment = TextEditingController();
  Timer? timer;
  bool busy = false;
  int stars = 5;
  @override
  void initState() {
    super.initState();
    controller = OrderController(widget.store, widget.orderId);
    timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => controller.load(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    message.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.store, controller]),
    builder: (context, _) {
      final s = widget.store;
      final found = s.orders.where((o) => o.id == widget.orderId);
      if (found.isEmpty) {
        return const PageFrame(
          title: 'الطلب',
          child: EmptyState(
            'الطلب غير متاح',
            'أعد تسجيل الدخول بالحساب المرتبط بالطلب.',
          ),
        );
      }
      final order = found.first;
      final stage = orderStates.indexOf(order.status);
      return PageFrame(
        title: 'تفاصيل الطلب',
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Heading(
              'طلب #${order.id.substring(0, 6).toUpperCase()}',
              subtitle: '${order.total} أوقية • الدفع عند الاستلام',
            ),
            Panel(
              child: Column(
                children: [
                  for (var i = 0; i < orderLabels.length; i++)
                    ListTile(
                      leading: Icon(
                        i <= stage ? Icons.check_circle : Icons.circle_outlined,
                        color: i <= stage ? green : muted,
                      ),
                      title: Text(
                        orderLabels[i],
                        style: TextStyle(
                          fontWeight: i == stage
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: i <= stage ? green : muted,
                        ),
                      ),
                      subtitle: i == stage
                          ? const Text('الحالة الحالية')
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${i['quantity']} × ${i['name']} — ${i['price']} أوقية للحصة',
                      ),
                    ),
                  const Divider(),
                  Text('المستلم: ${order.customerName}'),
                  Text(
                    order.fulfillment == 'pickup'
                        ? 'استلام من المطبخ'
                        : 'طلب توصيل: ${order.address}',
                  ),
                ],
              ),
            ),
            if (s.sellerMode &&
                order.sellerId == s.userId &&
                stage >= 0 &&
                stage < 3)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton(
                  onPressed: busy ? null : () => action(() => s.advance(order)),
                  child: Text('تحديث: ${orderLabels[stage + 1]}'),
                ),
              ),
            if (!s.sellerMode &&
                order.status == 'delivered' &&
                !controller.reviewed) ...[
              const Heading('كيف كانت الوجبة؟'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setState(() => stars = i + 1),
                    icon: Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      color: gold,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'اكتب رأيك (اختياري)',
                ),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => action(
                        () => controller.review(
                          stars,
                          comment.text,
                          order.sellerId,
                        ),
                      ),
                child: const Text('إرسال التقييم'),
              ),
            ],
            if (controller.reviewed)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Pill('شكراً لتقييمك'),
              ),
            const Heading(
              'محادثة الطلب',
              subtitle: 'نسّق الاستلام وتفاصيل الوجبة هنا',
            ),
            if (s.demo)
              const Text(
                'محادثة تجريبية محلية، لا تصل إلى بائعة حقيقية.',
                style: TextStyle(color: muted),
              ),
            if (controller.error != null)
              TextButton(
                onPressed: controller.load,
                child: Text('${controller.error} • إعادة المحاولة'),
              ),
            for (final m in controller.messages)
              Align(
                alignment: m['sender_id'] == s.userId
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: m['sender_id'] == s.userId ? sage : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(m['body']),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'إرسال',
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          await controller.send(message.text);
                          message.clear();
                        }),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
