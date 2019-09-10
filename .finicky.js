module.exports = {
  defaultBrowser: "Safari",
  handlers: [
    {
      match: finicky.matchHostnames(["meet.google.com"]),
      browser: "Google Chrome"
    }
  ]
};
