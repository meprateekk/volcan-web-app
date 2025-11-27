import 'package:visionvolcan_site_app/main.dart';

/// Manages all operations related to construction sites in the application
class SiteService {
  // Private constructor for singleton pattern
  SiteService._();
  
  // Single instance of SiteService
  static final SiteService instance = SiteService._();

  /// Retrieves a list of all construction sites from the database
  Future<List<Map<String, dynamic>>> getSites() async {
    final response = await supabase
        .from('sites')
        .select();
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Updates a specific field of a site
  /// 
  /// [siteToUpdate] The site map containing at least the 'id' field
  /// [fieldKey] The name of the field to update
  /// [newValue] The new value to set for the field
  Future<void> updateSiteField(
    Map<String, dynamic> siteToUpdate, 
    String fieldKey, 
    dynamic newValue
  ) async {
    if (siteToUpdate['id'] != null) {
      await supabase
          .from('sites')
          .update({fieldKey: newValue})
          .eq('id', siteToUpdate['id']);
    }
  }

  /// Creates a new construction site in the database
  /// 
  /// [newSite] A map containing the site details (name, location, etc.)
  Future<void> addSite(Map<String, dynamic> newSite) async {
    await supabase
        .from('sites')
        .insert(newSite);
  }

  /// Permanently removes a site from the database
  /// 
  /// [siteToDelete] The site map containing at least the 'id' field
  Future<void> deleteSite(Map<String, dynamic> siteToDelete) async {
    if (siteToDelete['id'] != null) {
      await supabase
          .from('sites')
          .delete()
          .eq('id', siteToDelete['id']);
    }
  }

  /// Marks a site as completed in the system
  /// 
  /// [siteToUpdate] The site map containing at least the 'id' field
  Future<void> markSiteAsCompleted(Map<String, dynamic> siteToUpdate) async {
    if (siteToUpdate['id'] != null) {
      await supabase
          .from('sites')
          .update({'status': 'completed'})
          .eq('id', siteToUpdate['id']);
    }
  }
}