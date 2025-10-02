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
  final String? mediaType;
  final String? mediaId;

  UserReaction({
    this.reactionType,
    this.mediaType,
    this.mediaId,
  });

  factory UserReaction.fromJson(Map<String, dynamic> json) {
    return UserReaction(
      reactionType: json['type'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaId: json['mediaId'] as String?,
    );
  }
}
