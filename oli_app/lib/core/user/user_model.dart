class User {
  final String idOli;
  final String name;
  final String initial;
  final String? avatarUrl;
  final double wallet;

  User({
    required this.idOli,
    required this.name,
    required this.initial,
    this.avatarUrl,
    required this.wallet,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      idOli: json['id_oli'],
      name: json['name'],
      initial: json['initial'] ?? json['name'][0].toUpperCase(),
      avatarUrl: json['avatar_url'],
      wallet: (json['wallet'] ?? 0).toDouble(),
    );
  }
}
