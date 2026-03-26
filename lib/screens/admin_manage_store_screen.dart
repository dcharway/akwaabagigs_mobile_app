import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class AdminManageStoreScreen extends StatefulWidget {
  const AdminManageStoreScreen({super.key});

  @override
  State<AdminManageStoreScreen> createState() =>
      _AdminManageStoreScreenState();
}

class _AdminManageStoreScreenState extends State<AdminManageStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _products = await ApiService.getProducts(activeOnly: false);
      _orders = await ApiService.getOrders(adminView: true);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final priceController = TextEditingController(
      text: ((product['pricePesewas'] as int) / 100).toStringAsFixed(0),
    );
    final stockController = TextEditingController(
      text: (product['stock'] as int).toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (GHS)',
                prefixText: 'GH₵ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              final stock = int.tryParse(stockController.text);
              if (price != null && stock != null) {
                Navigator.pop(ctx, {
                  'pricePesewas': (price * 100).round(),
                  'stock': stock,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateProduct(
            product['id'] as String, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Product updated'),
                backgroundColor: Colors.green),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  Future<void> _toggleProductStatus(Map<String, dynamic> product) async {
    final currentStatus = product['status'] as String;
    final newStatus =
        currentStatus == 'active' ? 'inactive' : 'active';
    try {
      await ApiService.updateProduct(
          product['id'] as String, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Product ${newStatus == 'active' ? 'activated' : 'deactivated'}'),
              backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Store'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
                text: 'Products (${_products.length})',
                icon: const Icon(Icons.inventory_2, size: 18)),
            Tab(
                text: 'Orders (${_orders.length})',
                icon: const Icon(Icons.receipt_long, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('No products'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        itemBuilder: (_, i) {
          final p = _products[i];
          final priceGhs = (p['pricePesewas'] as int) / 100;
          final isActive = p['status'] == 'active';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.red50 : AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag,
                  color: isActive ? AppColors.red600 : AppColors.gray400,
                ),
              ),
              title: Text(p['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'GH₵ ${priceGhs.toStringAsFixed(0)} • Stock: ${p['stock']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : AppColors.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF2E7D32)
                            : AppColors.gray500,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editProduct(p);
                      if (v == 'toggle') _toggleProductStatus(p);
                      if (v == 'delete') _confirmDelete(p);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Price/Stock'),
                            ],
                          )),
                      PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                  isActive
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(isActive
                                  ? 'Deactivate'
                                  : 'Activate'),
                            ],
                          )),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          )),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (_, i) {
          final o = _orders[i];
          final totalGhs = (o['totalPesewas'] as int) / 100;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(o['productName'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'GH₵ ${totalGhs.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Buyer: ${o['buyerName']}  •  Qty: ${o['quantity']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.gray600),
                  ),
                  Text(
                    'Phone: ${o['buyerPhone']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.gray600),
                  ),
                  if (o['deliveryAddress'] != null &&
                      (o['deliveryAddress'] as String).isNotEmpty)
                    Text(
                      'Delivery: ${o['deliveryAddress']}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.gray600),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Delete "${product['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteProduct(product['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Product deleted'),
                backgroundColor: Colors.green),
          );
          _loadData();
        }
      } catch (_) {}
    }
  }
}
