import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/wishlist_repository.dart';
import '../../domain/wishlist_item.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(localDbProvider));
});

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistItem>>(
      WishlistNotifier.new,
    );

/// Read from the device; rebuilds after any change.
class WishlistNotifier extends AsyncNotifier<List<WishlistItem>> {
  @override
  List<WishlistItem> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(wishlistRepositoryProvider).fetchWishlist();
  }

  Future<void> addItem(Map<String, dynamic> data) async {
    await ref.read(wishlistRepositoryProvider).createItem(data);
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    await ref.read(wishlistRepositoryProvider).updateItem(id, data);
  }

  Future<void> togglePurchased(WishlistItem item) async {
    await ref.read(wishlistRepositoryProvider).updateItem(item.id, {
      'is_purchased': !item.isPurchased,
    });
  }

  Future<void> deleteItem(String id) async {
    await ref.read(wishlistRepositoryProvider).deleteItem(id);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = List<WishlistItem>.from(state.value ?? []);
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex > items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    state = AsyncData(items); // show the new order straight away
    await ref
        .read(wishlistRepositoryProvider)
        .reorder(items.map((i) => i.id).toList());
  }
}

/// Filter state: 'all', 'wanted', 'purchased'
final wishlistFilterProvider = NotifierProvider<WishlistFilterNotifier, String>(
  WishlistFilterNotifier.new,
);

class WishlistFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) => state = filter;
}

/// Category filter state: 'all', or a specific category name
final wishlistCategoryFilterProvider =
    NotifierProvider<WishlistCategoryFilterNotifier, String>(
      WishlistCategoryFilterNotifier.new,
    );

class WishlistCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) => state = category;
}

/// Distinct non-empty custom categories currently present in the user's wishlist
final wishlistCategoriesProvider = Provider<List<String>>((ref) {
  final items = ref.watch(wishlistProvider).value ?? [];
  final categories = <String>{};
  for (final item in items) {
    final cat = item.category?.trim();
    if (cat != null && cat.isNotEmpty) {
      categories.add(cat);
    }
  }
  final list = categories.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
});

/// Sort state: 'custom', 'priority', 'price_asc', 'price_desc', 'newest'
final wishlistSortProvider = NotifierProvider<WishlistSortNotifier, String>(
  WishlistSortNotifier.new,
);

class WishlistSortNotifier extends Notifier<String> {
  @override
  String build() => 'custom';

  void setSort(String sort) => state = sort;
}

/// Search query
final wishlistSearchProvider = NotifierProvider<WishlistSearchNotifier, String>(
  WishlistSearchNotifier.new,
);

class WishlistSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

class WishlistStats {
  final int totalCount;
  final int wantedCount;
  final int purchasedCount;
  final double totalValue;
  final double wantedValue;
  final double purchasedValue;
  final double progress; // 0.0 to 1.0

  const WishlistStats({
    required this.totalCount,
    required this.wantedCount,
    required this.purchasedCount,
    required this.totalValue,
    required this.wantedValue,
    required this.purchasedValue,
    required this.progress,
  });
}

/// Computes summary metrics for the wishlist header
final wishlistStatsProvider = Provider<WishlistStats>((ref) {
  final items = ref.watch(wishlistProvider).value ?? [];

  int wanted = 0;
  int purchased = 0;
  double wantedVal = 0;
  double purchasedVal = 0;

  for (final item in items) {
    final price = item.estimatedPrice ?? 0;
    if (item.isPurchased) {
      purchased++;
      purchasedVal += price;
    } else {
      wanted++;
      wantedVal += price;
    }
  }

  final total = items.length;
  final totalVal = wantedVal + purchasedVal;
  final progress = total == 0 ? 0.0 : (purchased / total);

  return WishlistStats(
    totalCount: total,
    wantedCount: wanted,
    purchasedCount: purchased,
    totalValue: totalVal,
    wantedValue: wantedVal,
    purchasedValue: purchasedVal,
    progress: progress,
  );
});

/// Filtered and sorted wishlist items
final filteredWishlistProvider = Provider<List<WishlistItem>>((ref) {
  final items = ref.watch(wishlistProvider).value ?? [];
  final filter = ref.watch(wishlistFilterProvider);
  final categoryFilter = ref.watch(wishlistCategoryFilterProvider);
  final sort = ref.watch(wishlistSortProvider);
  final query = ref.watch(wishlistSearchProvider).trim().toLowerCase();

  var list = items;

  // Filter by status (wanted vs purchased)
  if (filter == 'wanted') {
    list = list.where((i) => !i.isPurchased).toList();
  } else if (filter == 'purchased') {
    list = list.where((i) => i.isPurchased).toList();
  }

  // Filter by custom category
  if (categoryFilter != 'all') {
    list = list.where((i) {
      final cat = i.category?.trim();
      return cat != null && cat.toLowerCase() == categoryFilter.toLowerCase();
    }).toList();
  }

  // Filter by search query (title, note, or category)
  if (query.isNotEmpty) {
    list = list.where((i) {
      final titleMatch = i.title.toLowerCase().contains(query);
      final noteMatch = i.note?.toLowerCase().contains(query) ?? false;
      final categoryMatch = i.category?.toLowerCase().contains(query) ?? false;
      return titleMatch || noteMatch || categoryMatch;
    }).toList();
  }

  // Sort
  final sortedList = List<WishlistItem>.from(list);
  switch (sort) {
    case 'priority':
      int rank(String p) => switch (p.toLowerCase()) {
        'high' => 3,
        'normal' => 2,
        'low' => 1,
        _ => 0,
      };
      sortedList.sort((a, b) => rank(b.priority).compareTo(rank(a.priority)));
      break;
    case 'price_asc':
      sortedList.sort(
        (a, b) => (a.estimatedPrice ?? 0).compareTo(b.estimatedPrice ?? 0),
      );
      break;
    case 'price_desc':
      sortedList.sort(
        (a, b) => (b.estimatedPrice ?? 0).compareTo(a.estimatedPrice ?? 0),
      );
      break;
    case 'newest':
      sortedList.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      break;
    case 'custom':
    default:
      // stored order (unpurchased first, then sort_order)
      break;
  }

  return sortedList;
});
