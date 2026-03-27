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

  Future<void> processBarcode(String rawCode, {InputImage? inputImage}) async {
    final cleanCode = _cleanBarcode(rawCode);

    // Si ya existe en la lista (confirmado o no), incrementamos cantidad 
    // pero el usuario pidió que el escaneo cree el botón de confirmación.
    
    // Buscamos si ya existe
    final existingIndex = state.indexWhere((item) => item.code == cleanCode);
    
    if (existingIndex != -1) {
      // Si ya existe, simplemente lo movemos al principio (opcional) e incrementamos si está confirmado?
      // El usuario dice: "se escanea... aparece como botón para que el usuario lo confirme"
      // Si re-escanea el mismo, lo tratamos como un toque? O simplemente lo destacamos.
      // Vamos a seguir la lógica de: Escaneo -> Aparece arriba para confirmar.
    }

    // Datos extraídos por OCR si se proporciona imagen
    String? ocrTitle;
    double? ocrPrice;

    if (inputImage != null) {
      try {
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        final lines = recognizedText.blocks.expand((b) => b.lines).map((l) => l.text).toList();
        
        // Lógica de extracción simple:
        // 1. Precio: Buscar algo que termine en "€" o sea un número decimal al final
        final priceRegex = RegExp(r'(\d+[,.]\d{2})\s*€');
        for (var line in lines) {
          final match = priceRegex.firstMatch(line);
          if (match != null) {
            ocrPrice = double.tryParse(match.group(1)!.replaceAll(',', '.'));
          }
        }

        // 2. Descripción: Suele estar cerca del código. 
        // En la foto está justo debajo del código de barras. 
        // Como el código suele ser corto y en mayúsculas, buscamos líneas de texto largas.
        if (lines.isNotEmpty) {
          // Buscamos una línea que no sea el precio ni el código exacto
          ocrTitle = lines.firstWhere(
            (l) => !l.contains('€') && !l.contains('*') && l.length > 3,
            orElse: () => 'Producto OCR',
          );
        }
      } catch (e) {
        print("OCR Error: $e");
      }
    }

    final newItem = ScannedItem(
      code: cleanCode,
      description: ocrTitle ?? 'Buscando...',
      price: ocrPrice ?? 0.0,
      scannedAt: DateTime.now(),
      isConfirmed: false,
      notFoundInApi: ocrTitle == null,
    );
    
    // Si ya existe uno "Pendiente" con el mismo código, no añadimos otro, 
    // solo lo mantenemos para confirmar.
    if (state.any((item) => item.code == cleanCode && !item.isConfirmed)) {
      return;
    }

    state = [newItem, ...state];

    // Consulta API en paralelo (si no hay OCR o para validar)
    if (ocrTitle == null) {
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
