class TenantProfile {
  const TenantProfile({
    required this.daycareName,
    required this.businessName,
    required this.phone,
    required this.businessEmail,
    required this.personalEmail,
    required this.description,
    required this.ownerMessage,
    required this.hoursStartDay,
    required this.hoursEndDay,
    required this.hoursOpeningHour,
    required this.hoursClosingHour,
    required this.languagesList,
    required this.availabilityList,
    required this.programsOffered,
    required this.websiteExternalUrl,
    required this.websiteInstagramUrl,
    required this.websiteTikTokUrl,
    required this.planStatus,
    required this.featurePlan,
    required this.featureDaycare,
    required this.verificationStatus,
    required this.dealerCode,
  });

  final String daycareName;
  final String businessName;
  final String phone;
  final String businessEmail;
  final String personalEmail;
  final String description;
  final String ownerMessage;
  final String hoursStartDay;
  final String hoursEndDay;
  final String hoursOpeningHour;
  final String hoursClosingHour;
  final List<String> languagesList;
  final List<String> availabilityList;
  final String programsOffered;
  final String websiteExternalUrl;
  final String websiteInstagramUrl;
  final String websiteTikTokUrl;
  final String planStatus;
  final String featurePlan;
  final bool featureDaycare;
  final String verificationStatus;
  final String dealerCode;

  factory TenantProfile.fromMap(Map<String, dynamic> data) {
    return TenantProfile(
      daycareName: (data['daycareName'] ?? '').toString(),
      businessName: (data['businessName'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      businessEmail: (data['businessEmail'] ?? data['email'] ?? '').toString(),
      personalEmail: (data['personalEmail'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      ownerMessage: (data['websiteOwnerMessage'] ?? '').toString(),
      hoursStartDay: (data['hoursStartDay'] ?? '').toString(),
      hoursEndDay: (data['hoursEndDay'] ?? '').toString(),
      hoursOpeningHour: (data['hoursOpeningHour'] ?? '').toString(),
      hoursClosingHour: (data['hoursClosingHour'] ?? '').toString(),
      languagesList: _asCleanList(data['languagesList'] ?? data['languages']),
      availabilityList: _asCleanList(
        data['availabilityList'] ?? data['availability'],
      ),
      programsOffered: (data['programsOffered'] ?? '').toString(),
      websiteExternalUrl: (data['websiteExternalUrl'] ?? '').toString(),
      websiteInstagramUrl: (data['websiteInstagramUrl'] ?? '').toString(),
      websiteTikTokUrl: (data['websiteTikTokUrl'] ?? '').toString(),
      planStatus: (data['planStatus'] ?? '').toString(),
      featurePlan: (data['featurePlan'] ?? '').toString(),
      featureDaycare: data['featureDaycare'] == true,
      verificationStatus: (data['verificationStatus'] ?? '').toString(),
      dealerCode: (data['dealerCode'] ?? '').toString(),
    );
  }

  static List<String> _asCleanList(dynamic raw) {
    final values = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final token = item.toString().trim();
        if (!_isInvalid(token)) values.add(token);
      }
      return values;
    }
    if (raw is String) {
      final parts = raw.split(',');
      for (final item in parts) {
        final token = item.trim();
        if (!_isInvalid(token)) values.add(token);
      }
    }
    return values;
  }

  static bool _isInvalid(String value) {
    final lowered = value.toLowerCase();
    return value.isEmpty ||
        lowered == 'null' ||
        lowered == 'n/a' ||
        lowered == 'na';
  }
}
