module.exports = {
  config: {
    fontSize: 12,
    fontFamily: 'Ubuntu Mono derivative Powerline',
    cursorColor: 'rgba(248,28,229,0.75)',
    backgroundColor: "#212121",
    env: {
      "SHELL": "/usr/local/bin/zsh"
    },
    installDevTools: {
      extensions: [
        'REACT_DEVELOPER_TOOLS',
        'REDUX_DEVTOOLS'
      ],
      forceDownload: false
    },
    shell: "/usr/local/bin/zsh",
    showWindowControls: false,
    defaultSSHApp: true
  },

  plugins: [
    "hyperlinks",
    "hypertheme",
    "hyper-hybrid-reduced-contrast",
    "hyperterm-final-say",
    "hyperterm-install-devtools",
    "hyper-blink",
    "hyper-search"
  ],
};
