const cfg = require('./src/config/index');
console.log('cfg keys:', Object.keys(cfg));
console.log('FEES is:', cfg.FEES);
require('./src/services/wallet.service.js');
