import 'package:flutter/material.dart';

class QuickAddProductDialog extends StatefulWidget {
  final String barcode;
  final Function(String description, double price) onSubmit;

  const QuickAddProductDialog({
    Key? key,
    required this.barcode,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<QuickAddProductDialog> {
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
    if (_descController.text.isNotEmpty && price > 0) {
      widget.onSubmit(_descController.text, price);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Nueva: ${widget.barcode}", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Etiqueta no encontrada en SientiaERP. Dénla de alta rápido:", style: TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Descripción corta', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio (PVP)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
