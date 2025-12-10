import 'dart:math';
import 'package:nihongo_japanese_app/screens/difficulty_selection_screen.dart';

// Question pools for dynamic difficulty system
class QuestionPool {
  final String text;
  final List<String> options;
  final String correctAnswer;
  final String? customHint;

  QuestionPool({
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.customHint,
  });
}

// Easy questions - Basic Kanji meanings and simple vocabulary
final List<QuestionPool> easyQuestions = [
  QuestionPool(
    text: 'What does this Kanji mean: 学 (がく / gaku)?',
    options: ['A. Tree', 'B. Study', 'C. Moon', 'D. Wind'],
    correctAnswer: 'B. Study',
    customHint: 'This Kanji is related to education and learning. Think about what you do in school.',
  ),
  QuestionPool(
    text: 'Which word means "student"?',
    options: ['A. 先生/sensei', 'B. 学生/gakusei', 'C. 水生/suisei', 'D. 車生/shasei'],
    correctAnswer: 'B. 学生/gakusei',
    customHint: 'This word combines the Kanji for "study" (学) with "life" (生). Think about someone who studies.',
  ),
  QuestionPool(
    text: 'Which word means "school"?',
    options: ['A. 学校/gakkō', 'B. 教室/kyōshitsu', 'C. 大学/daigaku', 'D. 図書館/toshokan'],
    correctAnswer: 'A. 学校/gakkō',
    customHint: 'This word combines "study" (学) with "building" (校). It\'s where students go to learn.',
  ),
  QuestionPool(
    text: 'Choose the correct Kanji for "mountain":',
    options: ['A. 山/yama', 'B. 川/kawa', 'C. 木/ki', 'D. 田/ta'],
    correctAnswer: 'A. 山/yama',
    customHint: 'This Kanji looks like three peaks of a mountain. It\'s one of the simplest and most recognizable Kanji.',
  ),
  QuestionPool(
    text: 'Which Kanji means "time"?',
    options: ['A. 日/hi', 'B. 年/toshi', 'C. 時/toki', 'D. 分/fun'],
    correctAnswer: 'C. 時/toki',
    customHint: 'This Kanji combines "sun" (日) with "temple" (寺), representing the passage of time measured by the sun.',
  ),
  QuestionPool(
    text: 'Which one means "fire"?',
    options: ['A. 水/mizu', 'B. 火/hi', 'C. 木/ki', 'D. 石/ishi'],
    correctAnswer: 'B. 火/hi',
    customHint: 'This Kanji represents flames dancing upward. It\'s one of the basic elements.',
  ),
  QuestionPool(
    text: 'What does 水 (mizu) mean?',
    options: ['A. Fire', 'B. Water', 'C. Earth', 'D. Air'],
    correctAnswer: 'B. Water',
    customHint: 'This Kanji represents flowing water. It\'s one of the fundamental elements.',
  ),
  QuestionPool(
    text: 'Which Kanji means "tree"?',
    options: ['A. 木/ki', 'B. 森/mori', 'C. 林/hayashi', 'D. 花/hana'],
    correctAnswer: 'A. 木/ki',
    customHint: 'This Kanji looks like a tree with branches. It\'s the foundation for many other nature-related Kanji.',
  ),
  QuestionPool(
    text: 'What does 人 (hito) mean?',
    options: ['A. Animal', 'B. Person', 'C. Place', 'D. Thing'],
    correctAnswer: 'B. Person',
    customHint: 'This Kanji represents a person standing. It\'s one of the most basic and important Kanji.',
  ),
  QuestionPool(
    text: 'Which word means "book"?',
    options: ['A. 本/hon', 'B. 紙/kami', 'C. 筆/fude', 'D. 字/ji'],
    correctAnswer: 'A. 本/hon',
    customHint: 'This Kanji represents the root or origin, and is used for books as sources of knowledge.',
  ),
  QuestionPool(
    text: 'What does 日 (hi) mean?',
    options: ['A. Moon', 'B. Sun', 'C. Star', 'D. Cloud'],
    correctAnswer: 'B. Sun',
    customHint: 'This Kanji represents the sun. It\'s also used to mean "day" in compound words.',
  ),
  QuestionPool(
    text: 'Which Kanji means "house"?',
    options: ['A. 家/ie', 'B. 門/mon', 'C. 窓/mado', 'D. 部屋/heya'],
    correctAnswer: 'A. 家/ie',
    customHint: 'This Kanji represents a house with a roof. It\'s the basic character for dwelling.',
  ),
  QuestionPool(
    text: 'What does 車 (kuruma) mean?',
    options: ['A. Train', 'B. Car', 'C. Boat', 'D. Plane'],
    correctAnswer: 'B. Car',
    customHint: 'This Kanji represents a wheeled vehicle. It\'s used for various types of vehicles.',
  ),
  QuestionPool(
    text: 'Which word means "friend"?',
    options: ['A. 友達/tomodachi', 'B. 家族/kazoku', 'C. 先生/sensei', 'D. 学生/gakusei'],
    correctAnswer: 'A. 友達/tomodachi',
    customHint: 'This word combines "friend" (友) with "reach" (達), meaning someone you can reach out to.',
  ),
  QuestionPool(
    text: 'What does 手 (te) mean?',
    options: ['A. Foot', 'B. Hand', 'C. Head', 'D. Eye'],
    correctAnswer: 'B. Hand',
    customHint: 'This Kanji represents a hand with fingers. It\'s used in many compound words related to actions.',
  ),
  QuestionPool(
    text: 'Which Kanji means "eye"?',
    options: ['A. 目/me', 'B. 耳/mimi', 'C. 鼻/hana', 'D. 口/kuchi'],
    correctAnswer: 'A. 目/me',
    customHint: 'This Kanji represents an eye. It\'s used in words related to seeing and vision.',
  ),
  QuestionPool(
    text: 'What does 口 (kuchi) mean?',
    options: ['A. Nose', 'B. Mouth', 'C. Ear', 'D. Eye'],
    correctAnswer: 'B. Mouth',
    customHint: 'This Kanji represents a mouth opening. It\'s used in words related to speaking and eating.',
  ),
  QuestionPool(
    text: 'Which word means "food"?',
    options: ['A. 食べ物/tabemono', 'B. 飲み物/nomimono', 'C. 料理/ryōri', 'D. 食事/shokuji'],
    correctAnswer: 'A. 食べ物/tabemono',
    customHint: 'This word combines "eat" (食べ) with "thing" (物), meaning things you eat.',
  ),
  QuestionPool(
    text: 'What does 大 (dai) mean?',
    options: ['A. Small', 'B. Big', 'C. Medium', 'D. Tall'],
    correctAnswer: 'B. Big',
    customHint: 'This Kanji represents something large or great. It\'s used in many compound words.',
  ),
  QuestionPool(
    text: 'Which Kanji means "small"?',
    options: ['A. 小/chiisai', 'B. 大/ōkii', 'C. 中/naka', 'D. 高/takai'],
    correctAnswer: 'A. 小/chiisai',
    customHint: 'This Kanji represents something small. It\'s the opposite of "big" (大).',
  ),
  QuestionPool(
    text: 'What does 中 (naka) mean?',
    options: ['A. Outside', 'B. Inside', 'C. Middle', 'D. Around'],
    correctAnswer: 'C. Middle',
    customHint: 'This Kanji represents the center or middle. It\'s used in words like "middle school" (中学校).',
  ),
  QuestionPool(
    text: 'Which word means "good"?',
    options: ['A. 良い/ii', 'B. 悪い/warui', 'C. 新しい/atarashii', 'D. 古い/furui'],
    correctAnswer: 'A. 良い/ii',
    customHint: 'This word means good or nice. It\'s one of the most basic adjectives in Japanese.',
  ),
  QuestionPool(
    text: 'What does 新 (atarashii) mean?',
    options: ['A. Old', 'B. New', 'C. Good', 'D. Bad'],
    correctAnswer: 'B. New',
    customHint: 'This Kanji represents something new or fresh. It\'s used in words like "new year" (新年).',
  ),
  QuestionPool(
    text: 'Which Kanji means "year"?',
    options: ['A. 年/toshi', 'B. 月/tsuki', 'C. 日/hi', 'D. 時/toki'],
    correctAnswer: 'A. 年/toshi',
    customHint: 'This Kanji represents a year. It\'s used in words like "this year" (今年) and "next year" (来年).',
  ),
  QuestionPool(
    text: 'What does 月 (tsuki) mean?',
    options: ['A. Sun', 'B. Moon', 'C. Star', 'D. Cloud'],
    correctAnswer: 'B. Moon',
    customHint: 'This Kanji represents the moon. It\'s also used to mean "month" in compound words.',
  ),
];

// Normal questions - More complex vocabulary and compound words
final List<QuestionPool> normalQuestions = [
  QuestionPool(
    text: 'What does this Kanji mean: 学 (がく)?',
    options: ['A. Tree', 'B. Study', 'C. Moon', 'D. Wind'],
    correctAnswer: 'B. Study',
    customHint: 'This Kanji represents the concept of learning and education. It\'s fundamental to understanding Japanese education.',
  ),
  QuestionPool(
    text: 'Which compound word means "university"?',
    options: ['A. 小学校/shōgakkō', 'B. 中学校/chūgakkō', 'C. 大学/daigaku', 'D. 高校/kōkō'],
    correctAnswer: 'C. 大学/daigaku',
    customHint: 'This word combines "big" (大) with "study" (学), meaning the highest level of education.',
  ),
  QuestionPool(
    text: 'What does 先生 (sensei) mean?',
    options: ['A. Student', 'B. Teacher', 'C. Friend', 'D. Parent'],
    correctAnswer: 'B. Teacher',
    customHint: 'This word combines "before" (先) with "life" (生), meaning someone who has lived before and can teach.',
  ),
  QuestionPool(
    text: 'Which word means "library"?',
    options: ['A. 図書館/toshokan', 'B. 学校/gakkō', 'C. 教室/kyōshitsu', 'D. 事務所/jimusho'],
    correctAnswer: 'A. 図書館/toshokan',
    customHint: 'This word combines "picture" (図), "book" (書), and "building" (館), meaning a place for books.',
  ),
  QuestionPool(
    text: 'What does 時間 (jikan) mean?',
    options: ['A. Space', 'B. Time', 'C. Place', 'D. Thing'],
    correctAnswer: 'B. Time',
    customHint: 'This word combines "time" (時) with "interval" (間), meaning a period of time.',
  ),
  QuestionPool(
    text: 'Which compound word means "restaurant"?',
    options: ['A. 食堂/shokudō', 'B. 台所/daidokoro', 'C. 料理/ryōri', 'D. 食事/shokuji'],
    correctAnswer: 'A. 食堂/shokudō',
    customHint: 'This word combines "food" (食) with "hall" (堂), meaning a hall where food is served.',
  ),
  QuestionPool(
    text: 'What does 家族 (kazoku) mean?',
    options: ['A. Friends', 'B. Family', 'C. Teachers', 'D. Students'],
    correctAnswer: 'B. Family',
    customHint: 'This word combines "house" (家) with "tribe" (族), meaning the people who live in the same house.',
  ),
  QuestionPool(
    text: 'Which word means "hospital"?',
    options: ['A. 病院/byōin', 'B. 薬局/yakkyoku', 'C. 診療所/shinryōjo', 'D. 保健所/hokenjo'],
    correctAnswer: 'A. 病院/byōin',
    customHint: 'This word combines "sickness" (病) with "institution" (院), meaning a place for treating sickness.',
  ),
  QuestionPool(
    text: 'What does 電車 (densha) mean?',
    options: ['A. Car', 'B. Train', 'C. Bus', 'D. Plane'],
    correctAnswer: 'B. Train',
    customHint: 'This word combines "electricity" (電) with "car" (車), meaning an electric vehicle that runs on tracks.',
  ),
  QuestionPool(
    text: 'Which compound word means "telephone"?',
    options: ['A. 電話/denwa', 'B. 電車/densha', 'C. 電気/denki', 'D. 電波/denpa'],
    correctAnswer: 'A. 電話/denwa',
    customHint: 'This word combines "electricity" (電) with "speech" (話), meaning electric speech transmission.',
  ),
  QuestionPool(
    text: 'What does 映画 (eiga) mean?',
    options: ['A. Music', 'B. Movie', 'C. Book', 'D. Game'],
    correctAnswer: 'B. Movie',
    customHint: 'This word combines "reflection" (映) with "picture" (画), meaning moving pictures projected on screen.',
  ),
  QuestionPool(
    text: 'Which word means "shopping"?',
    options: ['A. 買い物/kaimono', 'B. 売り物/urimono', 'C. 物価/bukka', 'D. 商品/shōhin'],
    correctAnswer: 'A. 買い物/kaimono',
    customHint: 'This word combines "buy" (買い) with "thing" (物), meaning the act of buying things.',
  ),
  QuestionPool(
    text: 'What does 旅行 (ryokō) mean?',
    options: ['A. Work', 'B. Travel', 'C. Study', 'D. Sleep'],
    correctAnswer: 'B. Travel',
    customHint: 'This word combines "travel" (旅) with "go" (行), meaning the act of going on a journey.',
  ),
  QuestionPool(
    text: 'Which compound word means "weather"?',
    options: ['A. 天気/tenki', 'B. 気候/kikō', 'C. 温度/ondo', 'D. 湿度/shitsudo'],
    correctAnswer: 'A. 天気/tenki',
    customHint: 'This word combines "heaven" (天) with "spirit" (気), meaning the condition of the sky.',
  ),
  QuestionPool(
    text: 'What does 音楽 (ongaku) mean?',
    options: ['A. Art', 'B. Music', 'C. Dance', 'D. Theater'],
    correctAnswer: 'B. Music',
    customHint: 'This word combines "sound" (音) with "pleasure" (楽), meaning pleasant sounds.',
  ),
  QuestionPool(
    text: 'Which word means "sports"?',
    options: ['A. 運動/undō', 'B. 体育/taiiku', 'C. 競技/kyōgi', 'D. 試合/shiai'],
    correctAnswer: 'A. 運動/undō',
    customHint: 'This word combines "transport" (運) with "move" (動), meaning physical movement and exercise.',
  ),
  QuestionPool(
    text: 'What does 勉強 (benkyō) mean?',
    options: ['A. Work', 'B. Study', 'C. Play', 'D. Rest'],
    correctAnswer: 'B. Study',
    customHint: 'This word combines "effort" (勉) with "strong" (強), meaning to make a strong effort to learn.',
  ),
  QuestionPool(
    text: 'Which compound word means "homework"?',
    options: ['A. 宿題/shukudai', 'B. 課題/kadai', 'C. 問題/mondai', 'D. 練習/renshū'],
    correctAnswer: 'A. 宿題/shukudai',
    customHint: 'This word combines "lodging" (宿) with "topic" (題), meaning work to be done at home.',
  ),
  QuestionPool(
    text: 'What does 会社 (kaisha) mean?',
    options: ['A. School', 'B. Company', 'C. Hospital', 'D. Store'],
    correctAnswer: 'B. Company',
    customHint: 'This word combines "meeting" (会) with "society" (社), meaning a business organization.',
  ),
  QuestionPool(
    text: 'Which word means "station"?',
    options: ['A. 駅/eki', 'B. 空港/kūkō', 'C. 港/minato', 'D. 停留所/teiryūjo'],
    correctAnswer: 'A. 駅/eki',
    customHint: 'This Kanji represents a place where vehicles stop, specifically for trains.',
  ),
  QuestionPool(
    text: 'What does 銀行 (ginkō) mean?',
    options: ['A. Store', 'B. Bank', 'C. Office', 'D. School'],
    correctAnswer: 'B. Bank',
    customHint: 'This word combines "silver" (銀) with "line" (行), referring to the silver coins and lines of money.',
  ),
  QuestionPool(
    text: 'Which compound word means "post office"?',
    options: ['A. 郵便局/yūbinkyoku', 'B. 銀行/ginkō', 'C. 警察署/keisatsusho', 'D. 市役所/shiyakusho'],
    correctAnswer: 'A. 郵便局/yūbinkyoku',
    customHint: 'This word combines "mail" (郵便) with "office" (局), meaning a place for handling mail.',
  ),
  QuestionPool(
    text: 'What does 公園 (kōen) mean?',
    options: ['A. Garden', 'B. Park', 'C. Forest', 'D. Mountain'],
    correctAnswer: 'B. Park',
    customHint: 'This word combines "public" (公) with "garden" (園), meaning a public garden or park.',
  ),
  QuestionPool(
    text: 'Which word means "museum"?',
    options: ['A. 美術館/bijutsukan', 'B. 図書館/toshokan', 'C. 映画館/eigakan', 'D. 体育館/taiikukan'],
    correctAnswer: 'A. 美術館/bijutsukan',
    customHint: 'This word combines "art" (美術) with "hall" (館), meaning a hall for displaying art.',
  ),
  QuestionPool(
    text: 'What does 動物園 (dōbutsuen) mean?',
    options: ['A. Zoo', 'B. Aquarium', 'C. Farm', 'D. Forest'],
    correctAnswer: 'A. Zoo',
    customHint: 'This word combines "animal" (動物) with "garden" (園), meaning a garden for animals.',
  ),
  QuestionPool(
    text: 'Which compound word means "airport"?',
    options: ['A. 空港/kūkō', 'B. 駅/eki', 'C. 港/minato', 'D. 停留所/teiryūjo'],
    correctAnswer: 'A. 空港/kūkō',
    customHint: 'This word combines "sky" (空) with "port" (港), meaning a port for aircraft.',
  ),
];

// Hard questions - Advanced vocabulary, idioms, and complex grammar
final List<QuestionPool> hardQuestions = [
  QuestionPool(
    text: 'What does this Kanji mean: 学 (がく)?',
    options: ['A. Tree', 'B. Study', 'C. Moon', 'D. Wind'],
    correctAnswer: 'B. Study',
    customHint: 'This Kanji represents the concept of learning and education. It\'s fundamental to understanding Japanese education.',
  ),
  QuestionPool(
    text: 'Which compound word means "philosophy"?',
    options: ['A. 哲学/tetsugaku', 'B. 科学/kagaku', 'C. 文学/bungaku', 'D. 数学/sūgaku'],
    correctAnswer: 'A. 哲学/tetsugaku',
    customHint: 'This word combines "wisdom" (哲) with "study" (学), meaning the study of wisdom and fundamental questions.',
  ),
  QuestionPool(
    text: 'What does 経済 (keizai) mean?',
    options: ['A. Politics', 'B. Economy', 'C. Society', 'D. Culture'],
    correctAnswer: 'B. Economy',
    customHint: 'This word combines "manage" (経) with "world" (済), meaning the management of worldly affairs and resources.',
  ),
  QuestionPool(
    text: 'Which word means "democracy"?',
    options: ['A. 民主主義/minshushugi', 'B. 社会主義/shakaishugi', 'C. 資本主義/shibonshugi', 'D. 共産主義/kyōsanshugi'],
    correctAnswer: 'A. 民主主義/minshushugi',
    customHint: 'This word combines "people" (民), "master" (主), and "principle" (主義), meaning rule by the people.',
  ),
  QuestionPool(
    text: 'What does 環境 (kankyō) mean?',
    options: ['A. Society', 'B. Environment', 'C. Culture', 'D. Technology'],
    correctAnswer: 'B. Environment',
    customHint: 'This word combines "circle" (環) with "condition" (境), meaning the surrounding conditions and circumstances.',
  ),
  QuestionPool(
    text: 'Which compound word means "artificial intelligence"?',
    options: ['A. 人工知能/jinkōchinō', 'B. 機械学習/kikaigakushū', 'C. 深層学習/shinsōgakushū', 'D. 自然言語処理/shizengengoshori'],
    correctAnswer: 'A. 人工知能/jinkōchinō',
    customHint: 'This word combines "artificial" (人工) with "intelligence" (知能), meaning man-made intelligence.',
  ),
  QuestionPool(
    text: 'What does 心理学 (shinrigaku) mean?',
    options: ['A. Sociology', 'B. Psychology', 'C. Anthropology', 'D. Philosophy'],
    correctAnswer: 'B. Psychology',
    customHint: 'This word combines "mind" (心理) with "study" (学), meaning the study of the mind and behavior.',
  ),
  QuestionPool(
    text: 'Which word means "biotechnology"?',
    options: ['A. 生物工学/seibutsukōgaku', 'B. 遺伝子工学/idenshikōgaku', 'C. 分子生物学/bunshiseibutsugaku', 'D. 細胞生物学/saibōseibutsugaku'],
    correctAnswer: 'A. 生物工学/seibutsukōgaku',
    customHint: 'This word combines "living thing" (生物) with "engineering" (工学), meaning engineering with living organisms.',
  ),
  QuestionPool(
    text: 'What does 国際関係 (kokusaikankei) mean?',
    options: ['A. International Relations', 'B. Global Economy', 'C. World History', 'D. Cultural Exchange'],
    correctAnswer: 'A. International Relations',
    customHint: 'This word combines "international" (国際) with "relations" (関係), meaning relationships between nations.',
  ),
  QuestionPool(
    text: 'Which compound word means "sustainable development"?',
    options: ['A. 持続可能な開発/jizokukanōnakaihatsu', 'B. 環境保護/kankyōhogo', 'C. 再生可能エネルギー/saiseikanōenerugī', 'D. 循環型社会/junkangatashakai'],
    correctAnswer: 'A. 持続可能な開発/jizokukanōnakaihatsu',
    customHint: 'This phrase combines "sustainable" (持続可能な) with "development" (開発), meaning development that can be maintained.',
  ),
  QuestionPool(
    text: 'What does 量子力学 (ryōshirikigaku) mean?',
    options: ['A. Classical Mechanics', 'B. Quantum Mechanics', 'C. Thermodynamics', 'D. Electromagnetism'],
    correctAnswer: 'B. Quantum Mechanics',
    customHint: 'This word combines "quantum" (量子) with "mechanics" (力学), meaning the physics of quantum particles.',
  ),
  QuestionPool(
    text: 'Which word means "neuroscience"?',
    options: ['A. 神経科学/shinkeikagaku', 'B. 脳科学/nōkagaku', 'C. 認知科学/ninchikagaku', 'D. 行動科学/kōdōkagaku'],
    correctAnswer: 'A. 神経科学/shinkeikagaku',
    customHint: 'This word combines "nerve" (神経) with "science" (科学), meaning the study of the nervous system.',
  ),
  QuestionPool(
    text: 'What does 分子生物学 (bunshiseibutsugaku) mean?',
    options: ['A. Cell Biology', 'B. Molecular Biology', 'C. Genetics', 'D. Biochemistry'],
    correctAnswer: 'B. Molecular Biology',
    customHint: 'This word combines "molecule" (分子) with "biology" (生物学), meaning the study of biological molecules.',
  ),
  QuestionPool(
    text: 'Which compound word means "cybersecurity"?',
    options: ['A. サイバーセキュリティ/saibāsekyuriti', 'B. 情報セキュリティ/jōhōsekyuriti', 'C. ネットワークセキュリティ/nettowākusekyuriti', 'D. デジタルセキュリティ/dejitarusekyuriti'],
    correctAnswer: 'A. サイバーセキュリティ/saibāsekyuriti',
    customHint: 'This is a loanword combining "cyber" (サイバー) with "security" (セキュリティ), meaning protection of digital systems.',
  ),
  QuestionPool(
    text: 'What does 宇宙工学 (uchūkōgaku) mean?',
    options: ['A. Aerospace Engineering', 'B. Space Engineering', 'C. Rocket Science', 'D. Satellite Technology'],
    correctAnswer: 'B. Space Engineering',
    customHint: 'This word combines "space" (宇宙) with "engineering" (工学), meaning engineering for space exploration.',
  ),
  QuestionPool(
    text: 'Which word means "nanotechnology"?',
    options: ['A. ナノテクノロジー/nanotekunorojī', 'B. マイクロテクノロジー/maikurotekunorojī', 'C. バイオテクノロジー/baiotekunorojī', 'D. グリーンテクノロジー/gurīntekunorojī'],
    correctAnswer: 'A. ナノテクノロジー/nanotekunorojī',
    customHint: 'This is a loanword meaning technology at the nanometer scale, dealing with extremely small particles.',
  ),
  QuestionPool(
    text: 'What does 再生可能エネルギー (saiseikanōenerugī) mean?',
    options: ['A. Renewable Energy', 'B. Nuclear Energy', 'C. Solar Energy', 'D. Wind Energy'],
    correctAnswer: 'A. Renewable Energy',
    customHint: 'This phrase combines "renewable" (再生可能) with "energy" (エネルギー), meaning energy that can be replenished.',
  ),
  QuestionPool(
    text: 'Which compound word means "machine learning"?',
    options: ['A. 機械学習/kikaigakushū', 'B. 深層学習/shinsōgakushū', 'C. 強化学習/kyōkagakushū', 'D. 教師なし学習/kyōshinashigakushū'],
    correctAnswer: 'A. 機械学習/kikaigakushū',
    customHint: 'This word combines "machine" (機械) with "learning" (学習), meaning the ability of machines to learn from data.',
  ),
  QuestionPool(
    text: 'What does 遺伝子工学 (idenshikōgaku) mean?',
    options: ['A. Genetic Engineering', 'B. Molecular Biology', 'C. Biotechnology', 'D. Genomics'],
    correctAnswer: 'A. Genetic Engineering',
    customHint: 'This word combines "gene" (遺伝子) with "engineering" (工学), meaning the manipulation of genetic material.',
  ),
  QuestionPool(
    text: 'Which word means "blockchain"?',
    options: ['A. ブロックチェーン/burokkuchēn', 'B. 暗号通貨/angōtsūka', 'C. 分散台帳/bunsandaichō', 'D. スマートコントラクト/sumātokontorakuto'],
    correctAnswer: 'A. ブロックチェーン/burokkuchēn',
    customHint: 'This is a loanword meaning a distributed ledger technology that maintains a continuously growing list of records.',
  ),
  QuestionPool(
    text: 'What does 人工衛星 (jinkōeisei) mean?',
    options: ['A. Space Station', 'B. Artificial Satellite', 'C. Space Probe', 'D. Space Shuttle'],
    correctAnswer: 'B. Artificial Satellite',
    customHint: 'This word combines "artificial" (人工) with "satellite" (衛星), meaning a man-made object orbiting Earth.',
  ),
  QuestionPool(
    text: 'Which compound word means "virtual reality"?',
    options: ['A. バーチャルリアリティ/bācharurariti', 'B. 拡張現実/kakuchōgenjitsu', 'C. 混合現実/kongōgenjitsu', 'D. 没入型体験/botsunyūgata taiken'],
    correctAnswer: 'A. バーチャルリアリティ/bācharurariti',
    customHint: 'This is a loanword combining "virtual" (バーチャル) with "reality" (リアリティ), meaning computer-generated reality.',
  ),
  QuestionPool(
    text: 'What does 深層学習 (shinsōgakushū) mean?',
    options: ['A. Deep Learning', 'B. Machine Learning', 'C. Neural Networks', 'D. Artificial Intelligence'],
    correctAnswer: 'A. Deep Learning',
    customHint: 'This word combines "deep" (深層) with "learning" (学習), meaning learning with multiple layers of neural networks.',
  ),
  QuestionPool(
    text: 'Which word means "cryptocurrency"?',
    options: ['A. 暗号通貨/angōtsūka', 'B. デジタル通貨/dejitarutsūka', 'C. 仮想通貨/kasōtsūka', 'D. 電子マネー/denshimanē'],
    correctAnswer: 'A. 暗号通貨/angōtsūka',
    customHint: 'This word combines "cipher" (暗号) with "currency" (通貨), meaning digital currency secured by cryptography.',
  ),
  QuestionPool(
    text: 'What does 量子コンピュータ (ryōshikonpyūta) mean?',
    options: ['A. Quantum Computer', 'B. Supercomputer', 'C. Neural Computer', 'D. Optical Computer'],
    correctAnswer: 'A. Quantum Computer',
    customHint: 'This word combines "quantum" (量子) with "computer" (コンピュータ), meaning a computer that uses quantum mechanical phenomena.',
  ),
  QuestionPool(
    text: 'Which compound word means "augmented reality"?',
    options: ['A. 拡張現実/kakuchōgenjitsu', 'B. バーチャルリアリティ/bācharurariti', 'C. 混合現実/kongōgenjitsu', 'D. 没入型体験/botsunyūgata taiken'],
    correctAnswer: 'A. 拡張現実/kakuchōgenjitsu',
    customHint: 'This word combines "expansion" (拡張) with "reality" (現実), meaning reality enhanced by computer-generated information.',
  ),
  QuestionPool(
    text: 'What does 自然言語処理 (shizengengoshori) mean?',
    options: ['A. Natural Language Processing', 'B. Machine Translation', 'C. Speech Recognition', 'D. Text Analysis'],
    correctAnswer: 'A. Natural Language Processing',
    customHint: 'This word combines "natural language" (自然言語) with "processing" (処理), meaning computer processing of human language.',
  ),
  QuestionPool(
    text: 'Which word means "Internet of Things"?',
    options: ['A. モノのインターネット/monono intānetto', 'B. スマートホーム/sumātohōmu', 'C. ウェアラブルデバイス/wearaburudebaisu', 'D. エッジコンピューティング/ejjikonpyūtingu'],
    correctAnswer: 'A. モノのインターネット/monono intānetto',
    customHint: 'This phrase combines "things" (モノ) with "internet" (インターネット), meaning the network of physical objects with sensors.',
  ),
  QuestionPool(
    text: 'What does 分散台帳技術 (bunsandaichōgijutsu) mean?',
    options: ['A. Distributed Ledger Technology', 'B. Blockchain Technology', 'C. Peer-to-Peer Network', 'D. Cryptocurrency Technology'],
    correctAnswer: 'A. Distributed Ledger Technology',
    customHint: 'This phrase combines "distributed" (分散), "ledger" (台帳), and "technology" (技術), meaning technology for distributed record-keeping.',
  ),
];

// Function to get a random question from a specific difficulty pool
QuestionPool getRandomQuestion(Difficulty difficulty) {
  List<QuestionPool> questions;
  switch (difficulty) {
    case Difficulty.EASY:
      questions = easyQuestions;
      break;
    case Difficulty.NORMAL:
      questions = normalQuestions;
      break;
    case Difficulty.HARD:
      questions = hardQuestions;
      break;
  }
  
  // Use a proper random number generator for better randomness
  final random = Random();
  final randomIndex = random.nextInt(questions.length);
  return questions[randomIndex];
}

// Function to get a random question for any interaction (replaces fixed interaction-based selection)
QuestionPool getRandomQuestionForDifficulty(Difficulty difficulty) {
  return getRandomQuestion(difficulty);
}
