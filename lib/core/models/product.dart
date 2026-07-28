class Product {
  const Product({
    this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.brand,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockLevel,
    this.unitType = 'pcs',
    this.taxPercentage = 0,
    this.imagePath,
    this.expiryDate,
    this.notes,
    this.isFavourite = false,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? brand;
  final double costPrice;
  final double sellingPrice;
  final double stockQuantity;
  final double lowStockLevel;
  final String unitType;
  final double taxPercentage;
  final String? imagePath;
  final DateTime? expiryDate;
  final String? notes;
  final bool isFavourite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    String? brand,
    double? costPrice,
    double? sellingPrice,
    double? stockQuantity,
    double? lowStockLevel,
    String? unitType,
    double? taxPercentage,
    String? imagePath,
    DateTime? expiryDate,
    String? notes,
    bool? isFavourite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    barcode: barcode ?? this.barcode,
    categoryId: categoryId ?? this.categoryId,
    brand: brand ?? this.brand,
    costPrice: costPrice ?? this.costPrice,
    sellingPrice: sellingPrice ?? this.sellingPrice,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    lowStockLevel: lowStockLevel ?? this.lowStockLevel,
    unitType: unitType ?? this.unitType,
    taxPercentage: taxPercentage ?? this.taxPercentage,
    imagePath: imagePath ?? this.imagePath,
    expiryDate: expiryDate ?? this.expiryDate,
    notes: notes ?? this.notes,
    isFavourite: isFavourite ?? this.isFavourite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    barcode: map['barcode'] as String?,
    categoryId: map['category_id'] as int?,
    brand: map['brand'] as String?,
    costPrice: (map['cost_price'] as num).toDouble(),
    sellingPrice: (map['selling_price'] as num).toDouble(),
    stockQuantity: (map['stock_quantity'] as num).toDouble(),
    lowStockLevel: (map['low_stock_level'] as num).toDouble(),
    unitType: map['unit_type'] as String? ?? 'pcs',
    taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 0,
    imagePath: map['image_path'] as String?,
    expiryDate: _date(map['expiry_date']),
    notes: map['notes'] as String?,
    isFavourite: (map['is_favourite'] as int? ?? 0) == 1,
    createdAt: _date(map['created_at']),
    updatedAt: _date(map['updated_at']),
  );

  Map<String, Object?> toMap({bool includeId = false}) => {
    if (includeId && id != null) 'id': id,
    'name': name.trim(),
    'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
    'category_id': categoryId,
    'brand': brand?.trim(),
    'cost_price': costPrice,
    'selling_price': sellingPrice,
    'stock_quantity': stockQuantity,
    'low_stock_level': lowStockLevel,
    'unit_type': unitType,
    'tax_percentage': taxPercentage,
    'image_path': imagePath,
    'expiry_date': expiryDate?.toIso8601String(),
    'notes': notes?.trim(),
    'is_favourite': isFavourite ? 1 : 0,
    'updated_at': DateTime.now().toIso8601String(),
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

class CartItem {
  CartItem({required this.product, this.quantity = 1});

  final Product product;
  double quantity;

  double get total => product.sellingPrice * quantity;
  double get tax =>
      total * (product.taxPercentage.clamp(0, 100).toDouble() / 100);
}
