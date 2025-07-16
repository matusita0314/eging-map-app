const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const sharp = require("sharp");
const path = require("path");
const os = require("os");
const fs =require("fs");

initializeApp();

// =================================================================
// ▼▼▼ 1.【新規】チャレンジ達成時にランクアップを判定する関数 ▼▼▼
// =================================================================
exports.checkAndUpdateRank = onDocumentWritten({
  document: "users/{userId}/completed_challenges/{challengeId}",
  region: "asia-northeast1",
}, async (event) => {
  const userId = event.params.userId;
  const challengeSnap = await getFirestore().collection("challenges").doc(event.params.challengeId).get();
  if (!challengeSnap.exists) {
    console.log(`Challenge ${event.params.challengeId} not found.`);
    return null;
  }
  const challengeRank = challengeSnap.data().rank;

  const userRef = getFirestore().collection("users").doc(userId);

  return getFirestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
        throw new Error(`User ${userId} not found.`);
    }
    const userData = userDoc.data();
    const currentRank = userData.rank;

    // 達成したミッションが現在のランクと違う場合、ランクアップ処理は不要
    if (currentRank !== challengeRank) {
      console.log(`User rank (${currentRank}) does not match challenge rank (${challengeRank}). No rank update needed.`);
      return;
    }

    const rankInfo = userData.rankInfo || {};
    const completedCountField = `${currentRank}_completed_count`;
    const newCompletedCount = (rankInfo[completedCountField] || 0) + 1;

    const newRankInfo = { ...rankInfo, [completedCountField]: newCompletedCount };
    
    // --- ランクアップ条件を定義 ---
    // ※ここのミッション総数は、実際にFirestoreに登録するミッション数に合わせてください
    const TOTAL_MISSIONS = {
        beginner: 5, // 例: ビギナーミッションは全部で5個
        amateur: 10,   // 例: アマチュアミッションは全部で10個
    };

    let newRank = currentRank;
    if (currentRank === "beginner" && newCompletedCount >= TOTAL_MISSIONS.beginner) {
      newRank = "amateur";
    } else if (currentRank === "amateur" && newCompletedCount >= TOTAL_MISSIONS.amateur) {
      newRank = "pro";
    }

    // 更新内容をまとめる
    const updateData = { rankInfo: newRankInfo };
    if (newRank !== currentRank) {
      updateData.rank = newRank;
      console.log(`User ${userId} has been promoted to ${newRank}!`);
    }

    transaction.update(userRef, updateData);
  });
});


// =================================================================
// ▼▼▼ 2.【修正】投稿作成時の処理（ランクアップ部分を削除）▼▼▼
// =================================================================
// totalCatches や maxSize は記録として残す
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
  const userRef = getFirestore().collection('users').doc(userId);

  return getFirestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw `User document with ID ${userId} not found!`;
    }
    const userData = userDoc.data();
    const currentTotalCatches = userData.totalCatches || 0;
    const currentMaxSize = userData.maxSize || 0;
    
    // ランクアップのロジックは削除し、釣果数と最大サイズの更新のみ行う
    return transaction.update(userRef, {
      totalCatches: currentTotalCatches + 1,
      maxSize: Math.max(currentMaxSize, postSize),
    });
  });
});

exports.checkAndCompleteMissionsOnNewPost = onDocumentCreated({
  document: "posts/{postId}",
  region: "asia-northeast1",
}, async (event) => {
    const snap = event.data;
    if (!snap) { return; }

    const postData = snap.data();
    const userId = postData.userId;
    const userRef = getFirestore().collection("users").doc(userId);

    // 1. ユーザーの最新情報を取得
    const userDoc = await userRef.get();
    if (!userDoc.exists) { return; }
    const userData = userDoc.data();
    const totalCatches = userData.totalCatches || 0;
    const maxSize = userData.maxSize || 0;

    // 2. 未クリアのミッションを取得
    const challengesRef = getFirestore().collection("challenges");
    const completedChallengesRef = userRef.collection("completed_challenges");
    const [allChallengesSnap, completedChallengesSnap] = await Promise.all([
        challengesRef.get(),
        completedChallengesRef.get(),
    ]);
    const completedChallengeIds = new Set(completedChallengesSnap.docs.map((doc) => doc.id));
    const uncompletedMissions = allChallengesSnap.docs.filter((doc) => !completedChallengeIds.has(doc.id));
    
    // 3. 達成条件をチェック
    const batch = getFirestore().batch();
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

    // 4. 新しく達成したミッションがあればDBに書き込み
    if (missionsCompleted) {
        await batch.commit();
    }
});


// =================================================================
// ▼▼▼ 3.【変更なし】サムネイル生成の関数 ▼▼▼
// =================================================================
exports.generateThumbnail = onObjectFinalized({
  cpu: 2,
  region: "asia-northeast1",
}, async (event) => {
    // ... (この中身は変更ありません) ...
    const fileBucket = event.data.bucket;
    const filePath = event.data.name;
    const contentType = event.data.contentType;
    if (!contentType.startsWith("image/")) { return console.log("これは画像ファイルではありません。"); }
    if (!filePath.startsWith("posts/")) { return console.log("posts/フォルダ内の画像ではないので処理しません。"); }
    if (path.basename(filePath).startsWith("thumb_")) { return console.log("これは既にサムネイルです。"); }
    
    const bucket = getStorage().bucket(fileBucket);
    const fileName = path.basename(filePath);
    const tempFilePath = path.join(os.tmpdir(), fileName);
    const thumbFileName = `thumb_${fileName}`;
    const thumbTempFilePath = path.join(os.tmpdir(), thumbFileName);
    
    await bucket.file(filePath).download({ destination: tempFilePath });
    await sharp(tempFilePath).resize(400, 400, { fit: "inside" }).toFile(thumbTempFilePath);
    
    const thumbStoragePath = `thumbnails/${thumbFileName}`;
    await bucket.upload(thumbTempFilePath, {
      destination: thumbStoragePath,
      metadata: { contentType: "image/jpeg" },
    });
    
    fs.unlinkSync(tempFilePath);
    fs.unlinkSync(thumbTempFilePath);

    const originalFile = bucket.file(filePath);
    const thumbFile = bucket.file(thumbStoragePath);
    const config = { action: "read", expires: "03-09-2491" };

    const [originalUrl] = await originalFile.getSignedUrl(config);
    const [thumbUrl] = await thumbFile.getSignedUrl(config);
    
    const postId = path.parse(fileName).name;

    return getFirestore().collection("posts").doc(postId).update({
        imageUrl: originalUrl,
        thumbnailUrl: thumbUrl,
    });
});