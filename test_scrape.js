const axios = require('axios');

async function test() {
  try {
    const url = 'https://api.microlink.io/?url=https://www.yiwugo.com/product/detail/975246218.html';
    const res = await axios.get(url);
    console.log(JSON.stringify(res.data, null, 2));
  } catch(e) {
    console.error(e.message);
  }
}
test();
