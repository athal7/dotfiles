module.exports = {
  defaultBrowser: "Safari",
  handlers: [
    {
      match: finicky.matchHostnames([
        "github.com", 
        /.*\.google.com$/,
        /.*\.slack.com$/,
        /.*\.onelogin.com$/,
        /.*\.2u.com$/,
      ]),
      browser: "Google Chrome"
    }
  ]
};
