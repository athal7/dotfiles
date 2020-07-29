module.exports = {
    defaultBrowser: 'Safari',
    handlers: [
        {
            match: finicky.matchHostnames([/meet.google/]),
            browser: 'Google Chrome',
        },
    ],
}
