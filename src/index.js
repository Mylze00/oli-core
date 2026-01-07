const http = require("http");
const app = require("./app"); // express app
const { initSocket } = require("./socket");

const server = http.createServer(app);
initSocket(server);

server.listen(3000, () => {
  console.log("🚀 Server + Socket running on port 3000");
});
