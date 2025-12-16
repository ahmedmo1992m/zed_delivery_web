// في ملف RatingDialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatingDialog extends StatefulWidget {
  final String storeId;
  final String orderId;

  const RatingDialog({super.key, required this.storeId, required this.orderId});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اختر عدد النجوم أولاً.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // ✅ استخدام Transaction عشان نضمن تحديث البيانات بشكل سليم
      await firestore.runTransaction((transaction) async {
        final storeRef = firestore.collection('stores').doc(widget.storeId);
        final orderRef = firestore.collection('orders').doc(widget.orderId);

        final storeSnapshot = await transaction.get(storeRef);

        if (!storeSnapshot.exists) {
          throw Exception('المحل غير موجود.');
        }

        final storeData = storeSnapshot.data()!;

        // 🚀 التعديلات لضمان المرونة (الـRobustness):
        // 1. القراءة الآمنة للأرقام: بنستخدم (as num?) عشان نقبل int أو double
        // 2. بنستخدم (?? 0) عشان لو الحقل مش موجود، نعتبر قيمته صفر ونكمل حسابات

        // 💡 قراءة عدد النجوم الإجمالي (لو مش موجود نعتبره صفر)
        final currentTotalRating =
            (storeData['totalRating'] as num?)?.toInt() ?? 0;

        // 💡 قراءة عدد التقييمات (لو مش موجود نعتبره صفر)
        final currentRatingsCount =
            (storeData['ratingsCount'] as num?)?.toInt() ?? 0;

        // الحسابات هتتم دايماً بناءً على القيم اللي طلعناها (سواء كانت من Firestore أو صفر)
        final newTotalRating = currentTotalRating + _rating.toInt();
        final newRatingsCount = currentRatingsCount + 1;
        // بنستخدم (newRatingsCount > 0) لتجنب القسمة على صفر في حالة غير متوقعة
        final newAverageRating = newRatingsCount > 0
            ? newTotalRating / newRatingsCount
            : _rating;

        // تحديث بيانات المحل
        transaction.update(storeRef, {
          'totalRating': newTotalRating,
          'ratingsCount': newRatingsCount,
          'averageRating': newAverageRating,
        });

        // تحديث الأوردر (الكود ده أصلاً مرن لأنه بيكتب قيم جديدة ومش بيعتمد على قيم قديمة)
        transaction.update(orderRef, {
          'storeRating': _rating,
          // استخدام .text.trim() لضمان نص نظيف
          'storeReview': _reviewController.text.trim(),
        });
      });

      if (mounted) {
        Navigator.of(context).pop(); // قفل النافذة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً، تم تقييم الطلب بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التقييم: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'قيم المحل',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 40,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'اكتب تعليقك (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال التقييم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
