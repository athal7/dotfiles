module.exports = {
  config: {
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
    "hyperterm-gooey",
    "hyperterm-install-devtools",
    "hyper-blink",
    "hyper-search"
  ],
};
