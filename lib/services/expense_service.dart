import 'package:visionvolcan_site_app/main.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  // --- *** NEW MATERIAL PURCHASE FUNCTIONS *** ---
  // These talk to your new 'raw_material_purchases' table

  // NEW: Gets all purchases for a specific site
  Future<List<Map<String, dynamic>>> getMaterialPurchasesForSite(int siteId) async {
    final response = await supabase
        .from('raw_material_purchases') // <-- Uses new table
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // NEW: Adds a new purchase record
  Future<void> addMaterialPurchase(Map<String, dynamic> item) async {
    await supabase.from('raw_material_purchases').insert(item); // <-- Uses new table
  }

  // NEW: Deletes a purchase record
  Future<void> deleteMaterialPurchase(String id) async {
    await supabase
        .from('raw_material_purchases') // <-- Uses new table
        .delete()
        .eq('id', id);
  }


  // --- *** CONTRACTOR FUNCTIONS *** ---
  // This logic is correct and remains unchanged.

  Future<List<Map<String, dynamic>>> getContractorsForSite(int siteId) async {
    final response = await supabase
        .from('contractors')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> addContractor(Map<String, dynamic> contractor) async {
    await supabase.from('contractors').insert(contractor);
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


// --- *** OLD, DELETED FUNCTIONS *** ---
// We no longer need these functions as they talk to the old tables.

// Future<List<Map<String, dynamic>>> getRawMaterialsForSite(int siteId) async { ... }
// Future<void> addRawMaterial(Map<String, dynamic> newMaterial) async { ... }
// Future<void> updateRawMaterial(String id, Map<String, dynamic> updatedMaterial) async { ... }
// Future<void> deleteRawMaterial(String id) async { ... }

}