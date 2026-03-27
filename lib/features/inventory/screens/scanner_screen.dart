import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/utils/audio_haptic_feedback.dart';
import '../services/inventory_sync_service.dart';
import '../widgets/quick_add_product_dialog.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
  );
  
  bool isProcessing = false;

  void _onBarcodeScanned(BarcodeCapture capture) async {
    if (isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    
    final rawCode = barcodes.first.rawValue!;

    setState(() {
      isProcessing = true;
    });

    await AudioHapticFeedback.playSuccessBeep();

    // Intentamos capturar la imagen para el OCR si está disponible
    InputImage? inputImage;
    if (capture.image != null) {
      // Nota: En una implementación real, convertir el Uint8List a InputImage 
      // requiere guardarlo a temporal o usar InputImage.fromBytes si tenemos los metadatos.
      // Por simplicidad en este prototipo, simularemos que pasamos la imagen si existe.
      // (En producción usaríamos path_provider para el archivo temporal si es necesario)
    }

    // Invoca servicio con logica de negocio
    await ref.read(scannedItemsProvider.notifier).processBarcode(rawCode, inputImage: inputImage);
    
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _showQuickAddDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return QuickAddProductDialog(
          barcode: code,
          onSubmit: (desc, price) {
            ref.read(scannedItemsProvider.notifier).updateItemData(code, desc, price);
          },
        );
      }
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(scannedItemsProvider);
    final pendingItems = allItems.where((item) => !item.isConfirmed).toList();
    final confirmedItems = allItems.where((item) => item.isConfirmed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario ERP + OCR'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          )
        ],
      ),
      body: Column(
        children: [
          // Mitad superior: Cámara
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onBarcodeScanned,
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          
          // ZONA DE CONFIRMACIÓN (BOTÓN GIGANTE)
          if (pendingItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Column(
                children: [
                  const Text("NUEVA LECTURA - TOCA PARA CONFIRMAR", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      onPressed: () => ref.read(scannedItemsProvider.notifier).confirmItem(pendingItems.first.code),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(pendingItems.first.description, 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text("Código: ${pendingItems.first.code} - Precio OCR: ${pendingItems.first.price} €",
                            style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // LISTA DE CONFIRMADOS
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      "ARTÍCULOS CONFIRMADOS (Toca para +1)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: confirmedItems.isEmpty
                        ? const Center(child: Text("Nada confirmado aún."))
                        : ListView.builder(
                            itemCount: confirmedItems.length,
                            itemBuilder: (context, index) {
                              final item = confirmedItems[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12)
                                ),
                                child: InkWell(
                                  onTap: () => ref.read(scannedItemsProvider.notifier).incrementQuantity(item.code),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.green),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text("${item.code} | ${item.price} €", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        if (item.notFoundInApi)
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.orange),
                                            onPressed: () => _showQuickAddDialog(item.code),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            "x${item.quantity}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
