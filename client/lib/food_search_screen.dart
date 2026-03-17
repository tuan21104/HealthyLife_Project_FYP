import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'food_detail_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType;

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final Color _greenColor = const Color(0xFF65B362);
  final Color _lightBlueColor = const Color(0xFFD3E7F0);
  final Color _textGreenColor = const Color(0xFF5A9B58);

  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allFoods = []; // Kho chứa toàn bộ thức ăn từ Backend
  List<dynamic> _searchResults = []; // Kho chứa kết quả sau khi gõ tìm kiếm
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFoodDatabase();
  }

  // --- GỌI API LẤY DỮ LIỆU TỪ MONGODB ---
  Future<void> _fetchFoodDatabase() async {
    final result = await AuthService.getAllFoods();
    if (mounted) {
      setState(() {
        if (result['success'] == true && result['foods'] != null) {
          _allFoods = result['foods'];
        }
        _isLoading = false;
      });
    }
  }

  // --- HÀM LỌC KẾT QUẢ TÌM KIẾM ---
  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    // Tìm kiếm không phân biệt hoa thường
    final results = _allFoods.where((food) {
      final foodName = food['name'].toString().toLowerCase();
      return foodName.contains(query.toLowerCase());
    }).toList();

    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mealType,
          style: const TextStyle(color: Colors.black54, fontSize: 28),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 24),

              // HIỂN THỊ KẾT QUẢ HOẶC VÒNG LOADING
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF65B362),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                          ? _buildSearchResults()
                          : const SizedBox.shrink()),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _greenColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Add image",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ["Search", "My Foods", "Add Calories", "Recipes"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          bool isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _greenColor : _lightBlueColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textGreenColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchController.text.isNotEmpty
              ? _greenColor
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged, // Kích hoạt hàm lọc khi gõ
        decoration: InputDecoration(
          hintText: "Search (vd: Ức gà, cơm...)",
          hintStyle: TextStyle(color: Colors.grey[400]),
          suffixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _greenColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchController.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged(""); // Xóa kết quả
                  },
                  child: Icon(
                    Icons.cancel_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _lightBlueColor, thickness: 1),
          Expanded(
            child: _searchResults.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Không tìm thấy món ăn nào",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item =
                          _searchResults[index]; // Lấy 1 object từ MongoDB
                      return InkWell(
                        onTap: () async {
                          // CHỜ MÀN HÌNH DETAIL TRẢ DỮ LIỆU VỀ
                          final addedFood = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FoodDetailScreen(
                                mealType: widget.mealType,
                                foodData: item,
                              ),
                            ),
                          );

                          // NẾU CÓ DỮ LIỆU, LẬP TỨC ĐÓNG CỬA SỔ SEARCH VÀ GỬI VỀ TRANG CHỦ DIARY
                          if (addedFood != null && mounted) {
                            Navigator.pop(context, addedFood);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Hiển thị tóm tắt: xxx Kcal / 100g
                              Text(
                                "${item['calories']} Kcal / 100g",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
