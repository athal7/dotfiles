module.exports = {
    config: {
        env: {
            SHELL: '/usr/local/bin/zsh',
        },
        installDevTools: {
            extensions: ['REACT_DEVELOPER_TOOLS', 'REDUX_DEVTOOLS'],
            forceDownload: false,
        },
        shell: '/usr/local/bin/zsh',
        defaultSSHApp: true,
        fontFamily: 'Fira Code',
        webGLRenderer: false,
    },

    plugins: [
        'hyperlinks',
        'hypertheme',
        'hyper-blink',
        'hyper-search',
        'hyper-font-ligatures',
        'hyper-dracula',
        'hyper-hide-title',
    ],
}
