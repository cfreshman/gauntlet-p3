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

export const generateThumbnail = functions.https
  .onCall(async (request: functions.https.CallableRequest<{ filePath: string }>, context) => {
    const { filePath } = request.data;
    
    if (!filePath) {
      throw new functions.https.HttpsError('invalid-argument', 'File path is required');
    }

    const bucket = admin.storage().bucket();
    const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));
    const thumbnailFileName = `thumbnails/${path.parse(filePath).name}.jpg`;
    const thumbnailPath = path.join(os.tmpdir(), thumbnailFileName);

    try {
      // Download video file
      await bucket.file(filePath).download({destination: tempFilePath});
      console.log("Video downloaded to:", tempFilePath);

      // Get video duration using ffmpeg
      let durationMs = 0;
      await new Promise((resolve, reject) => {
        ffmpeg.ffprobe(tempFilePath, (err, metadata: { format: { duration?: number } }) => {
          if (err) {
            console.error("FFprobe error:", err);
            reject(err);
            return;
          }
          if (metadata.format.duration === undefined) {
            console.warn("Could not determine video duration");
            resolve(null);
            return;
          }
          durationMs = Math.round(metadata.format.duration * 1000);
          resolve(null);
        });
      });
      console.log("Video duration (ms):", durationMs);

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

      // Get the direct thumbnail URL
      const thumbnailUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(thumbnailFileName)}?alt=media`;

      // Return the metadata
      return {
        thumbnailUrl,
        durationMs,
      };

    } catch (error) {
      console.error("Error generating thumbnail:", error);
      throw new functions.https.HttpsError('internal', 'Error generating thumbnail: ' + error);
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

export { generatePreview } from './preview';
export { onVideoWrite, searchVideos, reindexAllVideos, onCommentWrite } from './ai/functions';
