import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { upsertVideo, deleteVideo, querySimilarVideos, resetAndReindexAll } from './pinecone';

// Load environment variables from .env.local
dotenv.config({ path: path.resolve(__dirname, '../../.env.local') });

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Initialize OpenAI client
function getClients() {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
  });
  return { openai };
}

// Get clients (OpenAI, etc)
const { openai } = getClients();

interface SearchRequest {
  query: string;
  limit?: number;
}

// Automatically update RAG when a video is created/updated
export const onVideoWrite = functions.firestore
  .onDocumentWritten('videos/{videoId}', async (event) => {
    if (!event.data) return;
    
    const videoId = event.params.videoId;
    
    // If video was deleted
    if (!event.data.after) {
      await deleteVideo(videoId);
      return;
    }
    
    // Video was created or updated
    const videoData = event.data.after.data();
    if (videoData) {
      const video = {
        id: videoId,
        title: videoData.title,
        description: videoData.description,
        videoUrl: videoData.videoUrl,
        thumbnailUrl: videoData.thumbnailUrl,
        durationMs: videoData.durationMs,
        creatorId: videoData.creatorId,
        creatorUsername: videoData.creatorUsername,
        tags: videoData.tags,
        createdAt: videoData.createdAt,
        likeCount: videoData.likeCount,
        commentCount: videoData.commentCount,
        viewCount: videoData.viewCount,
      };
      await upsertVideo(videoId, video);
    }
  });

// Automatically update comment summary when comments change
export const onCommentWrite = functions.firestore.onDocumentWritten({
  document: 'videos/{videoId}/comments/{commentId}',
  memory: '256MiB',  // Reduced memory since we're just summarizing text
  timeoutSeconds: 60, // 1 minute should be plenty for summarization
  minInstances: 0,    // Scale to zero when not in use
  maxInstances: 10    // Limit concurrent executions
}, async (event) => {
  const videoId = event.params.videoId;
  const commentId = event.params.commentId;
  
  try {
    console.log(`Processing comment update for video ${videoId}, comment ${commentId}`);

    // Get last summary update timestamp
    const metadataRef = admin.firestore()
      .collection('videos')
      .doc(videoId)
      .collection('metadata')
      .doc('commentSummary');
      
    const metadata = await metadataRef.get();
    const lastUpdate = metadata.exists ? metadata.data()?.updatedAt?.toDate() : null;
    
    // Only update if:
    // 1. No previous summary exists, or
    // 2. Last update was more than 10 seconds ago
    const cooldownMs = 10 * 1000; // 10 seconds
    if (!lastUpdate || Date.now() - lastUpdate.getTime() > cooldownMs) {
      console.log('Cooldown passed, generating new summary');
      
      // Get top 50 comments by likes
      const comments = await admin.firestore()
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('likeCount', 'desc')
        .limit(50)
        .get();

      // If no comments, delete summary if it exists
      if (comments.empty) {
        console.log('No comments found, removing summary');
        await metadataRef.delete();
        return;
      }

      const commentTexts = comments.docs
        .map(doc => doc.data().text)
        .join('\n');

      console.log(`Generating summary for ${comments.size} comments`);

      // Generate summary using GPT-4o-mini
      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [{
          role: "user",
          content: 
`Give a concise summary of the following Minecraft video comments such that a reader can get the general sentiment of the comment section. Speak like a Minecraft villager. Do not make assumptions or add information not present in the comments (but don't just copy comments, and you can add opinions - just not made up information):
${commentTexts}

DO NOT JUST REPEAT COMMENTS. you should be giving the overall sentiment of the comments, the majority opinion. what people generally think of the video they just watched. you don't have to consider all comments
again. do not repeat comments. thats so fucking stupid. people dont want to read acomment twice. this is being shown at the top of the comment section`
        }],
        temperature: 0.7,
      });

      const summary = response.choices[0].message.content;

      // Update summary with server timestamp
      await metadataRef.set({
        summary,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        commentCount: comments.size
      });

      console.log('Summary updated successfully');
    } else {
      console.log('Skipping update due to cooldown');
    }
  } catch (error) {
    console.error('Error updating comment summary:', error);
    // Don't throw - we want to fail gracefully for background operations
  }
});

// Callable function to search videos
export const searchVideos = functions.https.onCall<SearchRequest>(async (request) => {
  const { query, limit = 10 } = request.data;
  
  if (!query || typeof query !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Query must be a non-empty string'
    );
  }
  
  try {
    const results = await querySimilarVideos(query, limit);
    return { results };
  } catch (error) {
    console.error('Error searching videos:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to search videos'
    );
  }
});

// Admin-only function to reset and reindex all videos
export const reindexAllVideos = functions.https.onRequest(
  { 
    timeoutSeconds: 540, // 9 minutes
    memory: '1GiB'
  }, 
  async (req, res) => {
    try {
      // Only allow POST requests
      if (req.method !== 'POST') {
        res.status(405).send('Method not allowed');
        return;
      }

      // Check API key
      const apiKey = req.headers['x-reindex-key'];
      if (!apiKey || apiKey !== process.env.REINDEX_API_KEY) {
        res.status(401).send('Invalid API key');
        return;
      }

      try {
        const result = await resetAndReindexAll();
        res.status(200).json(result);
      } catch (error) {
        console.error('Error reindexing videos:', error);
        res.status(500).json({
          error: 'Failed to reindex videos',
          details: error instanceof Error ? error.message : String(error)
        });
      }
    } catch (error) {
      console.error('Error handling request:', error);
      res.status(500).send('Internal server error');
    }
  }
); 