import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/models.dart';
import 'shared.dart';
import 'customer.dart';
import 'seller.dart';
import 'auth.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.store});
  final AppController store;
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool started = false;
  int tab = 0;
  Timer? timer;
  bool recoveryNavigationPending = false;
  late bool previousSellerMode;
  @override
  void initState() {
    super.initState();
    previousSellerMode = widget.store.sellerMode;
    widget.store.addListener(_onControllerChange);
    unawaited(widget.store.refresh());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!widget.store.demo &&
          widget.store.signedIn &&
          !widget.store.loading) {
        unawaited(widget.store.refresh());
      }
    });
  }

  void _onControllerChange() {
    if (widget.store.sellerMode != previousSellerMode) {
      setState(() {
        previousSellerMode = widget.store.sellerMode;
        tab = 0;
      });
    }
    if (widget.store.recovering && !recoveryNavigationPending) {
      recoveryNavigationPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.store.recovering) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        recoveryNavigationPending = false;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.store.removeListener(_onControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store;
      if (s.recovering) return AuthPage(store: s, recovery: true);
      if (!started) {
        return Welcome(
          onStart: () => setState(() => started = true),
          demo: s.demo,
        );
      }
      final seller = s.sellerMode;
      final content = switch (tab) {
        0 => seller ? SellerDashboard(store: s) : Discover(store: s),
        1 => OrdersView(store: s),
        2 =>
          seller
              ? MealsView(store: s)
              : Discover(store: s, favoritesOnly: true),
        _ => AccountView(store: s),
      };
      final destinations = [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'الطلبات',
        ),
        NavigationDestination(
          icon: Icon(seller ? Icons.restaurant_menu : Icons.favorite_border),
          label: seller ? 'وجباتي' : 'المفضلة',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'حسابي',
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 82,
          title: const Brand(),
          leadingWidth: 74,
          leading: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: SizedBox.square(
                dimension: 48,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  tooltip: 'تغيير الموقع',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LocationPage(store: s)),
                  ),
                  icon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ),
          ),
          actions: [
            if (!seller)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Badge(
                  isLabelVisible: s.cartCount > 0,
                  label: Text('${s.cartCount}'),
                  child: SizedBox.square(
                    dimension: 48,
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(shape: const CircleBorder()),
                      tooltip: 'السلة',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CartPage(store: s)),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (s.demo)
              Container(
                width: double.infinity,
                color: sage,
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: const Text(
                  'نسخة تجريبية • بيانات توضيحية لا ترسل طلبات حقيقية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: green),
                ),
              ),
            if (s.error != null)
              MaterialBanner(
                content: Text(s.error!),
                actions: [
                  TextButton(
                    onPressed: s.refresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            if (s.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: content,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: sage,
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: destinations,
        ),
      );
    },
  );
}

class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.onStart, required this.demo});
  final VoidCallback onStart;
  final bool demo;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: LayoutBuilder(
              builder: (context, c) {
                final intro = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Pill('من مطابخ نواكشوط، بكل حب'),
                    const SizedBox(height: 28),
                    const Brand(large: true),
                    const SizedBox(height: 14),
                    const Text(
                      'أكل تقليدي.. من قلب بيتنا',
                      style: TextStyle(
                        color: green,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اكتشف طعم الدار، واطلب وجبتك المفضلة\nمن أقرب مطبخ إليك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 17, height: 1.8),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('اكتشف المطابخ'),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'صنع بأيدٍ محلية  •  طازج كل يوم',
                      style: TextStyle(color: muted),
                    ),
                    if (demo)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Pill('تجربة التطبيق بدون حساب'),
                      ),
                  ],
                );
                final photo = ClipRRect(
                  borderRadius: BorderRadius.circular(120),
                  child: Image.asset(
                    'assets/images/couscous.png',
                    height: c.maxWidth > 700 ? 500 : 230,
                    fit: BoxFit.cover,
                  ),
                );
                if (c.maxWidth > 700) {
                  return Row(
                    children: [
                      Expanded(child: intro),
                      const SizedBox(width: 50),
                      Expanded(child: photo),
                    ],
                  );
                }
                return Column(
                  children: [photo, const SizedBox(height: 26), intro],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class Discover extends StatefulWidget {
  const Discover({super.key, required this.store, this.favoritesOnly = false});
  final AppController store;
  final bool favoritesOnly;
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String query = '', category = 'الكل';
  bool onlyOpen = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final sellers = s.sellers.where((v) {
      final matches = s.meals.where(
        (m) =>
            m.sellerId == v.id &&
            (category == 'الكل' || m.category == category),
      );
      return (!widget.favoritesOnly || s.favorites.contains(v.id)) &&
          (!onlyOpen || v.open) &&
          (category == 'الكل' || matches.isNotEmpty) &&
          (v.name.contains(query) ||
              v.area.contains(query) ||
              matches.any((m) => m.name.contains(query)));
    }).toList()..sort((a, b) => s.distance(a).compareTo(s.distance(b)));
    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          Heading(
            widget.favoritesOnly ? 'مطابخك المفضلة' : 'أهلاً بك، على سفرتنا',
            subtitle:
                '${s.area}  •  ${s.hasLocation ? 'حسب موقعك' : 'المسافات من مركز الحي'}',
          ),
          if (!widget.favoritesOnly)
            Container(
              height: 190,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'طعم يجمعنا',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Text(
                            'وصفات أصيلة، من بيوت قريبة',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFD5E4C8),
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'طازج اليوم  ✦  محضّر بحب',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE9C78B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Image.asset(
                      'assets/images/couscous.png',
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          TextField(
            onChanged: (v) => setState(() => query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'ابحث عن وجبة أو مطبخ...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  selectedColor: sage,
                  onSelected: (_) => setState(() => category = c),
                ),
              FilterChip(
                label: const Text('متاح الآن'),
                selected: onlyOpen,
                onSelected: (v) => setState(() => onlyOpen = v),
              ),
            ],
          ),
          Heading(
            'مطابخ قريبة منك',
            subtitle: '${sellers.length} مطابخ • لقمة هنية من أيدٍ محلية',
            trailing: const Icon(Icons.near_me_outlined, color: green),
          ),
          if (sellers.isEmpty)
            const EmptyState(
              'لا توجد مطابخ هنا',
              'جرّب بحثاً آخر أو غيّر الفئة.',
            ),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth > 800
                  ? 3
                  : c.maxWidth > 540
                  ? 2
                  : 1;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final seller in sellers)
                    SizedBox(
                      width: (c.maxWidth - 18 * (columns - 1)) / columns,
                      child: SellerCard(store: s, seller: seller),
                    ),
                ],
              );
            },
          ),
          if (!widget.favoritesOnly)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Panel(
                color: sage,
                child: Row(
                  children: [
                    const Icon(Icons.groups_outlined, color: green, size: 32),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'جمعة الأهل تستاهل',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'اجمع حصصك من أكثر من مطبخ',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => familyDialog(context, s),
                      child: const Text('طلب عائلي'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 26),
          const Center(
            child: Text(
              'مولات كسكس  •  أكل تقليدي بطعم الأصالة',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.store, required this.seller});
  final AppController store;
  final Seller seller;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerPage(store: store, sellerId: seller.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                const FoodPhoto(height: 160),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Pill(
                    seller.open ? '● متاح الآن' : 'مغلق',
                    color: seller.open ? green : muted,
                  ),
                ),
                Positioned(
                  top: 3,
                  left: 3,
                  child: IconButton.filled(
                    onPressed: () => store.favorite(seller.id),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: green,
                    ),
                    tooltip: 'المفضلة',
                    icon: Icon(
                      store.favorites.contains(seller.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Avatar(seller.name, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    seller.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const Icon(Icons.star_rounded, color: gold, size: 19),
                Text(
                  seller.rating == 0
                      ? 'جديد'
                      : seller.rating.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${seller.area}  •  ${store.distance(seller).toStringAsFixed(1)} كم تقريباً',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const Divider(height: 25),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    seller.hours,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'اكتشف الوجبات',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: green, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.chevron_left, color: green, size: 18),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> familyDialog(BuildContext context, AppController s) async {
  String quantity = '20';
  String category = 'الكسكس';
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('طلب يجمع العائلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'نوزّع الحصص على المطابخ المتاحة حسب المسافة. ستراجع الأسعار والمطابخ في السلة قبل التأكيد.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: categories
                  .skip(1)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => update(() => category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '20',
              onChanged: (value) => quantity = value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الحصص'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              try {
                s.familyOrder(category, int.tryParse(quantity) ?? 0);
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CartPage(store: s)),
                );
              } catch (e) {
                toast(context, friendlyError(e));
              }
            },
            child: const Text('تجميع الطلب'),
          ),
        ],
      ),
    ),
  );
}
