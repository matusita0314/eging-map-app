const functions = require("firebase-functions");
const { onDocumentCreated, onDocumentWritten, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const algoliasearch = require("algoliasearch");

const { defineString } = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

const algoliaAppId = defineString("ALGOLIA_APP_ID");
const algoliaAdminKey = defineString("ALGOLIA_ADMIN_KEY");

const algoliaClient = algoliasearch(algoliaAppId.value(), algoliaAdminKey.value());
const algoliaIndex = algoliaClient.initIndex("posts");


const sharp = require("sharp");
const path = require("path");
const os = require("os");
const fs = require("fs");
const {onRequest} = require("firebase-functions/v2/https");
const { onCall } = require("firebase-functions/v2/https");

function initializeAlgolia() {
  if (algoliaAppId.value() && algoliaAdminKey.value()) {
    const algoliaClient = algoliasearch(algoliaAppId.value(), algoliaAdminKey.value());
    return {
      // ▼▼▼【修正点】書き込み先をプライマリインデックス名に変更 ▼▼▼
      postsIndex: algoliaClient.initIndex("posts"), 
      usersIndex: algoliaClient.initIndex("users"),
    };
  }
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

  const settings = userData.notificationSettings || {};
  const shouldNotify = settings[notificationData.type] !== false;

  if (!shouldNotify) {
    return console.log(`User ${recipientId} has disabled notifications for type "${notificationData.type}".`);
  }

  await userRef.collection("notifications").add({
    ...notificationData,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });

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

  return createNotification(postAuthorId, {
    type: "likes",
    fromUserName: likerName,
    fromUserId: likerId,
    postId: postId,
    postThumbnailUrl: postData.thumbnailUrl || postData.imageUrl,
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

  return createNotification(postAuthorId, {
    type: "comments",
    fromUserName: commentData.userName,
    fromUserId: commenterId,
    postId: postId,
    postThumbnailUrl: postData.thumbnailUrl || postData.imageUrl,
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

  return createNotification(postAuthorId, {
    type: "saves",
    fromUserName: saverName,
    fromUserId: userId,
    postId: postId,
    postThumbnailUrl: postData.thumbnailUrl || postData.imageUrl,
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
// ▼▼▼ 12. ユーザー情報をAlgoliaに同期する関数 ▼▼▼
// =================================================================
exports.syncUserToAlgolia = onDocumentWritten("users/{userId}", async (event) => {
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
exports.syncPostToAlgolia = onDocumentWritten("posts/{postId}", async (event) => {
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