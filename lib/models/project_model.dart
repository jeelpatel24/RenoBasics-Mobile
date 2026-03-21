class ProjectModel {
  final String id;
  final String homeownerUid;
  final String projectTitle;
  final String category;
  final String categoryName;
  final String propertyType;
  final String ownershipStatus;
  final String budgetRange;
  final String budgetLabel;
  final int creditCost;
  final String preferredStartDate;
  final String city;
  final String status;
  final String createdAt;
  final String updatedAt;

  ProjectModel({
    required this.id,
    required this.homeownerUid,
    required this.projectTitle,
    required this.category,
    required this.categoryName,
    required this.propertyType,
    required this.ownershipStatus,
    required this.budgetRange,
    required this.budgetLabel,
    required this.creditCost,
    required this.preferredStartDate,
    required this.city,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromMap(Map<dynamic, dynamic> map) {
    return ProjectModel(
      id: map['id'] ?? '',
      homeownerUid: map['homeownerUid'] ?? '',
      projectTitle: map['projectTitle'] ?? '',
      category: map['category'] ?? '',
      categoryName: map['categoryName'] ?? '',
      propertyType: map['propertyType'] ?? '',
      ownershipStatus: map['ownershipStatus'] ?? '',
      budgetRange: map['budgetRange'] ?? '',
      budgetLabel: map['budgetLabel'] ?? '',
      creditCost: (map['creditCost'] as num?)?.toInt() ?? 0,
      preferredStartDate: map['preferredStartDate'] ?? '',
      city: map['city'] ?? '',
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  factory ProjectModel.fromFirestore(Map<String, dynamic> map, String docId) {
    return ProjectModel(
      id: docId,
      homeownerUid: map['homeownerUid'] ?? '',
      projectTitle: map['projectTitle'] ?? '',
      category: map['category'] ?? '',
      categoryName: map['categoryName'] ?? '',
      propertyType: map['propertyType'] ?? '',
      ownershipStatus: map['ownershipStatus'] ?? '',
      budgetRange: map['budgetRange'] ?? '',
      budgetLabel: map['budgetLabel'] ?? '',
      creditCost: (map['creditCost'] as num?)?.toInt() ?? 0,
      preferredStartDate: map['preferredStartDate'] ?? '',
      city: map['city'] ?? '',
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] is String
          ? (map['createdAt'] as String)
          : (map['createdAt']?.toDate() ?? DateTime.now()).toIso8601String(),
      updatedAt: map['updatedAt'] is String
          ? (map['updatedAt'] as String)
          : (map['updatedAt']?.toDate() ?? DateTime.now()).toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'homeownerUid': homeownerUid,
      'projectTitle': projectTitle,
      'category': category,
      'categoryName': categoryName,
      'propertyType': propertyType,
      'ownershipStatus': ownershipStatus,
      'budgetRange': budgetRange,
      'budgetLabel': budgetLabel,
      'creditCost': creditCost,
      'preferredStartDate': preferredStartDate,
      'city': city,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class ProjectPrivateDetails {
  final String homeownerName;
  final String homeownerEmail;
  final String homeownerPhone;
  final String fullDescription;
  final String streetAddress;
  final String unit;
  final String province;
  final String postalCode;
  final List<String> scopeOfWork;
  final String hasDrawings;
  final String hasPermits;
  final String materialsProvider;
  final String deadline;
  final String contactPreference;
  final String parkingAvailable;
  final String buildingRestrictions;
  final List<String> photos;

  ProjectPrivateDetails({
    required this.homeownerName,
    required this.homeownerEmail,
    required this.homeownerPhone,
    required this.fullDescription,
    this.streetAddress = '',
    this.unit = '',
    this.province = '',
    this.postalCode = '',
    this.scopeOfWork = const [],
    this.hasDrawings = '',
    this.hasPermits = '',
    this.materialsProvider = '',
    this.deadline = '',
    this.contactPreference = 'in_app',
    this.parkingAvailable = '',
    this.buildingRestrictions = '',
    this.photos = const [],
  });

  factory ProjectPrivateDetails.fromMap(Map<dynamic, dynamic> map) {
    return ProjectPrivateDetails(
      homeownerName: map['homeownerName'] ?? '',
      homeownerEmail: map['homeownerEmail'] ?? '',
      homeownerPhone: map['homeownerPhone'] ?? '',
      fullDescription: map['fullDescription'] ?? '',
      streetAddress: map['streetAddress'] ?? '',
      unit: map['unit'] ?? '',
      province: map['province'] ?? '',
      postalCode: map['postalCode'] ?? '',
      scopeOfWork: map['scopeOfWork'] != null
          ? List<String>.from(map['scopeOfWork'] as List)
          : [],
      hasDrawings: map['hasDrawings'] ?? '',
      hasPermits: map['hasPermits'] ?? '',
      materialsProvider: map['materialsProvider'] ?? '',
      deadline: map['deadline'] ?? '',
      contactPreference: map['contactPreference'] ?? 'in_app',
      parkingAvailable: map['parkingAvailable'] ?? '',
      buildingRestrictions: map['buildingRestrictions'] ?? '',
      photos: map['photos'] != null
          ? List<String>.from(map['photos'] as List)
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'homeownerName': homeownerName,
      'homeownerEmail': homeownerEmail,
      'homeownerPhone': homeownerPhone,
      'fullDescription': fullDescription,
      'streetAddress': streetAddress,
      'unit': unit,
      'province': province,
      'postalCode': postalCode,
      'scopeOfWork': scopeOfWork,
      'hasDrawings': hasDrawings,
      'hasPermits': hasPermits,
      'materialsProvider': materialsProvider,
      'deadline': deadline,
      'contactPreference': contactPreference,
      'parkingAvailable': parkingAvailable,
      'buildingRestrictions': buildingRestrictions,
      'photos': photos,
    };
  }
}
