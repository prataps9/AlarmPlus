enum AlarmPersonality { gentle, warrior, zen, hype }

class PersonalityConfig {
  const PersonalityConfig({
    required this.type,
    required this.name,
    required this.wakeMessage,
    required this.emoji,
    required this.vibrationIntensity,
    required this.xpBonus,
  });

  final AlarmPersonality type;
  final String name;
  final String wakeMessage;
  final String emoji;
  final int vibrationIntensity; // 0-3
  final int xpBonus;

  static const Map<AlarmPersonality, PersonalityConfig> all = {
    AlarmPersonality.gentle: PersonalityConfig(
      type: AlarmPersonality.gentle,
      name: 'Gentle',
      wakeMessage: 'Rise gently, take it slow',
      emoji: '🌸',
      vibrationIntensity: 1,
      xpBonus: 0,
    ),
    AlarmPersonality.warrior: PersonalityConfig(
      type: AlarmPersonality.warrior,
      name: 'Warrior',
      wakeMessage: 'CONQUER TODAY',
      emoji: '⚔️',
      vibrationIntensity: 3,
      xpBonus: 10,
    ),
    AlarmPersonality.zen: PersonalityConfig(
      type: AlarmPersonality.zen,
      name: 'Zen',
      wakeMessage: 'Breathe. You\'re exactly where you need to be.',
      emoji: '🧘',
      vibrationIntensity: 0,
      xpBonus: 0,
    ),
    AlarmPersonality.hype: PersonalityConfig(
      type: AlarmPersonality.hype,
      name: 'Hype',
      wakeMessage: "LET'S GOOO 🚀",
      emoji: '🔥',
      vibrationIntensity: 2,
      xpBonus: 5,
    ),
  };

  static PersonalityConfig forName(String name) {
    return all[AlarmPersonality.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AlarmPersonality.gentle,
    )] ?? all[AlarmPersonality.gentle]!;
  }

  static AlarmPersonality suggestForDay(int weekday) {
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return AlarmPersonality.zen;
    }
    if (weekday == DateTime.monday || weekday == DateTime.wednesday) {
      return AlarmPersonality.warrior;
    }
    if (weekday == DateTime.friday) {
      return AlarmPersonality.hype;
    }
    return AlarmPersonality.gentle;
  }
}
