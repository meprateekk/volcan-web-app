import 'package:visionvolcan_site_app/main.dart';
import 'package:visionvolcan_site_app/services/cache_service.dart';

/// Manages all operations related to construction sites in the application
class SiteService {
  // Private constructor for singleton pattern
  SiteService._();
  
  // Single instance of SiteService
  static final SiteService instance = SiteService._();

  /// Retrieves a list of all construction sites from the cache or database
  Future<List<Map<String, dynamic>>> getSites({bool forceRefresh = false}) async {
    return await CacheService.instance.getSites(forceRefresh: forceRefresh);
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
    await CacheService.instance.updateSiteField(siteToUpdate, fieldKey, newValue);
  }

  /// Creates a new construction site in the database and cache
  /// 
  /// [newSite] A map containing the site details (name, location, etc.)
  Future<void> addSite(Map<String, dynamic> newSite) async {
    await CacheService.instance.addSite(newSite);
  }

  /// Permanently removes a site from the database and cache
  /// 
  /// [siteToDelete] The site map containing at least the 'id' field
  Future<void> deleteSite(Map<String, dynamic> siteToDelete) async {
    await CacheService.instance.deleteSite(siteToDelete);
  }

  /// Marks a site as completed in the system
  /// 
  /// [siteToUpdate] The site map containing at least the 'id' field
  Future<void> markSiteAsCompleted(Map<String, dynamic> siteToUpdate) async {
    await updateSiteField(siteToUpdate, 'status', 'completed');
  }
}