module.exports = {
  config: {
    fontSize: 13,
    fontFamily: 'Ubuntu Mono derivative Powerline',
    cursorColor: 'rgba(248,28,229,0.75)',
    installDevTools: {
      extensions: [
        'REACT_DEVELOPER_TOOLS',
        'REDUX_DEVTOOLS'
      ],
      forceDownload: false
    }
  },

  plugins: [
    "hyperlinks",
    "hypertheme",
    "hyperterm-one-light",
    "hyperterm-install-devtools",
    "hyperterm-final-say"
  ],
};
