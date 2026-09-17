import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/models.dart';
import 'auth.dart';
import 'shared.dart';

Seller? _ownSeller(AppController store) {
  if (!store.signedIn) return null;
  for (final seller in store.sellers) {
    if (seller.id == store.userId) return seller;
  }
  return null;
}

Map<String, dynamic> _sellerValues(Seller seller) => {
  'name': seller.name,
  'area': seller.area,
  'bio': seller.bio,
  'phone': seller.phone,
  'latitude': seller.lat,
  'longitude': seller.lng,
  'hours': seller.hours,
  'is_open': seller.open,
};

void _editSeller(BuildContext context, AppController store) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SellerEditorPage(store: store, seller: _ownSeller(store)),
    ),
  );
}

void _editMeal(BuildContext context, AppController store, [Meal? meal]) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MealEditorPage(store: store, meal: meal),
    ),
  );
}

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key, required this.store});

  final AppController store;

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  bool _saving = false;

  Future<void> _toggle(Seller seller, bool open) async {
    setState(() => _saving = true);
    try {
      await widget.store.saveSeller({
        ..._sellerValues(seller),
        'is_open': open,
      });
      if (mounted) {
        toast(
          context,
          open ? 'مطبخك متاح للطلبات.' : 'تم إغلاق المطبخ مؤقتاً.',
        );
      }
    } catch (error) {
      if (mounted) toast(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final seller = _ownSeller(store);
    if (seller == null) return _SellerSetup(store: store);
    final now = DateTime.now();
    final orders = store.orders
        .where((order) => order.sellerId == seller.id)
        .toList();
    final today = orders.where((order) {
      final date = order.createdAt.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final completed = today
        .where((order) => order.status == 'delivered')
        .length;
    final active = today
        .where(
          (order) => order.status != 'delivered' && order.status != 'cancelled',
        )
        .length;
    final total = today
        .where((order) => order.status == 'delivered')
        .fold<int>(0, (sum, order) => sum + order.total);
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Heading(
            'مرحباً، ${seller.name}',
            subtitle: 'من مطبخك تبدأ الحكاية. هذا يومك في لمحة.',
            trailing: Avatar(seller.name),
          ),
          Panel(
            color: green,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF306F5C),
                  child: Icon(Icons.storefront_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.open ? 'مطبخك مفتوح' : 'المطبخ مغلق حالياً',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        seller.open
                            ? 'جاهز لاستقبال طلبات جديدة'
                            : 'يمكنك متابعة طلباتك الحالية',
                        style: const TextStyle(
                          color: Color(0xFFD5E4C8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Switch(
                    value: seller.open,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF689567),
                    onChanged: (open) => _toggle(seller, open),
                  ),
              ],
            ),
          ),
          const Heading(
            'إحصائيات اليوم',
            subtitle: 'تُحسب من طلبات اليوم حسب توقيت جهازك',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    title: 'إجمالي الطلبات',
                    value: '${today.length}',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _Metric(
                    width: width,
                    title: 'قيد المعالجة',
                    value: '$active',
                    icon: Icons.soup_kitchen_outlined,
                  ),
                  _Metric(
                    width: width,
                    title: 'تم تسليمها',
                    value: '$completed',
                    icon: Icons.task_alt,
                  ),
                  _Metric(
                    width: width,
                    title: 'قيمة الطلبات المسلّمة',
                    value: '$total أوقية',
                    icon: Icons.payments_outlined,
                  ),
                ],
              );
            },
          ),
          Heading(
            'وجباتي',
            subtitle: '${store.ownMeals.length} وجبات في مطبخك',
            trailing: TextButton.icon(
              onPressed: () => _editMeal(context, store),
              icon: const Icon(Icons.add),
              label: const Text('إضافة وجبة'),
            ),
          ),
          if (store.ownMeals.isEmpty)
            EmptyState(
              'أول وجبة، أول حكاية',
              'أضف صورة ووصفاً وسعراً، وحدد عدد الحصص المتوفرة.',
              action: FilledButton.icon(
                onPressed: () => _editMeal(context, store),
                icon: const Icon(Icons.add),
                label: const Text('إضافة أول وجبة'),
              ),
            )
          else
            for (final meal in store.ownMeals.take(3))
              MealTile(
                meal: meal,
                edit: true,
                onTap: () => _editMeal(context, store, meal),
              ),
          const Heading(
            'آخر الطلبات',
            subtitle: 'افتح تبويب الطلبات لمتابعة مراحل التحضير والتسليم',
          ),
          if (orders.isEmpty)
            const EmptyState(
              'بانتظار أول طلب',
              'ستظهر الطلبات هنا بمجرد أن يطلب أحدهم من مطبخك.',
              icon: Icons.receipt_long_outlined,
            )
          else
            for (final order in orders.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: green),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName.isEmpty
                                  ? 'طلب جديد'
                                  : order.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${order.total} أوقية • ${order.items.length} أصناف',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(child: Pill(order.label)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _editSeller(context, store),
            icon: const Icon(Icons.tune),
            label: const Text('إعدادات المطبخ والموقع'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });
  final double width;
  final String title, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Panel(
      color: sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green, size: 23),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: green,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: muted)),
        ],
      ),
    ),
  );
}

class _SellerSetup extends StatelessWidget {
  const _SellerSetup({required this.store});
  final AppController store;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      EmptyState(
        'لنفتح باب مطبخك',
        'أكمل اسم المطبخ وموقعه ومعلومات التواصل، ثم أضف وجباتك لتظهر للزبائن.',
        icon: Icons.storefront_outlined,
        action: FilledButton.icon(
          onPressed: () => _editSeller(context, store),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('إعداد المطبخ'),
        ),
      ),
    ],
  );
}

class MealsView extends StatelessWidget {
  const MealsView({super.key, required this.store});
  final AppController store;

  @override
  Widget build(BuildContext context) {
    if (_ownSeller(store) == null) return _SellerSetup(store: store);
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Heading(
            'وجبات من قلب الدار',
            subtitle: 'حدّث الحصص يومياً حتى يجد الزبائن المتاح فعلاً.',
          ),
          FilledButton.icon(
            onPressed: () => _editMeal(context, store),
            icon: const Icon(Icons.add),
            label: const Text('إضافة وجبة جديدة'),
          ),
          const SizedBox(height: 22),
          if (store.ownMeals.isEmpty)
            const EmptyState(
              'قائمة مطبخك تبدأ هنا',
              'أضف أول وجبة وأخبرنا بما يجعلها مميزة.',
            )
          else
            for (final meal in store.ownMeals)
              MealTile(
                meal: meal,
                edit: true,
                onTap: () => _editMeal(context, store, meal),
              ),
          const SizedBox(height: 12),
          const Panel(
            color: sage,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'عند نفاد الوجبة، اجعل الحصص المتوفرة صفراً. يمكنك إعادة توفيرها بتحديث الكمية لاحقاً.',
                    style: TextStyle(color: green, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MealEditorPage extends StatefulWidget {
  const MealEditorPage({super.key, required this.store, this.meal});
  final AppController store;
  final Meal? meal;

  @override
  State<MealEditorPage> createState() => _MealEditorPageState();
}

class _MealEditorPageState extends State<MealEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.meal?.name ?? '');
  late final _price = TextEditingController(
    text: widget.meal?.price.toString() ?? '',
  );
  late final _stock = TextEditingController(
    text: widget.meal?.stock.toString() ?? '0',
  );
  late final _description = TextEditingController(
    text: widget.meal?.description ?? '',
  );
  late final _image = TextEditingController(text: widget.meal?.imageUrl ?? '');
  late String _category = widget.meal?.category ?? categories[1];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _price, _stock, _description, _image]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveMeal(
        id: widget.meal?.id,
        title: _name.text.trim(),
        category: _category,
        price: int.parse(_price.text.trim()),
        stock: int.parse(_stock.text.trim()),
        description: _description.text.trim(),
        imageUrl: _image.text.trim(),
      );
      if (!mounted) return;
      toast(context, 'تم حفظ الوجبة.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.meal == null ? 'إضافة وجبة جديدة' : 'تعديل الوجبة',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FoodPhoto(height: 230, category: _category, url: _image.text.trim()),
          const SizedBox(height: 22),
          TextFormField(
            controller: _name,
            enabled: !_busy,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'اسم الوجبة',
              hintText: 'مثلاً: كسكس بالخضار واللحم',
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'أدخل اسم الوجبة.' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'الفئة'),
            items: categories
                .skip(1)
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر (أوقية)'),
                  validator: (value) {
                    final price = int.tryParse(value?.trim() ?? '');
                    return price == null || price <= 0 || price > 1000000
                        ? 'أدخل عدداً من ١ إلى ١٬٠٠٠٬٠٠٠.'
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحصص المتوفرة',
                  ),
                  validator: (value) {
                    final stock = int.tryParse(value?.trim() ?? '');
                    return stock == null || stock < 0 || stock > 100000
                        ? 'أدخل عدداً من ٠ إلى ١٠٠٬٠٠٠.'
                        : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'وصف الوجبة (اختياري)',
              hintText: 'المكونات، حجم الحصة، وما يميز وصفتك...',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _image,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رابط صورة HTTPS (اختياري)',
              hintText: 'https://…',
              helperText: 'استخدم صورة عامة لديك حق استخدامها.',
            ),
            onFieldSubmitted: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final uri = Uri.tryParse(value.trim());
              return uri == null || uri.scheme != 'https' || uri.host.isEmpty
                  ? 'أدخل رابط HTTPS صحيحاً.'
                  : null;
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy ? null : () => setState(() {}),
              icon: const Icon(Icons.image_outlined),
              label: const Text('معاينة الصورة'),
            ),
          ),
          const Text(
            'إذا تركت الرابط فارغاً ستظهر صورة أو رسمة توضيحية للفئة.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ الوجبة'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class SellerEditorPage extends StatefulWidget {
  const SellerEditorPage({super.key, required this.store, this.seller});
  final AppController store;
  final Seller? seller;

  @override
  State<SellerEditorPage> createState() => _SellerEditorPageState();
}

class _SellerEditorPageState extends State<SellerEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.seller?.name ?? widget.store.name,
  );
  late final _area = TextEditingController(
    text: widget.seller?.area ?? widget.store.area,
  );
  late final _phone = TextEditingController(text: widget.seller?.phone ?? '');
  late final _hours = TextEditingController(
    text: widget.seller?.hours ?? '18:00 – 00:00',
  );
  late final _bio = TextEditingController(text: widget.seller?.bio ?? '');
  late final _latitude = TextEditingController(
    text: widget.seller?.lat.toString() ?? widget.store.latitude.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.seller?.lng.toString() ?? widget.store.longitude.toString(),
  );
  late bool _open = widget.seller?.open ?? true;
  bool _busy = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _area,
      _phone,
      _hours,
      _bio,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      await widget.store.locate();
      if (!mounted) return;
      setState(() {
        _latitude.text = widget.store.latitude.toString();
        _longitude.text = widget.store.longitude.toString();
      });
      toast(context, 'تم تحديد الإحداثيات. تأكد أنها موقع المطبخ.');
    } catch (error) {
      if (mounted) toast(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveSeller({
        'name': _name.text.trim(),
        'area': _area.text.trim(),
        'phone': _phone.text.trim(),
        'hours': _hours.text.trim(),
        'bio': _bio.text.trim(),
        'is_open': _open,
        'latitude': double.parse(_latitude.text.trim()),
        'longitude': double.parse(_longitude.text.trim()),
      });
      if (!mounted) return;
      toast(context, 'تم حفظ معلومات المطبخ.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _coordinate(String? text, double min, double max) {
    final value = double.tryParse(text?.trim() ?? '');
    return value == null || !value.isFinite || value < min || value > max
        ? 'أدخل قيمة بين $min و $max.'
        : null;
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.seller == null ? 'إعداد مطبخي' : 'معلومات المطبخ',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Panel(
            color: sage,
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: green, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'هذه المعلومات تظهر للزبائن وتساعدهم على الوصول إلى مطبخك والتواصل معك.',
                    style: TextStyle(color: green, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _name,
            enabled: !_busy,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'اسم المطبخ / البائعة',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'أدخل الاسم من حرفين على الأقل.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _area,
            enabled: !_busy,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'الحي والمدينة'),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'أدخل الحي والمدينة.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف (اختياري)',
              hintText: '+222 …',
            ),
            validator: (value) {
              final phone = value?.trim() ?? '';
              if (phone.isEmpty) return null;
              return RegExp(r'^\+?[0-9 ()-]{7,24}$').hasMatch(phone)
                  ? null
                  : 'أدخل رقم هاتف صحيحاً مع رمز الدولة.';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hours,
            enabled: !_busy,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'ساعات العمل',
              hintText: 'مثلاً: يومياً من السادسة مساءً حتى منتصف الليل',
            ),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'أدخل ساعات العمل.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bio,
            enabled: !_busy,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'حكاية مطبخك (اختياري)',
            ),
          ),
          const Heading(
            'موقع المطبخ',
            subtitle: 'راجع الإحداثيات بدقة؛ تظهر على الخريطة للزبائن.',
          ),
          OutlinedButton.icon(
            onPressed: _busy || _locating ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: Text(
              _locating ? 'جارٍ تحديد الموقع...' : 'استخدام موقعي الحالي',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _latitude,
            enabled: !_busy && !_locating,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'خط العرض (Latitude)'),
            validator: (value) => _coordinate(value, -90, 90),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _longitude,
            enabled: !_busy && !_locating,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'خط الطول (Longitude)',
            ),
            validator: (value) => _coordinate(value, -180, 180),
          ),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _open,
            onChanged: _busy ? null : (value) => setState(() => _open = value),
            title: const Text('متاح لاستقبال الطلبات'),
            subtitle: const Text(
              'أغلق المطبخ مؤقتاً عند الانشغال أو انتهاء اليوم.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || _locating ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ معلومات المطبخ'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class AccountView extends StatefulWidget {
  const AccountView({super.key, required this.store});
  final AppController store;

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  bool _busy = false;

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await widget.store.signOut();
      await widget.store.refresh();
    } catch (error) {
      if (mounted) toast(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _help() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Heading('نحن حول سفرة واحدة'),
              Text(
                'كيف أطلب؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: green,
                  fontSize: 18,
                ),
              ),
              Text(
                'اختر مطبخاً مفتوحاً، أضف حصصك إلى السلة، ثم راجع طريقة الاستلام وأرسل الطلب. تابع حالته من تبويب الطلبات.',
                style: TextStyle(height: 1.9),
              ),
              SizedBox(height: 20),
              Text(
                'الدفع والتواصل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: green,
                  fontSize: 18,
                ),
              ),
              Text(
                'الدفع عند الاستلام فقط في هذه النسخة. يمكنك الاتصال بالبائعة إذا أضافت رقم هاتفها. لا توجد دردشة داخل التطبيق أو مدفوعات إلكترونية مفعّلة.',
                style: TextStyle(height: 1.9),
              ),
              SizedBox(height: 20),
              Text(
                'متى تتحدث الطلبات؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: green,
                  fontSize: 18,
                ),
              ),
              Text(
                'اسحب القائمة للتحديث. عند الاتصال بالحساب، يجدد التطبيق البيانات دورياً أثناء فتحه. لا توجد إشعارات دفع عند إغلاق التطبيق في هذه النسخة.',
                style: TextStyle(height: 1.9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final seller = _ownSeller(store);
    final name = store.demo ? 'ضيف التجربة' : store.name;
    final canSell = store.demo || (store.signedIn && store.role == 'seller');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        Center(child: Avatar(name, radius: 42)),
        const SizedBox(height: 14),
        Center(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: green,
              fontSize: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Pill(
            store.demo
                ? 'حساب توضيحي'
                : store.signedIn
                ? store.role == 'seller'
                      ? 'حساب بائعة'
                      : 'حساب زبون'
                : 'تصفح كضيف',
          ),
        ),
        if (!store.demo && store.signedIn)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              AuthController(store).email,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
          ),
        const SizedBox(height: 28),
        if (store.demo) ...[
          const Panel(
            color: sage,
            child: Text(
              'هذه تجربة ببيانات توضيحية محفوظة في الذاكرة. تُمسح التغييرات عند إعادة تشغيل التطبيق. استكشف واجهتي الزبون والبائعة من الزر أدناه.',
              style: TextStyle(color: green, height: 1.8),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (!store.signedIn) ...[
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => AuthPage(store: store)),
            ),
            icon: const Icon(Icons.login),
            label: const Text('تسجيل الدخول أو إنشاء حساب'),
          ),
          const SizedBox(height: 18),
        ],
        if (canSell) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'مساحة البائعة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: green,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.sellerMode
                      ? 'يمكنك العودة لاكتشاف المطابخ والطلب منها.'
                      : 'أدر مطبخك ووجباتك وتابع طلبات الزبائن.',
                  style: const TextStyle(color: muted, height: 1.7),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: store.switchMode,
                  icon: Icon(
                    store.sellerMode
                        ? Icons.shopping_bag_outlined
                        : Icons.storefront_outlined,
                  ),
                  label: Text(
                    store.sellerMode
                        ? 'التبديل إلى واجهة الزبون'
                        : 'فتح لوحة البائعة',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AccountRow(
            icon: Icons.person_outline,
            title: seller == null ? 'إعداد معلومات المطبخ' : 'معلومات المطبخ',
            subtitle: 'الاسم والموقع والتواصل وساعات العمل',
            onTap: () => _editSeller(context, store),
          ),
        ],
        _AccountRow(
          icon: Icons.help_outline,
          title: 'المساعدة',
          subtitle: 'الطلبات والدفع والتواصل',
          onTap: _help,
        ),
        const SizedBox(height: 20),
        if (store.signedIn && !store.demo)
          OutlinedButton.icon(
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(_busy ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB14C36),
            ),
          ),
        const SizedBox(height: 28),
        const Text(
          'مولات كسكس\nأكل تقليدي.. من قلب بيتنا',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.8),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: green),
        onTap: onTap,
      ),
    ),
  );
}
