import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nihongo_japanese_app/models/inventory_item.dart';
import 'package:nihongo_japanese_app/models/kanji.dart';
import 'package:nihongo_japanese_app/services/lesson_service.dart';

class InventoryService {
  static const String _inventoryKey = 'inventory';
  final LessonService _lessonService = LessonService();
  int _xpMultiplier = 1;
  int _earnedXP = 0; // Mock XP system
  DateTime? _speedBoostEndTime;

  /// Normalize item names to ensure shop and reward items merge correctly
  String normalizeName(String name) {
    final nameMap = {
      'Learning Ticket': 'Lesson Ticket', // Reward → Shop equivalent
      'Power Boost': 'Speed Boost',      // Reward → Shop equivalent
      'Premium Kanji Pack': 'Kanji Pack', // Reward → Shop equivalent
      'Vocabulary Bundle': 'Lesson Ticket', // Reward → Shop equivalent (both unlock lesson content)
      // Add more mappings as needed for other shop/reward pairs
    };
    final normalized = nameMap[name] ?? name;
    debugPrint('Normalized item name: $name → $normalized');
    return normalized;
  }

  /// Load inventory items from SharedPreferences
  Future<List<InventoryItem>> loadInventory() async {
    debugPrint('Loading inventory items from storage');
    final prefs = await SharedPreferences.getInstance();
    final inventoryJson = prefs.getStringList(_inventoryKey) ?? [];
    
    debugPrint('Found ${inventoryJson.length} items in storage');
    
    final items = inventoryJson.map((json) {
      try {
        final Map<String, dynamic> itemMap = jsonDecode(json);
        return InventoryItem.fromJson(itemMap);
      } catch (e) {
        debugPrint('Error parsing inventory item: $e');
        return null;
      }
    }).whereType<InventoryItem>().toList();
    
    debugPrint('Successfully loaded ${items.length} inventory items');
    return items;
  }
  
  /// Save inventory items to SharedPreferences
  Future<void> saveInventory(List<InventoryItem> items) async {
    debugPrint('Saving ${items.length} items to SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final inventoryJson = items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_inventoryKey, inventoryJson);
    debugPrint('Successfully saved items to storage');
  }
  
  /// Add a new item to inventory or increment count
  Future<void> addItem(InventoryItem item) async {
    debugPrint('=== ADDING ITEM TO INVENTORY ===');
    debugPrint('Original item: ${item.name} (count: ${item.count}, type: ${item.type})');
    final normalizedItem = item.copyWith(name: normalizeName(item.name));
    debugPrint('Normalized item: ${normalizedItem.name} (count: ${normalizedItem.count}, type: ${normalizedItem.type})');
    
    final items = await loadInventory();
    debugPrint('Current inventory has ${items.length} items');
    
    // Find existing item with same normalized name and type, not used
    final existingItemIndex = items.indexWhere(
      (i) => normalizeName(i.name) == normalizedItem.name && 
             i.type == normalizedItem.type && 
             !i.isUsed,
    );
    
    if (existingItemIndex != -1) {
      // Increment count of existing item
      final existingItem = items[existingItemIndex];
      final newCount = existingItem.count + normalizedItem.count;
      debugPrint('✅ Found existing ${normalizedItem.name} (type: ${normalizedItem.type}), updating count from ${existingItem.count} to $newCount');
      items[existingItemIndex] = existingItem.copyWith(count: newCount);
    } else {
      // Add new item with normalized name
      debugPrint('🆕 No existing ${normalizedItem.name} (type: ${normalizedItem.type}) found, adding new item');
      items.add(normalizedItem);
    }
    
    await saveInventory(items);
    debugPrint('Successfully saved inventory with ${items.length} items');
    debugPrint('=== END ADDING ITEM ===');
  }
  
  /// Remove an item from inventory
  Future<void> removeItem(InventoryItem item) async {
    debugPrint('Removing item from inventory: ${item.name}');
    final items = await loadInventory();
    items.removeWhere((i) => 
      normalizeName(i.name) == normalizeName(item.name) && 
      i.obtainedDate == item.obtainedDate);
    await saveInventory(items);
    debugPrint('Successfully removed item from inventory');
  }
  
  /// Get items by category
  Future<List<InventoryItem>> getItemsByCategory(String category) async {
    debugPrint('Getting items for category: $category');
    final items = await loadInventory();
    final filteredItems = items.where((item) => item.type == category && !item.isUsed).toList();
    debugPrint('Found ${filteredItems.length} items in category $category');
    return filteredItems;
  }
  
  /// Mark an item as used
  Future<void> useItem(InventoryItem item, int count) async {
    debugPrint('Using $count ${item.name}(s)');
    final normalizedName = normalizeName(item.name);
    final items = await loadInventory();
    
    // Find the matching item
    final existingItemIndex = items.indexWhere(
      (i) => normalizeName(i.name) == normalizedName && 
             i.type == item.type && 
             !i.isUsed,
    );
    
    if (existingItemIndex == -1 || items[existingItemIndex].count < count) {
      debugPrint('Not enough ${item.name}(s) available to use');
      throw Exception('Not enough ${item.name}(s) available to use');
    }
    
    final existingItem = items[existingItemIndex];
    if (existingItem.count == count) {
      // Mark as used
      items[existingItemIndex] = existingItem.copyWith(isUsed: true);
    } else {
      // Reduce count
      items[existingItemIndex] = existingItem.copyWith(count: existingItem.count - count);
    }
    
    await saveInventory(items);
    debugPrint('Successfully used $count ${item.name}(s)');
  }
  
  /// Clear all items from inventory
  Future<void> clearInventory() async {
    debugPrint('Clearing all items from inventory');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inventoryKey);
    debugPrint('Successfully cleared inventory');
  }

  /// Get remaining time for speed boost in seconds
  int getSpeedBoostRemainingTime() {
    if (_speedBoostEndTime == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(_speedBoostEndTime!)) {
      _xpMultiplier = 1;
      _speedBoostEndTime = null;
      return 0;
    }
    return _speedBoostEndTime!.difference(now).inSeconds;
  }

  /// Apply item effect when purchased
  Future<void> applyItemEffect(ShopItem item, BuildContext context) async {
    debugPrint('Applying effect for item: ${item.name}');
    final normalizedName = normalizeName(item.name);

    switch (normalizedName) {
      case 'Speed Boost':
        final duration = item.effectData['duration'] as int;
        _xpMultiplier = 2;
        _speedBoostEndTime = DateTime.now().add(Duration(seconds: duration));
        Future.delayed(Duration(seconds: duration), () {
          _xpMultiplier = 1;
          _speedBoostEndTime = null;
          debugPrint('Speed Boost expired');
        });
        break;
      case 'Power Surge':
        final challengeId = item.effectData['challengeId'] as String;
        debugPrint('Completed challenge: $challengeId');
        break;
      case 'Lesson Ticket':
        final lessonPack = LessonPack.fromJson(item.effectData['lessonPack']);
        await _lessonService.unlockLessonPack(lessonPack);
        break;
      case 'Kanji Pack':
        final kanji = (item.effectData['kanji'] as List).map((k) => Kanji.fromJson(k)).toList();
        final currentKanji = await _lessonService.getUnlockedKanji();
        final newKanji = kanji.where((k) => !currentKanji.any((c) => c.character == k.character)).toList();
        if (newKanji.isNotEmpty) {
          await _lessonService.unlockKanji(newKanji);
        } else {
          debugPrint('No new kanji to unlock; already unlocked');
        }
        break;
    }
    debugPrint('Successfully applied effect for $normalizedName');
  }

  int getXpMultiplier() => _xpMultiplier;

  // Mock XP system
  void earnXP(int baseXP) {
    final totalXP = baseXP * _xpMultiplier;
    _earnedXP += totalXP;
    debugPrint('Earned $totalXP XP (Multiplier: $_xpMultiplier), Total: $_earnedXP');
  }

  int getEarnedXP() => _earnedXP;
  
  /// Debug method to print current inventory state
  Future<void> debugPrintInventory() async {
    debugPrint('=== CURRENT INVENTORY STATE ===');
    final items = await loadInventory();
    if (items.isEmpty) {
      debugPrint('Inventory is empty');
    } else {
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        debugPrint('Item $i: ${item.name} (type: ${item.type}, count: ${item.count}, used: ${item.isUsed})');
      }
    }
    debugPrint('=== END INVENTORY STATE ===');
  }
}