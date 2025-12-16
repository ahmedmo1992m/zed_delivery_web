const functions = require("firebase-functions/v1"); // 💡 تم التعديل
const crypto = require("crypto");
const admin = require("firebase-admin");

// تأكد من تهيئة Admin SDK
admin.initializeApp();
const db = admin.firestore();

// مفاتيح ImageKit
const IMAGEKIT_PRIVATE_KEY = "private_XVb2nRDWt1k6eOf1UB306WjwIoY=";
const IMAGEKIT_PUBLIC_KEY = "public_DdZaQNVPnIkcdTeeu+GlqFVn1hM=";

// 1️⃣ Function لتوليد Signature لـ ImageKit 
exports.getImageKitSignature = functions.https.onCall((data, context) => {
// ... باقي الكود زي ما هو
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = data.folder || "/stores_logos";
  const fileName = data.fileName || "temp_file.jpg";

  const signatureString = `folder=${folder}&fileName=${fileName}&timestamp=${timestamp}`;
  const signature = crypto
    .createHmac("sha1", IMAGEKIT_PRIVATE_KEY)
    .update(signatureString)
    .digest("hex");

  return {
    signature,
    timestamp,
    publicKey: IMAGEKIT_PUBLIC_KEY,
    folder,
    fileName,
  };
});


// 2️⃣ Function جديدة لإرسال الإشعارات عند وصول طلب جديد (FCM Function)
exports.onNewOrderCreated = functions.firestore
  .document("stores/{storeId}/orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    
    // ... باقي الكود زي ما هو
    const orderId = context.params.orderId;
    const storeId = context.params.storeId;
    
    const storeDoc = await db.collection("stores").doc(storeId).get();
    
    if (!storeDoc.exists) {
        console.log(`Store ${storeId} not found.`);
        return null;
    }
    
    const storeToken = storeDoc.data().fcmToken;
    const storeName = storeDoc.data().storeName || 'المتجر';
    
    if (!storeToken) {
        console.log(`FCM Token for Store ${storeId} is missing or empty.`);
        return null;
    }
    
    const payload = {
      notification: {
        title: `✅ طلب جديد من سابق: ${storeName}`,
        body: `وصلك طلب رقم #${orderId}. يرجى مراجعته فوراً.`,
        sound: "default", 
      },
      data: {
        type: 'new_order',
        orderId: orderId,
      }
    };
    
    try {
      const response = await admin.messaging().sendToDevice(storeToken, payload);
      console.log("Successfully sent message:", response);
    } catch (error) {
      console.error("Error sending message:", error);
    }
    
    return null;
  });