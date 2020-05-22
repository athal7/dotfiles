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
        /imsglobal/,
      ]),
      browser: "Google Chrome"
    }
  ]
};
