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
        /localhost/,
        /127.0.0.1/,
      ]),
      browser: "Google Chrome"
    }
  ]
};
