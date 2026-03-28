import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scanned_item.dart';
import '../../../core/network/api_client.dart';

// Definimos un proveedor de listado mutable
final scannedItemsProvider = NotifierProvider<ScannedItemsNotifier, List<ScannedItem>>(() {
  return ScannedItemsNotifier();
});

class ScannedItemsNotifier extends Notifier<List<ScannedItem>> {
  @override
  List<ScannedItem> build() {
    ref.onDispose(() {
      _textRecognizer.close();
    });
    return [];
  }

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
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

    // 1. Intento con OCR local (ML Kit) para tener algo rápido
    if (imagePath != null) {
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        // Búsqueda simple de precio (ej: 00,00 o 0.00)
        final priceRegex = RegExp(r'(\d+[,\.]\d{2})');
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
             if (finalPrice == null) {
               final match = priceRegex.firstMatch(line.text);
               if (match != null) {
                 finalPrice = double.tryParse(match.group(1)!.replaceAll(',', '.'));
               }
             }
             // El nombre suele ser el bloque con más texto o el primero grande
             if (finalTitle == null && line.text.length > 5) {
               finalTitle = line.text;
             }
          }
        }
      } catch (e) {
        debugPrint("Error in local OCR: $e");
      }
    }

    // 2. Intento con IA del Backend (Gemini) - Sobrescribe si tiene éxito
    if (imagePath != null) {
      final aiData = await ApiClient.scanLabelWithAi(imagePath);
      if (aiData != null) {
        finalTitle = aiData['name'] ?? aiData['description'] ?? finalTitle;
        finalPrice = (aiData['price'] as num?)?.toDouble() ?? finalPrice;
        
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

  void decrementQuantity(String code) {
    final item = state.firstWhere((item) => item.code == code);
    if (item.quantity > 1) {
      state = [
        for (final s in state)
          if (s.code == code) s.copyWith(quantity: s.quantity - 1) else s
      ];
    } else {
      removeItem(code);
    }
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
