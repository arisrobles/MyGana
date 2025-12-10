import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ReferenceCharacterGenerator {
  /// Generate a reference image for a character using text rendering
  static Future<String?> generateReferenceImage({
    required String character,
    required String svgPath, // We'll ignore this and use text rendering
    Size imageSize = const Size(512, 512),
  }) async {
    try {
      debugPrint('🎯 Generating text reference image for $character');

      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Fill white background
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height), backgroundPaint);

      // Create high-quality text-based reference
      final textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            fontSize: 400, // Large, clear font size
            color: Colors.black,
            fontFamily: 'Noto Sans JP', // Japanese font
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Center the text
      final offset = Offset(
        (imageSize.width - textPainter.width) / 2,
        (imageSize.height - textPainter.height) / 2,
      );

      textPainter.paint(canvas, offset);

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );

      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert reference image to byte data');
      }

      // Convert to base64
      final base64String = base64Encode(byteData.buffer.asUint8List());

      // Clean up
      picture.dispose();
      image.dispose();

      debugPrint('✅ Text reference generated for $character: ${base64String.length} characters');
      return base64String;
    } catch (e) {
      debugPrint('❌ Error generating reference image for $character: $e');
      return null;
    }
  }

  /// Get SVG path for a character
  static String getSvgPath(String character, String type) {
    // Map characters to their SVG filenames (matching actual file names)
    final svgMap = {
      // Hiragana - Basic vowels
      'あ': '1_a_hira.svg',
      'い': '1_i_hira.svg',
      'う': '1_u_hira.svg',
      'え': '1_e_hira.svg',
      'お': '1_o_hira.svg',

      // Hiragana - K series
      'か': '2_ka_hira.svg',
      'き': '2_ki_hira.svg',
      'く': '2_ku_hira.svg',
      'け': '2_ke_hira.svg',
      'こ': '2_ko_hira.svg',

      // Hiragana - S series
      'さ': '3_sa_hira.svg',
      'し': '3_shi_hira.svg',
      'す': '3_su_hira.svg',
      'せ': '3_se_hira.svg',
      'そ': '3_so_hira.svg',

      // Hiragana - T series
      'た': '4_ta_hira.svg',
      'ち': '4_chi_hira.svg',
      'つ': '4_tsu_hira.svg',
      'て': '4_te_hira.svg',
      'と': '4_to_hira.svg',

      // Hiragana - N series
      'な': '5_na_hira.svg',
      'に': '5_ni_hira.svg',
      'ぬ': '5_nu_hira.svg',
      'ね': '5_ne_hira.svg',
      'の': '5_no_hira.svg',
      'ん': '5_n_hira.svg',

      // Hiragana - H series
      'は': '6_ha_hira.svg',
      'ひ': '6_hi_hira.svg',
      'ふ': '6_fu_hira.svg',
      'へ': '6_he_hira.svg',
      'ほ': '6_ho_hira.svg',

      // Hiragana - M series
      'ま': '7_ma_hira.svg',
      'み': '7_mi_hira.svg',
      'む': '7_mu_hira.svg',
      'め': '7_me_hira.svg',
      'も': '7_mo_hira.svg',

      // Hiragana - Y series
      'や': '8_ya_hira.svg',
      'ゆ': '8_yu_hira.svg',
      'よ': '8_yo_hira.svg',

      // Hiragana - R series
      'ら': '9_ra_hira.svg',
      'り': '9_ri_hira.svg',
      'る': '9_ru_hira.svg',
      'れ': '9_re_hira.svg',
      'ろ': '9_ro_hira.svg',

      // Hiragana - W series
      'わ': '10_wa_hira.svg',
      'を': '10_wo_hira.svg',

      // Katakana - Basic vowels
      'ア': '1_a_kata.svg',
      'イ': '1_i_kata.svg',
      'ウ': '1_u_kata.svg',
      'エ': '1_e_kata.svg',
      'オ': '1_o_kata.svg',

      // Katakana - K series
      'カ': '2_ka_kata.svg',
      'キ': '2_ki_kata.svg',
      'ク': '2_ku_kata.svg',
      'ケ': '2_ke_kata.svg',
      'コ': '2_ko_kata.svg',

      // Katakana - S series
      'サ': '3_sa_kata.svg',
      'シ': '3_shi_kata.svg',
      'ス': '3_su_kata.svg',
      'セ': '3_se_kata.svg',
      'ソ': '3_so_kata.svg',

      // Katakana - T series
      'タ': '4_ta_kata.svg',
      'チ': '4_chi_kata.svg',
      'ツ': '4_tsu_kata.svg',
      'テ': '4_te_kata.svg',
      'ト': '4_to_kata.svg',

      // Katakana - N series
      'ナ': '5_na_kata.svg',
      'ニ': '5_ni_kata.svg',
      'ヌ': '5_nu_kata.svg',
      'ネ': '5_ne_kata.svg',
      'ノ': '5_no_kata.svg',
      'ン': '5_p_kata.svg', // Note: This might be 'n' in your files

      // Katakana - H series
      'ハ': '6_ha_kata.svg',
      'ヒ': '6_hi_kata.svg',
      'フ': '6_fu_kata.svg',
      'ヘ': '6_he_kata.svg',
      'ホ': '6_ho_kata.svg',

      // Katakana - M series
      'マ': '7_ma_kata.svg',
      'ミ': '7_mi_kata.svg',
      'ム': '7_mu_kata.svg',
      'メ': '7_me_kata.svg',
      'モ': '7_mo_kata.svg',

      // Katakana - Y series
      'ヤ': '8_ya_kata.svg',
      'ユ': '8_yu_kata.svg',
      'ヨ': '8_yo_kata.svg',

      // Katakana - R series
      'ラ': '9_ra_kata.svg',
      'リ': '9_ri_kata.svg',
      'ル': '9_ru_kata.svg',
      'レ': '9_re_kata.svg',
      'ロ': '9_ro_kata.svg',

      // Katakana - W series
      'ワ': '10_wa_kata.svg',
      'ヲ': '10_wo_kata.svg',
    };

    final filename = svgMap[character];
    if (filename == null) {
      throw Exception('No SVG found for character: $character');
    }

    return 'assets/HiraganaSVG/$filename';
  }
}
