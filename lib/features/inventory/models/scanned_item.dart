class ScannedItem {
  final String code;
  final String description;
  final double price;
  final int quantity;
  final DateTime scannedAt;
  final bool isSynced;
  final bool notFoundInApi; 
  final bool isConfirmed;

  ScannedItem({
    required this.code,
    required this.description,
    required this.price,
    this.quantity = 0, // Inicia en 0 si no se ha pulsado nada, o 1 si lo prefieres
    required this.scannedAt,
    this.isSynced = false,
    this.notFoundInApi = false,
    this.isConfirmed = false,
  });

  ScannedItem copyWith({
    String? code,
    String? description,
    double? price,
    int? quantity,
    DateTime? scannedAt,
    bool? isSynced,
    bool? notFoundInApi,
    bool? isConfirmed,
  }) {
    return ScannedItem(
      code: code ?? this.code,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      scannedAt: scannedAt ?? this.scannedAt,
      isSynced: isSynced ?? this.isSynced,
      notFoundInApi: notFoundInApi ?? this.notFoundInApi,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}
