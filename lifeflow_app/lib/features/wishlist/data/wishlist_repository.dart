import '../../../core/local/local_db.dart';
import '../domain/wishlist_item.dart';

/// Wishlist items, stored on the device (synced by SyncService).
class WishlistRepository {
  final LocalDb _db;
  static const _store = 'wishlist';

  WishlistRepository(this._db);

  /// Not-yet-bought first, then in the user's order, newest first on ties.
  List<WishlistItem> fetchWishlist() {
    final rows = _db.all(_store)
      ..sort((a, b) {
        final bought = (a['is_purchased'] == true ? 1 : 0).compareTo(
          b['is_purchased'] == true ? 1 : 0,
        );
        if (bought != 0) return bought;
        final order = ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        );
        if (order != 0) return order;
        return '${b['created_at']}'.compareTo('${a['created_at']}');
      });
    return rows.map(WishlistItem.fromJson).toList();
  }

  /// New items go to the top of the list.
  Future<WishlistItem> createItem(Map<String, dynamic> data) async {
    final orders = _db.all(_store).map((r) => (r['sort_order'] as num?) ?? 0);
    final top = orders.isEmpty
        ? 0
        : orders.reduce((a, b) => a < b ? a : b).toInt() - 1;
    return WishlistItem.fromJson(
      await _db.save(_store, {
        'priority': 'normal',
        'is_purchased': false,
        ...data,
        'sort_order': data['sort_order'] ?? top,
      }),
    );
  }

  Future<WishlistItem> updateItem(String id, Map<String, dynamic> data) async {
    return WishlistItem.fromJson(await _db.save(_store, data, id: id));
  }

  Future<void> deleteItem(String id) => _db.delete(_store, id);

  /// [order]: item ids, top first.
  Future<void> reorder(List<String> order) => _db.saveAll(_store, {
    for (final (i, id) in order.indexed) id: {'sort_order': i},
  });
}
