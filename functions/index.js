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
      console.log(`User ${userId} has been promoted to ${newRank}!`);
    }

    transaction.update(userRef, updateData);
  });
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
  const userRef = db.collection("users").doc(userId);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      console.log(`User ${userId} not found, cannot decrement stats.`);
      return;
    }
    
    const currentTotalCatches = userDoc.data().totalCatches || 0;
    if (currentTotalCatches > 0) {
      transaction.update(userRef, {
        totalCatches: admin.firestore.FieldValue.increment(-1),
      });
    }
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
// ▼▼▼ 15.ユーザーのスコアを再計算する共通関数 ▼▼▼
// =================================================================
async function _internalRecalculateRankings(tournamentId) {
  console.log(`--- Internal ranking calculation started for tournament: ${tournamentId} ---`);

  const tournamentDoc = await db.collection("tournaments").doc(tournamentId).get();
  if (!tournamentDoc.exists) {
    // この関数は内部呼び出しなので、HttpsErrorではなく通常のErrorを投げるか、ログ出力に留める
    console.error(`Tournament with ID ${tournamentId} not found.`);
    return { success: false, message: "指定された大会が見つかりません。" };
  }

  const rankingsRef = tournamentDoc.ref.collection("rankings");
  // scoreの降順で並び替え
  const rankingsQuery = rankingsRef.orderBy("score", "desc");
  const rankingsSnapshot = await rankingsQuery.get();

  if (rankingsSnapshot.empty) {
    console.log(`No rankings to update for tournament: ${tournamentId}`);
    return { success: true, message: "ランキング対象のユーザーがいません。", count: 0 };
  }

  const batch = db.batch();
  let rank = 1;

  for (const userRankingDoc of rankingsSnapshot.docs) {
    const userId = userRankingDoc.id;
    const entryRef = tournamentDoc.ref.collection("entries").doc(userId);
    // userRankingDocとentryRefの両方に順位を書き込む
    batch.update(userRankingDoc.ref, { rank: rank });
    batch.update(entryRef, { currentRank: rank });
    rank++;
  }

  await batch.commit();
  // 大会ドキュメントに最終更新日時を記録
  await tournamentDoc.ref.update({ lastRankingUpdate: admin.firestore.FieldValue.serverTimestamp() });

  const successMessage = `Successfully updated ${rankingsSnapshot.size} rankings for tournament: ${tournamentId}`;
  console.log(successMessage);
  return { success: true, message: successMessage, count: rankingsSnapshot.size };
}


// =================================================================
// ▼▼▼ 16.大会への新規投稿時に、投稿制限を処理する関数 ▼▼▼
// =================================================================
exports.updateScoreOnApproval = onDocumentUpdated({
  document: "tournaments/{tournamentId}/posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status !== "pending" || after.status !== "approved") {
    return null;
  }

  // 承認されたユーザーのスコアを再計算
  await recalculateUserScore(event.params.tournamentId, after.userId);

  // ランキング全体を再計算（順位を振り直す）
  try {
    // ▼▼▼【修正】新しい内部関数を直接呼び出す ▼▼▼
    await _internalRecalculateRankings(event.params.tournamentId);
 } catch(error) {
  console.error(`Error recalculating ranks for ${event.params.tournamentId}:`, error);
 }

  return null;
});



// =================================================================
// ▼▼▼ 17.投稿が削除されたときにスコアを再計算する関数  ▼▼▼
// =================================================================
exports.onTournamentPostDeleted = onDocumentDeleted({
    document: "tournaments/{tournamentId}/posts/{postId}",
    region: "asia-northeast1",
}, async (event) => {
    const deletedPost = event.data.data();
    if (!deletedPost) return null;

    console.log(`Post deleted for user ${deletedPost.userId}. Recalculating score.`);
    
    // 投稿者のスコアを再計算
    await recalculateUserScore(event.params.tournamentId, deletedPost.userId);

    // ランキング全体を再計算（順位を振り直す）
    try {
    await _internalRecalculateRankings(event.params.tournamentId);
  } catch(error) {
    console.error(`Error recalculating ranks for ${event.params.tournamentId}:`, error);
  }
    
    return null;
});



// =================================================================
// ▼▼▼ 18.新しいユーザーが大会に参加した際に、参加者数を更新する ▼▼▼
// =================================================================
exports.incrementParticipantCount = onDocumentCreated({
  document: "tournaments/{tournamentId}/entries/{userId}",
  region: "asia-northeast1",
}, async (event) => {
  const tournamentId = event.params.tournamentId;
  const tournamentRef = db.collection("tournaments").doc(tournamentId);

  // トランザクションで安全にカウンターを増やす
  return tournamentRef.update({
    participantCount: admin.firestore.FieldValue.increment(1)
  });
});


// =================================================================
// ▼▼▼ 19.手動で特定大会のランキングを再計算する ▼▼▼
// =================================================================
exports.recalculateRankingsManually = onCall({
  region: "asia-northeast1",
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "この操作を行うには認証が必要です。");
  }

  const tournamentId = request.data.tournamentId;
  if (!tournamentId) {
    throw new functions.https.HttpsError("invalid-argument", "tournamentId が指定されていません。");
  }

  // ★★★ 修正点: 新しい内部関数を呼び出すだけにする ★★★
  const result = await _internalRecalculateRankings(tournamentId);

  // 内部関数からの結果を返す
  if (!result.success) {
     throw new functions.https.HttpsError("not-found", result.message);
  }
  return { message: result.message, count: result.count };
});

exports.updateTournamentPostLikeCount = onDocumentWritten({
  document: "tournaments/{tournamentId}/posts/{postId}/likes/{userId}",
  region: "asia-northeast1",
}, async (event) => {
    const tournamentId = event.params.tournamentId;
    const postId = event.params.postId;
    const postRef = db.collection("tournaments").doc(tournamentId).collection("posts").doc(postId);

    const likesSnapshot = await postRef.collection("likes").get();
    const likeCount = likesSnapshot.size;

    return postRef.update({ likeCount: likeCount });
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