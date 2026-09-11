class InventorySummary {
  final double currentStockPurchaseValue;
  final double expectedSalesValue;
  final double potentialProfit;
  final int itemsRemaining;
  final int productDesigns;
  final int categories;

  const InventorySummary({
    required this.currentStockPurchaseValue,
    required this.expectedSalesValue,
    required this.potentialProfit,
    required this.itemsRemaining,
    required this.productDesigns,
    required this.categories,
  });
}
