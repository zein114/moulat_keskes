class Seller {
  const Seller({
    required this.id,
    required this.name,
    required this.area,
    this.bio = '',
    this.phone = '',
    this.lat = 18.0735,
    this.lng = -15.9582,
    this.open = true,
    this.hours = '18:00 – 00:00',
    this.rating = 0,
  });
  final String id, name, area, bio, phone, hours;
  final double lat, lng, rating;
  final bool open;
  factory Seller.fromJson(Map<String, dynamic> j) => Seller(
    id: j['id'],
    name: j['name'],
    area: j['area'],
    bio: j['bio'] ?? '',
    phone: j['phone'] ?? '',
    lat: (j['latitude'] as num).toDouble(),
    lng: (j['longitude'] as num).toDouble(),
    open: j['is_open'],
    hours: j['hours'] ?? '',
    rating: (j['rating'] as num? ?? 0).toDouble(),
  );
}

class Meal {
  const Meal({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.description = '',
    this.imageUrl = '',
  });
  final String id, sellerId, name, category, description, imageUrl;
  final int price, stock;
  Meal withStock(int value) => Meal(
    id: id,
    sellerId: sellerId,
    name: name,
    category: category,
    price: price,
    stock: value,
    description: description,
    imageUrl: imageUrl,
  );
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
    id: j['id'],
    sellerId: j['seller_id'],
    name: j['name'],
    category: j['category'],
    price: j['price'],
    stock: j['stock'],
    description: j['description'] ?? '',
    imageUrl: j['image_url'] ?? '',
  );
}

const orderStates = ['pending', 'preparing', 'ready', 'delivered'];
const orderLabels = [
  'تم استلام الطلب',
  'قيد التحضير',
  'جاهز للاستلام',
  'تم التسليم',
];

class FoodOrder {
  FoodOrder({
    required this.id,
    required this.sellerId,
    required this.total,
    required this.items,
    this.status = 'pending',
    this.fulfillment = 'pickup',
    this.address = '',
    this.customerName = '',
    this.customerId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  final String id, sellerId, fulfillment, address, customerName, customerId;
  final int total;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  String status;
  String get label => status == 'cancelled'
      ? 'ملغي'
      : orderLabels[orderStates.indexOf(status).clamp(0, 3)];
  factory FoodOrder.fromJson(Map<String, dynamic> j) => FoodOrder(
    id: j['id'],
    sellerId: j['seller_id'],
    total: j['total'],
    items: List<Map<String, dynamic>>.from(j['items']),
    status: j['status'],
    fulfillment: j['fulfillment'],
    address: j['address'] ?? '',
    customerName: j['customer_name'] ?? '',
    customerId: j['customer_id'] ?? '',
    createdAt: DateTime.parse(j['created_at']),
  );
}

const demoSellers = [
  Seller(
    id: 'khadija',
    name: 'أم خديجة',
    area: 'تفرغ زينة',
    phone: '',
    bio: 'من مطبخي إلى مائدتكم، وصفات موريتانية أصيلة أحضّرها كل يوم بكل حب.',
    rating: 4.9,
  ),
  Seller(
    id: 'mariam',
    name: 'مريم',
    area: 'لكصر',
    lat: 18.098,
    lng: -15.974,
    rating: 4.8,
    bio: 'أكل الدار بطعم زمان. وجبات طازجة ومكونات مختارة بعناية.',
  ),
  Seller(
    id: 'fatima',
    name: 'فاطمة',
    area: 'تيارت',
    lat: 18.113,
    lng: -15.946,
    rating: 4.7,
    bio: 'أهلاً بكم في مطبخي، لقمة هنية لكل العائلة.',
  ),
];
const demoMeals = [
  Meal(
    id: 'm1',
    sellerId: 'khadija',
    name: 'كسكس بالخضار واللحم',
    category: 'الكسكس',
    price: 250,
    stock: 8,
    description: 'كسكس مفوّر على البخار مع خضار موسمية ولحم طري.',
  ),
  Meal(
    id: 'm2',
    sellerId: 'khadija',
    name: 'باسي تقليدي',
    category: 'الباسي',
    price: 200,
    stock: 6,
    description: 'باسي موريتاني بوصفة عائلية أصيلة.',
  ),
  Meal(
    id: 'm3',
    sellerId: 'mariam',
    name: 'كسكس الدار',
    category: 'الكسكس',
    price: 230,
    stock: 7,
    description: 'حصة سخية، محضرة يومياً.',
  ),
  Meal(
    id: 'm4',
    sellerId: 'fatima',
    name: 'عيش بالحليب',
    category: 'العيش',
    price: 150,
    stock: 12,
    description: 'عيش تقليدي ناعم مع الحليب.',
  ),
  Meal(
    id: 'm5',
    sellerId: 'fatima',
    name: 'كسكس عائلي',
    category: 'الكسكس',
    price: 240,
    stock: 5,
  ),
];
