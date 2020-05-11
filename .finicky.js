module.exports = {
  defaultBrowser: "Safari",
  handlers: [
    {
      match: finicky.matchHostnames([
        /github/, 
        /google/,
        /slack/,
        /onelogin/,
        /2u/,
        /fellow/,
        /zoom/,
        /lucidchart/,
      ]),
      browser: "Google Chrome"
    }
  ]
};
