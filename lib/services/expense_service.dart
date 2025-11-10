import 'package:visionvolcan_site_app/main.dart';

class ExpenseService {

  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();





  Future<List<Map<String, dynamic>>> getRawMaterialsForSite(int siteId) async {
    final response = await supabase
        .from('raw_materials')           // ← Table name in Supabase
        .select()                         // ← Get all columns
        .eq('site_id', siteId);          // ← Filter: only this site's materials

    return List<Map<String, dynamic>>.from(response as List);
  }

// Add new raw material
  Future<void> addRawMaterial(Map<String, dynamic> newMaterial) async {
    await supabase
        .from('raw_materials')
        .insert(newMaterial);             // ← Saves to database
  }

  // Update raw material
  Future<void> updateRawMaterial(String id, Map<String, dynamic> updatedMaterial) async {
    await supabase
        .from('raw_materials')
        .update(updatedMaterial)
        .eq('id', id);
  }

  // Delete raw material
  Future<void> deleteRawMaterial(String id) async {
    await supabase
        .from('raw_materials')
        .delete()
        .eq('id', id);
  }

  // Get contractors for a specific site
  Future<List<Map<String, dynamic>>> getContractorsForSite(int siteId) async {
    final response = await supabase
        .from('contractors')
        .select()
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Add contractor
  Future<void> addContractor(Map<String, dynamic> newContractor) async {
    await supabase.from('contractors').insert(newContractor);
  }

  // Update contractor
  Future<void> updateContractor(String id, Map<String, dynamic> updatedContractor) async {
    await supabase
        .from('contractors')
        .update(updatedContractor)
        .eq('id', id);
  }


  // Delete contractor
  Future<void> deleteContractor(String id) async {
    await supabase
        .from('contractors')
        .delete()
        .eq('id', id);
  }
}