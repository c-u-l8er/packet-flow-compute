// Simple topbar implementation
const topbar = {
  show() {
    // Create progress bar if it doesn't exist
    if (!this.bar) {
      this.bar = document.createElement('div');
      this.bar.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 0%;
        height: 2px;
        background: #29d;
        z-index: 9999;
        transition: width 0.2s ease;
      `;
      document.body.appendChild(this.bar);
    }
    
    // Animate progress bar
    this.bar.style.width = '100%';
    setTimeout(() => {
      this.bar.style.width = '0%';
    }, 100);
  },
  
  hide() {
    if (this.bar) {
      this.bar.style.width = '0%';
    }
  },
  
  config(options) {
    // Store configuration
    this.options = options;
  }
};

export default topbar;
