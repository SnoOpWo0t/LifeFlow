import '../../../core/network/api_client.dart';
import '../domain/expense_models.dart';

class ExpenseRepository {
  final ApiClient _apiClient;

  ExpenseRepository(this._apiClient);

  Future<TransactionPage> fetchTransactions({int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/transactions',
      queryParameters: {'page': page},
    );
    return TransactionPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CategorySpending>> fetchSpendingByCategory() async {
    final response = await _apiClient.dio.get('/transactions/by-category');
    return (response.data['categories'] as List)
        .map((json) => CategorySpending.fromJson(json))
        .toList();
  }

  Future<Transaction> addTransaction(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/transactions', data: data);
    return Transaction.fromJson(response.data);
  }

  Future<Transaction> updateTransaction(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.dio.put('/transactions/$id', data: data);
    return Transaction.fromJson(response.data);
  }

  Future<void> deleteTransaction(int id) async {
    await _apiClient.dio.delete('/transactions/$id');
  }

  Future<List<ExpenseCategory>> fetchCategories() async {
    final response = await _apiClient.dio.get('/categories');
    return (response.data as List)
        .map((json) => ExpenseCategory.fromJson(json))
        .toList();
  }

  Future<ExpenseCategory> createCategory(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/categories', data: data);
    return ExpenseCategory.fromJson(response.data);
  }

  Future<ExpenseCategory> updateCategory(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.dio.put('/categories/$id', data: data);
    return ExpenseCategory.fromJson(response.data);
  }

  Future<void> deleteCategory(int id) async {
    await _apiClient.dio.delete('/categories/$id');
  }

  Future<List<Map<String, dynamic>>> fetchChartData() async {
    final response = await _apiClient.dio.get('/transactions/chart');
    return List<Map<String, dynamic>>.from(response.data);
  }
}
