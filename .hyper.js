module.exports = {
  config: {
    env: {
      SHELL: "/usr/local/bin/zsh"
    },
    installDevTools: {
      extensions: ["REACT_DEVELOPER_TOOLS", "REDUX_DEVTOOLS"],
      forceDownload: false
    },
    shell: "/usr/local/bin/zsh",
    defaultSSHApp: true,
    fontSize: 13
  },

  plugins: [
    "hyperlinks",
    "hypertheme",
    "hyper-one-dark",
    "hyperterm-install-devtools",
    "hyper-blink",
    "hyper-search"
  ]
};
