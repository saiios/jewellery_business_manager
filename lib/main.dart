import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/product_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/product_repository.dart';
import 'screens/add_product_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://glaojmnqpjhaflojzeed.supabase.co',
    publishableKey: 'sb_publishable_pvh9QY6Dr_AdAygo8LCm8Q_JY2MS36I',
  );

  final supabase = Supabase.instance.client;
  final repository = ProductRepository(supabase);

  runApp(JewelAdminApp(repository: repository));
}

class JewelAdminApp extends StatelessWidget {
  final ProductRepository repository;

  const JewelAdminApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jewel Admin',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: ProductListScreen(
        repository: ProductRepository(Supabase.instance.client),
      ),
    );
  }
}
