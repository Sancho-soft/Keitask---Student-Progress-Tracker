import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardWidgets {
  static Widget buildLeaderboardContent(
    BuildContext context,
    List<QueryDocumentSnapshot> users,
  ) {
    if (users.isEmpty) {
      return const Center(child: Text('No students found.'));
    }

    // Split top 3 and the rest
    final topThree = users.take(3).toList();
    final rest = users.skip(3).toList();

    return CustomScrollView(
      slivers: [
        // Top 3 Podium
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: _buildPodium(context, topThree),
          ),
        ),
        // The Rest of the List
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final userDoc = rest[index];
            final rank = index + 4; // 1-based, skipping top 3
            return _buildRankItem(context, userDoc, rank);
          }, childCount: rest.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  static Widget _buildPodium(
    BuildContext context,
    List<QueryDocumentSnapshot> topThree,
  ) {
    if (topThree.isEmpty) return const SizedBox();

    // Reorder for visual podium: 2nd (Left), 1st (Center/Top), 3rd (Right)
    List<Widget> podiumItems = [];

    // 2nd Place
    if (topThree.length >= 2) {
      podiumItems.add(_buildPodiumItem(context, topThree[1], 2));
    } else {
      podiumItems.add(const SizedBox(width: 100)); // Placeholder spacing
    }

    // 1st Place
    if (topThree.isNotEmpty) {
      podiumItems.add(_buildPodiumItem(context, topThree[0], 1));
    }

    // 3rd Place
    if (topThree.length >= 3) {
      podiumItems.add(_buildPodiumItem(context, topThree[2], 3));
    } else {
      podiumItems.add(const SizedBox(width: 100)); // Placeholder spacing
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: podiumItems,
    );
  }

  static Widget _buildPodiumItem(
    BuildContext context,
    QueryDocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final points = data['points'] ?? 0;
    final profileImage = data['profileImage'];

    // Podium styling based on rank
    double avatarSize = rank == 1 ? 48 : 36;
    // Height offset steps
    double heightOffset = rank == 1 ? 40 : (rank == 2 ? 16 : 0);

    Color color = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : const Color(0xFFCD7F32); // Bronze

    return Container(
      width: 100, // Fixed width for consistent centering
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Crown for 1st place
          if (rank == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 28,
              ),
            ),

          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((0.4 * 255).round()),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: avatarSize,
              backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                  ? NetworkImage(profileImage)
                  : null,
              backgroundColor: Colors.grey[200],
              child: (profileImage == null || profileImage.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: avatarSize * 0.8,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          // Points
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$points pts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),

          // Spacer for step effect
          SizedBox(height: heightOffset),
        ],
      ),
    );
  }

  static Widget _buildRankItem(
    BuildContext context,
    QueryDocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final points = data['points'] ?? 0;
    final profileImage = data['profileImage'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              (Theme.of(context).brightness == Brightness.dark
                      ? 0.3
                      : 0.1 * 255)
                  .round(),
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                  ? NetworkImage(profileImage)
                  : null,
              backgroundColor: Colors.blue[50],
              child: (profileImage == null || profileImage.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    )
                  : null,
            ),
          ],
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          '$points pts',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
