import 'package:flutter/material.dart';
import '../../../scan/presentation/scan_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/wishlist_item.dart';
import '../../domain/wishlist_category_utils.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/wishlist_dialog.dart';
import '../../../../core/utils/formatters.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final filteredItems = ref.watch(filteredWishlistProvider);
    final stats = ref.watch(wishlistStatsProvider);
    final activeFilter = ref.watch(wishlistFilterProvider);
    final activeCategory = ref.watch(wishlistCategoryFilterProvider);
    final categories = ref.watch(wishlistCategoriesProvider);
    final activeSort = ref.watch(wishlistSortProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search wishlist...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (val) =>
                    ref.read(wishlistSearchProvider.notifier).setSearch(val),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Wishlist',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (stats.totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stats.totalCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Scan a shopping list or product screenshot',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => startScan(context, target: 'wishlist'),
          ),
          IconButton(
            tooltip: _isSearching ? 'Close search' : 'Search items',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(wishlistSearchProvider.notifier).setSearch('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort items',
            icon: const Icon(Icons.sort),
            initialValue: activeSort,
            onSelected: (val) =>
                ref.read(wishlistSortProvider.notifier).setSort(val),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'custom',
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator, size: 18),
                    SizedBox(width: 8),
                    Text('Custom Order'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'priority',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Priority: High to Low'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price_desc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 18),
                    SizedBox(width: 8),
                    Text('Price: High to Low'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price_asc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 18),
                    SizedBox(width: 8),
                    Text('Price: Low to High'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Recently Added'),
                  ],
                ),
              ),
            ],
          ),
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: FilledButton.icon(
                onPressed: () => showWishlistDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New item'),
              ),
            ),
        ],
      ),
      floatingActionButton: !isWide
          ? FloatingActionButton.extended(
              onPressed: () => showWishlistDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New item'),
            )
          : null,
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load your wishlist."),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(wishlistProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allItems) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(wishlistProvider);
              await ref.read(wishlistProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                // Top Hero Summary Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildSummaryCard(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      stats: stats,
                    ),
                  ),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All (${stats.totalCount})',
                          value: 'all',
                          isSelected: activeFilter == 'all',
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Wanted (${stats.wantedCount})',
                          value: 'wanted',
                          isSelected: activeFilter == 'wanted',
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Purchased (${stats.purchasedCount})',
                          value: 'purchased',
                          isSelected: activeFilter == 'purchased',
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Filter Chips (scrollable horizontal bar)
                if (categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip(
                              label: 'All Categories',
                              icon: Icons.apps,
                              isSelected: activeCategory == 'all',
                              color: theme.colorScheme.primary,
                              onTap: () => ref
                                  .read(wishlistCategoryFilterProvider.notifier)
                                  .setCategory('all'),
                              theme: theme,
                            ),
                            ...categories.map((cat) {
                              final isSelected =
                                  activeCategory.toLowerCase() ==
                                  cat.toLowerCase();
                              final count = allItems
                                  .where(
                                    (i) =>
                                        i.category?.trim().toLowerCase() ==
                                        cat.toLowerCase(),
                                  )
                                  .length;
                              final color = WishlistCategoryUtils.getColor(cat);
                              final icon = WishlistCategoryUtils.getIcon(cat);

                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildCategoryChip(
                                  label: '$cat ($count)',
                                  icon: icon,
                                  isSelected: isSelected,
                                  color: color,
                                  onTap: () => ref
                                      .read(
                                        wishlistCategoryFilterProvider.notifier,
                                      )
                                      .setCategory(isSelected ? 'all' : cat),
                                  theme: theme,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 4)),

                // Item list or Empty State
                if (filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: _buildEmptyState(
                          theme: theme,
                          hasItemsInOtherFilters: allItems.isNotEmpty,
                          filter: activeFilter,
                          activeCategory: activeCategory,
                        ),
                      ),
                    ),
                  )
                else if (activeFilter == 'all' && activeSort == 'custom')
                  // Reorderable list for custom order
                  SliverToBoxAdapter(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Flutter's default desktop handle was drawn over the
                      // card's edge; the card shows its own handle instead.
                      buildDefaultDragHandles: false,
                      itemCount: filteredItems.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(wishlistProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildItemCard(
                          key: ValueKey(item.id),
                          context: context,
                          theme: theme,
                          isDark: isDark,
                          item: item,
                          canDrag: true,
                          dragIndex: index,
                        );
                      },
                    ),
                  )
                else
                  // Standard sliver list
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = filteredItems[index];
                        return _buildItemCard(
                          key: ValueKey(item.id),
                          context: context,
                          theme: theme,
                          isDark: isDark,
                          item: item,
                          canDrag: false,
                        );
                      }, childCount: filteredItems.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required WishlistStats stats,
  }) {
    final percent = (stats.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wishlist Target',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(stats.totalValue),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percent% Acquired',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stat counters
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  theme: theme,
                  icon: Icons.hourglass_top,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Wanted',
                  value:
                      '${stats.wantedCount} ${stats.wantedCount == 1 ? 'item' : 'items'} · ${formatMoney(stats.wantedValue)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  theme: theme,
                  icon: Icons.check_circle_outline,
                  iconColor: const Color(0xFF10B981),
                  title: 'Purchased',
                  value:
                      '${stats.purchasedCount} ${stats.purchasedCount == 1 ? 'item' : 'items'} · ${formatMoney(stats.purchasedValue)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required ThemeData theme,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(wishlistFilterProvider.notifier).setFilter(value),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimary : null,
      ),
      selectedColor: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard({
    required Key key,
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required WishlistItem item,
    required bool canDrag,
    int? dragIndex,
  }) {
    final priorityColor = switch (item.priority) {
      'high' => const Color(0xFFF43F5E),
      'low' => const Color(0xFF10B981),
      _ => const Color(0xFFF59E0B),
    };

    final priorityLabel = switch (item.priority) {
      'high' => 'High',
      'low' => 'Low',
      _ => 'Normal',
    };

    final card = Container(
      key: canDrag && dragIndex != null ? null : key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showWishlistDialog(context, existing: item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Interactive Checkbox / Circle
                GestureDetector(
                  onTap: () async {
                    final willBePurchased = !item.isPurchased;
                    await ref
                        .read(wishlistProvider.notifier)
                        .togglePurchased(item);

                    if (willBePurchased && context.mounted) {
                      // Offer converting to expense!
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Purchased "${item.title}"!'),
                          action: SnackBarAction(
                            label: 'Record Expense',
                            textColor: Colors.amberAccent,
                            onPressed: () {
                              showConvertToExpenseDialog(
                                context,
                                ref: ref,
                                item: item.copyWith(isPurchased: true),
                              );
                            },
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isPurchased
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      border: Border.all(
                        color: item.isPurchased
                            ? const Color(0xFF10B981)
                            : Colors.grey.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: item.isPurchased
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Title, priority badge, notes, link
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: item.isPurchased
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isPurchased
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.category != null &&
                              item.category!.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                final currentCat = ref.read(
                                  wishlistCategoryFilterProvider,
                                );
                                if (currentCat.toLowerCase() ==
                                    item.category!.trim().toLowerCase()) {
                                  ref
                                      .read(
                                        wishlistCategoryFilterProvider.notifier,
                                      )
                                      .setCategory('all');
                                } else {
                                  ref
                                      .read(
                                        wishlistCategoryFilterProvider.notifier,
                                      )
                                      .setCategory(item.category!.trim());
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: WishlistCategoryUtils.getColor(
                                    item.category,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      WishlistCategoryUtils.getIcon(
                                        item.category,
                                      ),
                                      size: 10,
                                      color: WishlistCategoryUtils.getColor(
                                        item.category,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.category!.trim(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: WishlistCategoryUtils.getColor(
                                          item.category,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              priorityLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.note != null && item.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (item.link != null && item.link!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.link!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.link!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Price
                if (item.estimatedPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(item.estimatedPrice!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.isPurchased
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (item.isPurchased)
                        const Text(
                          'Bought',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),

                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) async {
                    switch (action) {
                      case 'record_expense':
                        showConvertToExpenseDialog(
                          context,
                          ref: ref,
                          item: item,
                        );
                        break;
                      case 'edit':
                        showWishlistDialog(context, existing: item);
                        break;
                      case 'toggle':
                        await ref
                            .read(wishlistProvider.notifier)
                            .togglePurchased(item);
                        break;
                      case 'delete':
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('Delete Wishlist Item?'),
                            content: Text(
                              'Are you sure you want to remove "${item.title}" from your wishlist?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(wishlistProvider.notifier)
                              .deleteItem(item.id);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'record_expense',
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Record as Expense'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Item'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            item.isPurchased
                                ? Icons.undo
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.isPurchased
                                ? 'Mark as Wanted'
                                : 'Mark as Purchased',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canDrag && dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: 'Drag to reorder',
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.drag_indicator, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!canDrag || dragIndex == null) return card;
    // Long-press anywhere to drag (touch); the handle below drags right away.
    return ReorderableDelayedDragStartListener(
      key: key,
      index: dragIndex,
      child: card,
    );
  }

  Widget _buildEmptyState({
    required ThemeData theme,
    required bool hasItemsInOtherFilters,
    required String filter,
    required String activeCategory,
  }) {
    if (activeCategory != 'all') {
      final color = WishlistCategoryUtils.getColor(activeCategory);
      final icon = WishlistCategoryUtils.getIcon(activeCategory);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            'No items in "$activeCategory"',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You haven\'t added any wishlist items under this category yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(wishlistCategoryFilterProvider.notifier)
                .setCategory('all'),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('View All Categories'),
          ),
        ],
      );
    }

    if (hasItemsInOtherFilters) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filter == 'purchased'
                ? Icons.shopping_bag_outlined
                : Icons.hourglass_empty,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            filter == 'purchased'
                ? 'No purchased items yet'
                : 'No wanted items right now',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filter == 'purchased'
                ? 'Check off items as you acquire them to see them here.'
                : 'All your wishlist items have been acquired! Add more to keep dreaming.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.card_giftcard,
            size: 52,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Dream it. Plan it. Own it.',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Put items you want to buy, save up for, or treat yourself with.\nTrack their prices and mark them off as you get them!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => showWishlistDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add your first wish'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}
