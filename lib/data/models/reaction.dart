class Reaction {
  final String type;
  final int count;

  Reaction({required this.type, required this.count});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      type: json['type'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class UserReaction {
  final String? reactionType;

  UserReaction({this.reactionType});

  factory UserReaction.fromJson(Map<String, dynamic> json) {
    return UserReaction(
      reactionType: json['type'] as String?,
    );
  }
}
