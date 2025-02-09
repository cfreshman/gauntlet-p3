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
import { OpenAI } from 'openai';

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

export const getOrCreateCaptions = functions.https
  .onCall({
    memory: "1GiB",  // Increase memory limit to handle video processing
  }, async (request: functions.https.CallableRequest<{ videoId: string }>, context) => {
    const { videoId } = request.data;
    
    if (!videoId) {
      throw new functions.https.HttpsError('invalid-argument', 'Video ID is required');
    }

    console.log('Starting caption generation for video:', videoId);

    const bucket = admin.storage().bucket();
    const tempFilePath = path.join(os.tmpdir(), `${videoId}.mp4`);
    const audioPath = path.join(os.tmpdir(), `${videoId}.mp3`);
    const captionsFileName = `captions/${videoId}.vtt`;
    const captionsPath = path.join(os.tmpdir(), captionsFileName);

    try {
      // Check if captions already exist
      console.log('Checking for existing video document...');
      const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Video not found');
      }

      const videoData = videoDoc.data()!;
      if (videoData.captionsUrl) {
        console.log('Captions already exist, returning URL');
        return { captionsUrl: videoData.captionsUrl };
      }

      // Extract storage path from video URL
      console.log('Original video URL:', videoData.videoUrl);
      const videoUrl = videoData.videoUrl;
      const pathWithQuery = videoUrl.split('/o/')[1];
      const storagePath = decodeURIComponent(pathWithQuery.split('?')[0]);
      console.log('Extracted storage path:', storagePath);

      // Download video and generate captions
      console.log('Downloading video file...');
      await bucket.file(storagePath).download({destination: tempFilePath});
      console.log('Video downloaded to:', tempFilePath);

      // Extract audio using ffmpeg
      console.log('Extracting audio...');
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .toFormat('mp3')
          .on('end', () => {
            console.log('Audio extraction complete');
            resolve(null);
          })
          .on('error', (err) => {
            console.error('FFmpeg error:', err);
            reject(err);
          })
          .save(audioPath);
      });

      // Generate captions with Whisper
      console.log('Generating captions with Whisper...');
      const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY,
      });

      console.log('Creating audio file stream...');
      const audioFile = fs.createReadStream(audioPath);
      
      console.log('Calling Whisper API...');
      const transcription = await openai.audio.transcriptions.create({
        file: audioFile,
        model: "whisper-1",
        response_format: "vtt",
        language: "en"
      });
      console.log('Transcription complete');

      // Create directory if it doesn't exist
      console.log('Creating captions directory...');
      const captionsDir = path.dirname(captionsPath);
      if (!fs.existsSync(captionsDir)) {
        fs.mkdirSync(captionsDir, { recursive: true });
      }

      // Save VTT file
      console.log('Saving VTT file...');
      fs.writeFileSync(captionsPath, String(transcription));
      console.log('VTT file saved to:', captionsPath);

      // Upload captions
      console.log('Uploading captions to storage...');
      await bucket.upload(captionsPath, {
        destination: captionsFileName,
        metadata: {
          contentType: 'text/vtt',
        },
      });
      console.log('Captions uploaded');

      // Get the direct captions URL
      const captionsUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(captionsFileName)}?alt=media`;
      console.log('Generated captions URL:', captionsUrl);

      // Update video document with captions URL
      console.log('Updating video document...');
      await videoDoc.ref.update({ captionsUrl });
      console.log('Video document updated');

      return { captionsUrl };

    } catch (error) {
      console.error('Detailed error in getOrCreateCaptions:', error);
      if (error instanceof Error) {
        console.error('Error name:', error.name);
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);
      }
      throw new functions.https.HttpsError('internal', `Error generating captions: ${error}`);
    } finally {
      // Cleanup temporary files
      console.log('Cleaning up temporary files...');
      try {
        if (fs.existsSync(tempFilePath)) {
          fs.unlinkSync(tempFilePath);
          console.log('Cleaned up temp video file');
        }
        if (fs.existsSync(audioPath)) {
          fs.unlinkSync(audioPath);
          console.log('Cleaned up audio file');
        }
        if (fs.existsSync(captionsPath)) {
          fs.unlinkSync(captionsPath);
          console.log('Cleaned up captions file');
        }
      } catch (error) {
        console.warn('Error cleaning up temporary files:', error);
      }
    }
  });

export { generatePreview } from './preview';
export { onVideoWrite, searchVideos, reindexAllVideos, onCommentWrite, rateSkin } from './ai/functions';
