import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Cache the index.html content
let indexHtml: string | null = null;

const getIndexHtml = async (): Promise<string> => {
  if (indexHtml) return indexHtml;
  
  // Fetch from hosting URL
  const response = await fetch('https://reel-ai-dev.web.app/index.html');
  const html = await response.text();
  indexHtml = html;
  return html;
};

export const generatePreview = functions.https.onRequest(async (req, res) => {
  // Parse the video ID from the URL path
  const matches = req.path.match(/^\/video\/([^\/]+)/);
  if (!matches) {
    // Not a video route, return normal index.html
    res.send(await getIndexHtml());
    return;
  }

  const videoId = matches[1];

  try {
    // Get video data from Firestore
    const videoDoc = await db.collection('videos').doc(videoId).get();
    const videoData = videoDoc.data();

    if (!videoDoc.exists || !videoData) {
      // Video not found, return normal index.html
      res.send(await getIndexHtml());
      return;
    }

    // Get the base HTML
    const html = await getIndexHtml();

    // Prepare meta tags with proper escaping
    const metaTags = `
    <meta property="og:title" content="${(videoData.title || 'TikBlok Video').replace(/"/g, '&quot;')}" />
    <meta property="og:description" content="${(videoData.description || 'Watch this Minecraft video on TikBlok').replace(/"/g, '&quot;')}" />
    <meta property="og:image" content="${videoData.thumbnailUrl || ''}" />
    <meta property="og:url" content="https://reel-ai-dev.web.app/video/${videoId}" />
    <meta property="og:type" content="video.other" />
    <meta property="og:site_name" content="TikBlok" />
    
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${(videoData.title || 'TikBlok Video').replace(/"/g, '&quot;')}" />
    <meta name="twitter:description" content="${(videoData.description || 'Watch this Minecraft video on TikBlok').replace(/"/g, '&quot;')}" />
    <meta name="twitter:image" content="${videoData.thumbnailUrl || ''}" />
    `;

    // Insert meta tags after the <head> tag
    const modifiedHtml = html.replace('</head>', `${metaTags}\n</head>`);

    // Set content type and send response
    res.setHeader('Content-Type', 'text/html');
    res.send(modifiedHtml);

  } catch (error) {
    console.error('Error generating preview:', error);
    // On error, return normal index.html
    res.send(await getIndexHtml());
  }
}); 