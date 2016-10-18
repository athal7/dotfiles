const backgroundColor = '#282c34'
const foregroundColor = '#abb2bf'
const cursorColor = foregroundColor
const borderColor = backgroundColor

const colors = [
  backgroundColor,
  '#e06c75', // red
  '#98c379', // green
  '#d19a66', // yellow
  '#56b6c2', // blue
  '#c678dd', // pink
  '#56b6c2', // cyan
  '#d0d0d0', // light gray
  '#808080', // medium gray
  '#e06c75', // red
  '#98c379', // green
  '#d19a66', // yellow
  '#56b6c2', // blue
  '#c678dd', // pink
  '#56b6c2', // cyan
  '#ffffff', // white
  foregroundColor
]

exports.decorateConfig = config => {
  return Object.assign({}, config, {
    foregroundColor,
    backgroundColor,
    borderColor,
    cursorColor,
    colors,
    termCSS: `
      ${config.termCSS || ''}
      * {
        text-rendering: optimizeLegibility;
      }
    `,
    css: `
      ${config.css || ''}
      .header_header {
        top: 0;
        right: 0;
        left: 0;
      }
      .terms_terms {
        margin-top: 42px;
      }
      .tabs_list {
        max-height: 42px;
        background-color: #21252b !important;
        border-bottom-color: rgba(0,0,0,.15) !important;
      }
      .tab_text {
        height: 42px; font-size: 14px;
      }
      .tab_textInner {
        top: 4px;
      }
      .tab_hasActivity {
        color: #56b6c2;
      }
      .tab_tab.tab_active {
        font-weight: 500;
        background-color: ${backgroundColor};
        border-color: rgba(0,0,0,.27) !important;
      }
      .tab_tab.tab_active::before {
        border-bottom-color: ${backgroundColor};
      }
    `
  })
}
