import { LightningElement, api } from 'lwc';

export default class ViolationsDemo extends LightningElement {
  @api title = 'Violations Demo';
  imageUrl = 'https://example.com/image.png';

  connectedCallback() {
    // JS violations (typical ESLint / LWC rules): var, unused var, ==, console, eval, api reassignment
    var unused = 123;
    if (unused == '123') {
      console.log('eqeqeq + no-console');
    }
    eval('console.log("no-eval")');

    this.title = 'Mutated @api prop'; // often flagged: no-api-reassignments
  }

  renderedCallback() {
    // Often flagged in LWC: querying document instead of this.template
    const el = document.querySelector('div');
    if (el) {
      // Often flagged / insecure pattern: innerHTML
      el.innerHTML = '<img src=x onerror=alert(1)>';
    }
  }

  handleClick() {
    // Often flagged: implied eval via string-based timeout
    setTimeout("console.log('string timeout')", 10);
  }
}
