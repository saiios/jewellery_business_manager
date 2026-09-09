import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';

class WhatsAppService {
  static String buildCustomerMessage(Product product) {
    final availability = product.quantity > 0
        ? 'Available: ${product.quantity} pieces'
        : 'Available: Sold Out';

    return '''
${product.productName}
Price: ₹${product.sellingPrice.toStringAsFixed(0)}
$availability
'''
        .trim();
  }

  static Future<void> shareProduct(Product product) async {
    final message = buildCustomerMessage(product);

    if (product.imageUrl == null || product.imageUrl!.trim().isEmpty) {
      await SharePlus.instance.share(ShareParams(text: message));
      return;
    }

    try {
      final response = await http.get(Uri.parse(product.imageUrl!));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to download product image.');
      }

      final Uint8List imageBytes = response.bodyBytes;

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          files: [
            XFile.fromData(
              imageBytes,
              name: 'jewellery_product.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
          fileNameOverrides: const ['jewellery_product.jpg'],
        ),
      );
    } catch (error) {
      // If image sharing fails, still allow text sharing.
      await SharePlus.instance.share(ShareParams(text: message));
    }
  }
}
