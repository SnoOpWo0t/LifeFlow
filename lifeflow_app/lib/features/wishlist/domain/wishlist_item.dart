class WishlistItem {
  final int id;
  final String title;
  final String? note;
  final double? estimatedPrice;
  final String priority; // 'low', 'normal', 'high'
  final String? category; // e.g. 'Tech', 'Perfume', 'Fashion', 'Gaming', etc.
  final bool isPurchased;
  final String? link;
  final int sortOrder;
  final DateTime? createdAt;

  WishlistItem({
    required this.id,
    required this.title,
    this.note,
    this.estimatedPrice,
    this.priority = 'normal',
    this.category,
    this.isPurchased = false,
    this.link,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as int,
      title: json['title'] as String,
      note: json['note'] as String?,
      estimatedPrice: json['estimated_price'] != null
          ? double.tryParse(json['estimated_price'].toString())
          : null,
      priority: (json['priority'] as String?)?.toLowerCase() ?? 'normal',
      category: json['category'] as String?,
      isPurchased: json['is_purchased'] == true || json['is_purchased'] == 1,
      link: json['link'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (note != null) 'note': note,
      if (estimatedPrice != null) 'estimated_price': estimatedPrice,
      'priority': priority,
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      'is_purchased': isPurchased,
      if (link != null) 'link': link,
      'sort_order': sortOrder,
    };
  }

  WishlistItem copyWith({
    int? id,
    String? title,
    String? note,
    double? estimatedPrice,
    String? priority,
    String? category,
    bool clearCategory = false,
    bool? isPurchased,
    String? link,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      priority: priority ?? this.priority,
      category: clearCategory ? null : (category ?? this.category),
      isPurchased: isPurchased ?? this.isPurchased,
      link: link ?? this.link,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
