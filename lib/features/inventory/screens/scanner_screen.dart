import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
  final List<Uint8List> capturedFrames = [];
  String? lastCode;

  @override
  void initState() {
    super.initState();
    // Forzamos wakelock para evitar que la pantalla se apague
    _enableWakelock();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
      debugPrint("Wakelock activado correctamente");
    } catch (e) {
      debugPrint("Error activando Wakelock: $e");
    }
  }

  void _onBarcodeScanned(BarcodeCapture capture) async {
    if (isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    
    final rawCode = barcodes.first.rawValue!;
    final image = capture.image;

    // Si es un nuevo código o el primero de la ráfaga
    if (lastCode != rawCode) {
      lastCode = rawCode;
      capturedFrames.clear();
      if (image != null) capturedFrames.add(image);
      
      // Iniciamos contador de ráfaga (esperamos 3 capturas o 500ms)
      Timer(const Duration(milliseconds: 400), () => _startOcrProcessing(rawCode));
    } else {
      // Si recibimos más capturas del mismo código mientras esperamos, las añadimos
      if (image != null && capturedFrames.length < 3) {
        capturedFrames.add(image);
      }
    }
  }

  Future<void> _startOcrProcessing(String code) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    await AudioHapticFeedback.playSuccessBeep();

    String? tempPath;
    if (capturedFrames.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/last_scan.jpg');
        // Usamos el ÚLTIMO fotograma para asegurar mejor enfoque
        await file.writeAsBytes(capturedFrames.last);
        tempPath = file.path;
      } catch (e) {
        debugPrint("Error saving temp frame: $e");
      }
    }

    // Llamamos al servicio con la ruta de la imagen para que la procese Gemini
    await ref.read(scannedItemsProvider.notifier).processBarcode(code, imagePath: tempPath);
    
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        isProcessing = false;
        lastCode = null;
        capturedFrames.clear();
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
    WakelockPlus.disable();
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
                    width: 220, // Menos ancho según feedback del usuario
                    height: 160, // Más alto para compensar y encuadrar mejor la etiqueta
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.cyanAccent),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "ANALIZANDO CON IA...",
                              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "NUEVA LECTURA - TOCA PARA CONFIRMAR", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.orange, size: 20),
                        onPressed: () => ref.read(scannedItemsProvider.notifier).removeItem(pendingItems.first.code),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        onPressed: () => ref.read(scannedItemsProvider.notifier).confirmItem(pendingItems.first.code),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pendingItems.first.description, 
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Código: ${pendingItems.first.code} - Precio: ${pendingItems.first.price.toStringAsFixed(2)} €",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => ref.read(scannedItemsProvider.notifier).removeItem(item.code),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
