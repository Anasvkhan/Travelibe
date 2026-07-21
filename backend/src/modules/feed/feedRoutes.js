import { Router } from 'express';
import { FeedService } from './feedService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

// Create Post
router.post('/posts', authenticateToken, async (req, res) => {
  try {
    const { text, location, totalExperienceCost, media, originalPostId } = req.body;
    const post = await FeedService.createPost(req.user.id, { text, location, totalExperienceCost, media, originalPostId });
    res.status(201).json(post);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Get Feed
router.get('/posts', authenticateToken, async (req, res) => {
  try {
    const { filter, limit } = req.query;
    const feed = await FeedService.getFeed(req.user.id, { filter, limit });
    res.json(feed);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Edit Post
router.put('/posts/:id', authenticateToken, async (req, res) => {
  try {
    const { text, location } = req.body;
    const post = await FeedService.updatePost(req.user.id, req.params.id, { text, location });
    res.json(post);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Delete Post
router.delete('/posts/:id', authenticateToken, async (req, res) => {
  try {
    await FeedService.deletePost(req.user.id, req.params.id);
    res.json({ message: 'Post deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Get Posts by User ID
router.get('/posts/user/:userId', authenticateToken, async (req, res) => {
  try {
    const posts = await FeedService.getUserPosts(req.params.userId, req.user.id);
    res.json(posts);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// React to Post
router.post('/posts/:id/react', authenticateToken, async (req, res) => {
  try {
    const { reactionType } = req.body;
    const result = await FeedService.toggleReaction(req.user.id, req.params.id, reactionType);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Reshare Post
router.post('/posts/:id/share', authenticateToken, async (req, res) => {
  try {
    const post = await FeedService.sharePost(req.user.id, req.params.id, req.body);
    res.status(201).json(post);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Save / Bookmark Post
router.post('/posts/:id/save', authenticateToken, async (req, res) => {
  try {
    const result = await FeedService.toggleSavePost(req.user.id, req.params.id);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Get Comments for Post
router.get('/posts/:id/comments', authenticateToken, async (req, res) => {
  try {
    const comments = await FeedService.getComments(req.user.id, req.params.id);
    res.json(comments);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Add Comment
router.post('/posts/:id/comment', authenticateToken, async (req, res) => {
  try {
    const { text, parentId } = req.body;
    const comment = await FeedService.addComment(req.user.id, req.params.id, { text, parentId });
    res.status(201).json(comment);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// React / Like Comment
router.post('/comments/:id/react', authenticateToken, async (req, res) => {
  try {
    const result = await FeedService.toggleCommentReaction(req.user.id, req.params.id);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Create
router.post('/stories', authenticateToken, async (req, res) => {
  try {
    const { mediaUrl, mediaType } = req.body;
    const story = await FeedService.createStory(req.user.id, { mediaUrl, mediaType });
    res.status(201).json(story);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Get Active
router.get('/stories', authenticateToken, async (req, res) => {
  try {
    const stories = await FeedService.getActiveStories(req.user.id);
    res.json(stories);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Like Story
router.post('/stories/:id/like', authenticateToken, async (req, res) => {
  try {
    const result = await FeedService.toggleStoryLike(req.user.id, req.params.id);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Record View
router.post('/stories/:id/view', authenticateToken, async (req, res) => {
  try {
    const result = await FeedService.recordStoryView(req.user.id, req.params.id);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Get Viewers List
router.get('/stories/:id/viewers', authenticateToken, async (req, res) => {
  try {
    const viewers = await FeedService.getStoryViewers(req.params.id);
    res.json(viewers);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Reply to Story (Inbox Direct Message)
router.post('/stories/:id/reply', authenticateToken, async (req, res) => {
  try {
    const { text } = req.body;
    const result = await FeedService.replyToStory(req.user.id, req.params.id, { text });
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Stories: Delete Story
router.delete('/stories/:id', authenticateToken, async (req, res) => {
  try {
    await FeedService.deleteStory(req.user.id, req.params.id);
    res.json({ message: 'Story deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
