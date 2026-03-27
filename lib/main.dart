import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: InventoryApp()));
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sientia ERP Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Model
class ScannedItem {
  final String code;
  final String description;
  final double price;
  final int quantity;
  final DateTime scannedAt;

  ScannedItem({
    required this.code,
    required this.description,
    required this.price,
    this.quantity = 1,
    required this.scannedAt,
  });
}

// State Management
final scannedItemsProvider = StateNotifierProvider<ScannedItemsNotifier, List<ScannedItem>>((ref) {
  return ScannedItemsNotifier();
});

class ScannedItemsNotifier extends StateNotifier<List<ScannedItem>> {
  ScannedItemsNotifier() : super([]);

  void addItem(ScannedItem item) {
    // Si queremos agrupar cantidades o simplemente listar el último arriba:
    state = [item, ...state];
  }
}

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
  );
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isProcessing = false;

  Future<void> _playBeep() async {
    // beep rápido usando audioplayers o fallback a Haptic
    try {
      HapticFeedback.vibrate();
      // Reproducir sonido system alert si tienes un asset, 
      // Por ahora, solo vibramos para feedback inmediato fiable
    } catch (e) {
      debugPrint("Error play beep: $e");
    }
  }

  void _onBarcodeScanned(BarcodeCapture capture) async {
    if (isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;
    final code = barcode.rawValue!;

    setState(() {
      isProcessing = true;
    });

    await _playBeep();

    // Lógica Mock API (Simula tardar 500ms y añadir)
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Aquí es donde comprobarías en Sientia si existe o no.
    // Vamos a simular que lo añadimos directo a la lista temporal
    ref.read(scannedItemsProvider.notifier).addItem(
      ScannedItem(
        code: code,
        description: 'Artículo Escaneado',
        price: 0.0,
        scannedAt: DateTime.now(),
      )
    );
    
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Escaneado: $code"),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.green.shade800,
      )
    );

    // Damos un pequeño delay antes de permitir otra lectura
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      isProcessing = false;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(scannedItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario ERP'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Mitad superior: Cámara
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onBarcodeScanned,
                ),
                // Guía central
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          
          // Mitad inferior: Lista en tiempo real
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Últimos artículos escaneados:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text("Cámara lista. Escanea una etiqueta."))
                        : ListView.builder(
                            itemCount: items.length < 10 ? items.length : 10,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.qr_code),
                                  title: Text(item.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("\$${item.price} - ${item.scannedAt.hour}:${item.scannedAt.minute}:${item.scannedAt.second}"),
                                  trailing: CircleAvatar(child: Text("${item.quantity}")),
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
