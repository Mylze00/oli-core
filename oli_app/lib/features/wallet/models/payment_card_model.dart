class PaymentCard {
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final String cardholderName;

  PaymentCard({
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    required this.cardholderName,
  });

  // Validation helpers
  bool get isValidCardNumber {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d{16}$').hasMatch(cleaned);
  }

  bool get isValidExpiryDate {
    return RegExp(r'^\d{2}/\d{2}$').hasMatch(expiryDate);
  }

  bool get isValidCvv {
    return RegExp(r'^\d{3,4}$').hasMatch(cvv);
  }

  bool get isValid {
    return isValidCardNumber && isValidExpiryDate && isValidCvv;
  }

  // Get masked card number for display
  String get maskedCardNumber {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length >= 4) {
      return '**** **** **** ${cleaned.substring(cleaned.length - 4)}';
    }
    return '****';
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber.replaceAll(RegExp(r'\s'), ''),
      'expiryDate': expiryDate,
      'cvv': cvv,
      'cardholderName': cardholderName,
    };
  }
}
