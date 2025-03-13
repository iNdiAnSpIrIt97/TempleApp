// lib/models/room.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String roomId;
  final String title;
  final String type;
  final String amount;
  final List<String> features;
  final int occupancy;
  final int totalRooms;

  Room({
    required this.roomId,
    required this.title,
    required this.type,
    required this.amount,
    required this.features,
    required this.occupancy,
    required this.totalRooms,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    print('Parsing room document: ${doc.id} - $data');
    return Room(
      roomId: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      amount: data['amount'] ?? '0',
      features: List<String>.from(data['features'] ?? []),
      occupancy: data['occupancy'] ?? 0,
      totalRooms: int.parse(data['total_rooms'] ?? '0'),
    );
  }
}
