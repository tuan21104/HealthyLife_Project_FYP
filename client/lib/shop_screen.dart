import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final Color _primaryGreen = const Color(0xFF76B543);
  final TextEditingController _addressController = TextEditingController(
    text: "49 Pham Van Dong street",
  );

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isFetched = false; // CHẶN VÒNG LẶP CHÍ MẠNG

  @override
  void initState() {
    super.initState();
    debugPrint("--- ShopScreen: initState called ---");
    _loadData(); // Chỉ gọi 1 lần duy nhất khi khởi tạo
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    debugPrint(
      "--- ShopScreen: _loadData triggered. _isFetched: $_isFetched ---",
    );
    if (_isFetched) {
      debugPrint("--- ShopScreen: Data already fetched. Aborting. ---");
      return;
    }

    try {
      final result = await AuthService.getAllProducts();
      debugPrint("--- ShopScreen: API Response received: $result ---");

      final rawProducts = result['products'];
      final safeProducts = rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _products = safeProducts;
          _isLoading = false;
          _isFetched = true; // Đánh dấu đã xong, không gọi lại nữa
        });
        debugPrint(
          "--- ShopScreen: State updated. Products count: ${_products.length} ---",
        );
      }
    } catch (e) {
      debugPrint("--- ShopScreen: Error loading data: $e ---");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // CẤM GỌI _loadData() Ở ĐÂY
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : RefreshIndicator(
              // Thêm để bạn có thể test tải lại thủ công nếu muốn
              onRefresh: () async {
                _isFetched = false;
                await _loadData();
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    _buildPromoBanner(),
                    _buildSection("Top Categories", _buildCategoryList()),
                    _buildSection("Top Discount", _buildProductGrid()),
                    const SizedBox(height: 100), // Khoảng trống cho Bottom Nav
                  ],
                ),
              ),
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Icon(Icons.location_on, color: _primaryGreen),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current location",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Text(
            _addressController.text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search goods, dishes or etc",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage(
            "https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=500",
          ),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Claim your\ndiscount 30%\ndaily now!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "See all",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildCategoryList() {
    final cats = [
      {
        "n": "Food",
        "i": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200",
      },
      {
        "n": "Drink",
        "i": "https://images.unsplash.com/photo-1544145945-f904253d0c7b?w=200",
      },
      {
        "n": "Tool",
        "i":
            "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=200",
      },
      {
        "n": "Supps",
        "i":
            "https://images.unsplash.com/photo-1593095191071-82b0fdd64aef?w=200",
      },
    ];
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: cats.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: cats[i]['i']!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 5),
              Text(cats[i]['n']!, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No products found in Atlas."),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // CHỐNG SẬP
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
        final imageUrl = (p['imageUrl'] ?? '').toString();
        final productName = (p['name'] ?? '').toString();
        final priceVND = p['priceVND'];
        final priceCalo = p['priceCalo'];
        return GestureDetector(
          onTap: () => _showCheckout(p),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
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
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (c, u, e) => const Icon(Icons.fastfood),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      Text(
                        "${priceVND ?? 0} vnđ",
                        style: TextStyle(
                          color: _primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "+ ${priceCalo ?? 0} kcal",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCheckout(Map<String, dynamic> p) {
    debugPrint("--- ShopScreen: Opening checkout for ${p['name']} ---");
    // Luồng hiện BottomSheet giữ nguyên
  }
}
