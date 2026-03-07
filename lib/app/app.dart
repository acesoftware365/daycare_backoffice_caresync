import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../features/auth/auth_gate.dart';
import 'theme_tokens.dart';

class DaycareBackofficeApp extends StatelessWidget {
  const DaycareBackofficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1440, 1024),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .doc('system/daycareapp_config')
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final palette = (data['palette'] ?? 'blush').toString().trim();

            return MaterialApp(
              title: 'Daycare Backoffice',
              debugShowCheckedModeBanner: false,
              theme: BackofficeTheme.forPalette(palette),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}
