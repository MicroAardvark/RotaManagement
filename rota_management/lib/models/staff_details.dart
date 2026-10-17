String _str(dynamic value) => value is String ? value : '';

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

/// Reads a date-only value saved at UTC midnight back as a local date.
DateTime? _date(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value)?.toUtc();
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// One option in the right to work dropdown (GET /api/employees/rtw-types).
class RtwType {
  final String value;
  final String label;

  /// Time-limited permission needs a follow-up check date.
  final bool timeLimited;

  const RtwType({required this.value, required this.label, required this.timeLimited});

  factory RtwType.fromJson(Map<String, dynamic> json) => RtwType(
        value: json['value'] as String,
        label: json['label'] as String,
        timeLimited: json['timeLimited'] == true,
      );
}

/// An uploaded proof document on someone's record.
class StaffDocument {
  final String id;
  final String kind; // rightToWork or niProof
  final String mimeType;
  final DateTime? uploadedAt;

  const StaffDocument({
    required this.id,
    required this.kind,
    required this.mimeType,
    this.uploadedAt,
  });

  factory StaffDocument.fromJson(Map<String, dynamic> json) => StaffDocument(
        id: json['_id'] as String,
        kind: _str(json['kind']),
        mimeType: _str(json['mimeType']),
        uploadedAt: DateTime.tryParse(_str(json['createdAt']))?.toLocal(),
      );
}

/// What the add/edit staff sheet sends to the API.
class StaffInput {
  final String name;
  final String email; // ignored when editing
  final String role;
  final String phone;
  final String houseNumber;
  final String addressLine1;
  final String town;
  final String postcode;
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;
  final String rtwCheckType;
  final DateTime? rtwFollowUpDue;
  final String niNumber;

  const StaffInput({
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.houseNumber,
    required this.addressLine1,
    required this.town,
    required this.postcode,
    required this.emergencyName,
    required this.emergencyRelationship,
    required this.emergencyPhone,
    required this.rtwCheckType,
    required this.rtwFollowUpDue,
    required this.niNumber,
  });

  Map<String, dynamic> toJson() {
    final due = rtwFollowUpDue;
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': {
        'houseNumber': houseNumber,
        'addressLine1': addressLine1,
        'town': town,
        'postcode': postcode,
      },
      'emergencyContact': {
        'name': emergencyName,
        'relationship': emergencyRelationship,
        'phone': emergencyPhone,
      },
      'rightToWork': {
        'checkType': rtwCheckType,
        // Date only: send UTC midnight so it can't shift a day
        'followUpDue': due == null
            ? null
            : DateTime.utc(due.year, due.month, due.day).toIso8601String(),
      },
      'niNumber': niNumber,
    };
  }
}

/// One person's full record (GET /api/employees/:id). Every field
/// tolerates being missing, so records from before these fields existed
/// still load.
class StaffRecord {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool passwordSet;
  final String phone;
  final String houseNumber;
  final String addressLine1;
  final String town;
  final String postcode;
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;
  final String rtwCheckType;
  final DateTime? rtwFollowUpDue;
  final String? rtwProofDocumentId;
  final String niNumber;
  final String? niProofDocumentId;
  final String? photoVersion;
  final bool detailsComplete;
  final List<StaffDocument> documents;

  const StaffRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.passwordSet,
    required this.phone,
    required this.houseNumber,
    required this.addressLine1,
    required this.town,
    required this.postcode,
    required this.emergencyName,
    required this.emergencyRelationship,
    required this.emergencyPhone,
    required this.rtwCheckType,
    required this.rtwFollowUpDue,
    required this.rtwProofDocumentId,
    required this.niNumber,
    required this.niProofDocumentId,
    required this.photoVersion,
    required this.detailsComplete,
    required this.documents,
  });

  factory StaffRecord.fromJson(Map<String, dynamic> employee, List<dynamic> documents) {
    final address = _map(employee['address']);
    final emergency = _map(employee['emergencyContact']);
    final rtw = _map(employee['rightToWork']);
    return StaffRecord(
      id: employee['_id'] as String,
      name: _str(employee['name']),
      email: _str(employee['email']),
      role: _str(employee['role']).isEmpty ? 'employee' : _str(employee['role']),
      passwordSet: employee['passwordSet'] == true,
      phone: _str(employee['phone']),
      houseNumber: _str(address['houseNumber']),
      addressLine1: _str(address['addressLine1']),
      town: _str(address['town']),
      postcode: _str(address['postcode']),
      emergencyName: _str(emergency['name']),
      emergencyRelationship: _str(emergency['relationship']),
      emergencyPhone: _str(emergency['phone']),
      rtwCheckType: _str(rtw['checkType']),
      rtwFollowUpDue: _date(rtw['followUpDue']),
      rtwProofDocumentId: rtw['proofDocumentId'] as String?,
      niNumber: _str(employee['niNumber']),
      niProofDocumentId: employee['niProofDocumentId'] as String?,
      photoVersion: employee['photoVersion'] as String?,
      detailsComplete: employee['detailsComplete'] == true,
      documents: documents
          .whereType<Map<String, dynamic>>()
          .map(StaffDocument.fromJson)
          .toList(),
    );
  }

  StaffDocument? documentById(String? documentId) {
    if (documentId == null) return null;
    for (final doc in documents) {
      if (doc.id == documentId) return doc;
    }
    return null;
  }
}
