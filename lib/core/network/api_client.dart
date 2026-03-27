import 'package:dio/dio.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://erp.sientia.test/api', // TODO: Update to real URL
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  static Future<Map<String, dynamic>?> fetchProductData(String code) async {
    try {
      // Endpoint mock, assumes SientiaERP has an endpoint to fetch product by code
      // final response = await _dio.get('/products/$code');
      // return response.data;
      
      // MOCK DATA for now to ensure prototype works offline
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'code': code,
        'description': 'Producto Descargado Sientia',
        'price': 25.50
      };
    } catch (e) {
      return null; // Devuelve null si no existe o falla conexión
    }
  }
}
