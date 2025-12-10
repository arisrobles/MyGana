import 'package:nihongo_japanese_app/screens/story_screen.dart';

class StoryBeat {
  final String text;
  final String? speaker;
  final String background;
  final String? character;
  final CharacterPosition characterPosition;
  final Question? question;
  final String harukiExpression;
  final String? soundFile; // Optional sound file for character voice
  final String? bgmFile; // Optional BGM file for background music

  StoryBeat({
    required this.text,
    this.speaker,
    required this.background,
    this.character,
    this.characterPosition = CharacterPosition.center,
    this.question,
    required this.harukiExpression,
    this.soundFile, // Optional sound file parameter
    this.bgmFile, // Optional BGM file parameter
  });
}

class Question {
  final String text;
  final List<String> options;
  final String correctAnswer;
  final String? customHint;

  Question({
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.customHint,
  });
}

// EASY MODE - Simplest questions with obvious answers
final List<StoryBeat> easyStoryBeats = [
  // Introduction
  StoryBeat(
    text:                                       
        'Haruki is a high school student who suddenly gets transported to a mysterious academy where every person he meets tests his Kanji skills. If he passes all 10 trials, he can return home—stronger and wiser.',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Surprised).png',
    
  ),

  // Interaction 1: Sensei Aki
  StoryBeat(
    text:
        'Haruki wakes up in a classroom bathed in golden light. A kind-looking woman greets him.',
    background: 'Classroom (Inter1).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/writing.mp3',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text: 'Welcome, Haruki. To move forward, you must understand the basics.',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Aki1.wav',

  ),
  StoryBeat(
    text: '',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What does this Kanji mean: 学 (がく / gaku)?',
      options: ['A. Tree', 'B. Study', 'C. Moon', 'D. Wind'],
      correctAnswer: 'B. Study',
      customHint: 'This Kanji is related to education and learning. Think about what you do in school.',
    ),
    harukiExpression: 'Haruki (Normal).png',


  ),

  // Interaction 2: Yuto
  StoryBeat(
    text: 'Haruki meets a shy first-year named Yuto in the hallway.',
    background: 'Hallway (Inter2).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/hallway.mp3',
  ),
  StoryBeat(
    speaker: 'Yuto',
    text:
        'I always mix up the word for "student"... Can you help me figure it out?',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Sad).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/Yuto.wav',

  ),
  StoryBeat(
    text: '',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'Which word means "student"?',
      options: ['A. 先生/sensei', 'B. 学生/gakusei', 'C. 水生/suisei', 'D. 車生/shasei'],
      correctAnswer: 'B. 学生/gakusei',
      customHint: 'This word combines the Kanji for "study" (学) with "life" (生). Think about someone who studies.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 3: Hana
  StoryBeat(
    text: 'In the library, Haruki meets Hana surrounded by textbooks.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/library.mp3',
  ),
  StoryBeat(
    speaker: 'Hana',
    text:
        'I\'m writing a journal entry. Can you help me identify the word for "school"?',
    background: 'Library (Inter3).png',
    character: 'Hana (Delighted).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Hana.wav',

  ),
  StoryBeat(
    text: '',
    background: 'Library (Inter3).png',
    character: 'Hana (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text: 'Which word means "school"?',
      options: ['A. 学校/gakkō', 'B. 教室/kyōshitsu', 'C. 大学/daigaku', 'D. 図書館/toshokan'],
      correctAnswer: 'A. 学校/gakkō',
      customHint: 'This word combines "study" (学) with "building" (校). It\'s where students go to learn.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 4: Kenta
  StoryBeat(
    text: 'Kenta jogs past Haruki on the school field.',
    background: 'Athletics Track (Inter4).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/sports.mp3',
  ),
  StoryBeat(
    speaker: 'Kenta',
    text:
        'Every day I climb the hills near here. Do you know the Kanji for "mountain"?',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/Kenta.wav',

  ),
  StoryBeat(
    text: '',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Choose the correct Kanji for "mountain":',
      options: ['A. 山/yama', 'B. 川/kawa', 'C. 木/ki', 'D. 田/ta'],
      correctAnswer: 'A. 山/yama',
      customHint: 'This Kanji looks like three peaks of a mountain. It\'s one of the simplest and most recognizable Kanji.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 5: Emi
  StoryBeat(
    text: 'Haruki sees Emi adjusting a sundial in the courtyard.',
    background: 'Courtyard (Inter5).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/courtyard.mp3',
  ),
  StoryBeat(
    speaker: 'Emi',
    text: 'Time is precious. Do you know the Kanji that means "time"?',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Smug).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Emi(Sage).wav',

  ),
  StoryBeat(
    text: '',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'Which Kanji means "time"?',
      options: ['A. 日/hi', 'B. 年/toshi', 'C. 時/toki', 'D. 分/fun'],
      correctAnswer: 'C. 時/toki',
      customHint: 'This Kanji combines "sun" (日) with "temple" (寺), representing the passage of time measured by the sun.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 6: Sota
  StoryBeat(
    text: 'Sota breathes fire on stage during a play rehearsal.',
    background: 'Stage (Inter6).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Sota',
    text: 'Fire is my favorite symbol. Can you pick the right Kanji for it?',
    background: 'Stage (Inter6).png',
    character: 'Sota (Laugh).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/Sota(Onyx).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Stage (Inter6).png',
    character: 'Sota (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Which one means "fire"?',
      options: ['A. 水/mizu', 'B. 火/hi', 'C. 木/ki', 'D. 石/ishi'],
      correctAnswer: 'B. 火/hi',
      customHint: 'This Kanji represents flames dancing upward. It\'s one of the five basic elements.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 7: Nao
  StoryBeat(
    text: 'Nao dives into the pool with a splash.',
    background: 'Pool (Inter7).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/swimmingpool.mp3',
  ),
  StoryBeat(
    speaker: 'Nao',
    text:
        'I love water. It flows like words in a sentence. Can you recognize it?',
    background: 'Pool (Inter7).png',
    character: 'Nao (Smile).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Nao(Shimmer).wav',

  ),
  StoryBeat(
    text: '',
    background: 'Pool (Inter7).png',
    character: 'Nao (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text: 'What is the Kanji for "water"?',
      options: ['A. 火/hi', 'B. 土/do', 'C. 水/mizu', 'D. 風/kaze'],
      correctAnswer: 'C. 水/mizu',
      customHint: 'This Kanji represents flowing water with streams. It\'s another of the five basic elements.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 8: Toshi
  StoryBeat(
    text: 'In the calligraphy room, Toshi shows Haruki a half-written scroll.',
    background: 'Arts Room (Inter8).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/art.mp3',
  ),
  StoryBeat(
    speaker: 'Toshi',
    text: 'Since we’re in the arts room, do you know what “calligraphy” is called in Japanese?',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Smirk).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Toshi(Ashe).wav',

  ),
  StoryBeat(
    text: '',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'What is the Japanese word for “calligraphy”?',
      options: ['A. 書道/shodō', 'B. 絵/e', 'C. 音楽/ongku', 'D. 文字/moji'],
      correctAnswer: 'A. 書道/shodō',
      customHint: '書 (sho) means “to write” and 道 (dō) means “way.” So 書道 means “the way of writing” — Japanese calligraphy.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 9: Mei
  StoryBeat(
    text: 'Mei greets Haruki with a bright smile in the study hall.',
    background: 'Student Council Room (Inter9).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/CouncilRoom.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text:
        'I want to be a university student one day. Do you know how to say that in Kanji?',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Smile2).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Mei(Nova).wav',

  ),
  StoryBeat(
    text: '',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What is the correct phrase for "university student"?',
      options: ['A. 小学生/shōgakusei', 'B. 大学生/daigakusei', 'C. 学生大/gakuseidai', 'D. 高校生/kōkōsei'],
      correctAnswer: 'B. 大学生/daigakusei',
      customHint: 'This combines "big" (大) with "student" (学生). University is considered "big school" in Japanese.',
    ),
    harukiExpression: 'Haruki (Normal).png',

  ),

  // Interaction 10: Professor Hoshino
  StoryBeat(
    text: 'Haruki enters the final chamber, where an older professor awaits.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Normal).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text:
        'To return to your world, you must master this final challenge. Form a complete and meaningful phrase.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Normal).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Prof Hoshino(Echo).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smirk).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Which of the following means "Japanese language"?',
      options: ['A. 中国語/Chūgokugo', 'B. 英語/Eigo', 'C. 日本語/Nihongo', 'D. 語日本/Go Nihon'],
      correctAnswer: 'C. 日本語/Nihongo',
      customHint: 'This combines "Japan" (日本) with "language" (語). It\'s the language spoken in Japan.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Ending
  StoryBeat(
    text:
        'As Haruki answers the final question, the air around him shimmers with golden light. Professor Hoshino smiles and slowly closes the ancient book he had been holding.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text:
        'You\'ve done well, Haruki. You walked the path of the Kanji Seeker, not only memorizing characters—but understanding their meaning in life, through people, and through purpose.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile2).png',
    soundFile: 'assets/sounds/ProfHoshinoExit.mp3',
  ),
  StoryBeat(
    text:
        'The ground beneath Haruki glows. One by one, all the people he met—Aki-sensei, Yuto, Hana, Kenta, Emi, Sota, Nao, Toshi, Mei—appear around him in a circle. They bow respectfully.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text:
        'Remember, Kanji is not just for tests. It\'s a mirror of culture, history, and identity.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Aki sensei (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/AkiExit.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text: 'We\'ll always be part of your story, even when you go back.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Mei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/MeiExit.mp3',
  ),
  StoryBeat(
    text:
        'The characters begin to fade into glowing symbols, swirling around Haruki as the notebook reappears in his hands. A soft wind blows, carrying the sound of distant school bells.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Sad).png',
  ),
  StoryBeat(
    text:
        'Haruki opens his eyes…\n\nHe\'s back in the real-world school library, sitting exactly where he first found the notebook. The mysterious title on the cover still reads "The Path of Characters," but now—there\'s a new inscription on the last page:\n\n"Those who seek meaning will always find it—in words, in people, in themselves."',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    text:
        'Haruki smiles, stands up, and looks out the window.\n\nFrom that day forward, he approaches his Kanji studies not as a chore—but as a journey.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Smile2).png',
  ),
  StoryBeat(
    text:
        'Congratulations! You\'ve completed your Kanji Journey with Haruki.\nBut remember—this is only the beginning of your own adventure in Japanese learning!',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
];

// NORMAL MODE - Original story with moderate difficulty
final List<StoryBeat> normalStoryBeats = [
  // Introduction
  StoryBeat(
    text:
        'Haruki is a high school student who suddenly gets transported to a mysterious academy where every person he meets tests his Kanji skills. If he passes all 10 trials, he can return home—stronger and wiser.',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),

  // Interaction 1: Sensei Aki
  StoryBeat(
    text:
        'Haruki wakes up in a classroom bathed in golden light. A kind-looking woman greets him.',
    background: 'Classroom (Inter1).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/writing.mp3',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text: 'Welcome, Haruki. To move forward, you must understand the basics.',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Aki1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What does this Kanji mean: 学 (がく)?',
      options: ['A. Tree', 'B. Study', 'C. Moon', 'D. Wind'],
      correctAnswer: 'B. Study',
      customHint: 'This Kanji represents the concept of learning and education. It\'s fundamental to understanding Japanese education.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 2: Yuto
  StoryBeat(
    text: 'Haruki meets a shy first-year named Yuto in the hallway.',
    background: 'Hallway (Inter2).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/hallway.mp3',
  ),
  StoryBeat(
    speaker: 'Yuto',
    text:
        'I always mix up the word for "student"... Can you help me figure it out?',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Sad).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/Yuto.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'Which Kanji completes this phrase: ___生 (student)?',
      options: ['A. 校', 'B. 学', 'C. 水', 'D. 本'],
      correctAnswer: 'B. 学',
      customHint: 'The Kanji for "study" (学) combined with "life" (生) creates the word for student. Think about what students do.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 3: Hana
  StoryBeat(
    text: 'In the library, Haruki meets Hana surrounded by textbooks.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/library.mp3',
  ),
  StoryBeat(
    speaker: 'Hana',
    text:
        'I\'m writing a journal entry. Can you help me identify the word for "school"?',
    background: 'Library (Inter3).png',
    character: 'Hana (Delighted).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Hana.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Library (Inter3).png',
    character: 'Hana (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text: 'Which word means "school"?',
      options: ['A. 学校', 'B. 教室', 'C. 大学', 'D. 図書館'],
      correctAnswer: 'A. 学校',
      customHint: 'This word combines "study" (学) with "building" (校). It\'s where students go to learn.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 4: Kenta
  StoryBeat(
    text: 'Kenta jogs past Haruki on the school field.',
    background: 'Athletics Track (Inter4).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/sports.mp3',
  ),
  StoryBeat(
    speaker: 'Kenta',
    text:
        'Every day I climb the hills near here. Do you know the Kanji for "mountain"?',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/Kenta.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Choose the correct Kanji for "mountain":',
      options: ['A. 山', 'B. 火', 'C. 木', 'D. 空'],
      correctAnswer: 'A. 山',
      customHint: 'This Kanji represents three mountain peaks. It\'s one of the most basic and recognizable Kanji characters.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 5: Emi
  StoryBeat(
    text: 'Haruki sees Emi adjusting a sundial in the courtyard.',
    background: 'Courtyard (Inter5).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/courtyard.mp3',
  ),
  StoryBeat(
    speaker: 'Emi',
    text: 'Time is precious. Do you know the Kanji that means "time"?',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Smug).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Emi(Sage).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'Which Kanji means "time"?',
      options: ['A. 日', 'B. 分', 'C. 時', 'D. 曜'],
      correctAnswer: 'C. 時',
      customHint: 'This Kanji combines "sun" (日) with "temple" (寺), representing time as measured by the sun\'s movement.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 6: Sota
  StoryBeat(
    text: 'Sota breathes fire on stage during a play rehearsal.',
    background: 'Stage (Inter6).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Sota',
    text: 'Fire is my favorite symbol. Can you pick the right Kanji for it?',
    background: 'Stage (Inter6).png',
    character: 'Sota (Laugh).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/Sota(Onyx).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Stage (Inter6).png',
    character: 'Sota (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Which one means "fire"?',
      options: ['A. 水', 'B. 火', 'C. 光', 'D. 石'],
      correctAnswer: 'B. 火',
      customHint: 'This Kanji represents flames rising upward. It\'s one of the five basic elements in Japanese philosophy.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 7: Nao
  StoryBeat(
    text: 'Nao dives into the pool with a splash.',
    background: 'Pool (Inter7).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/swimmingpool.mp3',
  ),
  StoryBeat(
    speaker: 'Nao',
    text:
        'I love water. It flows like words in a sentence. Can you recognize it?',
    background: 'Pool (Inter7).png',
    character: 'Nao (Smile).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Nao(Shimmer).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Pool (Inter7).png',
    character: 'Nao (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text: 'What is the Kanji for "water"?',
      options: ['A. 雨', 'B. 氷', 'C. 水', 'D. 海'],
      correctAnswer: 'C. 水',
      customHint: 'This Kanji represents flowing water with streams. It\'s another of the five basic elements.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 8: Toshi
  StoryBeat(
    text: 'In the calligraphy room, Toshi shows Haruki a half-written scroll.',
    background: 'Arts Room (Inter8).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/art.mp3',
  ),
  StoryBeat(
    speaker: 'Toshi',
    text: 'Since we’re in the arts room, do you know what “calligraphy” is called in Japanese?',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Smirk).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Toshi(Ashe).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'What is the Japanese word for “calligraphy”?',
      options: ['A. 書道', 'B. 絵', 'C. 音楽', 'D. 文字'],
      correctAnswer: 'A. 書道',
      customHint: '書 (sho) means “to write” and 道 (dō) means “way.” So 書道 means “the way of writing” — Japanese calligraphy.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 9: Mei
  StoryBeat(
    text: 'Mei greets Haruki with a bright smile in the study hall.',
    background: 'Student Council Room (Inter9).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/CouncilRoom.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text:
        'I want to be a university student one day. Do you know how to say that in Kanji?',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Smile2).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/Mei(Nova).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What is the correct phrase for "university student"?',
      options: ['A. 高学校', 'B. 大学生', 'C. 学生大', 'D. 大高校生'],
      correctAnswer: 'B. 大学生',
      customHint: 'This combines "big" (大) with "student" (学生). University is considered "big school" compared to high school.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 10: Professor Hoshino
  StoryBeat(
    text: 'Haruki enters the final chamber, where an older professor awaits.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Normal).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text:
        'To return to your world, you must master this final challenge. Form a complete and meaningful phrase.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Normal).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/Prof Hoshino(Echo).wav',
  ),
  StoryBeat(
    text: '',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smirk).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Which of the following means "Japanese language"?',
      options: ['A. 日語', 'B. 本日', 'C. 日本語', 'D. 語日'],
      correctAnswer: 'C. 日本語',
      customHint: 'This combines "Japan" (日本) with "language" (語). It\'s the official term for the Japanese language.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Ending (same as easy mode)
  StoryBeat(
    text:
        'As Haruki answers the final question, the air around him shimmers with golden light. Professor Hoshino smiles and slowly closes the ancient book he had been holding.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text:
        'You\'ve done well, Haruki. You walked the path of the Kanji Seeker, not only memorizing characters—but understanding their meaning in life, through people, and through purpose.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile2).png',
    soundFile: 'assets/sounds/ProfHoshinoExit.mp3',
  ),
  StoryBeat(
    text:
        'The ground beneath Haruki glows. One by one, all the people he met—Aki-sensei, Yuto, Hana, Kenta, Emi, Sota, Nao, Toshi, Mei—appear around him in a circle. They bow respectfully.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text:
        'Remember, Kanji is not just for tests. It\'s a mirror of culture, history, and identity.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Aki sensei (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/AkiExit.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text: 'We\'ll always be part of your story, even when you go back.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Mei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/MeiExit.mp3',
  ),
  StoryBeat(
    text:
        'The characters begin to fade into glowing symbols, swirling around Haruki as the notebook reappears in his hands. A soft wind blows, carrying the sound of distant school bells.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Sad).png',
  ),
  StoryBeat(
    text:
        'Haruki opens his eyes…\n\nHe\'s back in the real-world school library, sitting exactly where he first found the notebook. The mysterious title on the cover still reads "The Path of Characters," but now—there\'s a new inscription on the last page:\n\n"Those who seek meaning will always find it—in words, in people, in themselves."',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    text:
        'Haruki smiles, stands up, and looks out the window.\n\nFrom that day forward, he approaches his Kanji studies not as a chore—but as a journey.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Smile2).png',
  ),
  StoryBeat(
    text:
        'Congratulations! You\'ve completed your Kanji Journey with Haruki.\nBut remember—this is only the beginning of your own adventure in Japanese learning!',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
];

// HARD MODE - More complex questions with challenging options
final List<StoryBeat> hardStoryBeats = [
  // Introduction
  StoryBeat(
    text:
        'Haruki is a high school student who suddenly gets transported to a mysterious academy where every person he meets tests his Kanji skills. If he passes all 10 trials, he can return home—stronger and wiser.',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),

  // Interaction 1: Sensei Aki
  StoryBeat(
    text:
        'Haruki wakes up in a classroom bathed in golden light. A kind-looking woman greets him.',
    background: 'Classroom (Inter1).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/writing.mp3',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text: 'Manabi no tabi e youkoso, Haruki-san. Mae ni susumu tame ni wa, kihon o rikai shinakereba narimasen.',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/AkiHard.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Classroom (Inter1).png',
    character: 'Aki sensei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What is the function of "manabi" in the phrase "manabi no tabi"?',
      options: ['A. "to learn"', 'B. "learning"', 'C. "educational"', 'D. A particle showing possession'],
      correctAnswer: 'B. "learning"',
      customHint: 'The word "manabi" comes from "manabu" (to learn). When used before "no," it becomes a noun that modifies "tabi" — meaning "journey of learning."',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 2: Yuto
  StoryBeat(
    text: 'Haruki meets a shy first-year named Yuto in the hallway.',
    background: 'Hallway (Inter2).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/hallway.mp3',
  ),
  StoryBeat(
    speaker: 'Yuto',
    text: 'Watashi wa gakusei desu ga, “gaku” to “sei” no kanji no imi o itsumo kondou shite shimaimasu. Tasukete kuremasu ka?',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Sad).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/YutoHard.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Hallway (Inter2).png',
    character: 'Yuto (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'What is the correct meaning of the compound 学生 (gakusei)?',
      options: [
        'A. Someone who studies life',
        'B. A student',
        'C. A teacher',
        'D. School life'
      ],
      correctAnswer: 'B. A student',
      customHint: '学生 combines "study" (学) with "life" (生) to mean "student" - someone whose life is dedicated to studying.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 3: Hana
  StoryBeat(
    text: 'In the library, Haruki meets Hana surrounded by textbooks.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/library.mp3',
  ),
  StoryBeat(
    speaker: 'Hana',
    text: 'Nikki o kaiteimasu. Kono bunshou o kansei saseru no o tetsudatte kuremasu ka? “Watashi wa mainichi _ _ _ ni ikimasu.”',
    background: 'Library (Inter3).png',
    character: 'Hana (Delighted).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/EmiHard.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Library (Inter3).png',
    character: 'Hana (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text:
          'Which would be most natural to complete "Watashi wa mainichi ___ ni ikimasu." (I go to ___ every day)?',
      options: ['A. daigakkou', 'B. gakkou', 'C. kouenkou', 'D. tokou'],
      correctAnswer: 'B. gakkou',
      customHint: '"Gakkou" is the standard compound word for "school," combining "gaku" (study) and "kou" (building).',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 4: Kenta
  StoryBeat(
    text: 'Kenta jogs past Haruki on the school field.',
    background: 'Athletics Track (Inter4).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/sports.mp3',
  ),
  StoryBeat(
    speaker: 'Kenta',
    text: 'Mainichi, chikaku no yama o nobotteimasu. Yama to kawa, dochira no kanji ga yori fukuzatsu da to omoimasu ka?',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/KentaHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Athletics Track (Inter4).png',
    character: 'Kenta (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'In the compound yamagawa (山川), which meaning is correct?',
      options: [
        'A. Mountains and rivers',
        'B. A mountain river',
        'C. A person\'s name',
        'D. A mountain range'
      ],
      correctAnswer: 'A. Mountains and rivers',
      customHint: '山川 combines "mountain" (山) and "river" (川) to mean "mountains and rivers" - representing natural landscapes.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 5: Emi
  StoryBeat(
    text: 'Haruki sees Emi adjusting a sundial in the courtyard.',
    background: 'Courtyard (Inter5).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/courtyard.mp3',
  ),
  StoryBeat(
    speaker: 'Emi',
    text: 'Toki wa kichou desu. “Jikan” to “tokei” no chigai wa nan desu ka?',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Smug).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/EmiHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Courtyard (Inter5).png',
    character: 'Emi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'Which sentence correctly uses the word "jikan" (時間)?',
      options: [
        'A. Watashi wa jikan o benkyou shimasu',
        'B. Watashi wa jikan ga arimasu',
        'C. Watashi wa jikan ni tabemasu',
        'D. Watashi wa jikan o ikimasu',
      ],
      correctAnswer: 'B. Watashi wa jikan ga arimasu',
      customHint: '“Jikan ga arimasu” means “I have time.” The particle “ga” marks what you have or exist — here, time.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 6: Sota
  StoryBeat(
    text: 'Sota breathes fire on stage during a play rehearsal.',
    background: 'Stage (Inter6).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Sota',
    text: 'Hi wa watashi no okiniiri no shinboru desu. “Kazan” to iu kotoba no imi wa nan desu ka?',
    background: 'Stage (Inter6).png',
    character: 'Sota (Laugh).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Laugh).png',
    soundFile: 'assets/sounds/SotaHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Stage (Inter6).png',
    character: 'Sota (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What does the compound kazan (火山) mean?',
      options: [
        'A. Fire mountain (volcano)',
        'B. Forest fire',
        'C. Burning tree',
        'D. Campfire'
      ],
      correctAnswer: 'A. Fire mountain (volcano)',
      customHint: '火山 literally means "fire mountain" - combining "fire" (火) and "mountain" (山) to create the word for volcano.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 7: Nao
  StoryBeat(
    text: 'Nao dives into the pool with a splash.',
    background: 'Pool (Inter7).png',
    harukiExpression: 'Haruki (Surprised).png',
    bgmFile: 'assets/sounds/swimmingpool.mp3',
  ),
  StoryBeat(
    speaker: 'Nao',
    text: 'Mizu ga daisuki desu. Bunshou no naka no kotoba no you ni nagaremasu. Kono kanji “oyogu” no imi wa nan desu ka?',
    background: 'Pool (Inter7).png',
    character: 'Nao (Smile).png',
    characterPosition: CharacterPosition.left,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/NaoHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Pool (Inter7).png',
    character: 'Nao (Normal).png',
    characterPosition: CharacterPosition.left,
    question: Question(
      text: 'What does the Kanji 泳 in 水泳 (suiei) mean?',
      options: ['A. To drink', 'B. To swim', 'C. To wash', 'D. To flow'],
      correctAnswer: 'B. To swim',
      customHint: '泳 means "to swim" and combines with 水 (water) to form 水泳 (swimming). The character represents movement through water.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 8: Toshi
  StoryBeat(
    text: 'In the calligraphy room, Toshi shows Haruki a half-written scroll.',
    background: 'Arts Room (Inter8).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/art.mp3',
  ),
  StoryBeat(
    speaker: 'Toshi',
    text: '“Kouchou sensei” to kaiteimasu. “Chou” no imi wa nan desu ka?',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Smirk).png',
    characterPosition: CharacterPosition.right,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/ToshiHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Arts Room (Inter8).png',
    character: 'Toshi (Normal).png',
    characterPosition: CharacterPosition.right,
    question: Question(
      text: 'In the phrase "kouchou sensei" (校長先生), what does "chou" (長) mean?',
      options: ['A. Old', 'B. Long', 'C. Head/Chief', 'D. Teacher'],
      correctAnswer: 'C. Head/Chief',
      customHint: '長 means "head" or "chief" in this context. 校長先生 means "principal teacher" - the head of the school.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 9: Mei
  StoryBeat(
    text: 'Mei greets Haruki with a bright smile in the study hall.',
    background: 'Student Council Room (Inter9).png',
    harukiExpression: 'Haruki (Normal).png',
    bgmFile: 'assets/sounds/CouncilRoom.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text: 'Itsuka daigakusei ni naritai desu. “Daigakuinsei” to iu kotoba no imi wa nan desu ka?',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Smile2).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile1).png',
    soundFile: 'assets/sounds/MeiHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Student Council Room (Inter9).png',
    character: 'Mei (Normal).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'What does "daigakuinsei" (大学院生) mean compared to "daigakusei" 大学生?',
      options: [
        'A. High school student vs. university student',
        'B. University student vs. graduate student',
        'C. Elementary student vs. university student',
        'D. First-year student vs. senior student'
      ],
      correctAnswer: 'B. University student vs. graduate student',
      customHint: '大学生 means "university student" while 大学院生 means "graduate student" - someone studying at the graduate level.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Interaction 10: Professor Hoshino
  StoryBeat(
    text: 'Haruki enters the final chamber, where an older professor awaits.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Normal).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text: 'Anata no sekai ni kaeru tame ni wa, kono saigo no chousen o masutā suru hitsuyou ga arimasu. Imi no aru bunshou o tsukurinasai.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Normal).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/ProfHoshinoHard_1.wav',
  ),
  StoryBeat(
    text: '',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smirk).png',
    characterPosition: CharacterPosition.center,
    question: Question(
      text: 'Which phrase means "I live near the university"?',
      options: [
        'A. Watashi wa daigaku no chikaku ni sundeimasu',
        'B. Watashi wa daigaku de sundeimasu',
        'C. Watashi wa daigaku ni sundeimasu',
        'D. Watashi wa daigaku o sundeimasu',
      ],
      correctAnswer: 'A. Watashi wa daigaku no chikaku ni sundeimasu',
      customHint: 'The phrase "no chikaku ni" means "near." Use it to describe a location close to something.',
    ),
    harukiExpression: 'Haruki (Normal).png',
  ),

  // Ending (same as other modes)
  StoryBeat(
    text:
        'As Haruki answers the final question, the air around him shimmers with golden light. Professor Hoshino smiles and slowly closes the ancient book he had been holding.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
  StoryBeat(
    speaker: 'Professor Hoshino',
    text:
        'You\'ve done well, Haruki. You walked the path of the Kanji Seeker, not only memorizing characters—but understanding their meaning in life, through people, and through purpose.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Prof Hoshino (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Smile2).png',
    soundFile: 'assets/sounds/ProfHoshinoExit.mp3',
  ),
  StoryBeat(
    text:
        'The ground beneath Haruki glows. One by one, all the people he met—Aki-sensei, Yuto, Hana, Kenta, Emi, Sota, Nao, Toshi, Mei—appear around him in a circle. They bow respectfully.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    speaker: 'Aki-sensei',
    text:
        'Remember, Kanji is not just for tests. It\'s a mirror of culture, history, and identity.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Aki sensei (Smile).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Normal).png',
    soundFile: 'assets/sounds/AkiExit.mp3',
  ),
  StoryBeat(
    speaker: 'Mei',
    text: 'We\'ll always be part of your story, even when you go back.',
    background: 'Principal\'s Office (Inter10).png',
    character: 'Mei (Delighted).png',
    characterPosition: CharacterPosition.center,
    harukiExpression: 'Haruki (Sad).png',
    soundFile: 'assets/sounds/MeiExit.mp3',
  ),
  StoryBeat(
    text:
        'The characters begin to fade into glowing symbols, swirling around Haruki as the notebook reappears in his hands. A soft wind blows, carrying the sound of distant school bells.',
    background: 'Principal\'s Office (Inter10).png',
    harukiExpression: 'Haruki (Sad).png',
  ),
  StoryBeat(
    text:
        'Haruki opens his eyes…\n\nHe\'s back in the real-world school library, sitting exactly where he first found the notebook. The mysterious title on the cover still reads "The Path of Characters," but now—there\'s a new inscription on the last page:\n\n"Those who seek meaning will always find it—in words, in people, in themselves."',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Surprised).png',
  ),
  StoryBeat(
    text:
        'Haruki smiles, stands up, and looks out the window.\n\nFrom that day forward, he approaches his Kanji studies not as a chore—but as a journey.',
    background: 'Library (Inter3).png',
    harukiExpression: 'Haruki (Smile2).png',
  ),
  StoryBeat(
    text:
        'Congratulations! You\'ve completed your Kanji Journey with Haruki.\nBut remember—this is only the beginning of your own adventure in Japanese learning!',
    background: 'Gate (Intro).png',
    harukiExpression: 'Haruki (Smile1).png',
  ),
];