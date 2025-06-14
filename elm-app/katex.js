const init = async function(app) {

  console.log("I am starting elm-katex: init");

  var katexJs = document.createElement('script');
  katexJs.type = 'text/javascript';
  katexJs.onload = function() {
    console.log("elm-katex: katex loading");
    initKatex();
    console.log("elm-katex: mhchem loading");
    loadMhchem();
  };
  katexJs.src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js";

  document.head.appendChild(katexJs);
  console.log("elm-katex: I have appended katexJs to document.head");
}

function loadMhchem() {
  var mhChemJs = document.createElement('script');
  mhChemJs.type = 'text/javascript';
  mhChemJs.onload = function() {
    console.log("elm-katex: mhchem loaded");
  };
  mhChemJs.src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/mhchem.min.js";

  document.head.appendChild(mhChemJs);
  console.log("elm-katex: I have appended mhChemJs to document.head");
}

function initKatex() {
  console.log("elm-katex: initializing");

  class MathText extends HTMLElement {
    constructor() {
      super();
    }

    connectedCallback() {
      this.attachShadow({mode: "open"});
      this.shadowRoot.innerHTML =
        katex.renderToString(
          this.content,
          {
            throwOnError: false,
            displayMode: this.display,
            trust: true // Allows mhchem to be used
          }
        );
      let link = document.createElement('link');
      link.setAttribute('rel', 'stylesheet');
      link.setAttribute('href', 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css');
      this.shadowRoot.appendChild(link);
    }
  }

  customElements.define('math-text', MathText);
}
