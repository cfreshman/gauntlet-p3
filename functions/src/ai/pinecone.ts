import { Pinecone } from '@pinecone-database/pinecone';
import { OpenAI } from 'openai';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';

interface VideoData {
  id: string;
  title: string;
  description: string;
  videoUrl: string;
  thumbnailUrl: string;
  durationMs: number;
  creatorId: string;
  creatorUsername: string;
  tags: string[];
  createdAt: admin.firestore.Timestamp;
  likeCount: number;
  commentCount: number;
  viewCount: number;
}

interface VideoMetadata {
  [key: string]: string | number | string[] | boolean;
  title: string;
  description: string;
  thumbnailUrl: string;
  creatorId: string;
  creatorUsername: string;
  createdAt: number;
  tags: string[];
  viewCount: number;
  likeCount: number;
  commentCount: number;
}

// Load environment variables from Firebase config
const getConfig = () => {
  const config = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
  return {
    openaiApiKey: process.env.OPENAI_API_KEY || config.openai?.api_key,
    pineconeApiKey: process.env.PINECONE_API_KEY || config.pinecone?.api_key,
    pineconeIndex: process.env.PINECONE_INDEX || config.pinecone?.index || 'tikblok-videos',
    pineconeNamespace: process.env.PINECONE_NAMESPACE || config.pinecone?.namespace || 'videos',
    pineconeHost: process.env.PINECONE_HOST || config.pinecone?.host,
  };
};

// Constants
const { pineconeIndex: PINECONE_INDEX, pineconeNamespace: PINECONE_NAMESPACE, pineconeHost: PINECONE_HOST } = getConfig();

let openaiClient: OpenAI | null = null;
let pineconeClient: Pinecone | null = null;

// Initialize clients
function getClients() {
  if (!openaiClient || !pineconeClient) {
    const { openaiApiKey, pineconeApiKey, pineconeHost } = getConfig();
    if (!openaiApiKey) throw new Error('OpenAI API key not configured');
    if (!pineconeApiKey) throw new Error('Pinecone API key not configured');
    if (!pineconeHost) throw new Error('Pinecone host not configured');
    
    openaiClient = new OpenAI({ apiKey: openaiApiKey });
    pineconeClient = new Pinecone({ apiKey: pineconeApiKey });
  }
  return { openai: openaiClient, pinecone: pineconeClient };
}

// Initialize Pinecone index
async function getIndex() {
  const { pinecone } = getClients();
  return pinecone.index(PINECONE_INDEX).namespace(PINECONE_NAMESPACE);
}

// Generate embeddings for text
async function generateEmbedding(text: string): Promise<number[]> {
  console.log('Generating embedding for text length:', text.length);
  const { openai } = getClients();
  const response = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: text,
  });
  console.log('Generated embedding of dimension:', response.data[0].embedding.length);
  return response.data[0].embedding;
}

// Prepare video metadata for embedding
function prepareVideoText(video: VideoData): string {
  const parts = [
    video.title,
    video.description,
    video.tags.join(' '),
  ];
  return parts.join(' ').toLowerCase();
}

// Upsert a single video to Pinecone
export async function upsertVideo(videoId: string, videoData: VideoData) {
  console.log('Upserting video to RAG:', videoId);
  try {
    const index = await getIndex();
    const text = prepareVideoText(videoData);
    console.log('Prepared text for embedding:', {
      videoId,
      textLength: text.length,
      title: videoData.title,
      tags: videoData.tags
    });
    
    const embedding = await generateEmbedding(text);
    
    const metadata: VideoMetadata = {
      title: videoData.title,
      description: videoData.description,
      thumbnailUrl: videoData.thumbnailUrl,
      creatorId: videoData.creatorId,
      creatorUsername: videoData.creatorUsername,
      createdAt: videoData.createdAt.toMillis(),
      tags: videoData.tags,
      viewCount: videoData.viewCount,
      likeCount: videoData.likeCount,
      commentCount: videoData.commentCount,
    };

    await index.upsert([{
      id: videoId,
      values: embedding,
      metadata
    }]);
    console.log('Successfully upserted video to RAG:', videoId);
  } catch (error) {
    console.error('Error upserting video to RAG:', {
      videoId,
      error: error instanceof Error ? error.message : error
    });
    throw error;
  }
}

// Delete a video from Pinecone
export async function deleteVideo(videoId: string) {
  console.log('Deleting video from RAG:', videoId);
  try {
    const index = await getIndex();
    await index.deleteOne(videoId);
    console.log('Successfully deleted video from RAG:', videoId);
  } catch (error) {
    console.error('Error deleting video from RAG:', {
      videoId,
      error: error instanceof Error ? error.message : error
    });
    throw error;
  }
}

// Query similar videos
export async function querySimilarVideos(queryText: string, limit: number = 10) {
  console.log('Searching similar videos:', { queryText, limit });
  try {
    const index = await getIndex();
    const queryEmbedding = await generateEmbedding(queryText);
    
    const results = await index.query({
      vector: queryEmbedding,
      topK: limit,
      includeMetadata: true
    });
    
    console.log('Search results:', {
      queryText,
      numResults: results.matches?.length || 0,
      scores: results.matches?.map(m => m.score)
    });
    
    return results.matches || [];
  } catch (error) {
    console.error('Error searching videos:', {
      queryText,
      error: error instanceof Error ? error.message : error
    });
    throw error;
  }
}

// Reset and reindex all videos
export async function resetAndReindexAll() {
  console.log('Starting full RAG reindex');
  try {
    const { pineconeApiKey } = getConfig();
    const db = admin.firestore();
    
    // Delete all vectors using direct API call
    console.log('Deleting all existing vectors');
    const deleteResponse = await fetch(`${PINECONE_HOST}/vectors/delete`, {
      method: 'POST',
      headers: {
        'Api-Key': pineconeApiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        deleteAll: true,
        namespace: PINECONE_NAMESPACE
      })
    });
    
    if (!deleteResponse.ok) {
      const errorText = await deleteResponse.text();
      throw new Error(`Failed to delete vectors: ${deleteResponse.statusText} - ${errorText}`);
    }
    
    // Get all videos from Firestore
    console.log('Fetching all videos from Firestore');
    const videosSnapshot = await db.collection('videos').get();
    const videos = videosSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as VideoData));
    
    console.log(`Found ${videos.length} videos to reindex`);
    
    // Process in batches of 100
    const batchSize = 100;
    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      console.log(`Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(videos.length/batchSize)}`);
      
      const vectors = await Promise.all(
        batch.map(async (video) => {
          const text = prepareVideoText(video);
          const embedding = await generateEmbedding(text);
          const metadata: VideoMetadata = {
            title: video.title,
            description: video.description,
            thumbnailUrl: video.thumbnailUrl,
            creatorId: video.creatorId,
            creatorUsername: video.creatorUsername,
            createdAt: video.createdAt.toMillis(),
            tags: video.tags,
            viewCount: video.viewCount,
            likeCount: video.likeCount,
            commentCount: video.commentCount,
          };
          return {
            id: video.id,
            values: embedding,
            metadata
          };
        })
      );
      
      // Upsert vectors using direct API call
      const upsertResponse = await fetch(`${PINECONE_HOST}/vectors/upsert`, {
        method: 'POST',
        headers: {
          'Api-Key': pineconeApiKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
          vectors,
          namespace: PINECONE_NAMESPACE
        })
      });
      
      if (!upsertResponse.ok) {
        const errorText = await upsertResponse.text();
        throw new Error(`Failed to upsert vectors: ${upsertResponse.statusText} - ${errorText}`);
      }
      
      console.log(`Processed ${i + batch.length} / ${videos.length} videos`);
    }
    
    console.log('RAG reindex completed successfully');
    return {
      totalProcessed: videos.length,
      message: 'RAG index reset and reindexed successfully'
    };
  } catch (error) {
    console.error('Error during RAG reindex:', {
      error: error instanceof Error ? error.message : error
    });
    throw error;
  }
} 