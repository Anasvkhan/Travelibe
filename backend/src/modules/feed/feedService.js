import { prisma } from '../../prisma.js';
import { ChatService } from '../chat/chatService.js';
import { NotificationService } from '../notifications/notificationService.js';

export class FeedService {
  static async createPost(userId, { text, location, totalExperienceCost, media, originalPostId }) {
    return await prisma.post.create({
      data: {
        userId,
        text: text || '',
        location,
        totalExperienceCost: totalExperienceCost ? parseFloat(totalExperienceCost) : null,
        originalPostId: originalPostId || null,
        media: {
          create: media?.map((m, idx) => ({
            mediaUrl: m.mediaUrl,
            mediaType: m.mediaType || 'image',
            altText: m.altText,
            orderIndex: idx,
          })) || [],
        },
      },
      include: {
        media: true,
        user: {
          select: { id: true, email: true, profile: true },
        },
        originalPost: {
          include: {
            user: { select: { id: true, email: true, profile: true } },
            media: true,
          },
        },
        reactions: true,
        comments: true,
        shares: true,
      },
    });
  }

  static async updatePost(userId, postId, { text, location }) {
    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new Error('Post not found');
    if (post.userId !== userId) throw new Error('Unauthorized to edit this post');

    return await prisma.post.update({
      where: { id: postId },
      data: {
        text: text || '',
        location: location || null,
      },
      include: {
        media: true,
        user: {
          select: { id: true, email: true, profile: true },
        },
        originalPost: {
          include: {
            user: { select: { id: true, email: true, profile: true } },
            media: true,
          },
        },
        reactions: true,
        comments: true,
        shares: true,
      },
    });
  }

  static async deletePost(userId, postId) {
    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new Error('Post not found');
    if (post.userId !== userId) throw new Error('Unauthorized to delete this post');

    // Clean up references to avoid constraint violation
    await prisma.savedItem.deleteMany({
      where: { targetType: 'POST', targetId: postId },
    });
    await prisma.boostCampaign.deleteMany({
      where: { targetId: postId },
    });
    await prisma.post.updateMany({
      where: { originalPostId: postId },
      data: { originalPostId: null },
    });

    return await prisma.post.delete({
      where: { id: postId },
    });
  }

  static async getFeed(userId, { filter = 'for_you', limit = 20 } = {}) {
    const connections = await prisma.connection.findMany({
      where: {
        OR: [
          { requesterId: userId, status: 'ACCEPTED' },
          { receiverId: userId, status: 'ACCEPTED' },
        ],
      },
    });

    const connectedUserIds = connections.map((c) =>
      c.requesterId === userId ? c.receiverId : c.requesterId
    );

    let whereCondition = {};
    if (filter === 'following') {
      whereCondition = { userId: { in: [userId, ...connectedUserIds] } };
    }

    const posts = await prisma.post.findMany({
      where: whereCondition,
      orderBy: filter === 'trending' ? undefined : { createdAt: 'desc' },
      take: parseInt(limit, 10) * 2,
      include: {
        media: true,
        reactions: {
          include: { user: { select: { id: true, profile: true } } },
        },
        comments: {
          orderBy: { createdAt: 'desc' },
          include: {
            user: { select: { id: true, profile: true } },
            reactions: {
          include: { user: { select: { id: true, profile: true } } },
        },
          },
        },
        shares: true,
        originalPost: {
          include: {
            user: { select: { id: true, profile: true } },
            media: true,
          },
        },
        user: {
          select: { id: true, email: true, profile: true },
        },
      },
    });

    // Get user's saved items
    const savedItems = await prisma.savedItem.findMany({
      where: { userId, targetType: 'POST' },
      select: { targetId: true },
    });
    const savedPostIds = new Set(savedItems.map((s) => s.targetId));

    const formattedPosts = posts.map((post) => {
      const isLikedByMe = post.reactions.some((r) => r.userId === userId);
      const isSavedByMe = savedPostIds.has(post.id);

      let score = 0;
      if (post.isBoosted) score += 3;
      if (connectedUserIds.includes(post.userId)) score += 2;
      const hoursOld = (Date.now() - new Date(post.createdAt).getTime()) / (1000 * 60 * 60);
      score += Math.max(0, 1 - hoursOld / 168);
      if (filter === 'trending') {
        score += post.reactions.length * 2 + post.comments.length * 3 + post.shares.length * 4;
      }

      return {
        ...post,
        likeCount: post.reactions.length,
        commentCount: post.comments.length,
        shareCount: post.shares.length,
        isLikedByMe,
        isSavedByMe,
        score,
      };
    });

    if (filter === 'trending' || filter === 'for_you') {
      formattedPosts.sort((a, b) => b.score - a.score);
    }

    return formattedPosts.slice(0, parseInt(limit, 10));
  }

  static async getUserPosts(userId, currentUserId) {
    const posts = await prisma.post.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        media: true,
        reactions: {
          include: { user: { select: { id: true, profile: true } } },
        },
        comments: {
          include: { user: { select: { id: true, profile: true } }, reactions: true },
        },
        shares: true,
        originalPost: {
          include: {
            user: { select: { id: true, profile: true } },
            media: true,
          },
        },
        user: {
          select: { id: true, email: true, profile: true },
        },
      },
    });

    const savedItems = await prisma.savedItem.findMany({
      where: { userId: currentUserId, targetType: 'POST' },
      select: { targetId: true },
    });
    const savedPostIds = new Set(savedItems.map((s) => s.targetId));

    return posts.map((post) => ({
      ...post,
      likeCount: post.reactions.length,
      commentCount: post.comments.length,
      shareCount: post.shares.length,
      isLikedByMe: post.reactions.some((r) => r.userId === currentUserId),
      isSavedByMe: savedPostIds.has(post.id),
    }));
  }

  static async toggleReaction(userId, postId, reactionType = 'LIKE') {
    const existing = await prisma.reaction.findUnique({
      where: { userId_postId: { userId, postId } },
    });

    if (existing) {
      if (existing.reactionType === reactionType) {
        await prisma.reaction.delete({ where: { id: existing.id } });
        const count = await prisma.reaction.count({ where: { postId } });
        return { liked: false, count };
      } else {
        await prisma.reaction.update({
          where: { id: existing.id },
          data: { reactionType },
        });
        const count = await prisma.reaction.count({ where: { postId } });
        return { liked: true, count };
      }
    } else {
      await prisma.reaction.create({
        data: { userId, postId, reactionType },
      });
      const count = await prisma.reaction.count({ where: { postId } });
      const targetPost = await prisma.post.findUnique({ where: { id: postId } });
      if (targetPost) {
        await NotificationService.createNotification({
          userId: targetPost.userId,
          actorId: userId,
          type: 'LIKE',
          title: 'Liked your post',
          message: 'liked your travel post.',
          targetId: postId,
        });
      }
      return { liked: true, count };
    }
  }

  static async sharePost(userId, postId, { text }) {
    const originalPost = await prisma.post.findUnique({
      where: { id: postId },
    });
    if (!originalPost) throw new Error('Original post not found');

    return await prisma.post.create({
      data: {
        userId,
        originalPostId: postId,
        text: text || '',
      },
      include: {
        media: true,
        user: { select: { id: true, email: true, profile: true } },
        originalPost: {
          include: {
            user: { select: { id: true, email: true, profile: true } },
            media: true,
          },
        },
        reactions: true,
        comments: true,
        shares: true,
      },
    });
  }

  static async getComments(userId, postId) {
    const comments = await prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: 'asc' },
      include: {
        user: { select: { id: true, profile: true } },
        reactions: true,
      },
    });

    return comments.map((c) => ({
      ...c,
      likeCount: c.reactions.length,
      isLikedByMe: c.reactions.some((r) => r.userId === userId),
    }));
  }

  static async addComment(userId, postId, { text, parentId }) {
    const comment = await prisma.comment.create({
      data: {
        userId,
        postId,
        parentId,
        text,
      },
      include: {
        user: { select: { id: true, profile: true } },
        reactions: true,
      },
    });

    const targetPost = await prisma.post.findUnique({ where: { id: postId } });
    if (targetPost) {
      await NotificationService.createNotification({
        userId: targetPost.userId,
        actorId: userId,
        type: 'COMMENT',
        title: 'Commented on your post',
        message: `commented: "${text.substring(0, 30)}${text.length > 30 ? '...' : ''}"`,
        targetId: postId,
      });
    }

    return {
      ...comment,
      likeCount: 0,
      isLikedByMe: false,
    };
  }

  static async toggleCommentReaction(userId, commentId) {
    const existing = await prisma.commentReaction.findUnique({
      where: { userId_commentId: { userId, commentId } },
    });

    if (existing) {
      await prisma.commentReaction.delete({ where: { id: existing.id } });
      const count = await prisma.commentReaction.count({ where: { commentId } });
      return { liked: false, count };
    } else {
      await prisma.commentReaction.create({
        data: { userId, commentId },
      });
      const count = await prisma.commentReaction.count({ where: { commentId } });
      return { liked: true, count };
    }
  }

  static async toggleSavePost(userId, targetId) {
    const existing = await prisma.savedItem.findUnique({
      where: { userId_targetType_targetId: { userId, targetType: 'POST', targetId } },
    });

    if (existing) {
      await prisma.savedItem.delete({ where: { id: existing.id } });
      return { saved: false };
    } else {
      await prisma.savedItem.create({
        data: { userId, targetType: 'POST', targetId },
      });
      return { saved: true };
    }
  }

  static async createStory(userId, { mediaUrl, mediaType }) {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    return await prisma.story.create({
      data: {
        userId,
        mediaUrl,
        mediaType: mediaType || 'image',
        expiresAt,
      },
      include: {
        user: { select: { id: true, profile: true } },
        likes: true,
      },
    });
  }

  static async deleteStory(userId, storyId) {
    const story = await prisma.story.findUnique({ where: { id: storyId } });
    if (!story) throw new Error('Story not found');
    if (story.userId !== userId) throw new Error('Unauthorized to delete this story');

    return await prisma.story.delete({
      where: { id: storyId },
    });
  }

  static async getActiveStories(userId) {
    const stories = await prisma.story.findMany({
      where: {
        expiresAt: { gt: new Date() },
        isArchived: false,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, profile: true } },
        likes: true,
        views: true,
      },
    });

    return stories.map((story) => ({
      ...story,
      likeCount: story.likes.length,
      viewCount: story.views.length,
      isLikedByMe: story.likes.some((l) => l.userId === userId),
      isViewedByMe: story.views.some((v) => v.userId === userId),
    }));
  }

  static async recordStoryView(userId, storyId) {
    try {
      await prisma.storyView.upsert({
        where: { userId_storyId: { userId, storyId } },
        create: { userId, storyId },
        update: {},
      });
      const count = await prisma.storyView.count({ where: { storyId } });
      return { viewed: true, count };
    } catch (e) {
      console.error('[recordStoryView] error:', e);
      return { viewed: false, count: 0 };
    }
  }

  static async getStoryViewers(storyId) {
    const views = await prisma.storyView.findMany({
      where: { storyId },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            profile: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const likes = await prisma.storyLike.findMany({
      where: { storyId },
      select: { userId: true },
    });

    const likedUserIds = new Set(likes.map((l) => l.userId));

    return views.map((v) => ({
      id: v.user.id,
      name: v.user.profile?.displayName || 'Traveler',
      avatarUrl: v.user.profile?.avatarUrl,
      handle: v.user.profile?.handle || 'user',
      isLiked: likedUserIds.has(v.user.id),
      viewedAt: v.createdAt,
    }));
  }

  static async toggleStoryLike(userId, storyId) {
    const existing = await prisma.storyLike.findUnique({
      where: { userId_storyId: { userId, storyId } },
    });

    if (existing) {
      await prisma.storyLike.delete({ where: { id: existing.id } });
      const count = await prisma.storyLike.count({ where: { storyId } });
      return { liked: false, count };
    } else {
      await prisma.storyLike.create({
        data: { userId, storyId },
      });
      const count = await prisma.storyLike.count({ where: { storyId } });
      return { liked: true, count };
    }
  }

  static async replyToStory(userId, storyId, { text }) {
    const story = await prisma.story.findUnique({
      where: { id: storyId },
    });
    if (!story) throw new Error('Story not found');

    if (story.userId === userId) {
      throw new Error('You cannot reply to your own story');
    }

    const conversation = await ChatService.getOrCreateConversation(userId, story.userId);

    const message = await ChatService.saveMessage(userId, conversation.id, {
      text: text || 'Replied to your story',
      messageType: 'ATTACHMENT',
      attachments: [
        {
          fileUrl: story.mediaUrl,
          fileType: story.mediaType,
          fileName: 'Story Reply',
        },
      ],
    });

    return { conversation, message };
  }

  static async purgeExpiredStories() {
    const now = new Date();
    const result = await prisma.story.updateMany({
      where: {
        expiresAt: { lte: now },
        isArchived: false,
      },
      data: {
        isArchived: true,
      },
    });
    console.log(`[StoryPurgeJob] Archived ${result.count} expired stories.`);
    return result;
  }
}
