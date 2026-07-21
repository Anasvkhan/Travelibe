import { redisClient } from '../../redis.js';

export async function idempotencyMiddleware(req, res, next) {
  // Only apply idempotency to mutating methods
  if (['POST', 'PUT', 'PATCH', 'DELETE'].indexOf(req.method) === -1) {
    return next();
  }

  const key = req.headers['idempotency-key'];
  if (!key) {
    return next(); // If no key is provided, proceed normally
  }

  const cacheKey = `idempotency:${req.method}:${req.originalUrl}:${key}`;

  try {
    if (redisClient.isOpen) {
      const cachedResponse = await redisClient.get(cacheKey);
      if (cachedResponse) {
        const { status, body, headers } = JSON.parse(cachedResponse);
        res.status(status);
        Object.entries(headers).forEach(([hKey, hVal]) => {
          res.setHeader(hKey, hVal);
        });
        return res.send(body);
      }
    }
  } catch (err) {
    console.error('Idempotency check error:', err);
  }

  // Intercept the response to save it
  const originalSend = res.send;
  res.send = function (body) {
    res.send = originalSend; // Restore original send
    
    // Cache standard successful JSON responses
    if (res.statusCode >= 200 && res.statusCode < 300) {
      const responseData = {
        status: res.statusCode,
        body: body,
        headers: res.getHeaders(),
      };
      
      if (redisClient.isOpen) {
        redisClient.set(cacheKey, JSON.stringify(responseData), {
          EX: 86400, // Keep cached response for 24 hours
        }).catch((err) => console.error('Failed to cache response in Redis:', err));
      }
    }
    
    return originalSend.apply(res, arguments);
  };

  next();
}

export default idempotencyMiddleware;
