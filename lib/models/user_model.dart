class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final String? profilePicture;
  final String createdAt;
  final String updatedAt;

  // Contractor-specific
  final String? companyName;
  final String? contactName;
  final String? businessNumber;
  final String? obrNumber;
  final String? verificationStatus;
  final String? verifiedDate;
  final String? adminNotes;
  final int creditBalance;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.profilePicture,
    required this.createdAt,
    required this.updatedAt,
    this.companyName,
    this.contactName,
    this.businessNumber,
    this.obrNumber,
    this.verificationStatus,
    this.verifiedDate,
    this.adminNotes,
    this.creditBalance = 0,
  });

  factory AppUser.fromMap(Map<dynamic, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'homeowner',
      profilePicture: map['profilePicture'],
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
      companyName: map['companyName'],
      contactName: map['contactName'],
      businessNumber: map['businessNumber'],
      obrNumber: map['obrNumber'],
      verificationStatus: map['verificationStatus'],
      verifiedDate: map['verifiedDate'],
      adminNotes: map['adminNotes'],
      creditBalance: (map['creditBalance'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'creditBalance': creditBalance,
    };
    if (profilePicture != null) map['profilePicture'] = profilePicture;
    if (companyName != null) map['companyName'] = companyName;
    if (contactName != null) map['contactName'] = contactName;
    if (businessNumber != null) map['businessNumber'] = businessNumber;
    if (obrNumber != null) map['obrNumber'] = obrNumber;
    if (verificationStatus != null) map['verificationStatus'] = verificationStatus;
    if (verifiedDate != null) map['verifiedDate'] = verifiedDate;
    if (adminNotes != null) map['adminNotes'] = adminNotes;
    return map;
  }

  bool get isHomeowner => role == 'homeowner';
  bool get isContractor => role == 'contractor';
  bool get isAdmin => role == 'admin';
  bool get isVerified => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';
}
