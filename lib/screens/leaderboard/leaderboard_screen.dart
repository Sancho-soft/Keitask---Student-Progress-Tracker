import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .orderBy('points', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data?.docs ?? [];

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
                  child: _buildPodium(topThree),
                ),
              ),
              // The Rest of the List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final userDoc = rest[index];
                  final rank = index + 4; // 1-based, skipping top 3
                  return _buildRankItem(userDoc, rank);
                }, childCount: rest.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodium(List<QueryDocumentSnapshot> topThree) {
    if (topThree.isEmpty) return const SizedBox();

    // Reorder for visual podium: 2nd (Left), 1st (Center/Top), 3rd (Right)
    // If we have less than 3, we handle gracefully.
    List<Widget> podiumItems = [];

    // 2nd Place
    if (topThree.length >= 2) {
      podiumItems.add(_buildPodiumItem(topThree[1], 2));
    } else {
      podiumItems.add(const Expanded(child: SizedBox()));
    }

    // 1st Place
    if (topThree.isNotEmpty) {
      podiumItems.add(_buildPodiumItem(topThree[0], 1));
    }

    // 3rd Place
    if (topThree.length >= 3) {
      podiumItems.add(_buildPodiumItem(topThree[2], 3));
    } else {
      podiumItems.add(const Expanded(child: SizedBox()));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: podiumItems,
    );
  }

  Widget _buildPodiumItem(QueryDocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final points = data['points'] ?? 0;
    final profileImage = data['profileImage'];

    // Podium styling based on rank
    double avatarSize = rank == 1 ? 50 : 40;
    double heightOffset = rank == 1 ? 0 : (rank == 2 ? 20 : 40);
    Color color = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : const Color(0xFFCD7F32); // Bronze

    return Expanded(
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
                size: 32,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Points
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$points pts',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

          // Visual Podium Step
          SizedBox(height: 10 + heightOffset),
        ],
      ),
    );
  }

  Widget _buildRankItem(QueryDocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final points = data['points'] ?? 0;
    final profileImage = data['profileImage'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
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
