const jwt = require('jsonwebtoken');
const token = jwt.sign({ id: 71, phone: '+243827088682', role: 'user' }, 'oli_strong_secret_change_me', { expiresIn: '1h' });
console.log(token);
