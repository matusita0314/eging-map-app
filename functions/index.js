// functions/index.js (リージョン指定を追加した最終版)

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const sharp = require("sharp");
const path = require("path");
const os = require("os");
const fs = require("fs");

initializeApp();

/**
 * 1. 投稿作成時にユーザーランクを更新する関数
 */
// ▼▼▼ リージョンを指定 ▼▼▼
exports.updateUserRankOnNewPost = onDocumentCreated({
  document: "posts/{postId}",
  region: "asia-northeast1", // 東京リージョン
}, async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const newPost = snap.data();
  // ... (以降の処理は変更なし) ...
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
    const currentRank = userData.rank || 'beginner';
    const newTotalCatches = currentTotalCatches + 1;
    const newMaxSize = Math.max(currentMaxSize, postSize);
    let newRank = currentRank;
    if (currentRank === 'beginner' && newTotalCatches >= 5 && newMaxSize >= 15) {
      newRank = 'amateur';
    } else if (currentRank === 'amateur' && newTotalCatches >= 15 && newMaxSize >= 25) {
      newRank = 'pro';
    }
    return transaction.update(userRef, {
      totalCatches: newTotalCatches,
      maxSize: newMaxSize,
      rank: newRank
    });
  });
});

/**
 * 2. 画像アップロード時にサムネイルを生成する関数
 */
// ▼▼▼ リージョンを指定 ▼▼▼
exports.generateThumbnail = onObjectFinalized({
  cpu: 2,
  region: "asia-northeast1", // 東京リージョン
}, async (event) => {
  const fileBucket = event.data.bucket;
  const filePath = event.data.name;
  const contentType = event.data.contentType;
  // ... (以降の処理は変更なし) ...
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