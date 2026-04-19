import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  int _quantity = 1;
  bool _isPurchasing = false;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      _product = await ApiService.getProduct(widget.productId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _purchase() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true || !mounted) return;
    }

    if (_phoneController.text.trim().isEmpty) {
      AppNotifier.warning(context, 'Please enter your MoMo number');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final user = context.read<AuthProvider>().user!;
      final result = await ApiService.createStoreOrder(
        productId: widget.productId,
        productName: _product!['name'] as String,
        pricePesewas: _product!['pricePesewas'] as int,
        quantity: _quantity,
        paymentMethod: 'mobile_money',
        buyerName: user.fullName,
        buyerPhone: _phoneController.text.trim(),
        buyerEmail: user.email,
        deliveryAddress: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
      );

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        AppNotifier.error(
            context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final totalGhs = (result['total'] as int) / 100;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
            SizedBox(width: 8),
            Text('Order Placed!'),
          ],
        ),
        content: Text(
          'Your order for ${_product!['name']} has been confirmed.\n\n'
          'Total: GH₵ ${totalGhs.toStringAsFixed(2)}\n'
          'Payment via MoMo will be processed shortly.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.red600, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: AppColors.red600)),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.red600, foregroundColor: Colors.white),
        body: const Center(child: Text('Product not found')),
      );
    }

    final images = _product!['images'] as List<String>;
    final priceGhs = (_product!['pricePesewas'] as int) / 100;
    final stock = _product!['stock'] as int;
    final totalGhs = priceGhs * _quantity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 280,
              width: double.infinity,
              child: images.isNotEmpty
                  ? PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.red50,
                          child: const Icon(Icons.shopping_bag,
                              size: 64, color: AppColors.red600),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.red50,
                      child: const Center(
                        child: Icon(Icons.shopping_bag,
                            size: 64, color: AppColors.red600),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and price
                  Text(_product!['name'] as String,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray900)),
                  const SizedBox(height: 8),
                  Text('GH₵ ${priceGhs.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.red700)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stock > 0
                          ? const Color(0x194CAF50)
                          : AppColors.red50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stock > 0 ? '$stock in stock' : 'Sold out',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stock > 0
                            ? const Color(0xFF2E7D32)
                            : AppColors.red600,
                      ),
                    ),
                  ),
                  // Category
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.category,
                          size: 16, color: AppColors.gray500),
                      const SizedBox(width: 4),
                      Text(_product!['category'] as String,
                          style: const TextStyle(
                              color: AppColors.gray600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Description
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray900)),
                  const SizedBox(height: 8),
                  Text(_product!['description'] as String,
                      style: const TextStyle(
                          color: AppColors.gray700, height: 1.5)),

                  if (stock > 0) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Quantity
                    const Text('Quantity',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQtyButton(Icons.remove, () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          child: Text('$_quantity',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        _buildQtyButton(Icons.add, () {
                          if (_quantity < stock) {
                            setState(() => _quantity++);
                          }
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // MoMo payment
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'MoMo Number',
                        hintText: '024 XXX XXXX',
                        prefixIcon: const Icon(Icons.phone_android,
                            color: AppColors.red600),
                        filled: true,
                        fillColor: AppColors.gray100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Delivery Address (Optional)',
                        hintText: 'e.g., East Legon, Accra',
                        prefixIcon: const Icon(Icons.location_on,
                            color: AppColors.red600),
                        filled: true,
                        fillColor: AppColors.gray100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Order summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Price', 'GH₵ ${priceGhs.toStringAsFixed(2)}'),
                          _summaryRow('Quantity', '$_quantity'),
                          const Divider(height: 16),
                          _summaryRow(
                            'Total',
                            'GH₵ ${totalGhs.toStringAsFixed(2)}',
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Buy button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isPurchasing ? null : _purchase,
                        icon: _isPurchasing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.shopping_cart),
                        label: Text(
                          'Buy Now — GH₵ ${totalGhs.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.red50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.red600.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppColors.red600),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.gray600,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  color: bold ? AppColors.red700 : AppColors.gray900,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}
