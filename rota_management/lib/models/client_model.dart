class Client {
  final String id;
  final String name;
  final String houseNumber;
  final String addressLine1;
  final String postcode;
  final String phone;
  final String email;
  final String access;

  Client({
    required this.id,
    required this.name,
    required this.houseNumber,
    required this.addressLine1,
    required this.postcode,
    required this.phone,
    required this.email,
    required this.access,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['_id'] as String,
      name: json['name'] as String,
      houseNumber: json['houseNumber'] as String? ?? '',
      addressLine1: json['addressLine1'] as String? ?? '',
      postcode: json['postcode'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      access: json['access'] as String? ?? ''
    );
  }
  String get fullAddress => '$houseNumber $addressLine1, $postcode';
}