import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

import 'services/auth_service.dart';
import 'main_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const Color _primaryGreen = Color(0xFF67B420);
  static const Color _darkText = Color(0xFF30363A);
  static const Color _mutedText = Color(0xFF8B949E);
  static const Color _surface = Color(0xFFF7F8F4);
  static const Color _softBorder = Color(0xFFE7ECE2);
  static const double _storeLat = 21.0382;
  static const double _storeLng = 105.7827;
  static const String _defaultAddress = '51 ngõ 59 đường Phạm Văn Đồng';
  static const double _shippingRatePerKm = 5000;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(
    text: _defaultAddress,
  );
  final TextEditingController _addressEditingController =
      TextEditingController();

  final List<Map<String, dynamic>> _categoryTabs = const [
    {'key': 'all', 'label': 'All', 'icon': Icons.apps_rounded},
    {'key': 'food', 'label': 'Foods', 'icon': Icons.restaurant_rounded},
    {
      'key': 'equipment',
      'label': 'Equipment',
      'icon': Icons.fitness_center_rounded,
    },
  ];

  List<dynamic> _products = [];
  bool _isLoading = true;
  int _currentStep = 0;
  bool _isSubmitting = false;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _cartItems = [];
  String _lastDeliveredAddress = '';
  double _lastPaidAmount = 0;
  int _estimatedTimeMins = 30;
  File? _billImage;
  bool _isLoadingOrders = false;
  List<Map<String, dynamic>> _orderHistory = [];
  double _calculatedDistance = 0.0;
  int _shippingFeeVnd = 0;
  int _totalPriceVnd = 0;
  bool _isCalculatingShipping = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _loadData();
    _calculateShipping(_defaultAddress);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addressController.dispose();
    _addressEditingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final result = await AuthService.getAllProducts();
      if (!mounted) return;
      setState(() {
        _products = result['products'] ?? [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateShipping(String address) async {
    if (address.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập địa chỉ giao hàng'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isCalculatingShipping = true);

    try {
      final List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tìm thấy địa chỉ: $address'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _isCalculatingShipping = false);
        }
        return;
      }

      final Location location = locations.first;
      final double distance = Geolocator.distanceBetween(
        _storeLat,
        _storeLng,
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        setState(() {
          final distanceKm = distance / 1000;
          final shippingFee = (distanceKm * _shippingRatePerKm).round();

          _calculatedDistance = distanceKm;
          _shippingFeeVnd = shippingFee;
          _estimatedTimeMins = 15 + (distanceKm * 2).round();
          _totalPriceVnd = (_cartSubtotal + shippingFee).round();
          _addressController.text = address.trim();
          _isCalculatingShipping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => _isCalculatingShipping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: IndexedStack(
          index: _currentStep,
          children: [
            _buildMainPage(),
            _buildCartPage(),
            _buildCheckoutPage(),
            _buildSuccessPage(),
            _buildOrderHistoryPage(),
          ],
        ),
        bottomNavigationBar: _currentStep < 4 ? _buildBottomNavBar() : null,
      ),
    );
  }

  Widget _buildMainPage() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
        : SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(child: _buildLocationHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(child: _buildSearchField()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(child: _buildPromoBanner()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Top Categories'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(child: _buildCategoryRow()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Top Discount'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(child: _buildDiscountRow()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Popular items'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.74,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _visibleProducts[index];
                      return _buildProductCard(product);
                    }, childCount: _visibleProducts.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          );
  }

  Widget _buildLocationHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _primaryGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current location',
                style: TextStyle(fontSize: 12, color: _mutedText),
              ),
              Text(
                _addressController.text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _openOrderHistory,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _softBorder),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: _darkText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => setState(() => _currentStep = 1),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _softBorder),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                        color: _darkText,
                      ),
                    ),
                  ),
                ),
                if (_cartItems.isNotEmpty)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _cartItems.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _softBorder),
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration(
          hintText: 'Search goods, dishes or etc',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _mutedText),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 144,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DBA2F), Color(0xFF8ED14A)],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -10,
            child: Opacity(
              opacity: 0.18,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.18),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_dining_rounded,
                  size: 86,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Claim your\ndiscount 30%\ndaily now!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Order now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _darkText,
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedCategory = 'all'),
          style: TextButton.styleFrom(foregroundColor: _mutedText),
          child: const Text('See all'),
        ),
      ],
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = _categoryTabs[index];
          final isActive = _selectedCategory == category['key'];
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCategory = category['key'] as String),
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? _primaryGreen.withOpacity(0.16)
                          : Colors.white,
                      border: Border.all(
                        color: isActive ? _primaryGreen : _softBorder,
                      ),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: isActive ? _primaryGreen : _mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _darkText,
                      height: 1.1,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscountRow() {
    final discounts = _discountProducts;
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: discounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final product = discounts[index];
          return GestureDetector(
            onTap: () => _addToCart(product, openCart: true),
            child: Container(
              width: 154,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _softBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: _resolveImageUrl(product['imageUrl']),
                      height: 108,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFF0F3EC),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => _buildImageFallback(
                        isFood: _isFoodProduct(product),
                        width: double.infinity,
                        height: 108,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Text(
                      product['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Text(
                      _formatVnd(_productPrice(product)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => _addToCart(product, openCart: true),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _softBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: _resolveImageUrl(product['imageUrl']),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFF0F3EC),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => _buildImageFallback(
                    isFood: _isFoodProduct(product),
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                product['name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _darkText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                product['category']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _mutedText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatVnd(_productPrice(product)),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _primaryGreen,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _addToCart(product),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPage() {
    final subtotal = _cartSubtotal;

    return SafeArea(
      child: Column(
        children: [
          _buildScreenHeader(
            title: 'Cart',
            leading: Icons.arrow_back,
            onBack: () => setState(() => _currentStep = 0),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 34,
                              color: _primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Giỏ hàng đang trống',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      final product = item['product'] as Map<String, dynamic>;
                      final qty = item['quantity'] as int;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _softBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: _resolveImageUrl(product['imageUrl']),
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 92,
                                  height: 92,
                                  color: const Color(0xFFF0F3EC),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _buildImageFallback(
                                      isFood: _isFoodProduct(product),
                                      width: 92,
                                      height: 92,
                                      compact: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatVnd(_productPrice(product) * qty),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildQuantityButton(
                                        icon: Icons.remove,
                                        onTap: qty > 1
                                            ? () => _updateCartQty(
                                                product['_id'].toString(),
                                                qty - 1,
                                              )
                                            : null,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          qty.toString(),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _buildQuantityButton(
                                        icon: Icons.add,
                                        onTap: () => _updateCartQty(
                                          product['_id'].toString(),
                                          qty + 1,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => _removeFromCart(
                                          product['_id'].toString(),
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: _mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildActionBar(
            leftTitle: _formatVnd(subtotal),
            rightLabel: 'Proceed to pay',
            onTap: _cartItems.isEmpty
                ? () {}
                : () => setState(() => _currentStep = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutPage() {
    if (_cartItems.isEmpty) return const SizedBox.shrink();
    final subtotal = _cartSubtotal;
    final distanceKm = _distanceFromStoreKm;
    final shippingFee = _shippingFee;
    final total = _totalPriceVnd;

    return SafeArea(
      child: Column(
        children: [
          _buildScreenHeader(
            title: 'Checkout',
            leading: Icons.arrow_back,
            onBack: () => setState(() => _currentStep = 1),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              children: [
                _buildCheckoutCard(
                  icon: Icons.location_on_outlined,
                  label: 'Deliver to',
                  child: _buildDeliveryAddressCard(),
                ),
                const SizedBox(height: 14),
                _buildCheckoutCard(
                  icon: Icons.credit_card_outlined,
                  label: 'Payment from',
                  child: const Text(
                    'VCB 9947890196',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSummaryRow('Subtotal', _formatVnd(subtotal)),
                const SizedBox(height: 10),
                _buildSummaryRow(
                  'Distance',
                  '${distanceKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(height: 10),
                _buildSummaryRow('Shipping Fee', '+${_formatVnd(shippingFee)}'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                _buildSummaryRow('Total', _formatVnd(total), bold: true),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _softBorder),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Scan QR to pay',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _softBorder),
                        ),
                        child: Image.network(
                          'https://img.vietqr.io/image/VCB-9947890196-compact.png?amount=${total.round()}&addInfo=HealthyLifeOrder',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'VCB - 9947890196',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickBillImage,
                          icon: const Icon(Icons.attachment_outlined),
                          label: Text(
                            _billImage == null
                                ? 'Attach bill image'
                                : 'Bill image attached',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryGreen,
                            side: const BorderSide(color: _softBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (_billImage != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _billImage!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _billImage = null),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Remove bill'),
                          style: TextButton.styleFrom(
                            foregroundColor: _mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildActionBar(
            leftTitle: _formatVnd(total),
            rightLabel: 'Place order',
            isLoading: _isSubmitting,
            onTap: _placeOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => setState(() => _currentStep = 0),
                icon: const Icon(Icons.close, color: _mutedText),
              ),
            ),
            const Spacer(flex: 2),
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFF5FAE17),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 26),
            const Text(
              'Yay! Your order\nhas been placed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 28),
            _buildSuccessDetail(
              Icons.access_time,
              'Estimated time',
              '${_estimatedTimeMins} mins',
            ),
            const SizedBox(height: 12),
            _buildSuccessDetail(
              Icons.location_on_outlined,
              'Deliver to',
              _lastDeliveredAddress.isEmpty
                  ? _addressController.text
                  : _lastDeliveredAddress,
            ),
            const SizedBox(height: 12),
            _buildSuccessDetail(
              Icons.credit_card_outlined,
              'Amount Paid',
              _formatVnd(_lastPaidAmount),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text(
                  'Back to main homepage',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistoryPage() {
    return SafeArea(
      child: Column(
        children: [
          _buildScreenHeader(
            title: 'Orders',
            leading: Icons.arrow_back,
            onBack: () => setState(() => _currentStep = 0),
          ),
          Expanded(
            child: _isLoadingOrders
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryGreen),
                  )
                : _orderHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: _primaryGreen,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Chưa có đơn nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Các đơn đã mua sẽ xuất hiện ở đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: _mutedText),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    itemCount: _orderHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _orderHistory[index];
                      final isFood =
                          (order['productCategory']?.toString().toLowerCase() ??
                              '') ==
                          'food';
                      final totalVnd = ((order['totalVnd'] ?? 0) as num)
                          .toDouble();
                      final quantity = ((order['quantity'] ?? 1) as num)
                          .toInt();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _softBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: _resolveImageUrl(
                                  order['productImageUrl'],
                                ),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 72,
                                  height: 72,
                                  color: const Color(0xFFF0F3EC),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _buildImageFallback(
                                      isFood: isFood,
                                      width: 72,
                                      height: 72,
                                      compact: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          order['productName']?.toString() ??
                                              '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: _darkText,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFood
                                              ? _primaryGreen.withOpacity(0.12)
                                              : const Color(0xFFEFF2F7),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          isFood ? 'Food' : 'Equipment',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isFood
                                                ? _primaryGreen
                                                : _darkText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_formatVnd(totalVnd)} · x$quantity',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    order['address']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _mutedText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: _mutedText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        order['createdAtText']?.toString() ??
                                            '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenHeader({
    required String title,
    required IconData leading,
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      color: _surface,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(leading, color: _darkText),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkText,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCheckoutCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _mutedText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: _mutedText),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: _darkText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _mutedText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: _mutedText),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: _darkText),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: const Color(0xFFF0F3EC),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? _softBorder : _darkText,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar({
    required String leftTitle,
    required String rightLabel,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            leftTitle,
            style: const TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w900,
              color: _darkText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : onTap,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        rightLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: 0,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: Colors.grey[400],
        elevation: 0,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _navigateFromBottomNav,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home_filled),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.pie_chart),
            ),
            label: 'Diaries',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.settings),
            ),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.person),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _navigateFromBottomNav(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) return;

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ nhận hàng.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String billUrl = '';
      if (_billImage != null) {
        final uploadedBillUrl = await AuthService.uploadImage(_billImage!);
        if (uploadedBillUrl != null) {
          billUrl = uploadedBillUrl;
        }
      }

      for (final item in _cartItems) {
        final product = item['product'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;

        final response = await AuthService.redeemProduct(
          productId: product['_id'].toString(),
          billUrl: billUrl,
          address: address,
          distanceKm: _distanceFromStoreKm,
          shippingFee: _shippingFee,
          quantity: quantity,
        );

        if (response?['success'] != true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response?['message']?.toString() ??
                    'Không thể đặt hàng lúc này.',
              ),
            ),
          );
          return;
        }
      }

      if (!mounted) return;

      setState(() {
        _lastDeliveredAddress = address;
        _lastPaidAmount = _totalPriceVnd.toDouble();
        _cartItems = [];
        _billImage = null;
        _totalPriceVnd = 0;
        _currentStep = 3;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối tới Server.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _addToCart(Map<String, dynamic> product, {bool openCart = false}) {
    final productId = product['_id']?.toString() ?? '';
    if (productId.isEmpty) return;

    final index = _cartItems.indexWhere(
      (item) =>
          ((item['product'] as Map<String, dynamic>)['_id']?.toString() ??
              '') ==
          productId,
    );

    setState(() {
      if (index >= 0) {
        _cartItems[index]['quantity'] =
            (_cartItems[index]['quantity'] as int) + 1;
      } else {
        _cartItems.add({
          'product': Map<String, dynamic>.from(product),
          'quantity': 1,
        });
      }

      if (openCart) {
        _currentStep = 1;
      }

      _recomputeTotalPrice();
    });
  }

  void _updateCartQty(String productId, int quantity) {
    final index = _cartItems.indexWhere(
      (item) =>
          ((item['product'] as Map<String, dynamic>)['_id']?.toString() ??
              '') ==
          productId,
    );
    if (index < 0) return;

    setState(() {
      _cartItems[index]['quantity'] = quantity;
      _recomputeTotalPrice();
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cartItems.removeWhere(
        (item) =>
            ((item['product'] as Map<String, dynamic>)['_id']?.toString() ??
                '') ==
            productId,
      );
      _recomputeTotalPrice();
    });
  }

  Future<void> _openOrderHistory() async {
    setState(() {
      _currentStep = 4;
      _isLoadingOrders = true;
    });

    final result = await AuthService.getOrderHistory();
    if (!mounted) return;

    setState(() {
      _orderHistory = List<Map<String, dynamic>>.from(
        (result['orders'] ?? const []).whereType<Map>().map(
          (order) => Map<String, dynamic>.from(order),
        ),
      );
      _isLoadingOrders = false;
    });
  }

  double _productPrice(Map<String, dynamic> product) {
    return ((product['priceVND'] ?? 0) as num).toDouble();
  }

  String _formatVnd(num value) {
    return '${NumberFormat.decimalPattern('vi_VN').format(value.round())} vnđ';
  }

  bool _matchesCategory(Map<String, dynamic> product) {
    final category = product['category']?.toString().toLowerCase() ?? '';
    final name = product['name']?.toString().toLowerCase() ?? '';

    if (_selectedCategory == 'all') return true;
    if (_selectedCategory == 'food') return category == 'food';
    if (_selectedCategory == 'equipment') return category == 'equipment';

    if (_selectedCategory == 'seafood') {
      return category == 'food' &&
          (name.contains('fish') ||
              name.contains('salmon') ||
              name.contains('shrimp') ||
              name.contains('seafood') ||
              name.contains('tôm') ||
              name.contains('cá'));
    }

    if (_selectedCategory == 'dessert') {
      return category == 'food' &&
          (name.contains('ice') ||
              name.contains('cake') ||
              name.contains('sweet') ||
              name.contains('dessert') ||
              name.contains('kem'));
    }

    return true;
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _searchQuery.toLowerCase();
    return _products
        .whereType<Map>()
        .map((product) => Map<String, dynamic>.from(product))
        .where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          final category = product['category']?.toString().toLowerCase() ?? '';
          final matchesSearch =
              query.isEmpty || name.contains(query) || category.contains(query);
          return matchesSearch && _matchesCategory(product);
        })
        .toList();
  }

  List<Map<String, dynamic>> get _discountProducts {
    final filtered = _visibleProducts
        .where((product) => _isFoodProduct(product))
        .toList();
    if (filtered.isNotEmpty) {
      return filtered.take(2).toList();
    }
    return _visibleProducts.take(2).toList();
  }

  bool _isFoodProduct(Map<String, dynamic> product) {
    return product['category']?.toString().toLowerCase() == 'food';
  }

  String _resolveImageUrl(dynamic value) {
    final url = value?.toString().trim() ?? '';
    if (url.isEmpty) return '';

    // Some legacy Unsplash URLs in DB miss query params and fail intermittently.
    if (url.contains('images.unsplash.com') && !url.contains('?')) {
      return '$url?auto=format&fit=crop&w=1000&q=80';
    }

    return url;
  }

  Widget _buildImageFallback({
    required bool isFood,
    double? width,
    double? height,
    bool compact = false,
  }) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF0F3EC),
      alignment: Alignment.center,
      child: Icon(
        isFood ? Icons.restaurant_menu_rounded : Icons.fitness_center_rounded,
        size: compact ? 22 : 30,
        color: _mutedText,
      ),
    );
  }

  Future<void> _pickBillImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _billImage = File(picked.path);
    });
  }

  Widget _buildDeliveryAddressCard() {
    if (_isCalculatingShipping) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primaryGreen,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Đang tính toán phí ship...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _mutedText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _addressController.text.trim().isEmpty
              ? 'Chưa có địa chỉ giao hàng'
              : _addressController.text.trim(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _darkText,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _showAddressEditDialog,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Chỉnh sửa'),
          style: TextButton.styleFrom(
            foregroundColor: _darkText,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  void _showAddressEditDialog() {
    _addressEditingController.text = _addressController.text;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Chỉnh sửa địa chỉ giao hàng',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _darkText,
          ),
        ),
        content: TextField(
          controller: _addressEditingController,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
          decoration: InputDecoration(
            hintText: 'Nhập địa chỉ giao hàng',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primaryGreen, width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: _mutedText, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              final newAddress = _addressEditingController.text.trim();
              if (newAddress.isNotEmpty) {
                Navigator.pop(context);
                _calculateShipping(newAddress);
              }
            },
            child: const Text(
              'Xác nhận',
              style: TextStyle(
                color: _primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _distanceFromStoreKm {
    return _calculatedDistance;
  }

  int get _shippingFee {
    return _shippingFeeVnd;
  }

  void _recomputeTotalPrice() {
    _totalPriceVnd = (_cartSubtotal + _shippingFee).round();
  }

  double get _cartSubtotal {
    return _cartItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          _productPrice(item['product'] as Map<String, dynamic>) *
              (item['quantity'] as int),
    );
  }
}
