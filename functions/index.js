// functions/index.js (v2構文 修正版)

const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {initializeApp} = require("firebase-admin/app");
const {getStorage} = require("firebase-admin/storage");
const logger = require("firebase-functions/logger");
const path = require("path");
const os = require("os");
const fs = require("fs");
const sharp = require("sharp");

initializeApp();

exports.generateThumbnail = onObjectFinalized(
  { region: "asia-northeast1" },
  async (event) => {
  const fileBucket = event.bucket;
  const filePath = event.data.name;
  const contentType = event.data.contentType;

  if (!filePath.startsWith("posts/")) {
    logger.log("This is not a post image.");
    return;
  }
  if (path.basename(filePath).startsWith("thumb_")) {
    logger.log("This is already a thumbnail, skipping.");
    return;
  }
  // 3. 画像ファイル以外は無視
  if (!contentType.startsWith("image/")) {
    logger.log("This is not an image, skipping.");
    return;
  }

  const bucket = getStorage().bucket(fileBucket);
  const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));
  await bucket.file(filePath).download({destination: tempFilePath});
  logger.log("Image downloaded locally to", tempFilePath);

  const thumbFileName = `thumb_${path.basename(filePath)}`;
  const thumbFilePath = path.join(os.tmpdir(), thumbFileName);

  await sharp(tempFilePath)
      .resize(200, 200)
      .toFile(thumbFilePath);

  const thumbFileDir = path.dirname(filePath);
  const thumbUploadPath = path.join(thumbFileDir, thumbFileName);

  await bucket.upload(thumbFilePath, {
    destination: thumbUploadPath,
    metadata: {contentType: "image/jpeg"},
  });

  fs.unlinkSync(tempFilePath);
  fs.unlinkSync(thumbFilePath);
  return logger.log("Thumbnail generation finished.");
});