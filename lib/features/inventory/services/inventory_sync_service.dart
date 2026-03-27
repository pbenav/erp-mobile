import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scanned_item.dart';
import '../../../core/network/api_client.dart';

// Definimos un proveedor de listado mutable
final scannedItemsProvider = StateNotifierProvider<ScannedItemsNotifier, List<ScannedItem>>((ref) {
  return ScannedItemsNotifier();
});

class ScannedItemsNotifier extends StateNotifier<List<ScannedItem>> {
  ScannedItemsNotifier() : super([]);

  // Limpia el código escaneado quitando asteriscos
  String _cleanBarcode(String rawCode) {
    return rawCode.replaceAll('*', '').trim();
  }

  Future<void> processBarcode(String rawCode, {String? imagePath}) async {
    final cleanCode = _cleanBarcode(rawCode);
    
    // Si ya existe uno "Pendiente" con el mismo código, no procesamos de nuevo
    if (state.any((item) => item.code == cleanCode && !item.isConfirmed)) {
      return;
    }

    String? finalTitle;
    double? finalPrice;

    // Si tenemos imagen, usamos la IA del Backend (Gemini)
    if (imagePath != null) {
      final aiData = await ApiClient.scanLabelWithAi(imagePath);
      if (aiData != null) {
        finalTitle = aiData['name'] ?? aiData['description'];
        finalPrice = (aiData['price'] as num?)?.toDouble();
        
        // Si el backend encontró el producto en la DB, podemos usar esos datos
        if (aiData['in_database'] == true) {
          finalTitle = aiData['database_name'] ?? finalTitle;
          finalPrice = (aiData['database_price'] as num?)?.toDouble() ?? finalPrice;
        }
      }
    }

    final newItem = ScannedItem(
      code: cleanCode,
      description: (finalTitle != null && finalTitle.isNotEmpty) ? finalTitle : 'Desconocido',
      price: finalPrice ?? 0.0,
      scannedAt: DateTime.now(),
      isConfirmed: false,
      notFoundInApi: finalTitle == null,
    );
    
    state = [newItem, ...state];
  }

  void removeItem(String code) {
    state = state.where((item) => item.code != code).toList();
  }

  void confirmItem(String code) {
    state = [
      for (final item in state)
        if (item.code == code)
          item.copyWith(
            isConfirmed: true,
            quantity: item.quantity + 1,
          )
        else
          item
    ];
  }

  void incrementQuantity(String code) {
    state = [
      for (final item in state)
        if (item.code == code)
          item.copyWith(quantity: item.quantity + 1)
        else
          item
    ];
  }

  void updateItemData(String code, String newDesc, double newPrice) {
    state = [
      for (final item in state)
        if (item.code == code)
          item.copyWith(
            description: newDesc,
            price: newPrice,
            notFoundInApi: false,
            isSynced: true,
            isConfirmed: true,
            quantity: item.quantity == 0 ? 1 : item.quantity,
          )
        else
          item
    ];
  }
}
