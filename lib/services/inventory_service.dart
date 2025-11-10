import 'package:visionvolcan_site_app/main.dart';

class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  // Get stock items for a specific site
  Future<List<Map<String, dynamic>>> getStockForSite(int siteId) async {
    final response = await supabase
        .from('inventory_stock')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Get used items for a specific site
  Future<List<Map<String, dynamic>>> getUsedItemsForSite(int siteId) async {
    final response = await supabase
        .from('inventory_used')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Add new stock item
  Future<void> addStockItem(Map<String, dynamic> item) async {
    await supabase.from('inventory_stock').insert(item);
  }

  // Update stock item
  Future<void> updateStockItem(String id, Map<String, dynamic> updatedItem) async {
    await supabase
        .from('inventory_stock')
        .update(updatedItem)
        .eq('id', id);
  }

  // Delete stock item
  Future<void> deleteStockItem(String id) async {
    await supabase
        .from('inventory_stock')
        .delete()
        .eq('id', id);
  }

  // Add used item (when material is consumed)
  Future<void> addUsedItem(Map<String, dynamic> item) async {
    await supabase.from('inventory_used').insert(item);
  }

  // Update used item
  Future<void> updateUsedItem(String id, Map<String, dynamic> updatedItem) async {
    await supabase
        .from('inventory_used')
        .update(updatedItem)
        .eq('id', id);
  }

  // Delete used item
  Future<void> deleteUsedItem(String id) async {
    await supabase
        .from('inventory_used')
        .delete()
        .eq('id', id);
  }

  // Use stock (reduces stock quantity and logs usage)
  Future<void> useStockItem({
    required int siteId,
    required String materialName,
    required int quantityUsed,
    required String date,
  }) async {
    // 1. Find the stock item
    final stockItems = await supabase
        .from('inventory_stock')
        .select()
        .eq('site_id', siteId)
        .eq('material', materialName);

    if (stockItems.isNotEmpty) {
      final stockItem = stockItems.first;
      final currentQty = stockItem['quantity'] as int;
      final newQty = currentQty - quantityUsed;

      // 2. Update stock quantity
      await supabase
          .from('inventory_stock')
          .update({'quantity': newQty})
          .eq('id', stockItem['id']);

      // 3. Log the usage
      await supabase.from('inventory_used').insert({
        'site_id': siteId,
        'sector': stockItem['sector'],
        'material': materialName,
        'quantity': quantityUsed,
        'unit': stockItem['unit'],
        'used_date': date,
      });

      print('Inventory Updated: Used $quantityUsed of $materialName');
    } else {
      print('Warning: $materialName not found in stock');
    }
  }
}