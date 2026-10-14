import '../../../core/network/api_client.dart';
import '../domain/wishlist_item.dart';

class WishlistRepository {
  final ApiClient _apiClient;

  WishlistRepository(this._apiClient);

  Future<List<WishlistItem>> fetchWishlist() async {
    final response = await _apiClient.dio.get('/wishlist');
    final List list = response.data is List ? response.data : (response.data['data'] ?? []);
    return list.map((json) => WishlistItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<WishlistItem> createItem(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/wishlist', data: data);
    final json = response.data is Map<String, dynamic> ? response.data : (response.data['data'] as Map<String, dynamic>);
    return WishlistItem.fromJson(json);
  }

  Future<WishlistItem> updateItem(int id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put('/wishlist/$id', data: data);
    final json = response.data is Map<String, dynamic> ? response.data : (response.data['data'] as Map<String, dynamic>);
    return WishlistItem.fromJson(json);
  }

  Future<void> deleteItem(int id) async {
    await _apiClient.dio.delete('/wishlist/$id');
  }

  Future<void> reorder(List<int> order) async {
    await _apiClient.dio.post('/wishlist/reorder', data: {'order': order});
  }
}
