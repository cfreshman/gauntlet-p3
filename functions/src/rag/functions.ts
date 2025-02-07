import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { upsertVideo, deleteVideo, querySimilarVideos, resetAndReindexAll } from './pinecone';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

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