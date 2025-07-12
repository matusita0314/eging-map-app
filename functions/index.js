// functions/index.js (v2対応版)

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

// Firebase Admin SDKを初期化
initializeApp();

/**
 * 新しい投稿が作成されたときに、ユーザーの累計釣果とランクを更新する関数
 */
exports.updateUserRankOnNewPost = onDocumentCreated("posts/{postId}", async (event) => {
  // 作成されたドキュメントのスナップショットを取得
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const newPost = snap.data();
  const userId = newPost.userId;
  const postSize = newPost.squidSize;

  const userRef = getFirestore().collection('users').doc(userId);

  // トランザクションを使って、安全にデータの読み書きを行う
  return getFirestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw `User document with ID ${userId} not found!`;
    }

    const userData = userDoc.data();
    
    // 累計記録を計算
    const currentTotalCatches = userData.totalCatches || 0;
    const currentMaxSize = userData.maxSize || 0;
    const currentRank = userData.rank || 'beginner';

    const newTotalCatches = currentTotalCatches + 1;
    const newMaxSize = Math.max(currentMaxSize, postSize);
    
    let newRank = currentRank;

    // ランクアップ条件を判定
    if (currentRank === 'beginner' && newTotalCatches >= 5 && newMaxSize >= 15) {
      newRank = 'amateur';
      console.log(`User ${userId} ranked up to amateur!`);
    } else if (currentRank === 'amateur' && newTotalCatches >= 15 && newMaxSize >= 25) {
      newRank = 'pro';
      console.log(`User ${userId} ranked up to pro!`);
    }

    // 計算結果をFirestoreに書き込む
    console.log(`Updating user ${userId}: Catches=${newTotalCatches}, MaxSize=${newMaxSize}, Rank=${newRank}`);
    return transaction.update(userRef, {
      totalCatches: newTotalCatches,
      maxSize: newMaxSize,
      rank: newRank
    });
  });
});