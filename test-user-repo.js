const userRepo = require("./src/repositories/user.repository");

(async () => {
  const user = await userRepo.createUser("+33699999999");
  console.log(user);
})();
