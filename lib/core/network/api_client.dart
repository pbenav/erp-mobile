import 'package:dio/dio.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://erp.sientia.test/api', // TODO: Update to real URL
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  static Future<Map<String, dynamic>?> scanLabelWithAi(String imagePath) async {
    try {
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(imagePath, filename: "label_scan.jpg"),
      });

      final response = await _dio.post('/erp/productos/scan-label', data: formData);
      return response.data;
    } catch (e) {
      print("Error in scanLabelWithAi: $e");
      return null;
    }
  }
}
