import 'meal_guide.dart';

enum MealChatAuthor { assistant, user }

class MealChatMessage {
  const MealChatMessage({
    required this.id,
    required this.author,
    required this.text,
  });

  final String id;
  final MealChatAuthor author;
  final String text;
}

class MealChatReply {
  const MealChatReply({required this.message, this.recommendation});

  final String message;
  final MealRecommendation? recommendation;
}
