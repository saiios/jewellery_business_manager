import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/product_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repositories/product_category_repository.dart';

import 'firebase_options.dart';
import 'repositories/product_repository.dart';
import 'services/admin_push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://glaojmnqpjhaflojzeed.supabase.co',
    publishableKey: 'sb_publishable_pvh9QY6Dr_AdAygo8LCm8Q_JY2MS36I',
  );

  final supabase = Supabase.instance.client;

  final repository = ProductRepository(supabase);

  // Keep category-admin auth separate from the existing product client so signing
  // into category management does not change the role/session used by legacy CRUD.
  final categoryAuthClient = SupabaseClient(
    'https://glaojmnqpjhaflojzeed.supabase.co',
    'sb_publishable_pvh9QY6Dr_AdAygo8LCm8Q_JY2MS36I',
    authOptions: const AuthClientOptions(),
  );
  final categoryRepository = ProductCategoryRepository(
    publicClient: supabase,
    adminClient: categoryAuthClient,
  );

  final pushService = AdminPushNotificationService(supabase: supabase);

  await pushService.initialize();

  runApp(
    JewelAdminApp(
      repository: repository,
      categoryRepository: categoryRepository,
    ),
  );
}

class JewelAdminApp extends StatelessWidget {
  final ProductRepository repository;
  final ProductCategoryRepository categoryRepository;

  const JewelAdminApp({
    super.key,
    required this.repository,
    required this.categoryRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jewel Admin',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: ProductListScreen(
        repository: repository,
        categoryRepository: categoryRepository,
      ),
    );
  }
}
