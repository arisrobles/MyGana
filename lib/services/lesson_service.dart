import 'package:nihongo_japanese_app/models/kanji.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LessonService {
  static const String _kanjiKey = 'unlocked_kanji';
  static const String _lessonPackKey = 'unlocked_lesson_packs';

  Future<void> unlockKanji(List<Kanji> kanji) async {
    final prefs = await SharedPreferences.getInstance();
    final currentKanjiJson = prefs.getStringList(_kanjiKey) ?? [];
    final newKanjiJson = kanji.map((k) => jsonEncode(k.toJson())).toList();
    currentKanjiJson.addAll(newKanjiJson);
    await prefs.setStringList(_kanjiKey, currentKanjiJson);
  }

  Future<void> unlockLessonPack(LessonPack lessonPack) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPacksJson = prefs.getStringList(_lessonPackKey) ?? [];
    currentPacksJson.add(jsonEncode(lessonPack.toJson()));
    await prefs.setStringList(_lessonPackKey, currentPacksJson);
  }

  Future<List<Kanji>> getUnlockedKanji() async {
    final prefs = await SharedPreferences.getInstance();
    final kanjiJson = prefs.getStringList(_kanjiKey) ?? [];
    return kanjiJson.map((json) => Kanji.fromJson(jsonDecode(json))).toList();
  }

  Future<List<LessonPack>> getUnlockedLessonPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final packsJson = prefs.getStringList(_lessonPackKey) ?? [];
    return packsJson.map((json) => LessonPack.fromJson(jsonDecode(json))).toList();
  }
}