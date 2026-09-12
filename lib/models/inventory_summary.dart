class InventorySummary {
  final double currentStockPurchaseValue;
  final double currentStockSellingValue;
  final double potentialProfit;

  final double totalSalesRevenue;
  final double totalCostOfSoldItems;
  final double realizedProfit;

  final int itemsRemaining;
  final int itemsSold;
  final int productDesigns;
  final int categories;
  final int totalSales;

  const InventorySummary({
    required this.currentStockPurchaseValue,
    required this.currentStockSellingValue,
    required this.potentialProfit,
    required this.totalSalesRevenue,
    required this.totalCostOfSoldItems,
    required this.realizedProfit,
    required this.itemsRemaining,
    required this.itemsSold,
    required this.productDesigns,
    required this.categories,
    required this.totalSales,
  });
}
