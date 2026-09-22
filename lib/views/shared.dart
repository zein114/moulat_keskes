import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

const green = Color(0xFF075442);
const cream = Color(0xFFF8F7EE);
const sage = Color(0xFFE8EEDC);
const ink = Color(0xFF233E34);
const muted = Color(0xFF788377);
const line = Color(0xFFE5E7DB);
const gold = Color(0xFFBD8D42);
const categories = ['الكل', 'الكسكس', 'الباسي', 'العيش'];
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
String friendlyError(Object e) {
  if (e is StateError) return e.message;
  if (e is PostgrestException) {
    if (e.code == '42501') {
      return 'صلاحيات قاعدة البيانات تمنع هذه العملية. تحقق من RLS وطبّق migration.';
    }
    if (e.code == 'PGRST116') return 'البيانات المطلوبة غير موجودة في قاعدة البيانات.';
    return 'خطأ قاعدة البيانات (${e.code}): ${e.message}';
  }
  final text = e.toString();
  if (text.contains('price changed')) {
    return 'تغير سعر وجبة. حدّث السلة وراجع الإجمالي قبل التأكيد.';
  }
  if (text.contains('stock')) return 'تغير المخزون. حدّث القائمة وراجع الكمية.';
  if (text.contains('Invalid login')) return 'بيانات الدخول غير صحيحة.';
  if (text.contains('Email not confirmed')) {
    return 'أكد بريدك الإلكتروني أولاً.';
  }
  return 'تعذر إتمام العملية. تحقق من الاتصال وحاول مجدداً.';
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/logo.png',
        width: large ? 140 : 40,
        height: large ? 140 : 40,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      Text(
        'مولات كسكس',
        style: TextStyle(
          fontSize: large ? 36 : 22,
          fontWeight: FontWeight.bold,
          color: green,
        ),
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = green});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: muted, height: 1.7),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class FoodPhoto extends StatelessWidget {
  const FoodPhoto({
    super.key,
    this.height = 180,
    this.url = '',
    this.category = 'الكسكس',
  });
  final double height;
  final String url, category;
  @override
  Widget build(BuildContext context) {
    final fallback = category == 'الكسكس'
        ? Image.asset(
            'assets/images/couscous.png',
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : Container(
            height: height,
            color: sage,
            alignment: Alignment.center,
            child: Icon(
              category == 'العيش' ? Icons.rice_bowl : Icons.ramen_dining,
              size: height * .46,
              color: green,
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 26});
  final String name;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: sage,
    child: Text(
      name.isEmpty ? 'م' : name.substring(0, 1),
      style: TextStyle(
        color: green,
        fontSize: radius,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.ramen_dining,
    this.action,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: sage,
            child: Icon(icon, size: 38, color: green),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.8),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 20), child: action!),
        ],
      ),
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.bottom,
  });
  final String title;
  final Widget child;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: child,
      ),
    ),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            child: Padding(padding: const EdgeInsets.all(16), child: bottom),
          ),
  );
}

class MealTile extends StatelessWidget {
  const MealTile({
    super.key,
    required this.meal,
    required this.onTap,
    this.edit = false,
  });
  final Meal meal;
  final VoidCallback onTap;
  final bool edit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: FoodPhoto(
              height: 86,
              category: meal.category,
              url: meal.imageUrl,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meal.price} أوقية',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  meal.stock > 0 ? '${meal.stock} حصص متوفرة' : 'نفدت الكمية',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: edit || meal.stock > 0 ? onTap : null,
            tooltip: edit ? 'تعديل الوجبة' : 'أضف للسلة',
            icon: Icon(edit ? Icons.edit_outlined : Icons.add),
          ),
        ],
      ),
    ),
  );
}
