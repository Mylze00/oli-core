const axios = require('axios');
axios.post('https://oli-core.onrender.com/webhooks/unipesa/deposit', {order_id:'test', status:1, amount:1000})
  .then(r => console.log('OK', r.data))
  .catch(e => console.log('ERROR', e.response ? e.response.data : e.message));
