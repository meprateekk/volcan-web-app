import 'package:visionvolcan_site_app/main.dart';
import 'package:visionvolcan_site_app/services/cache_service.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  // --- *** NEW MATERIAL PURCHASE FUNCTIONS *** ---
  // These talk to your new 'raw_material_purchases' table

  // NEW: Gets all purchases for a specific site
  Future<List<Map<String, dynamic>>> getMaterialPurchasesForSite(int siteId, {bool forceRefresh = false}) async {
    return await CacheService.instance.getMaterialPurchasesForSite(siteId, forceRefresh: forceRefresh);
  }

  // 2. Realtime Stream (Isse ADD karo)
  Stream<List<Map<String, dynamic>>> materialPurchasesStream(int siteId) {
    return supabase
        .from('raw_material_purchases')
        .stream(primaryKey: ['id']) // 'id' column primary key hona zaroori hai
        .eq('site_id', siteId);
  }

  // NEW: Adds a new purchase record
  Future<void> addMaterialPurchase(Map<String, dynamic> item) async {
    await CacheService.instance.addMaterialPurchase(item);
  }

  // NEW: Deletes a purchase record
  Future<void> updateMaterialPurchase(String id, Map<String, dynamic> updatedData) async {
    try {
      await supabase
          .from('raw_material_purchases') // Make sure this matches your Supabase table name
          .update(updatedData)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update purchase: $e');
    }
  }

  // --- DELETE METHOD ---
  Future<void> deleteMaterialPurchase(String id) async {
    try {
      await supabase
          .from('raw_material_purchases')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete purchase: $e');
    }
  }


  // --- *** CONTRACTOR FUNCTIONS *** ---
  // This logic is correct and remains unchanged.

  Future<List<Map<String, dynamic>>> getContractorsForSite(int siteId, {bool forceRefresh = false}) async {
    return await CacheService.instance.getContractorsForSite(siteId, forceRefresh: forceRefresh);
  }

  Future<void> addContractor(Map<String, dynamic> contractor) async {
    await CacheService.instance.addContractor(contractor);
  }

  Future<void> updateContractor(String id, Map<String, dynamic> updatedContractor) async {
    await supabase
        .from('contractors')
        .update(updatedContractor)
        .eq('id', id);
  }

  Future<void> deleteContractor(String id) async {
    await supabase
        .from('contractors')
        .delete()
        .eq('id', id);
  }

}