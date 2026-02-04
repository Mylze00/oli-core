class User {
  final int id; // Backend ID (Primary Key)
  final String? idOli;
  final String name;
  final String? phone; // Numéro de téléphone
  final String initial;
  final String? avatarUrl;
  final double wallet;
  final String? subscriptionPlan; // 'none', 'certified', 'enterprise'
  final bool isAdmin;
  final bool isVerified; // Basic verification
  final String accountType; // 'ordinary', 'certifie', 'entreprise', 'premium'

  User({
    required this.id,
    this.idOli,
    required this.name,
    this.phone,
    required this.initial,
    this.avatarUrl,
    required this.wallet,
    this.subscriptionPlan,
    this.isAdmin = false,
    this.isVerified = false,
    this.accountType = 'ordinary',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      idOli: json['id_oli'],
      name: json['name'],
      phone: json['phone'],
      initial: json['initial'] ?? (json['name'] != null ? json['name'][0].toUpperCase() : '?'),
      avatarUrl: json['avatar_url'],
      wallet: double.tryParse(json['wallet']?.toString() ?? '0') ?? 0.0,
      subscriptionPlan: json['subscription_plan'],
      isAdmin: json['is_admin'] ?? false,
      isVerified: json['is_verified'] ?? false,
      accountType: json['account_type'] ?? 'ordinary',
    );
  }

  // Helpers
  bool get isCertified => accountType == 'certifie' || subscriptionPlan == 'certified';
  bool get isEnterprise => accountType == 'entreprise' || subscriptionPlan == 'enterprise';
  bool get isPremium => accountType == 'premium';
}
