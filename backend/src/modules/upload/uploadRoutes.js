import { Router } from 'express';
import { upload } from '../../common/middleware/upload.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/media', authenticateToken, upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Please select a file to upload' });
    }

    // Construct static URL (e.g. http://localhost:8000/uploads/filename.jpg)
    const host = req.get('host');
    const protocol = req.protocol;
    const mediaUrl = `${protocol}://${host}/uploads/${req.file.filename}`;

    res.status(201).json({
      success: true,
      mediaUrl,
      fileName: req.file.filename,
      fileSize: req.file.size,
      fileType: req.file.mimetype.split('/')[0], // "image" or "video"
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/media-multiple', authenticateToken, upload.array('files', 10), (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'Please select files to upload' });
    }

    const host = req.get('host');
    const protocol = req.protocol;
    const urls = req.files.map(file => `${protocol}://${host}/uploads/${file.filename}`);

    res.status(201).json({
      success: true,
      mediaUrls: urls,
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
