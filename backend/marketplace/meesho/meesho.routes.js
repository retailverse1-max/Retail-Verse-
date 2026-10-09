const express = require('express');
const router = express.Router();
const { protect: authMiddleware } = require('../../middleware/authMiddleware');
const meeshoController = require('./meesho.controller');

router.get('/status', authMiddleware, meeshoController.checkStatus);
router.post('/connect', authMiddleware, meeshoController.connectAccount);
router.post('/disconnect', authMiddleware, meeshoController.disconnectAccount);
router.post('/products/push', authMiddleware, meeshoController.pushProduct);
router.post('/products/bulk-push', authMiddleware, meeshoController.bulkPushProducts);

module.exports = router;
