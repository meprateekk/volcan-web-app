import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:visionvolcan_site_app/main.dart';

/// Simple logger for better error handling
class AppLogger {
  static void log(String message, {String? error}) {
    if (kDebugMode) {
      if (error != null) {
        print('ERROR: $message - $error');
      } else {
        print('INFO: $message');
      }
    }
  }
  
  static void error(String message, {dynamic error}) {
    if (kDebugMode) {
      print('ERROR: $message');
      if (error != null) {
        print('DETAILS: $error');
      }
    }
  }
}

/// Offline-first caching service for the VisionVolcan Site App
/// Provides local storage and synchronization with Supabase
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();
  
  Database? _database;
  bool _isInitialized = false;
  bool _isWebPlatform = kIsWeb;
  static const String _dbName = 'visionvolcan_cache.db';
  static const int _dbVersion = 2;
  
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
    
    AppLogger.log('Initializing cache database...');
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, _dbName);
      AppLogger.log('Database path: $dbPath');
      
      // Check if database file exists
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        AppLogger.log('Database file exists, checking version...');
      } else {
        AppLogger.log('Database file does not exist, will create new one');
      }
      
      _database = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
      
      _isInitialized = true;
      AppLogger.log('Cache database initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize cache database', error: e);
      _isInitialized = false;
    }
  }
  
  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    AppLogger.log('Database opened, checking schema...');
    try {
      // Check if created_at column exists in all tables
      final tablesToCheck = [sitesTable, materialPurchasesTable, contractorsTable, materialConsumedTable];
      
      for (final tableName in tablesToCheck) {
        final columns = await db.rawQuery("PRAGMA table_info($tableName)");
        final hasCreatedAt = columns.any((column) => column['name'] == 'created_at');
        AppLogger.log('$tableName table has created_at column: $hasCreatedAt');
        
        if (!hasCreatedAt) {
          AppLogger.log('created_at column missing in $tableName table, adding it...');
          try {
            await db.execute('ALTER TABLE $tableName ADD COLUMN created_at TEXT');
            AppLogger.log('Added created_at to $tableName');
          } catch (e) {
            AppLogger.error('Failed to add created_at to $tableName', error: e);
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error checking database schema', error: e);
    }
  }
  
  /// Check if cache service is available
  bool get isAvailable {
    final available = _isInitialized && !_isWebPlatform;
    AppLogger.log('Cache service availability check: _isInitialized=$_isInitialized, _isWebPlatform=$_isWebPlatform, available=$available');
    return available;
  }
  
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
        created_at TEXT,
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
        created_at TEXT,
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
        status TEXT,
        created_at TEXT,
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
        created_at TEXT,
        cached_at INTEGER,
        last_sync_at INTEGER
      )
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.log('Database upgrade: oldVersion=$oldVersion, newVersion=$newVersion');
    if (oldVersion < 2) {
      AppLogger.log('Adding created_at columns to all tables...');
      try {
        await db.execute('ALTER TABLE $sitesTable ADD COLUMN created_at TEXT');
        AppLogger.log('Added created_at to $sitesTable');
        
        await db.execute('ALTER TABLE $materialPurchasesTable ADD COLUMN created_at TEXT');
        AppLogger.log('Added created_at to $materialPurchasesTable');
        
        await db.execute('ALTER TABLE $contractorsTable ADD COLUMN created_at TEXT');
        AppLogger.log('Added created_at to $contractorsTable');
        
        await db.execute('ALTER TABLE $materialConsumedTable ADD COLUMN created_at TEXT');
        AppLogger.log('Added created_at to $materialConsumedTable');
        
        AppLogger.log('Database upgrade completed successfully');
      } catch (e) {
        AppLogger.error('Error during database upgrade', error: e);
        rethrow;
      }
    }
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
    AppLogger.log('getSites called with forceRefresh=$forceRefresh');
    await init();
    
    // Test Supabase connection
    AppLogger.log('Testing Supabase connection...');
    try {
      final user = supabase.auth.currentUser;
      AppLogger.log('Current user: ${user?.email}');
    } catch (e) {
      AppLogger.error('Supabase auth check failed', error: e);
    }
    
    // If cache is not available (web platform or initialization failed), fetch directly from server
    if (!isAvailable) {
      AppLogger.log('Cache not available, fetching directly from server');
      try {
        final response = await supabase.from('sites').select();
        final sites = List<Map<String, dynamic>>.from(response as List);
        AppLogger.log('Direct fetch returned ${sites.length} sites');
        return sites;
      } catch (e) {
        AppLogger.error('Direct fetch from server failed', error: e);
        rethrow;
      }
    }
    
    if (!forceRefresh) {
      AppLogger.log('Checking cached sites...');
      try {
        final cachedSites = await _database!.query(
          sitesTable,
          orderBy: 'cached_at DESC',
        );
        
        AppLogger.log('Found ${cachedSites.length} cached sites');
        
        if (cachedSites.isNotEmpty && _isCacheValid(cachedSites.first['cached_at'] as int)) {
          AppLogger.log('Returning cached sites (cache is valid)');
          return cachedSites.map((site) {
            final siteMap = Map<String, dynamic>.from(site);
            siteMap.remove('cached_at');
            siteMap.remove('last_sync_at');
            return siteMap;
          }).toList();
        }
      } catch (e) {
        AppLogger.error('Error checking cached sites', error: e);
      }
    }
    
    // Fetch from server
    AppLogger.log('Fetching sites from server...');
    try {
      final response = await supabase.from('sites').select();
      final sites = List<Map<String, dynamic>>.from(response as List);
      AppLogger.log('Fetched ${sites.length} sites from server');
      
      // Update cache
      final timestamp = _getCurrentTimestamp();
      final batch = _database!.batch();
      
      // Clear old cache
      batch.delete(sitesTable);
      
      // Insert new data
      for (final site in sites) {
        final siteData = {
          ...site,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        };
        // Ensure created_at field exists - if not, add current timestamp
        if (!site.containsKey('created_at')) {
          siteData['created_at'] = DateTime.now().toIso8601String();
        }
        batch.insert(sitesTable, siteData);
      }
      
      await batch.commit(noResult: true);
      AppLogger.log('Sites cached successfully');
      return sites;
    } catch (e) {
      AppLogger.error('Failed to fetch sites from server, returning cached data', error: e);
      // If server fails, return cached data even if expired
      try {
        final cachedSites = await _database!.query(sitesTable);
        if (cachedSites.isNotEmpty) {
          AppLogger.log('Returning expired cached sites as fallback');
          return cachedSites.map((site) {
            final siteMap = Map<String, dynamic>.from(site);
            siteMap.remove('cached_at');
            siteMap.remove('last_sync_at');
            return siteMap;
          }).toList();
        }
      } catch (cacheError) {
        AppLogger.error('Failed to get cached sites as fallback', error: cacheError);
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
      final siteData = {
        ...site,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      };
      // Remove created_at if it doesn't exist in the site data to avoid errors
      if (!site.containsKey('created_at')) {
        siteData['created_at'] = DateTime.now().toIso8601String();
      }
      await _database!.insert(sitesTable, siteData);
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      final siteData = {
        ...site,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      };
      // Remove created_at if it doesn't exist in the site data to avoid errors
      if (!site.containsKey('created_at')) {
        siteData['created_at'] = DateTime.now().toIso8601String();
      }
      await _database!.insert(sitesTable, siteData);
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
        final purchaseData = {
          ...purchase,
          'cached_at': timestamp,
          'last_sync_at': timestamp,
        };
        // Ensure created_at field exists - if not, add current timestamp
        if (!purchase.containsKey('created_at')) {
          purchaseData['created_at'] = DateTime.now().toIso8601String();
        }
        batch.insert(materialPurchasesTable, purchaseData);
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
      final purchaseData = {
        ...purchase,
        'cached_at': timestamp,
        'last_sync_at': timestamp,
      };
      // Ensure created_at field exists - if not, add current timestamp
      if (!purchase.containsKey('created_at')) {
        purchaseData['created_at'] = DateTime.now().toIso8601String();
      }
      await _database!.insert(materialPurchasesTable, purchaseData);
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      final purchaseData = {
        ...purchase,
        'cached_at': timestamp,
        'last_sync_at': 0, // 0 indicates sync pending
      };
      // Ensure created_at field exists - if not, add current timestamp
      if (!purchase.containsKey('created_at')) {
        purchaseData['created_at'] = DateTime.now().toIso8601String();
      }
      await _database!.insert(materialPurchasesTable, purchaseData);
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
          _hydrateContractorInstallments(contractorMap);
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
        final contractorData = _normalizeContractorForCache(
          contractor,
          cachedAt: timestamp,
          lastSyncAt: timestamp,
        );
        batch.insert(contractorsTable, contractorData);
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
          _hydrateContractorInstallments(contractorMap);
          return contractorMap;
        }).toList();
      }
      rethrow;
    }
  }

  void _hydrateContractorInstallments(Map<String, dynamic> contractorMap) {
    final raw = contractorMap['installmentsData'];
    if (raw == null) {
      contractorMap['installments'] = <dynamic>[];
      return;
    }

    if (raw is List) {
      contractorMap['installments'] = raw;
      return;
    }

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          contractorMap['installments'] = decoded;
        } else {
          contractorMap['installments'] = <dynamic>[];
        }
      } catch (_) {
        contractorMap['installments'] = <dynamic>[];
      }
      return;
    }

    contractorMap['installments'] = <dynamic>[];
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
      final contractorData = _normalizeContractorForCache(
        contractor,
        cachedAt: timestamp,
        lastSyncAt: timestamp,
      );
      await _database!.insert(contractorsTable, contractorData);
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      final contractorData = _normalizeContractorForCache(
        contractor,
        cachedAt: timestamp,
        lastSyncAt: 0,
      );
      await _database!.insert(contractorsTable, contractorData);
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeContractorForCache(
    Map<String, dynamic> contractor, {
    required int cachedAt,
    required int lastSyncAt,
  }) {
    final contractorData = <String, dynamic>{
      ...contractor,
      'cached_at': cachedAt,
      'last_sync_at': lastSyncAt,
    };

    if (!contractorData.containsKey('created_at')) {
      contractorData['created_at'] = DateTime.now().toIso8601String();
    }

    // Always remove `installments` key so SQLite never tries to write it.
    // Store it into installmentsData as JSON (string), regardless of whether
    // the incoming value is a List, a JSON String, null, etc.
    if (contractorData.containsKey('installments')) {
      final installments = contractorData['installments'];
      contractorData.remove('installments');

      if (installments == null) {
        contractorData['installmentsData'] = jsonEncode([]);
      } else if (installments is String) {
        contractorData['installmentsData'] = installments;
      } else if (installments is List) {
        contractorData['installmentsData'] = jsonEncode(installments);
      } else {
        contractorData['installmentsData'] = jsonEncode([]);
      }
    } else if (!contractorData.containsKey('installmentsData')) {
      contractorData['installmentsData'] = jsonEncode([]);
    }

    return contractorData;
  }

  Map<String, dynamic> _normalizeMaterialConsumedForCache(
    Map<String, dynamic> item, {
    required int cachedAt,
    required int lastSyncAt,
  }) {
    final itemData = <String, dynamic>{
      ...item,
      'cached_at': cachedAt,
      'last_sync_at': lastSyncAt,
    };

    if (!itemData.containsKey('created_at')) {
      itemData['created_at'] = DateTime.now().toIso8601String();
    }

    // Supabase/mobile UI may use: material, quantity, date_used, floor
    // SQLite schema uses: material_name, quantity_used, date_of_consumption
    if (itemData.containsKey('material') && !itemData.containsKey('material_name')) {
      itemData['material_name'] = itemData['material'];
    }
    if (itemData.containsKey('quantity') && !itemData.containsKey('quantity_used')) {
      itemData['quantity_used'] = itemData['quantity'];
    }
    if (itemData.containsKey('date_used') && !itemData.containsKey('date_of_consumption')) {
      itemData['date_of_consumption'] = itemData['date_used'];
    }

    // Remove keys that are not columns in cached_material_consumed
    itemData.remove('material');
    itemData.remove('quantity');
    itemData.remove('date_used');
    itemData.remove('floor');

    return itemData;
  }

  void _hydrateMaterialConsumedForUi(Map<String, dynamic> consumedMap) {
    if (!consumedMap.containsKey('material') && consumedMap.containsKey('material_name')) {
      consumedMap['material'] = consumedMap['material_name'];
    }
    if (!consumedMap.containsKey('quantity') && consumedMap.containsKey('quantity_used')) {
      consumedMap['quantity'] = consumedMap['quantity_used'];
    }
    if (!consumedMap.containsKey('date_used') && consumedMap.containsKey('date_of_consumption')) {
      consumedMap['date_used'] = consumedMap['date_of_consumption'];
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
          _hydrateMaterialConsumedForUi(consumedMap);
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
        final itemData = _normalizeMaterialConsumedForCache(
          item,
          cachedAt: timestamp,
          lastSyncAt: timestamp,
        );
        batch.insert(materialConsumedTable, itemData);
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
          _hydrateMaterialConsumedForUi(consumedMap);
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
      final itemData = _normalizeMaterialConsumedForCache(
        item,
        cachedAt: timestamp,
        lastSyncAt: timestamp,
      );
      await _database!.insert(materialConsumedTable, itemData);
    } catch (e) {
      // If server fails, add to cache with sync pending flag
      final timestamp = _getCurrentTimestamp();
      final itemData = _normalizeMaterialConsumedForCache(
        item,
        cachedAt: timestamp,
        lastSyncAt: 0,
      );
      await _database!.insert(materialConsumedTable, itemData);
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
    
    try {
      await getMaterialPurchasesForSite(siteId, forceRefresh: true);
      await getContractorsForSite(siteId, forceRefresh: true);
      await getMaterialConsumedForSite(siteId, forceRefresh: true);
    } catch (e) {
      AppLogger.error('Failed to refresh site data', error: e);
      rethrow;
    }
  }
  
  /// Reset the entire database (for debugging purposes)
  Future<void> resetDatabase() async {
    if (_isWebPlatform) return;
    
    AppLogger.log('Resetting database...');
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, _dbName);
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        await dbFile.delete();
        AppLogger.log('Database file deleted');
      }
      
      _isInitialized = false;
      await init();
      AppLogger.log('Database reset complete');
    } catch (e) {
      AppLogger.error('Failed to reset database', error: e);
      rethrow;
    }
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
