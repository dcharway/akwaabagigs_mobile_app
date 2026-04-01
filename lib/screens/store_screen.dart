import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import 'product_detail_screen.dart';
import 'admin_post_product_screen.dart';
import 'admin_manage_store_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _selectedCategory;
  bool _isAdmin = false;
  LiveQuery? _liveQuery;
  Subscription? _productSubscription;

  static const List<String> _categories = [
    'Fashion',
    'Electronics',
    'Food & Drinks',
    'Health & Beauty',
    'Home & Garden',
    'Arts & Crafts',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkAdmin();
    _subscribeLiveQuery();
  }

  @override
  void dispose() {
    if (_liveQuery != null && _productSubscription != null) {
      _liveQuery!.client.unSubscribe(_productSubscription!);
    }
    super.dispose();
  }

  /// LiveQuery: auto-refresh when any product is created/updated/deleted.
  Future<void> _subscribeLiveQuery() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.productClass));
      _productSubscription = await _liveQuery!.client.subscribe(query);
      _productSubscription!.on(LiveQueryEvent.create, (_) {
        if (mounted) _loadProducts();
      });
      _productSubscription!.on(LiveQueryEvent.update, (_) {
        if (mounted) _loadProducts();
      });
      _productSubscription!.on(LiveQueryEvent.delete, (_) {
        if (mounted) _loadProducts();
      });
    } catch (_) {}
  }

  Future<void> _checkAdmin() async {
    final admin = await ApiService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _products = await ApiService.getProducts(category: _selectedCategory);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akwaaba Store'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Post Item',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPostProductScreen()),
                );
                if (created == true) _loadProducts();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Manage Store',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminManageStoreScreen()),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildCategoryChip(null, 'All'),
                ..._categories
                    .map((c) => _buildCategoryChip(c, c)),
              ],
            ),
          ),
          // Products grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.red600))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                size: 64, color: AppColors.gray400),
                            const SizedBox(height: 16),
                            const Text('No products yet',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray800)),
                            const SizedBox(height: 4),
                            const Text('Check back soon!',
                                style: TextStyle(
                                    color: AppColors.gray500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: AppColors.red600,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(_products[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = value);
          _loadProducts();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.red600
                : AppColors.gray100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.gray700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final images = product['images'] as List<String>;
    final priceGhs = (product['pricePesewas'] as int) / 100;
    final stock = product['stock'] as int;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(productId: product['id'] as String),
          ),
        );
        _loadProducts(); // refresh stock
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.red50,
                          child: const Center(
                            child: Icon(Icons.shopping_bag,
                                color: AppColors.red600, size: 32),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.red50,
                          child: const Center(
                            child: Icon(Icons.shopping_bag,
                                color: AppColors.red600, size: 32),
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.red50,
                        child: const Center(
                          child: Icon(Icons.shopping_bag,
                              color: AppColors.red600, size: 32),
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.gray900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GH₵ ${priceGhs.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.red700,
                        ),
                      ),
                      if (stock <= 5 && stock > 0)
                        Text(
                          '$stock left',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (stock <= 0)
                        const Text(
                          'Sold out',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.red600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
