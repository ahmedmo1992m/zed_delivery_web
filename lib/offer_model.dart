// offer_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String storeId;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> details;

  OfferModel({
    required this.id,
    required this.storeId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.details,
  });

  // 💡 دالة تحويل من Firestore Document لـ OfferModel
  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      id: doc.id,
      storeId: data['store_id'] ?? '',
      title: data['title'] ?? 'عرض مميز',
      description: data['description'] ?? '',
      imageUrl: data['image_url'],
      // تحويل Timestamp لـ DateTime
      startDate: (data['start_date'] as Timestamp).toDate(),
      endDate: (data['end_date'] as Timestamp).toDate(),
      details: data['details'] as Map<String, dynamic>,
    );
  }
}
