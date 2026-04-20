import 'dart:convert';

import 'package:http/http.dart' as http;

class ExpenseModel {
  final String? id;
  final String userId;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  ExpenseModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawAmount = json['amount'];
    final dynamic rawDate = json['date'];

    return ExpenseModel(
      id: json['_id']?.toString(),
      userId: json['userId']?.toString() ?? '',
      amount: rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0,
      category: json['category']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      date: rawDate != null
          ? DateTime.tryParse(rawDate.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }
}

class ExpenseService {
  static const String myWifiIp = '192.168.1.27';
  static const bool isOnlineMode = false;
  static const String baseUrl = isOnlineMode
      ? 'http://$myWifiIp:3000'
      : 'http://10.0.2.2:3000';

  static Future<List<ExpenseModel>> fetchExpenses(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/expense/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);
      final dynamic rawExpenses = decoded is Map<String, dynamic>
          ? decoded['expenses']
          : decoded;

      if (rawExpenses is List) {
        return rawExpenses
            .whereType<Map<String, dynamic>>()
            .map(ExpenseModel.fromJson)
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<int> fetchMonthlyBudget(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/users/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 10000000;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic user = decoded['user'];
        if (user is Map<String, dynamic>) {
          final dynamic monthlyBudget = user['monthlyBudget'];
          final parsed = monthlyBudget is num
              ? monthlyBudget.toInt()
              : int.tryParse(monthlyBudget?.toString() ?? '');
          if (parsed != null && parsed >= 0) {
            return parsed;
          }
        }
      }

      return 10000000;
    } catch (_) {
      return 10000000;
    }
  }

  static Future<Map<String, dynamic>> updateMonthlyBudget(
    String userId,
    int newBudget,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/user/$userId/budget'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'newBudget': newBudget}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': decoded};
      }

      if (decoded is Map<String, dynamic>) {
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Cập nhật thất bại',
        };
      }

      return {'success': false, 'message': 'Cập nhật thất bại'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối tới Server',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> addExpense(ExpenseModel expense) async {
    try {
      final payload = expense.toJson();
      payload['userId'] = expense.userId.trim();

      print('==== [ExpenseService] POST $baseUrl/api/expense/add ====');
      print('==== [ExpenseService] Payload: ${jsonEncode(payload)} ====');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/expense/add'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      print('==== [ExpenseService] Status: ${response.statusCode} ====');
      print('==== [ExpenseService] Body: ${response.body} ====');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Đã thêm thành công!'};
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return {
            'success': false,
            'message': decoded['message']?.toString() ?? 'Vui lòng thử lại!',
            'statusCode': response.statusCode,
          };
        }
      } catch (_) {}

      return {
        'success': false,
        'message': 'Lỗi ${response.statusCode}: Không thể lưu chi tiêu',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      print('==== [ExpenseService] Exception: $e ====');
      return {
        'success': false,
        'message': 'Không thể kết nối tới Server',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteExpense(
    String expenseId,
    String userId,
  ) async {
    final String trimmedExpenseId = expenseId.trim();
    final String trimmedUserId = userId.trim();

    if (trimmedExpenseId.isEmpty || trimmedUserId.isEmpty) {
      return {'success': false, 'message': 'Dữ liệu xoá chi tiêu không hợp lệ'};
    }

    try {
      final Uri uri = Uri.parse(
        '$baseUrl/api/expenses/$trimmedExpenseId?userId=$trimmedUserId',
      );

      final http.Response response = await http
          .delete(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final dynamic decoded = jsonDecode(response.body);
      final String message =
          decoded is Map<String, dynamic> && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Vui lòng thử lại!';

      if (response.statusCode == 200) {
        return {'success': true, 'message': message};
      }

      return {'success': false, 'message': message};
    } catch (_) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }

  static Future<Map<String, dynamic>> updateExpense({
    required String expenseId,
    required String userId,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    final String trimmedExpenseId = expenseId.trim();
    final String trimmedUserId = userId.trim();
    final String trimmedCategory = category.trim();

    if (trimmedExpenseId.isEmpty || trimmedUserId.isEmpty) {
      return {'success': false, 'message': 'Dữ liệu cập nhật không hợp lệ'};
    }

    if (amount <= 0 || trimmedCategory.isEmpty) {
      return {'success': false, 'message': 'Dữ liệu cập nhật không hợp lệ'};
    }

    try {
      final Uri uri = Uri.parse('$baseUrl/api/expenses/$trimmedExpenseId');

      final http.Response response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': trimmedUserId,
              'amount': amount,
              'category': trimmedCategory,
              'note': note.trim(),
              'date': date.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final dynamic decoded = jsonDecode(response.body);
      final String message =
          decoded is Map<String, dynamic> && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Vui lòng thử lại!';

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': message,
          'expense': decoded is Map<String, dynamic>
              ? decoded['expense']
              : null,
        };
      }

      return {'success': false, 'message': message};
    } catch (_) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }
}
