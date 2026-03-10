import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';
import 'main_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập Email và Mật khẩu", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    // Gọi API Login
    final result = await AuthService.login(email, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showMessage("Đăng nhập thành công!", Colors.green);

      // Bắt cờ hasProfile từ Backend gửi về
      bool hasProfile = result['hasProfile'] ?? false;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        if (hasProfile) {
          // --- NHÁNH 1: TÀI KHOẢN CŨ (Đã có thông tin chiều cao/cân nặng) ---
          print("Tài khoản cũ -> Bypass Onboarding, vào thẳng Trang chủ");
          _showMessage("Chào mừng trở lại! (Sẽ chuyển thẳng vào Trang chủ)", Colors.blue);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
          
        } else {
          // --- NHÁNH 2: TÀI KHOẢN MỚI (Chưa có thông tin) ---
          print("Tài khoản mới -> Vào luồng Onboarding điền thông tin");
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => WelcomeScreen(email: email)
              )
          );
        }
      });

    } else {
      _showMessage(result['message'], Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Log In", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              const SizedBox(height: 30),

              _buildLabel("Email"),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: _inputDecoration("Nhập email của bạn"),
              ),

              const SizedBox(height: 20),

              _buildLabel("Password"),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: _inputDecoration("***********").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Log In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                    child: const Text("Sign up", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)));

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
    );
  }
}