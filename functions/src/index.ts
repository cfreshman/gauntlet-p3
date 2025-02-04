/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import ffmpeg = require("fluent-ffmpeg");

admin.initializeApp();

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

export const generateThumbnail = functions.storage
  .onObjectFinalized(async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    // Log the event data for debugging
    console.log("Event data:", {
      filePath,
      contentType,
      bucket: event.data.bucket,
      metageneration: event.data.metageneration
    });

    // Only process video files
    if (!contentType?.startsWith("video/")) {
      console.log("Not a video, skipping thumbnail generation. Content type:", contentType);
      return;
    }

    const fileName = path.basename(filePath);
    const bucket = admin.storage().bucket(event.data.bucket);
    const tempFilePath = path.join(os.tmpdir(), fileName);
    const thumbnailFileName = `thumbnails/${path.parse(fileName).name}.jpg`;
    const thumbnailPath = path.join(os.tmpdir(), thumbnailFileName);

    try {
      // Download video file
      await bucket.file(filePath).download({destination: tempFilePath});
      console.log("Video downloaded to:", tempFilePath);

      // Generate thumbnail using cloud environment's ffmpeg
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .screenshots({
            timestamps: ["1"],
            filename: path.basename(thumbnailPath),
            folder: path.dirname(thumbnailPath),
            size: "640x360",
          })
          .on("end", resolve)
          .on("error", (err) => {
            console.error("FFmpeg error:", err);
            reject(err);
          });
      });
      console.log("Thumbnail generated at:", thumbnailPath);

      // Upload thumbnail
      await bucket.upload(thumbnailPath, {
        destination: thumbnailFileName,
        metadata: {
          contentType: "image/jpeg",
        },
      });
      console.log("Thumbnail uploaded to:", thumbnailFileName);

      // Get thumbnail URL
      const thumbnailFile = bucket.file(thumbnailFileName);
      const [thumbnailUrl] = await thumbnailFile.getSignedUrl({
        action: "read",
        expires: "03-01-2500", // Far future expiration
      });

      // Get the full video URL to match against Firestore
      const videoUrl = `https://firebasestorage.googleapis.com/v0/b/${event.data.bucket}/o/videos%2F${encodeURIComponent(fileName)}?alt=media`;
      console.log("Looking for video document with URL:", videoUrl);

      // Find the video document using the full video URL
      const videoDoc = await admin.firestore()
        .collection("videos")
        .where("videoUrl", "==", videoUrl)
        .limit(1)
        .get();

      if (!videoDoc.empty) {
        await videoDoc.docs[0].ref.update({
          thumbnailUrl: thumbnailUrl,
        });
        console.log("Video document updated with thumbnail URL:", thumbnailUrl);
      } else {
        console.log("No matching video document found for URL:", videoUrl);
        
        // Fallback: try searching by filename
        const fallbackDoc = await admin.firestore()
          .collection("videos")
          .where("videoUrl", ">=", fileName)
          .where("videoUrl", "<=", fileName + "\uf8ff")
          .limit(1)
          .get();
          
        if (!fallbackDoc.empty) {
          await fallbackDoc.docs[0].ref.update({
            thumbnailUrl: thumbnailUrl,
          });
          console.log("Video document updated with thumbnail URL (fallback):", thumbnailUrl);
        } else {
          console.log("No matching video document found with fallback search");
        }
      }

    } catch (error) {
      console.error("Error generating thumbnail:", error);
      throw error;
    } finally {
      // Cleanup
      try {
        fs.unlinkSync(tempFilePath);
        fs.unlinkSync(thumbnailPath);
      } catch (error) {
        console.warn("Error cleaning up temporary files:", error);
      }
    }
  });
