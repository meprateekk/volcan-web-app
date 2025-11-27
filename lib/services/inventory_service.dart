import 'package:visionvolcan_site_app/main.dart';

class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  // =======================================================
  // 📈 NEW FUNCTIONS FOR THE "INVENTORY" SCREEN
  // =======================================================

  // NEW: Gets all purchases from the 'raw_material_purchases' table
  // This is used by InventoryScreen to calculate "Total Bought".
  Future<List<Map<String, dynamic>>> getAllPurchases(int siteId) async {
    final response = await supabase
        .from('raw_material_purchases')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // NEW: Gets all consumed logs from the 'material_consumed' table
  // This is used by InventoryScreen to calculate "Total Used".
  Future<List<Map<String, dynamic>>> getAllConsumed(int siteId) async {
    final response = await supabase
        .from('material_consumed')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // NEW: Adds a new "usage" log to the 'material_consumed' table
  // This is called when you press the "+" button on the "Consumed" tab.
  Future<void> logMaterialUsage(Map<String, dynamic> item) async {
    await supabase.from('material_consumed').insert(item);
  }

  // NEW: Deletes a "usage" log from the 'material_consumed' table
  // This is called when you press the delete button on the "Consumed" tab.
  Future<void> deleteConsumedLog(String id) async {
    await supabase
        .from('material_consumed')
        .delete()
        .eq('id', id);
  }


  // =======================================================
  // 🗑️ OLD, DEPRECATED FUNCTIONS
  // We no longer use these, but we'll keep them here for now.
  // =======================================================

  Future<List<Map<String, dynamic>>> getStockForSite(int siteId) async {
    // This function is no longer used.
    // The 'inventory_stock' table is no longer used.
    return [];
  }

  Future<void> addStockItem(Map<String, dynamic> item) async {
    // This function is no longer used.
  }

  Future<void> updateStockItem(String id, Map<String, dynamic> updatedItem) async {
    // This function is no longer used.
  }

  Future<void> deleteStockItem(String id) async {
    // This function is no longer used.
  }

  Future<List<Map<String, dynamic>>> getUsedItemsForSite(int siteId) async {
    // This function is no longer used.
    // The 'inventory_used' table is no longer used.
    return [];
  }

  Future<void> addUsedItem(Map<String, dynamic> item) async {
    // This function is no longer used.
  }


  Future<void> updateUsedItem(String id, Map<String, dynamic> updatedItem) async {
    // This function is no longer used.
  }

  Future<void> deleteUsedItem(String id) async {
    // This function is no longer used.
  }

  Future<void> useStockItem({
    required Map<String, dynamic> stockItem,
    required int quantityUsed,
    required String date,
  }) async {
    // This function is no longer used.
  }
}