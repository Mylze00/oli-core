const jwt = require('jsonwebtoken');
console.log(jwt.sign({ id: 127 }, 'oli_strong_secret_change_me', { expiresIn: '1d' }));
