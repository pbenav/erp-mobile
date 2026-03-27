import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scanned_item.dart';
import '../../../core/network/api_client.dart';

// Definimos un proveedor de listado mutable
final scannedItemsProvider = StateNotifierProvider<ScannedItemsNotifier, List<ScannedItem>>((ref) {
  return ScannedItemsNotifier();
});

class ScannedItemsNotifier extends StateNotifier<List<ScannedItem>> {
  ScannedItemsNotifier() : super([]);

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // Limpia el código escaneado quitando asteriscos
  String _cleanBarcode(String rawCode) {
    return rawCode.replaceAll('*', '').trim();
  }

  Future<void> processBarcode(String rawCode, {List<InputImage>? images}) async {
    final cleanCode = _cleanBarcode(rawCode);
    
    // Si ya existe uno "Pendiente" con el mismo código, no procesamos de nuevo
    if (state.any((item) => item.code == cleanCode && !item.isConfirmed)) {
      return;
    }

    String? finalTitle;
    double? finalPrice;

    if (images != null && images.isNotEmpty) {
      final List<Map<String, dynamic>> results = [];

      for (var img in images) {
        try {
          final RecognizedText recognizedText = await _textRecognizer.processImage(img);
          final lines = recognizedText.blocks.expand((b) => b.lines).map((l) => l.text).toList();
          
          double? p;
          String? t;

          // 1. Buscar precio
          final priceRegex = RegExp(r'(\d+[,.]\d{2})\s*€');
          for (var line in lines) {
            final match = priceRegex.firstMatch(line);
            if (match != null) {
              p = double.tryParse(match.group(1)!.replaceAll(',', '.'));
              break;
            }
          }

          // 2. Buscar descripción (línea más larga que no sea precio ni código)
          if (lines.isNotEmpty) {
            t = lines.firstWhere(
              (l) => !l.contains('€') && !l.contains('*') && l.length > 3,
              orElse: () => '',
            );
          }

          if (t != null && t.isNotEmpty) {
            results.add({'title': t, 'price': p});
          }
        } catch (e) {
          print("OCR Error in frame: $e");
        }
      }

      if (results.isNotEmpty) {
        // Lógica de Consenso:
        if (results.length >= 2) {
          // Si los dos primeros coinciden, perfecto
          if (results[0]['title'] == results[1]['title'] && results[0]['price'] == results[1]['price']) {
            finalTitle = results[0]['title'];
            finalPrice = results[0]['price'];
          } else if (results.length >= 3) {
            // Si hay 3, buscamos mayoría
            // (Simplificado: si 1==2 o 1==3 o 2==3)
            if (results[0]['title'] == results[2]['title'] && results[0]['price'] == results[2]['price']) {
              finalTitle = results[0]['title'];
              finalPrice = results[2]['price'];
            } else if (results[1]['title'] == results[2]['title'] && results[1]['price'] == results[2]['price']) {
              finalTitle = results[1]['title'];
              finalPrice = results[1]['price'];
            }
          }
        }

        // Si no hay consenso claro, cogemos el primero que tenga precio
        if (finalTitle == null) {
          final best = results.firstWhere((r) => r['price'] != null, orElse: () => results.first);
          finalTitle = best['title'];
          finalPrice = best['price'];
        }
      }
    }

    final newItem = ScannedItem(
      code: cleanCode,
      description: (finalTitle != null && finalTitle.isNotEmpty) ? finalTitle : 'Buscando...',
      price: finalPrice ?? 0.0,
      scannedAt: DateTime.now(),
      isConfirmed: false,
      notFoundInApi: finalTitle == null,
    );
    
    // Si ya existe uno "Pendiente" con el mismo código, no añadimos otro, 
    // solo lo mantenemos para confirmar.
    if (state.any((item) => item.code == cleanCode && !item.isConfirmed)) {
      return;
    }

    state = [newItem, ...state];

    // Consulta API en paralelo (si no hay OCR o para validar)
    if (finalTitle == null) {
      final productData = await ApiClient.fetchProductData(cleanCode);
      if (productData != null) {
        state = [
          for (final item in state)
            if (item.code == cleanCode && !item.isConfirmed)
              item.copyWith(
                description: productData['description'],
                price: productData['price'].toDouble(),
                isSynced: true,
                notFoundInApi: false,
              )
            else
              item
        ];
      }
    }
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
