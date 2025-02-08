import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { Langfuse } from 'langfuse-node';
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

// Initialize Langfuse
const langfuse = new Langfuse({
  publicKey: process.env.LANGFUSE_PUBLIC_KEY || '',
  secretKey: process.env.LANGFUSE_SECRET_KEY || '',
  baseUrl: process.env.LANGFUSE_BASE_URL // optional
});

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
  memory: '256MiB',
  timeoutSeconds: 60,
  minInstances: 0,
  maxInstances: 10
}, async (event) => {
  const videoId = event.params.videoId;
  const commentId = event.params.commentId;
  let trace;
  
  try {
    console.log(`Processing comment update for video ${videoId}, comment ${commentId}`);

    // Get video data for context
    const videoDoc = await admin.firestore()
      .collection('videos')
      .doc(videoId)
      .get();
    
    const videoData = videoDoc.data();

    // Create trace with rich context
    trace = await langfuse.trace({
      id: `comment-summary-${videoId}-${Date.now()}`,
      name: "Comment Summary Generation",
      metadata: {
        videoId,
        triggerCommentId: commentId,
        videoTitle: videoData?.title,
        creatorId: videoData?.creatorId,
        creatorUsername: videoData?.creatorUsername,
        eventType: event.type,
        functionName: 'onCommentWrite'
      },
      tags: [
        'function:comment_summary',
        `video:${videoId}`,
        event.type // 'created' or 'updated' or 'deleted'
      ]
    });

    // Get last summary update timestamp
    const metadataRef = admin.firestore()
      .collection('videos')
      .doc(videoId)
      .collection('metadata')
      .doc('commentSummary');
      
    const metadata = await metadataRef.get();
    const lastUpdate = metadata.exists ? metadata.data()?.updatedAt?.toDate() : null;
    
    // Track cooldown check
    const cooldownMs = 10 * 1000; // 10 seconds
    const timeSinceLastUpdate = lastUpdate ? Date.now() - lastUpdate.getTime() : null;
    
    await trace.update({
      metadata: {
        lastSummaryUpdate: lastUpdate?.toISOString(),
        timeSinceLastUpdateMs: timeSinceLastUpdate,
        cooldownMs
      }
    });

    if (!lastUpdate || (timeSinceLastUpdate !== null && timeSinceLastUpdate > cooldownMs)) {
      console.log('Cooldown passed, generating new summary');
      
      // Get comments with timing span
      const commentsSpan = await trace.span({
        name: "Fetch Comments",
      });
      
      const comments = await admin.firestore()
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('likeCount', 'desc')
        .limit(50)
        .get();

      // Calculate comment stats
      const commentStats = comments.docs.reduce((acc, doc) => {
        const data = doc.data();
        return {
          totalLikes: acc.totalLikes + (data.likeCount || 0),
          avgLength: acc.avgLength + (data.text?.length || 0),
          withReplies: acc.withReplies + (data.replyCount > 0 ? 1 : 0),
          maxLikes: Math.max(acc.maxLikes, data.likeCount || 0)
        };
      }, { totalLikes: 0, avgLength: 0, withReplies: 0, maxLikes: 0 });
      
      if (comments.size > 0) {
        commentStats.avgLength = Math.round(commentStats.avgLength / comments.size);
      }

      await commentsSpan.update({
        output: {
          commentCount: comments.size,
          ...commentStats
        }
      });

      // If no comments, delete summary if it exists
      if (comments.empty) {
        console.log('No comments found, removing summary');
        await metadataRef.delete();
        await trace.update({
          output: {
            status: 'no_comments',
            message: 'No comments found, summary removed'
          }
        });
        return;
      }

      const commentTexts = comments.docs
        .map(doc => doc.data().text)
        .join('\n');

      console.log(`Generating summary for ${comments.size} comments`);

      // Create generation span for OpenAI call
      const generation = await trace.generation({
        name: "Comment Summary",
        model: "gpt-4o-mini",
        input: commentTexts,
        metadata: {
          commentCount: comments.size,
          ...commentStats,
          promptLength: commentTexts.length,
          videoContext: {
            title: videoData?.title,
            description: videoData?.description?.slice(0, 100), // First 100 chars
            tags: videoData?.tags
          }
        }
      });

      // Generate summary using GPT-4o-mini
      const startTime = Date.now();
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
      if (!summary) {
        throw new Error('No summary generated');
      }

      // Update generation with detailed output
      await generation.update({
        output: summary,
        metadata: {
          numComments: comments.size,
          promptTokens: response.usage?.prompt_tokens,
          completionTokens: response.usage?.completion_tokens,
          totalTokens: response.usage?.total_tokens,
          processingTimeMs: Date.now() - startTime,
          summaryLength: summary.length,
          commentStats
        }
      });

      // Update summary with server timestamp
      await metadataRef.set({
        summary,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        commentCount: comments.size,
        stats: commentStats
      });

      await trace.update({
        output: {
          status: 'success',
          commentCount: comments.size,
          summaryLength: summary.length,
          processingTimeMs: Date.now() - startTime,
          commentStats
        }
      });

      console.log('Summary updated successfully');
    } else {
      console.log('Skipping update due to cooldown');
      await trace.update({
        output: {
          status: 'skipped',
          reason: 'cooldown',
          timeSinceLastUpdateMs: timeSinceLastUpdate || 0,
          cooldownMs
        }
      });
    }
  } catch (error) {
    console.error('Error updating comment summary:', error);
    if (trace) {
      await trace.update({
        output: {
          status: 'error',
          error: error instanceof Error ? error.message : String(error),
          errorType: error instanceof Error ? error.constructor.name : 'Unknown',
          stack: error instanceof Error ? error.stack : undefined
        }
      });
    }
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