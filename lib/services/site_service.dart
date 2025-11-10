import 'package:visionvolcan_site_app/main.dart';

class SiteService {
  SiteService._();
  static final SiteService instance = SiteService._();

  // Get all sites from Supabase
  Future<List<Map<String, dynamic>>> getSites() async {
    final response = await supabase
        .from('sites') // The name of your table
        .select(); // "Get all columns"
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Update a specific field of a site in Supabase
  Future<void> updateSiteField(Map<String, dynamic> siteToUpdate, String fieldKey, dynamic newValue) async {
    if (siteToUpdate['id'] != null) {
      await supabase
          .from('sites')
          .update({fieldKey: newValue})
          .eq('id', siteToUpdate['id']);
    }
  }

  // Add a new site to Supabase
  Future<void> addSite(Map<String, dynamic> newSite) async {
    await supabase
        .from('sites')
        .insert(newSite);
  }

  // Delete a site from Supabase
  Future<void> deleteSite(Map<String, dynamic> siteToDelete) async {
    if (siteToDelete['id'] != null) {
      await supabase
          .from('sites')
          .delete()
          .eq('id', siteToDelete['id']);
    }
  }

  // Mark a site as completed in Supabase
  Future<void> markSiteAsCompleted(Map<String, dynamic> siteToUpdate) async {
    if (siteToUpdate['id'] != null) {
      await supabase
          .from('sites')
          .update({'status': 'completed'})
          .eq('id', siteToUpdate['id']);
    }
  }
}