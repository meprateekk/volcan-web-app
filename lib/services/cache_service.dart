import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:visionvolcan_site_app/main.dart';

/// Offline-first caching service for the VisionVolcan Site App
/// Provides local storage and synchronization with Supabase
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();
  
  Database? _database;
  bool _isInitialized = false;
  bool _isWebPlatform = kIsWeb;
  static const String _dbName = 'visionvolcan_cache.db';
  static const int _dbVersion = 1;
  
  // Table names
  static const String sitesTable = 'cached_sites';
  static const String materialPurchasesTable = 'cached_material_purchases';
  static const String contractorsTable = 'cached_contractors';
  static const String materialConsumedTable = 'cached_material_consumed';
  
  // Cache duration (in minutes)
  static const int cacheDuration = 30;
  
  /// Initialize the database
  Future<void> init() async {
    if (_isWebPlatform || _database != null) return;
    
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, _dbName);
      
      _database = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize cache database: $e');
      _isInitialized = false;
    }
  }
  
  /// Check if cache service is available
  bool get isAvailable => _isInitialized && !_isWebPlatform;
  
  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Sites table
    await db.execute('''
      CREATE TABLE $sitesTable (
        id INTEGER PRIMARY KEY,
        name TEXT,
        location TEXT,
        plot_size TEXT,
        floors TEXT,
        start_date TEXT,
        due_date TEXT,
        status TEXT,
        cached_at INTEGER,
        last_sync_at INTEGER
      )
    ''');
    
    // Material purchases table
    await db.execute('''
      CREATE TABLE $materialPurchasesTable (
        id TEXT PRIMARY KEY,
        site_id INTEGER,
        material TEXT,
        quantity INTEGER,
        unit TEXT,
        rate REAL,
        total_amount REAL,
        date_of_purchase TEXT,
        sector TEXT,
        cached_at INTEGER,
        last_sync_at INTEGER
      )
    ''');
    
    // Contractors table
    await db.execute('''
      CREATE TABLE $contractorsTable (
        id TEXT PRIMARY KEY,
        site_id INTEGER,
        name TEXT,
        sector TEXT,
        total TEXT,
        paid TEXT,
        pending TEXT,
        next_payment_date TEXT,
        installmentsData TEXT,
        cached_at INTEGER,
        last_sync_at INTEGER
      )
    ''');
    
    // Material consumed table
    await db.execute('''
      CREATE TABLE $materialConsumedTable (
        id TEXT PRIMARY KEY,
        site_id INTEGER,
        material_name TEXT,
        quantity_used INTEGER,
        unit TEXT,
        date_of_consumption TEXT,
        sector TEXT,
        cached_at INTEGER,
        last_sync_at INTEGER
      )
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades in future versions
  }
  
  /// Check if cache is valid (not expired)
  bool _isCacheValid(int cachedAt) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAge = (now - cachedAt) / (1000 * 60); // Convert to minutes
    return cacheAge < cacheDuration;
  }
  
  /// Get current timestamp
  int _getCurrentTimestamp() => DateTime.now().millisecondsSinceEpoch;
  
  // ==================== SITES ====================
  
  /// Get cached sites or fetch from server if cache is invalid
  Future<List<Map<String, dynamic>>> getSites({bool forceRefresh = false}) async {
    await init();
    
    // If cache is not available (web platform or initialization failed), fetch directly from server
    if (!isAvailable) {
      final response = await supabase.from('sites').select();
      return List<Map<String, dynamic>>.from(response as List);
    }
    
    if (!forceRefresh) {
      final cachedSites = await _database!.query(
        sitesTable,
        orderBy: 'cached_at DESC',
      );
      
      if (cachedSites.isNotEmpty && _isCacheValid(cachedSites.first['cached_at'] as int)) {
        return cachedSites.map((site) {
          final siteMap = Map<String, dynamic>.from(site);
          siteMap.remove('cached_at');
          siteMap.remove('last_sync_at');
          return siteMap;
        }).toList();
      }
    }
    
    // Fetch from server
    try {
      final response = await supabase.from('sites').select();
      final sites = List<Map<String, dynamic>>.from(response as List);
      
      // Update cache
      final timestamp = _getCurrentTimestamp();
      final batch = _database!.batch();
      
      // Clear old cache
      batch.delete(sitesTable);
      
      // Insert new data
      for (final site in sites) {
        batch.insert(sitesTable, {
          ...site,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        });
      }
      
      await batch.commit(noResult: true);
      return sites;
    } catch (e) {
      // If server fails, return cached data even if expired
      final cachedSites = await _database!.query(sitesTable);
      if (cachedSites.isNotEmpty) {
        return cachedSites.map((site) {
          final siteMap = Map<String, dynamic>.from(site);
          siteMap.remove('cached_at');
          siteMap.remove('last_sync_at');
          return siteMap;
        }).toList();
      }
      rethrow;
    }
  }
  
  /// Add site to both cache and server
  Future<void> addSite(Map<String, dynamic> site) async {
    await init();
    
    // If cache is not available, add directly to server
    if (!isAvailable) {
      await supabase.from('sites').insert(site);
      return;
    }
    
    try {
      // Add to server first
      await supabase.from('sites').insert(site);
      
      // Add to cache
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(sitesTable, {
        ...site,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      });
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(sitesTable, {
        ...site,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      });
      rethrow;
    }
  }
  
  /// Update site in both cache and server
  Future<void> updateSiteField(Map<String, dynamic> site, String fieldKey, dynamic newValue) async {
    await init();
    
    // If cache is not available, update directly on server
    if (!isAvailable) {
      if (site['id'] != null) {
        await supabase
            .from('sites')
            .update({fieldKey: newValue})
            .eq('id', site['id']);
      }
      return;
    }
    
    try {
      // Update server first
      if (site['id'] != null) {
        await supabase
            .from('sites')
            .update({fieldKey: newValue})
            .eq('id', site['id']);
      }
      
      // Update cache
      await _database!.update(
        sitesTable,
        {
          fieldKey: newValue,
          'last_sync_at': _getCurrentTimestamp(),
        },
        where: 'id = ?',
        whereArgs: [site['id']],
      );
    } catch (e) {
      // If server fails, update cache only
      await _database!.update(
        sitesTable,
        {
          fieldKey: newValue,
          'last_sync_at': 0, // Mark as sync pending
        },
        where: 'id = ?',
        whereArgs: [site['id']],
      );
      rethrow;
    }
  }
  
  /// Delete site from both cache and server
  Future<void> deleteSite(Map<String, dynamic> site) async {
    await init();
    
    // If cache is not available, delete directly from server
    if (!isAvailable) {
      if (site['id'] != null) {
        await supabase
            .from('sites')
            .delete()
            .eq('id', site['id']);
      }
      return;
    }
    
    try {
      // Delete from server first
      if (site['id'] != null) {
        await supabase
            .from('sites')
            .delete()
            .eq('id', site['id']);
      }
      
      // Delete from cache
      await _database!.delete(
        sitesTable,
        where: 'id = ?',
        whereArgs: [site['id']],
      );
    } catch (e) {
      // If server fails, delete from cache only
      await _database!.delete(
        sitesTable,
        where: 'id = ?',
        whereArgs: [site['id']],
      );
      rethrow;
    }
  }
  
  // ==================== MATERIAL PURCHASES ====================
  
  /// Get cached material purchases for a site
  Future<List<Map<String, dynamic>>> getMaterialPurchasesForSite(int siteId, {bool forceRefresh = false}) async {
    await init();
    
    // If cache is not available, fetch directly from server
    if (!isAvailable) {
      final response = await supabase
          .from('raw_material_purchases')
          .select()
          .eq('site_id', siteId);
      return List<Map<String, dynamic>>.from(response as List);
    }
    
    if (!forceRefresh) {
      final cachedPurchases = await _database!.query(
        materialPurchasesTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cached_at DESC',
      );
      
      if (cachedPurchases.isNotEmpty && _isCacheValid(cachedPurchases.first['cached_at'] as int)) {
        return cachedPurchases.map((purchase) {
          final purchaseMap = Map<String, dynamic>.from(purchase);
          purchaseMap.remove('cached_at');
          purchaseMap.remove('last_sync_at');
          return purchaseMap;
        }).toList();
      }
    }
    
    // Fetch from server
    try {
      final response = await supabase
          .from('raw_material_purchases')
          .select()
          .eq('site_id', siteId);
      final purchases = List<Map<String, dynamic>>.from(response as List);
      
      // Update cache
      final timestamp = _getCurrentTimestamp();
      final batch = _database!.batch();
      
      // Clear old cache for this site
      batch.delete(
        materialPurchasesTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      
      // Insert new data
      for (final purchase in purchases) {
        batch.insert(materialPurchasesTable, {
          ...purchase,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        });
      }
      
      await batch.commit(noResult: true);
      return purchases;
    } catch (e) {
      // If server fails, return cached data even if expired
      final cachedPurchases = await _database!.query(
        materialPurchasesTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      if (cachedPurchases.isNotEmpty) {
        return cachedPurchases.map((purchase) {
          final purchaseMap = Map<String, dynamic>.from(purchase);
          purchaseMap.remove('cached_at');
          purchaseMap.remove('last_sync_at');
          return purchaseMap;
        }).toList();
      }
      rethrow;
    }
  }
  
  /// Add material purchase to both cache and server
  Future<void> addMaterialPurchase(Map<String, dynamic> purchase) async {
    await init();
    
    // If cache is not available, add directly to server
    if (!isAvailable) {
      await supabase.from('raw_material_purchases').insert(purchase);
      return;
    }
    
    try {
      // Add to server first
      await supabase.from('raw_material_purchases').insert(purchase);
      
      // Add to cache
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(materialPurchasesTable, {
        ...purchase,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      });
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(materialPurchasesTable, {
        ...purchase,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      });
      rethrow;
    }
  }
  
  // ==================== CONTRACTORS ====================
  
  /// Get cached contractors for a site
  Future<List<Map<String, dynamic>>> getContractorsForSite(int siteId, {bool forceRefresh = false}) async {
    await init();
    
    // If cache is not available, fetch directly from server
    if (!isAvailable) {
      final response = await supabase
          .from('contractors')
          .select()
          .eq('site_id', siteId);
      return List<Map<String, dynamic>>.from(response as List);
    }
    
    if (!forceRefresh) {
      final cachedContractors = await _database!.query(
        contractorsTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cached_at DESC',
      );
      
      if (cachedContractors.isNotEmpty && _isCacheValid(cachedContractors.first['cached_at'] as int)) {
        return cachedContractors.map((contractor) {
          final contractorMap = Map<String, dynamic>.from(contractor);
          contractorMap.remove('cached_at');
          contractorMap.remove('last_sync_at');
          return contractorMap;
        }).toList();
      }
    }
    
    // Fetch from server
    try {
      final response = await supabase
          .from('contractors')
          .select()
          .eq('site_id', siteId);
      final contractors = List<Map<String, dynamic>>.from(response as List);
      
      // Update cache
      final timestamp = _getCurrentTimestamp();
      final batch = _database!.batch();
      
      // Clear old cache for this site
      batch.delete(
        contractorsTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      
      // Insert new data
      for (final contractor in contractors) {
        batch.insert(contractorsTable, {
          ...contractor,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        });
      }
      
      await batch.commit(noResult: true);
      return contractors;
    } catch (e) {
      // If server fails, return cached data even if expired
      final cachedContractors = await _database!.query(
        contractorsTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      if (cachedContractors.isNotEmpty) {
        return cachedContractors.map((contractor) {
          final contractorMap = Map<String, dynamic>.from(contractor);
          contractorMap.remove('cached_at');
          contractorMap.remove('last_sync_at');
          return contractorMap;
        }).toList();
      }
      rethrow;
    }
  }
  
  /// Add contractor to both cache and server
  Future<void> addContractor(Map<String, dynamic> contractor) async {
    await init();
    
    // If cache is not available, add directly to server
    if (!isAvailable) {
      await supabase.from('contractors').insert(contractor);
      return;
    }
    
    try {
      // Add to server first
      await supabase.from('contractors').insert(contractor);
      
      // Add to cache
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(contractorsTable, {
        ...contractor,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      });
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(contractorsTable, {
        ...contractor,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      });
      rethrow;
    }
  }
  
  // ==================== MATERIAL CONSUMED ====================
  
  /// Get cached material consumed for a site
  Future<List<Map<String, dynamic>>> getMaterialConsumedForSite(int siteId, {bool forceRefresh = false}) async {
    await init();
    
    // If cache is not available, fetch directly from server
    if (!isAvailable) {
      final response = await supabase
          .from('material_consumed')
          .select()
          .eq('site_id', siteId);
      return List<Map<String, dynamic>>.from(response as List);
    }
    
    if (!forceRefresh) {
      final cachedConsumed = await _database!.query(
        materialConsumedTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cached_at DESC',
      );
      
      if (cachedConsumed.isNotEmpty && _isCacheValid(cachedConsumed.first['cached_at'] as int)) {
        return cachedConsumed.map((consumed) {
          final consumedMap = Map<String, dynamic>.from(consumed);
          consumedMap.remove('cached_at');
          consumedMap.remove('last_sync_at');
          return consumedMap;
        }).toList();
      }
    }
    
    // Fetch from server
    try {
      final response = await supabase
          .from('material_consumed')
          .select()
          .eq('site_id', siteId);
      final consumed = List<Map<String, dynamic>>.from(response as List);
      
      // Update cache
      final timestamp = _getCurrentTimestamp();
      final batch = _database!.batch();
      
      // Clear old cache for this site
      batch.delete(
        materialConsumedTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      
      // Insert new data
      for (final item in consumed) {
        batch.insert(materialConsumedTable, {
          ...item,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        });
      }
      
      await batch.commit(noResult: true);
      return consumed;
    } catch (e) {
      // If server fails, return cached data even if expired
      final cachedConsumed = await _database!.query(
        materialConsumedTable,
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      if (cachedConsumed.isNotEmpty) {
        return cachedConsumed.map((consumed) {
          final consumedMap = Map<String, dynamic>.from(consumed);
          consumedMap.remove('cached_at');
          consumedMap.remove('last_sync_at');
          return consumedMap;
        }).toList();
      }
      rethrow;
    }
  }
  
  /// Add material consumed to both cache and server
  Future<void> logMaterialUsage(Map<String, dynamic> item) async {
    await init();
    
    // If cache is not available, add directly to server
    if (!isAvailable) {
      await supabase.from('material_consumed').insert(item);
      return;
    }
    
    try {
      // Add to server first
      await supabase.from('material_consumed').insert(item);
      
      // Add to cache
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(materialConsumedTable, {
        ...item,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      });
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      await _database!.insert(materialConsumedTable, {
        ...item,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      });
      rethrow;
    }
  }
  
  // ==================== SYNC MANAGEMENT ====================
  
  /// Force refresh all cached data for a specific site
  Future<void> refreshSiteData(int siteId) async {
    if (!isAvailable) {
      // On web, just return - no cache to refresh
      return;
    }
    
    await getMaterialPurchasesForSite(siteId, forceRefresh: true);
    await getContractorsForSite(siteId, forceRefresh: true);
    await getMaterialConsumedForSite(siteId, forceRefresh: true);
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    if (!isAvailable) {
      // On web, just return - no cache to clear
      return;
    }
    
    await _database!.delete(sitesTable);
    await _database!.delete(materialPurchasesTable);
    await _database!.delete(contractorsTable);
    await _database!.delete(materialConsumedTable);
  }
  
  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!isAvailable) {
      // On web, return empty stats
      return {
        'sites': 0,
        'material_purchases': 0,
        'contractors': 0,
        'material_consumed': 0,
        'platform': 'web (cache not available)',
      };
    }
    
    final sitesCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM $sitesTable')
    ) ?? 0;
    
    final purchasesCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM $materialPurchasesTable')
    ) ?? 0;
    
    final contractorsCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM $contractorsTable')
    ) ?? 0;
    
    final consumedCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM $materialConsumedTable')
    ) ?? 0;
    
    return {
      'sites': sitesCount,
      'material_purchases': purchasesCount,
      'contractors': contractorsCount,
      'material_consumed': consumedCount,
      'platform': 'mobile (cache available)',
    };
  }
  
  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
