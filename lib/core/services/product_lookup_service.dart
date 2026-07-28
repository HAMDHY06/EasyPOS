import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductLookupResult {
  const ProductLookupResult({required this.name, this.brand, this.imageUrl});
  final String name;
  final String? brand;
  final String? imageUrl;
}

abstract class ProductLookupService {
  Future<ProductLookupResult?> lookup(String barcode);
}

class OpenFoodFactsLookupService implements ProductLookupService {
  OpenFoodFactsLookupService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ProductLookupResult?> lookup(String barcode) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 1 || body['product'] is! Map) return null;
      final product = Map<String, dynamic>.from(body['product'] as Map);
      final name = (product['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      return ProductLookupResult(
        name: name,
        brand: product['brands'] as String?,
        imageUrl: product['image_front_small_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
