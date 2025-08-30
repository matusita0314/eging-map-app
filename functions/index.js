const functions = require("firebase-functions");
const { onDocumentCreated, onDocumentWritten, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const algoliasearch = require("algoliasearch");
const { defineString } = require("firebase-functions/params");
const { onCall } = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

const algoliaAppId = defineString("ALGOLIA_APP_ID");
const algoliaAdminKey = defineString("ALGOLIA_ADMIN_KEY");

// const algoliaClient = algoliasearch(algoliaAppId.value(), algoliaAdminKey.value());
// const algoliaIndex = algoliaClient.initIndex("posts");


const sharp = require("sharp");
const path = require("path");
const os = require("os");
const fs = require("fs");
const {onRequest} = require("firebase-functions/v2/https");

function initializeAlgolia() {
  if (algoliaAppId.value() && algoliaAdminKey.value()) {
    // この関数が呼び出された時点（＝実行時）で初めて .value() を使ってキーを読み込む
    const algoliaClient = algoliasearch(algoliaAppId.value(), algoliaAdminKey.value());
    return {
      postsIndex: algoliaClient.initIndex("posts"), 
      usersIndex: algoliaClient.initIndex("users"),
    };
  }
  console.log("Algolia App ID or Admin Key is not configured.");
  return {};
}

// =================================================================
// ▼▼▼ 汎用的な通知作成関数 (プッシュ通知送信機能付き) ▼▼▼
// =================================================================
async function createNotification(recipientId, notificationData) {
  console.log(`--- createNotification called for user: ${recipientId} ---`);

  const userRef = db.collection("users").doc(recipientId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    return console.log(`[Error] Recipient user ${recipientId} not found.`);
  }
  const userData = userSnap.data();

  await userRef.collection("notifications").add({
    ...notificationData,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });
  console.log(`In-app notification created for ${recipientId}, type: ${notificationData.type}`);

  // 2. 【条件付きで実行】ユーザーの設定をチェックしてプッシュ通知を送信する
  const settings = userData.notificationSettings || {};
  const shouldSendPush = settings[notificationData.type] !== false; // プッシュ通知を送信すべきか

  if (!shouldSendPush) {
    // ユーザーがプッシュ通知をOFFにしている場合は、ここで処理を終了
    return console.log(`User ${recipientId} has disabled PUSH notifications for type "${notificationData.type}". Skipping push notification.`);
  }

  const fcmTokens = userData.fcmTokens || [];
  if (fcmTokens.length === 0) {
    return console.log(`User ${recipientId} has no FCM tokens. Skipping push notification.`);
  }

  let title = "新しいお知らせ";
  let body = "投稿に新しいアクティビティがありました。";

  switch (notificationData.type) {
    case "likes":
      title = "投稿に「いいね」がありました！";
      body = `${notificationData.fromUserName}さんがあなたの投稿に「いいね」しました。`;
      break;
    case "comments":
      title = "新しいコメントがあります！";
      body = `${notificationData.fromUserName}さんがコメントしました: ${notificationData.commentText}`;
      break;
    case "saves":
      title = "投稿が保存されました！";
      body = `${notificationData.fromUserName}さんがあなたの投稿を保存しました。`;
      break;
    case "follow":
      title = "新しいフォロワーがいます！";
      body = `${notificationData.fromUserName}さんがあなたをフォローしました。`;
      break;
    case "dm":
      title = `${notificationData.fromUserName}さんから新着メッセージ`;
      body = notificationData.commentText;
      break;
  }

  const message = {
    tokens: fcmTokens,
    notification: { title, body },
    data: {
      postId: notificationData.postId || "",
      type: notificationData.type,
      fromUserId: notificationData.fromUserId || "",
      chatRoomId: notificationData.chatRoomId || "",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { notification: { sound: "default" } },
    apns: { payload: { aps: { sound: "default" } } },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log("Successfully sent message:", response);
  } catch (error) {
    console.error("Error sending message:", error);
  }
}


// =================================================================
// ▼▼▼ 1. チャレンジ達成時にランクアップを判定する関数 ▼▼▼
// =================================================================
exports.checkAndUpdateRank = onDocumentWritten({
  document: "users/{userId}/completed_challenges/{challengeId}",
  region: "asia-northeast1",
}, async (event) => {
  const userId = event.params.userId;
  const challengeSnap = await db.collection("challenges").doc(event.params.challengeId).get();
  if (!challengeSnap.exists) {
    console.log(`Challenge ${event.params.challengeId} not found.`);
    return null;
  }
  const challengeRank = challengeSnap.data().rank;

  const userRef = db.collection("users").doc(userId);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found.`);
    }
    const userData = userDoc.data();
    const currentRank = userData.rank;

    if (currentRank !== challengeRank) {
      console.log(`User rank (${currentRank}) does not match challenge rank (${challengeRank}). No rank update needed.`);
      return;
    }

    const rankInfo = userData.rankInfo || {};
    const completedCountField = `${currentRank}_completed_count`;
    const newCompletedCount = (rankInfo[completedCountField] || 0) + 1;
    const newRankInfo = { ...rankInfo, [completedCountField]: newCompletedCount };

    const TOTAL_MISSIONS = {
      beginner: 5,
      amateur: 10,
    };

    let newRank = currentRank;
    if (currentRank === "beginner" && newCompletedCount >= TOTAL_MISSIONS.beginner) {
      newRank = "amateur";
    } else if (currentRank === "amateur" && newCompletedCount >= TOTAL_MISSIONS.amateur) {
      newRank = "pro";
    }

    const updateData = { rankInfo: newRankInfo };
    if (newRank !== currentRank) {
      updateData.rank = newRank;
      // ここで rankForCurrentMonth は意図的に更新しない！
      console.log(`User ${userId} has been promoted to ${newRank}! Monthly rank will update on the 1st.`);
    }

    transaction.update(userRef, updateData);
  });
});

// =================================================================
// ▼▼▼ 毎月1日に「今月のランク」を更新する関数 ▼▼▼
// =================================================================
exports.updateMonthlyRankings = onSchedule({
  schedule: "0 0 1 * *", // 毎月1日の午前0時0分に実行
  timeZone: "Asia/Tokyo",
  region: "asia-northeast1",
}, async (event) => {
  console.log("Running monthly user rank update job.");
  const db = admin.firestore();
  const usersRef = db.collection("users");
  const snapshot = await usersRef.get();

  if (snapshot.empty) {
    console.log("No users found to update.");
    return null;
  }

  const batch = db.batch();
  let updatedCount = 0;

  snapshot.forEach(doc => {
    const userData = doc.data();
    // 現在のランクと今月のランクが異なるユーザーのみを対象
    if (userData.rank !== userData.rankForCurrentMonth) {
      batch.update(doc.ref, { rankForCurrentMonth: userData.rank });
      updatedCount++;
      console.log(`Updating monthly rank for user ${doc.id} to ${userData.rank}`);
    }
  });

  if (updatedCount > 0) {
    await batch.commit();
    console.log(`Successfully updated monthly rank for ${updatedCount} users.`);
  } else {
    console.log("No users needed a monthly rank update.");
  }

  return null;
});

// =================================================================
// ▼▼▼ 2. 投稿作成時のユーザー統計更新 ▼▼▼
// =================================================================
exports.updateUserStatsOnNewPost = onDocumentCreated({
  document: "posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const newPost = snap.data();
  const userId = newPost.userId;
  const postSize = newPost.squidSize;
  const userRef = db.collection('users').doc(userId);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw `User document with ID ${userId} not found!`;
    }
    const userData = userDoc.data();
    const currentTotalCatches = userData.totalCatches || 0;
    const currentMaxSize = userData.maxSize || 0;

    return transaction.update(userRef, {
      totalCatches: currentTotalCatches + 1,
      maxSize: Math.max(currentMaxSize, postSize),
    });
  });
});

// =================================================================
// ▼▼▼ 3. 投稿作成時のミッション達成チェック ▼▼▼
// =================================================================
exports.checkAndCompleteMissionsOnNewPost = onDocumentCreated({
  document: "posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const snap = event.data;
  if (!snap) { return; }

  const postData = snap.data();
  const userId = postData.userId;
  const userRef = db.collection("users").doc(userId);

  const userDoc = await userRef.get();
  if (!userDoc.exists) { return; }
  const userData = userDoc.data();
  const totalCatches = userData.totalCatches || 0;
  const maxSize = userData.maxSize || 0;

  const challengesRef = db.collection("challenges");
  const completedChallengesRef = userRef.collection("completed_challenges");
  const [allChallengesSnap, completedChallengesSnap] = await Promise.all([
    challengesRef.get(),
    completedChallengesRef.get(),
  ]);
  const completedChallengeIds = new Set(completedChallengesSnap.docs.map((doc) => doc.id));
  const uncompletedMissions = allChallengesSnap.docs.filter((doc) => !completedChallengeIds.has(doc.id));

  const batch = db.batch();
  let missionsCompleted = false;

  for (const missionDoc of uncompletedMissions) {
    const mission = missionDoc.data();
    let isAchieved = false;

    if (mission.type === "totalCatches" && totalCatches >= mission.threshold) {
      isAchieved = true;
    } else if (mission.type === "maxSize" && maxSize >= mission.threshold) {
      isAchieved = true;
    }

    if (isAchieved) {
      const newCompletionRef = completedChallengesRef.doc(missionDoc.id);
      batch.set(newCompletionRef, { achievedAt: new Date() });
      missionsCompleted = true;
      console.log(`User ${userId} completed mission: ${missionDoc.id}`);
    }
  }

  if (missionsCompleted) {
    await batch.commit();
  }
});


// =================================================================
// ▼▼▼ 4. プロフィール更新時に過去の投稿データを更新する関数 ▼▼▼
// =================================================================
exports.updatePostsOnProfileChange = onDocumentUpdated({
  document: "users/{userId}",
  region: "asia-northeast1",
}, async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userId = event.params.userId;

  const nameChanged = beforeData.displayName !== afterData.displayName;
  const photoChanged = beforeData.photoUrl !== afterData.photoUrl;

  if (!nameChanged && !photoChanged) {
    console.log(`User ${userId}: No change in displayName or photoUrl.`);
    return null;
  }

  const updatePayload = {};
  if (nameChanged) {
    updatePayload.userName = afterData.displayName;
  }
  if (photoChanged) {
    updatePayload.userPhotoUrl = afterData.photoUrl;
  }

  const postsQuery = db.collection("posts").where("userId", "==", userId);
  const postsSnapshot = await postsQuery.get();

  if (postsSnapshot.empty) {
    console.log(`User ${userId} has no posts to update.`);
    return null;
  }

  const batch = db.batch();
  postsSnapshot.forEach((doc) => {
    batch.update(doc.ref, updatePayload);
  });

  console.log(`Updating ${postsSnapshot.size} posts for user ${userId}.`);
  return batch.commit();
});


// =================================================================
// ▼▼▼ 5. サムネイル生成の関数 ▼▼▼
// =================================================================
exports.generateThumbnail = onObjectFinalized({ cpu: 2, region: "asia-northeast1", memory: "1GiB" }, async (event) => {
  const fileBucket = event.data.bucket;
  const filePath = event.data.name;
  const contentType = event.data.contentType;

  if (!contentType.startsWith("image/")) return console.log("This is not an image.");
  if (!filePath.startsWith("posts/")) return console.log("This is not a post image.");

  const originalFileName = path.basename(filePath);
  if (originalFileName.startsWith("thumb_")) return console.log("This is already a thumbnail.");

  const bucket = storage.bucket(fileBucket);
  const postId = path.parse(originalFileName).name.split('_')[0];
  if (!postId) return console.log(`Could not extract postId from filename: ${originalFileName}`);

  const tempFilePath = path.join(os.tmpdir(), originalFileName);
  const thumbFileName = `thumb_${originalFileName}`;
  const thumbTempFilePath = path.join(os.tmpdir(), thumbFileName);

  try {
    await bucket.file(filePath).download({ destination: tempFilePath });
    await sharp(tempFilePath).resize(400, 400, { fit: "inside" }).toFile(thumbTempFilePath);

    const thumbStoragePath = path.join(path.dirname(filePath), 'thumbnails', thumbFileName);
    await bucket.upload(thumbTempFilePath, {
      destination: thumbStoragePath,
      metadata: { contentType: "image/jpeg" },
    });

    fs.unlinkSync(tempFilePath);
    fs.unlinkSync(thumbTempFilePath);

    const expires = '03-09-2491';
    const originalUrl = await bucket.file(filePath).getSignedUrl({ action: 'read', expires }).then(urls => urls[0]);
    const thumbUrl = await bucket.file(thumbStoragePath).getSignedUrl({ action: 'read', expires }).then(urls => urls[0]);

    await db.collection("posts").doc(postId).update({
      imageUrls: admin.firestore.FieldValue.arrayUnion(originalUrl),
      thumbnailUrls: admin.firestore.FieldValue.arrayUnion(thumbUrl),
    });

    console.log(`Successfully generated thumbnail for ${originalFileName} and updated Firestore doc ${postId}.`);
  } catch (error) {
    console.error("Error in generateThumbnail:", error);
  }
});




// =================================================================
// ▼▼▼ 6. 投稿が削除されたときにユーザーの統計情報を更新する関数 ▼▼▼
// =================================================================
exports.updateUserStatsOnPostDelete = onDocumentDeleted({
  document: "posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const deletedPost = event.data.data();
  if (!deletedPost) {
    console.log("No data associated with the event.");
    return null;
  }

  const userId = deletedPost.userId;
  const deletedSize = deletedPost.squidSize || 0;
  const userRef = db.collection("users").doc(userId);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      console.log(`User ${userId} not found, cannot update stats.`);
      return;
    }
    
    const userData = userDoc.data();
    const currentTotalCatches = userData.totalCatches || 0;
    const currentMaxSize = userData.maxSize || 0;

    // 1. 総釣果数を1減らす
    const newTotalCatches = currentTotalCatches > 0 ? currentTotalCatches - 1 : 0;
    let newMaxSize = currentMaxSize;

    // 2. 削除された投稿が最大サイズだった場合のみ、最大サイズを再計算
    if (deletedSize >= currentMaxSize) {
      console.log(`Max size post deleted for user ${userId}. Recalculating max size...`);
      
      const postsRef = db.collection("posts");
      const userPostsQuery = postsRef
        .where("userId", "==", userId)
        .orderBy("squidSize", "desc")
        .limit(1);
        
      const postsSnapshot = await userPostsQuery.get();
      
      if (postsSnapshot.empty) {
        // 残りの投稿がなければ最大サイズは0
        newMaxSize = 0;
      } else {
        // 残りの投稿の中で一番大きいサイズを新しい最大サイズとする
        newMaxSize = postsSnapshot.docs[0].data().squidSize || 0;
      }
      console.log(`New max size for user ${userId} is ${newMaxSize}.`);
    }

    // 3. ユーザー情報を更新
    transaction.update(userRef, {
      totalCatches: newTotalCatches,
      maxSize: newMaxSize,
    });
  });
});

// =================================================================
// ▼▼▼ 7. いいねされた時に通知を作成する関数 ▼▼▼
// =================================================================
exports.createNotificationOnLike = onDocumentCreated({
  document: "users/{likerId}/liked_posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  console.log(`🔥 createNotificationOnLike triggered! likerId: ${event.params.likerId}, postId: ${event.params.postId}`);
  const postId = event.params.postId;
  const likerId = event.params.likerId;

  const postSnap = await db.collection("posts").doc(postId).get();
  if (!postSnap.exists) return;

  const postData = postSnap.data();
  const postAuthorId = postData.userId;

  if (postAuthorId === likerId) return;

  const likerSnap = await db.collection("users").doc(likerId).get();
  if (!likerSnap.exists) return;
  const likerName = likerSnap.data().displayName || "名無しさん";

  const thumbnailUrl = (postData.thumbnailUrls && postData.thumbnailUrls.length > 0)
  ? postData.thumbnailUrls[0]
  : ((postData.imageUrls && postData.imageUrls.length > 0) ? postData.imageUrls[0] : "");

  return createNotification(postAuthorId, {
    type: "likes",
    fromUserName: likerName,
    fromUserId: likerId,
    postId: postId,
    postThumbnailUrl: thumbnailUrl,
  });
});

// =================================================================
// ▼▼▼ 8. コメントされた時に通知を作成する関数 ▼▼▼
// =================================================================
exports.createNotificationOnComment = onDocumentCreated({
  document: "posts/{postId}/comments/{commentId}",
  region: "asia-northeast1",
}, async (event) => {
  const postId = event.params.postId;
  const commentData = event.data.data();
  const commenterId = commentData.userId;

  const postSnap = await db.collection("posts").doc(postId).get();
  if (!postSnap.exists) return;

  const postData = postSnap.data();
  const postAuthorId = postData.userId;

  if (postAuthorId === commenterId) return;

  const thumbnailUrl = (postData.thumbnailUrls && postData.thumbnailUrls.length > 0)
    ? postData.thumbnailUrls[0]
    : ((postData.imageUrls && postData.imageUrls.length > 0) ? postData.imageUrls[0] : "");

  return createNotification(postAuthorId, {
    type: "comments",
    fromUserName: commentData.userName,
    fromUserId: commenterId,
    postId: postId,
    postThumbnailUrl: thumbnailUrl,
    commentText: commentData.text,
  });
});


// =================================================================
// ▼▼▼ 9. 保存された時に通知を作成する関数 ▼▼▼
// =================================================================
exports.createNotificationOnSave = onDocumentCreated({
  document: "users/{userId}/saved_posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const userId = event.params.userId;
  const postId = event.params.postId;

  const postSnap = await db.collection("posts").doc(postId).get();
  if (!postSnap.exists) return;

  const postData = postSnap.data();
  const postAuthorId = postData.userId;

  if (postAuthorId === userId) return;

  const saverSnap = await db.collection("users").doc(userId).get();
  if (!saverSnap.exists) return;
  const saverName = saverSnap.data().displayName || "名無しさん";

  const thumbnailUrl = (postData.thumbnailUrls && postData.thumbnailUrls.length > 0)
    ? postData.thumbnailUrls[0]
    : ((postData.imageUrls && postData.imageUrls.length > 0) ? postData.imageUrls[0] : "");

  return createNotification(postAuthorId, {
    type: "saves",
    fromUserName: saverName,
    fromUserId: userId,
    postId: postId,
    postThumbnailUrl: thumbnailUrl,
  });
});

// =================================================================
// ▼▼▼ 10. フォローされた時に通知を作成する関数 ▼▼▼
// =================================================================
exports.createNotificationOnFollow = onDocumentCreated({
  document: "users/{followedId}/followers/{followerId}",
  region: "asia-northeast1",
}, async (event) => {
  const followedId = event.params.followedId; // フォローされた人
  const followerId = event.params.followerId; // フォローした人

  // 自分自身をフォローした場合は通知しない
  if (followedId === followerId) {
    return console.log("User followed themselves, no notification needed.");
  }

  // フォローした人の情報を取得
  const followerSnap = await db.collection("users").doc(followerId).get();
  if (!followerSnap.exists) {
    return console.log(`Follower user ${followerId} not found.`);
  }
  const followerName = followerSnap.data().displayName || "名無しさん";

  // createNotification関数を呼び出して通知を作成
  return createNotification(followedId, {
    type: "follow", // 通知タイプ
    fromUserName: followerName,
    fromUserId: followerId,
    // フォロー通知には特定の投稿がないので、postIdなどは空にするか含めない
    postId: "",
    postThumbnailUrl: "", // フォロワーのアイコンを表示しても良い
  });
});

// =================================================================
// ▼▼▼ 11. DM受信時に通知を作成する関数 ▼▼▼
// =================================================================
exports.createNotificationOnNewMessage = onDocumentCreated({
  document: "chat_rooms/{chatRoomId}/messages/{messageId}",
  region: "asia-northeast1",
}, async (event) => {
  const chatRoomId = event.params.chatRoomId;
  const messageData = event.data.data();
  const senderId = messageData.senderId;

  // チャットルームの情報を取得して、参加メンバーを取得
  const chatRoomSnap = await db.collection("chat_rooms").doc(chatRoomId).get();
  if (!chatRoomSnap.exists) return;

  const chatRoomData = chatRoomSnap.data();
  const userIds = chatRoomData.userIds || [];

  // 送信者以外の全メンバーに通知を送る
  const recipients = userIds.filter((id) => id !== senderId);
  
  for (const recipientId of recipients) {
    // 汎用通知作成関数を呼び出す
    await createNotification(recipientId, {
      type: "dm",
      fromUserName: messageData.senderName,
      fromUserId: senderId,
      chatRoomId: chatRoomId,
      commentText: messageData.text, // メッセージ本文を通知内容にする
    });
  }
});

// =================================================================
// ▼▼▼ 12. ユーザー情報をAlgoliaに同期する関数 ▼▼▼
// =================================================================
exports.syncUserToAlgolia = onDocumentWritten({ document: "users/{userId}", region: "asia-northeast1" }, async (event) => {
  const { usersIndex } = initializeAlgolia();
  if (!usersIndex) return console.log("Algolia (users) not configured, skipping sync");

  const userId = event.params.userId;
  if (!event.data.after.exists) {
    await usersIndex.deleteObject(userId);
    return console.log(`Algolia user record deleted for userId: ${userId}`);
  }

  const userData = event.data.after.data();
  const record = {
    objectID: userId,
    displayName: userData.displayName,
    photoUrl: userData.photoUrl,
  };
  await usersIndex.saveObject(record);
  console.log(`Algolia user record saved for userId: ${userId}`);
});
// =================================================================
// ▼▼▼ 13. 投稿をAlgoliaに同期する関数（デバッグコード入り） ▼▼▼
// =================================================================
exports.syncPostToAlgolia = onDocumentWritten({ document: "posts/{postId}", region: "asia-northeast1" }, async (event) => {
  const { postsIndex } = initializeAlgolia();
  if (!postsIndex) {
    console.log("Algolia (posts) not configured, skipping sync");
    return null;
  }

  const postId = event.params.postId;

  // 削除処理
  if (!event.data.after.exists) {
    try {
      await postsIndex.deleteObject(postId);
      console.log(`Algolia record deleted for postId: ${postId}`);
    } catch (error) {
      console.error(`Error deleting Algolia record for postId ${postId}:`, error);
    }
    return null;
  }

  // 作成・更新処理
  const postData = event.data.after.data();

  // ★★★ createdAt と location が存在しない場合はエラーを防ぐ ★★★
  if (!postData.createdAt || !postData.location) {
      console.log(`Missing required fields (createdAt or location) for postId: ${postId}. Skipping sync.`);
      return null;
  }

  const record = {
    objectID: postId,
    userId: postData.userId,
    userName: postData.userName,
    userPhotoUrl: postData.userPhotoUrl,
    imageUrls: postData.imageUrls || [],
    thumbnailUrls: postData.thumbnailUrls || [],
    createdAt: postData.createdAt.toDate().getTime(),
    location: { // _geolocはAlgoliaの予約語なので、locationオブジェクトの中に含める
      lat: postData.location.latitude,
      lng: postData.location.longitude,
    },
    _geoloc: { // 地理空間検索のためにルートレベルにも配置
      lat: postData.location.latitude,
      lng: postData.location.longitude,
    },
    weather: postData.weather,
    airTemperature: postData.airTemperature,
    waterTemperature: postData.waterTemperature,
    caption: postData.caption,
    squidSize: postData.squidSize,
    weight: postData.weight,
    egiName: postData.egiName,
    egiMaker: postData.egiMaker,
    tackleRod: postData.tackleRod,
    tackleReel: postData.tackleReel,
    tackleLine: postData.tackleLine,
    likeCount: postData.likeCount || 0,
    commentCount: postData.commentCount || 0,
    squidType: postData.squidType,
    region: postData.region,
    timeOfDay: postData.timeOfDay,
  };

  try {
    await postsIndex.saveObject(record);
    console.log(`Algolia record saved for postId: ${postId}`);
  } catch (error) {
    console.error(`Error saving Algolia record for postId ${postId}:`, error);
  }

});

// =================================================================
// ▼▼▼ 14.大会投稿の判定結果に基づきランキングを更新する関数 ▼▼▼
// =================================================================
exports.updateRankingOnJudge = onDocumentUpdated({
  document: "tournaments/{tournamentId}/posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();

  // "status"が"approved"に変更された時だけ実行する
  if (beforeData.status === afterData.status || afterData.status !== "approved") {
    console.log(`Status not changed to 'approved' or status is unchanged. Exiting.`);
    return null;
  }

  const tournamentId = event.params.tournamentId;
  const userId = afterData.userId;
  const judgedSize = afterData.judgedSize;

  if (!userId || typeof judgedSize !== "number") {
    console.error(`Missing userId or invalid judgedSize for post ${event.params.postId}.`);
    return null;
  }
  
  const score = judgedSize;

  const rankingRef = db.collection("tournaments").doc(tournamentId).collection("rankings").doc(userId);

  return db.runTransaction(async (transaction) => {
    const rankingDoc = await transaction.get(rankingRef);

    if (!rankingDoc.exists) {
      console.log(`Creating new ranking document for user ${userId}.`);

      const userRef = db.collection("users").doc(userId);
      const userSnap = await transaction.get(userRef);
      const userData = userSnap.exists ? userSnap.data() : {};

      transaction.set(rankingRef, {
        userName: userData.displayName || "名無しさん", 
        userPhotoUrl: userData.photoUrl || "",       
        totalScore: score,
        maxSize: judgedSize,
        catchCount: 1,
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // 既存のランキングデータを更新
      console.log(`Updating ranking document for user ${userId}.`);
      const currentData = rankingDoc.data();
      transaction.update(rankingRef, {
        totalScore: admin.firestore.FieldValue.increment(score),
        maxSize: Math.max(currentData.maxSize || 0, judgedSize),
        catchCount: admin.firestore.FieldValue.increment(1),
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
});

// =================================================================
// ▼▼▼ 15.【新規追加】ユーザーのスコアをルールに基づき再計算する中心関数 ▼▼▼
// =================================================================
async function recalculateUserScore(tournamentId, userId) {
  console.log(`Recalculating score for user ${userId} in tournament ${tournamentId}`);
  
  const tournamentRef = db.collection("tournaments").doc(tournamentId);
  const tournamentSnap = await tournamentRef.get();
  if (!tournamentSnap.exists) {
    console.error(`Tournament ${tournamentId} not found.`);
    return;
  }
  const tournamentRule = tournamentSnap.data().rule;

  // ユーザーの承認済み投稿をすべて取得
  const postsQuery = tournamentRef.collection("posts")
    .where("userId", "==", userId)
    .where("status", "==", "approved");
  const postsSnapshot = await postsQuery.get();

  let newScore = 0;
  if (!postsSnapshot.empty) {
    // ルールに応じてスコアを計算
    if (tournamentRule.metric === 'SIZE') {
      // サイズ大会の場合：一番大きいjudgedSizeがスコアになる
      let maxSize = 0;
      postsSnapshot.forEach(doc => {
        const postSize = doc.data().judgedSize || 0;
        if (postSize > maxSize) {
          maxSize = postSize;
        }
      });
      newScore = maxSize;
    } else if (tournamentRule.metric === 'COUNT') {
      // 匹数大会の場合：judgedCountの合計がスコアになる
      let totalCount = 0;
      postsSnapshot.forEach(doc => {
        totalCount += doc.data().judgedCount || 0;
      });
      newScore = totalCount;
    }
  }

  const userSnap = await db.collection("users").doc(userId).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  const userName = userData.displayName || "名無しさん";
  const userPhotoUrl = userData.photoUrl || "";

  // 2. rankingsとentriesへの参照を準備
  const rankingRef = tournamentRef.collection("rankings").doc(userId);
  const entryRef = tournamentRef.collection("entries").doc(userId);

  await Promise.all([
    // rankingsにはスコアとプロフィール情報を書き込む
    rankingRef.set({
      score: newScore,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
    }, { merge: true }),
    
    // entriesにはスコアを書き込む
    entryRef.set({
      currentScore: newScore,
    }, { merge: true }),
  ]);
  console.log(`Score for user ${userId} updated to: ${newScore}`);
}


// =================================================================
// ▼▼▼ 16. ランキング順位を振り直す内部関数（修正） ▼▼▼
// =================================================================
async function _internalReorderRanks(tournamentId) {
  console.log(`--- Reordering ranks for tournament: ${tournamentId} ---`);

  const rankingsRef = db.collection("tournaments").doc(tournamentId).collection("rankings");
  const rankingsQuery = rankingsRef.orderBy("score", "desc"); // スコアの高い順
  const rankingsSnapshot = await rankingsQuery.get();

  if (rankingsSnapshot.empty) {
    console.log(`No rankings to reorder for tournament: ${tournamentId}`);
    return 0;
  }

  const batch = db.batch();
  let rank = 1;
  rankingsSnapshot.forEach(doc => {
    batch.update(doc.ref, { rank: rank });
    const entryRef = db.collection("tournaments").doc(tournamentId).collection("entries").doc(doc.id);
    batch.update(entryRef, { currentRank: rank });
    rank++;
  });

  await batch.commit();
  await db.collection("tournaments").doc(tournamentId).update({ lastRankingUpdate: admin.firestore.FieldValue.serverTimestamp() });

  console.log(`Successfully reordered ${rankingsSnapshot.size} ranks for tournament ${tournamentId}.`);
  return rankingsSnapshot.size;
}


// =================================================================
// ▼▼▼ 17. 大会投稿が承認された時の処理（修正） ▼▼▼
// =================================================================
exports.updateScoreOnApproval = onDocumentUpdated({
  document: "tournaments/{tournamentId}/posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // 承認された時だけ実行
  if (before.status !== "pending" || after.status !== "approved") {
    return null;
  }

  const tournamentId = event.params.tournamentId;
  const userId = after.userId;

  // 1. 投稿者のスコアを再計算
  await recalculateUserScore(tournamentId, userId);
  
  // 2. ランキング全体を再計算（順位を振り直す）
  await _internalReorderRanks(tournamentId);

  return null;
});


// =================================================================
// ▼▼▼ 18. 大会投稿が削除された時の処理（修正）▼▼▼
// =================================================================
exports.onTournamentPostDeleted = onDocumentDeleted({
    document: "tournaments/{tournamentId}/posts/{postId}",
    region: "asia-northeast1",
}, async (event) => {
    const deletedPost = event.data.data();
    if (!deletedPost) return null;
    
    const tournamentId = event.params.tournamentId;
    const userId = deletedPost.userId;
    
    // 1. 投稿者のスコアを再計算
    await recalculateUserScore(tournamentId, userId);
    
    // 2. ランキング全体を再計算（順位を振り直す）
    await _internalReorderRanks(tournamentId);
    
    return null;
});


// =================================================================
// ▼▼▼ 19. 【重要】手動でランキングを再計算する関数（大幅修正）▼▼▼
// =================================================================
exports.recalculateRankingsManually = onCall({
  region: "asia-northeast1",
  memory: "512MiB"
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "この操作を行うには認証が必要です。");
  }

  const tournamentId = request.data.tournamentId;
  if (!tournamentId) {
    throw new functions.https.HttpsError("invalid-argument", "tournamentId が指定されていません。");
  }

  console.log(`--- Manual ranking recalculation requested for tournament: ${tournamentId} ---`);
  
  // 1. 大会参加者全員のリストを取得
  const entriesSnapshot = await db.collection("tournaments").doc(tournamentId).collection("entries").get();
  if (entriesSnapshot.empty) {
    return { message: "ランキング対象の参加者がいません。", count: 0 };
  }
  
  // 2. 全参加者のスコアを順番に再計算
  for (const entryDoc of entriesSnapshot.docs) {
    const userId = entryDoc.id;
    await recalculateUserScore(tournamentId, userId);
  }
  
  // 3. 全員のスコア計算が終わったら、最後に順位を振り直す
  const count = await _internalReorderRanks(tournamentId);

  const successMessage = `ランキングの集計が完了しました。${count}人の順位が更新されました。`;
  console.log(successMessage);
  return { message: successMessage, count: count };
});

// =================================================================
// ▼▼▼ 20.サブ大会のいいねの合計とランキングを計算する関数 ▼▼▼
// =================================================================
exports.updateLikeCountRankings = onSchedule({
    schedule: "0 6,8,10,12,14,16,18,20,22 * * *",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
}, async (event) => {
    console.log("--- Running scheduled like count ranking update ---");

    const now = admin.firestore.Timestamp.now();
    const activeTournamentsQuery = db.collection("tournaments")
      .where("endDate", ">", now)
      .where("rule.judgingType", "==", "ALGORITHMIC")
      .where("rule.metric", "==", "LIKE_COUNT");

    const tournamentsSnapshot = await activeTournamentsQuery.get();

    if (tournamentsSnapshot.empty) {
      console.log("No active like-based tournaments found.");
      return null;
    }

    for (const tournamentDoc of tournamentsSnapshot.docs) {
      const tournamentId = tournamentDoc.id;
      const tournamentData = tournamentDoc.data();
      const rule = tournamentData.rule;
      console.log(`Processing tournament: ${tournamentData.name} (${tournamentId})`);

      const postsSnapshot = await db.collection("tournaments").doc(tournamentId).collection("posts").where("status", "==", "approved").get();

      if (postsSnapshot.empty) {
        console.log(`No posts found for tournament ${tournamentId}. Skipping.`);
        continue;
      }

      const userScores = new Map();
      postsSnapshot.forEach(postDoc => {
        const postData = postDoc.data();
        const userId = postData.userId;
        const likeCount = postData.likeCount || 0;
        
        if (!userScores.has(userId)) {
          userScores.set(userId, { 
            score: 0,
            userName: postData.userName,
            userPhotoUrl: postData.userPhotoUrl,
          });
        }
        
        if (rule.rankingMetric === 'SUM_VALUE') {
          userScores.get(userId).score += likeCount;
        } else {
          if (likeCount > userScores.get(userId).score) {
            userScores.get(userId).score = likeCount;
          }
        }
      });
      
      const batch = db.batch();
      userScores.forEach((data, userId) => {
        const rankingRef = db.collection("tournaments").doc(tournamentId).collection("rankings").doc(userId);
        batch.set(rankingRef, {
          userId: userId,
          userName: data.userName,
          userPhotoUrl: data.userPhotoUrl,
          score: data.score,
          lastUpdated: now,
        }, { merge: true });
      });

      await batch.commit();
      console.log(`Updated ${userScores.size} user rankings for tournament ${tournamentId}.`);

      try {
         // ★★★ 修正点: 新しい内部関数を呼び出す ★★★
         await _internalRecalculateRankings(tournamentId);
      } catch(error) {
         console.error(`Error recalculating ranks for ${tournamentId}:`, error);
      }
    }
    return null;
});

// =================================================================
// ▼▼▼ 21.管理者による手動での景品付与関数 (称号のみ) ▼▼▼
// =================================================================
exports.awardPrizesManually = onCall({ region: "asia-northeast1" }, async (request) => {
  // 1. 認証チェック
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "認証が必要です。");
  }
  // TODO: 本番環境では、カスタムクレーム等で管理者かどうかをチェックしてください

  const { tournamentId, winners } = request.data;
  if (!tournamentId || !winners) {
    throw new functions.https.HttpsError("invalid-argument", "必要なデータ（tournamentId, winners）が不足しています。");
  }

  const db = admin.firestore();
  const tournamentRef = db.collection("tournaments").doc(tournamentId);

  try {
    const tournamentDoc = await tournamentRef.get();
    if (!tournamentDoc.exists) {
      throw new functions.https.HttpsError("not-found", "対象の大会が見つかりません。");
    }
    const tournamentData = tournamentDoc.data();
    if (tournamentData.prizesAwarded) {
      throw new functions.https.HttpsError("failed-precondition", "この大会の賞品は授与済みです。");
    }
    if (!tournamentData.prizes) {
      throw new functions.https.HttpsError("failed-precondition", "この大会に賞品が設定されていません。");
    }
    
    const prizes = tournamentData.prizes;
    const batch = db.batch();

    // 2. winnersオブジェクトをループして、各ユーザーに称号を付与
    for (const rank in winners) { // rank は '1', '2', '3'
      const userId = winners[rank];
      const prizeForRank = prizes[`rank${rank}`];

      if (userId && prizeForRank && prizeForRank.title) {
          const newTitleAwardRef = db.collection("users").doc(userId).collection("awardedTitles").doc();
          batch.set(newTitleAwardRef, {
            title: prizeForRank.title,
            awardedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }

    // 3. 授与済みフラグを更新
    batch.update(tournamentRef, { prizesAwarded: true , status: 'finished' });

    await batch.commit();

    return { success: true, message: "称号の授与が完了しました。" };
  } catch (error) {
    console.error("手動での賞品授与エラー:", error);
    throw new functions.https.HttpsError("internal", "サーバーエラーが発生しました。");
  }
});

// =================================================================
// ▼▼▼ 22.毎日定時に大会ステータスを更新する関数 ▼▼▼
// =================================================================
exports.updateTournamentStatus = onSchedule({
  schedule: "24 15 * * *", // 毎日午後2時54分に実行
  timeZone: "Asia/Tokyo",
  region: "asia-northeast1",
}, async (event) => {
  console.log("Running scheduled tournament status update.");
  const db = admin.firestore();
  const now = new Date();
  
  // 今日の日付の開始と終了をTimestampで表現
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

  const tournamentsRef = db.collection("tournaments");

  // --- 開始日を迎えた大会を 'pending' から 'ongoing' に更新 ---
  const pendingTournamentsQuery = tournamentsRef
    .where("status", "==", "pending")
    .where("startDate", ">=", todayStart)
    .where("startDate", "<", todayEnd);

  const pendingSnapshot = await pendingTournamentsQuery.get();

  if (pendingSnapshot.empty) {
    console.log("No pending tournaments to start today.");
  } else {
    const batch = db.batch();
    pendingSnapshot.forEach(doc => {
      console.log(`Starting tournament: ${doc.id} - ${doc.data().name}`);
      batch.update(doc.ref, { status: "ongoing" });
    });
    await batch.commit();
    console.log(`Successfully started ${pendingSnapshot.size} tournaments.`);
  }

  // --- 終了日を過ぎた大会を 'ongoing' から 'judging' に更新 ---
  const ongoingTournamentsQuery = tournamentsRef
    .where("status", "==", "ongoing")
    .where("endDate", "<", now);

  const ongoingSnapshot = await ongoingTournamentsQuery.get();
  
  if (ongoingSnapshot.empty) {
    console.log("No ongoing tournaments to move to judging status.");
  } else {
    const batch = db.batch();
    ongoingSnapshot.forEach(doc => {
      // prizesAwardedに関係なく、ステータスを'judging'に変更する
      console.log(`Moving tournament to judging status: ${doc.id}`);
      batch.update(doc.ref, { status: "judging" }); 
    });
    await batch.commit();
    console.log(`Successfully moved ${ongoingSnapshot.size} tournaments to judging status.`);
  }

  return null;
});
