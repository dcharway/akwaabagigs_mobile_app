import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
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
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  LiveQuery? _liveQuery;
  Subscription? _productSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _subscribeLiveQuery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _unsubscribeLiveQuery();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _products = await ApiService.getProducts(activeOnly: false);
      _inventory = await ApiService.getInventory();
      _orders = await ApiService.getOrders(adminView: true);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _subscribeLiveQuery() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.productClass));
      _productSubscription = await _liveQuery!.client.subscribe(query);
      _productSubscription!.on(LiveQueryEvent.update, (_) {
        if (mounted) _loadData();
      });
    } catch (_) {}
  }

  void _unsubscribeLiveQuery() {
    if (_liveQuery != null && _productSubscription != null) {
      _liveQuery!.client.unSubscribe(_productSubscription!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _inventory
        .where((i) =>
            (i['quantity'] as int) <= (i['restockThreshold'] as int))
        .length;

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
            Tab(text: 'Products (${_products.length})',
                icon: const Icon(Icons.inventory_2, size: 18)),
            Tab(
              icon: Badge(
                isLabelVisible: lowStock > 0,
                label: Text('$lowStock'),
                child: const Icon(Icons.warehouse, size: 18),
              ),
              text: 'Inventory',
            ),
            Tab(text: 'Orders (${_orders.length})',
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
                _buildInventoryTab(),
                _buildOrdersTab(),
              ],
            ),
    );
  }

  // ============ PRODUCTS TAB ============

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('No products'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        itemBuilder: (_, i) => _buildProductTile(_products[i]),
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p) {
    final priceGhs = (p['pricePesewas'] as int) / 100;
    final isActive = p['status'] == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isActive ? AppColors.red50 : AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shopping_bag,
              color: isActive ? AppColors.red600 : AppColors.gray400),
        ),
        title: Text(p['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            'GH₵ ${priceGhs.toStringAsFixed(0)} • Stock: ${p['stock']}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'price') _showEditPrice(p);
            if (v == 'stock') _showEditStock(p);
            if (v == 'toggle') _toggleProductStatus(p);
            if (v == 'delete') _confirmDelete(p);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'price', child: Text('Edit Price')),
            const PopupMenuItem(value: 'stock', child: Text('Edit Stock')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(isActive ? 'Deactivate' : 'Activate')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  void _showEditPrice(Map<String, dynamic> product) async {
    final controller = TextEditingController(
      text: ((product['pricePesewas'] as int) / 100).toStringAsFixed(0),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Price: ${product['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Price (GH₵)', prefixText: 'GH₵ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final ghs = double.tryParse(controller.text);
              if (ghs != null) Navigator.pop(ctx, (ghs * 100).round());
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await ApiService.updateProductPrice(product['id'] as String, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Price updated to GH₵ ${(result / 100).toStringAsFixed(0)}'),
              backgroundColor: Colors.green),
          );
          _loadData();
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  void _showEditStock(Map<String, dynamic> product) async {
    final controller = TextEditingController();
    String reason = 'restock';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Adjust Stock: ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${product['stock']}',
                  style: const TextStyle(color: AppColors.gray600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Adjustment (+/- quantity)',
                  hintText: 'e.g. +10 or -3',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'restock', child: Text('Restock')),
                  DropdownMenuItem(value: 'sale', child: Text('Sale')),
                  DropdownMenuItem(value: 'damage', child: Text('Damage')),
                  DropdownMenuItem(value: 'correction', child: Text('Correction')),
                ],
                onChanged: (v) => setDialogState(() => reason = v ?? reason),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final adj = int.tryParse(controller.text);
                if (adj != null && adj != 0) {
                  Navigator.pop(ctx, {'adjustment': adj, 'reason': reason});
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        // Find inventory record for this product
        final invRecord = _inventory.firstWhere(
          (i) => i['productId'] == product['id'],
          orElse: () => <String, dynamic>{},
        );
        if (invRecord.isEmpty) {
          // Auto-create inventory record
          await ApiService.createInventory(
            productId: product['id'] as String,
            productName: product['name'] as String,
            quantity: product['stock'] as int,
          );
          await _loadData();
          final newInv = _inventory.firstWhere(
            (i) => i['productId'] == product['id'],
            orElse: () => <String, dynamic>{},
          );
          if (newInv.isNotEmpty) {
            await ApiService.adjustStock(
              inventoryId: newInv['id'] as String,
              productId: product['id'] as String,
              adjustment: result['adjustment'] as int,
              reason: result['reason'] as String,
            );
          }
        } else {
          await ApiService.adjustStock(
            inventoryId: invRecord['id'] as String,
            productId: product['id'] as String,
            adjustment: result['adjustment'] as int,
            reason: result['reason'] as String,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock adjusted by ${result['adjustment']} (${result['reason']})'),
              backgroundColor: Colors.green),
          );
          _loadData();
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  Future<void> _toggleProductStatus(Map<String, dynamic> product) async {
    final newStatus = product['status'] == 'active' ? 'inactive' : 'active';
    try {
      await ApiService.updateProduct(product['id'] as String, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product ${newStatus == 'active' ? 'activated' : 'deactivated'}'),
              backgroundColor: Colors.green));
        _loadData();
      }
    } catch (e) { _showError(e); }
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteProduct(product['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.green));
          _loadData();
        }
      } catch (_) {}
    }
  }

  // ============ INVENTORY TAB ============

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warehouse, size: 64, color: AppColors.gray400),
            const SizedBox(height: 16),
            const Text('No inventory records',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Stock adjustments will auto-create records',
                style: TextStyle(color: AppColors.gray500, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initInventoryForAllProducts,
              icon: const Icon(Icons.add),
              label: const Text('Initialize Inventory'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _inventory.length,
        itemBuilder: (_, i) => _buildInventoryTile(_inventory[i]),
      ),
    );
  }

  Widget _buildInventoryTile(Map<String, dynamic> inv) {
    final qty = inv['quantity'] as int;
    final threshold = inv['restockThreshold'] as int;
    final isLow = qty <= threshold;
    final lastReason = inv['lastAdjustmentReason'] as String?;
    final lastAmount = inv['lastAdjustmentAmount'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isLow ? AppColors.red50 : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2,
                      color: isLow ? AppColors.red600 : const Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv['productName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Location: ${inv['location']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$qty',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: isLow ? AppColors.red600 : AppColors.gray900)),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red50,
                          borderRadius: BorderRadius.circular(4)),
                        child: const Text('LOW STOCK',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                color: AppColors.red600)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Restock at: $threshold',
                    style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
                if (lastReason != null) ...[
                  const Text(' • ', style: TextStyle(color: AppColors.gray400)),
                  Text('Last: ${lastAmount != null && lastAmount > 0 ? '+$lastAmount' : '$lastAmount'} ($lastReason)',
                      style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickAdjust(inv, 'restock'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Restock', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editThreshold(inv),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Threshold', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _quickAdjust(Map<String, dynamic> inv, String reason) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock: ${inv['productName']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity to add'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(controller.text);
              if (qty != null && qty > 0) Navigator.pop(ctx, qty);
            },
            child: const Text('Add Stock')),
        ],
      ),
    );
    if (result != null) {
      try {
        await ApiService.adjustStock(
          inventoryId: inv['id'] as String,
          productId: inv['productId'] as String,
          adjustment: result,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('+$result added to ${inv['productName']}'),
                backgroundColor: Colors.green));
          _loadData();
        }
      } catch (e) { _showError(e); }
    }
  }

  void _editThreshold(Map<String, dynamic> inv) async {
    final controller = TextEditingController(
      text: (inv['restockThreshold'] as int).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Restock Threshold'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Alert when stock is at or below'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      try {
        await ApiService.updateInventory(
            inv['id'] as String, {'restockThreshold': result});
        if (mounted) _loadData();
      } catch (e) { _showError(e); }
    }
  }

  Future<void> _initInventoryForAllProducts() async {
    int created = 0;
    for (final p in _products) {
      final exists = _inventory.any((i) => i['productId'] == p['id']);
      if (!exists) {
        try {
          await ApiService.createInventory(
            productId: p['id'] as String,
            productName: p['name'] as String,
            quantity: p['stock'] as int,
          );
          created++;
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$created inventory records created'),
            backgroundColor: Colors.green));
      _loadData();
    }
  }

  // ============ ORDERS TAB ============

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(o['productName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text('GH₵ ${totalGhs.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                                color: Color(0xFF2E7D32))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Buyer: ${o['buyerName']}  •  Qty: ${o['quantity']}',
                      style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
                  Text('Phone: ${o['buyerPhone']}',
                      style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
                  if (o['deliveryAddress'] != null &&
                      (o['deliveryAddress'] as String).isNotEmpty)
                    Text('Delivery: ${o['deliveryAddress']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }
}
