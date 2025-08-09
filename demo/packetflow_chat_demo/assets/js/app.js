// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

Hooks.AutoFocus = {
  mounted() {
    // Small delay to ensure the element is fully rendered
    setTimeout(() => {
      this.el.focus()
      this.el.select()
    }, 10)
  },
  updated() {
    // Also focus when updated
    setTimeout(() => {
      this.el.focus()
      this.el.select()
    }, 10)
  }
}

Hooks.PanelResizer = {
  mounted() {
    this.setupResizer()
  },
  
  setupResizer() {
    const handle = this.el
    let isDragging = false
    let startX = 0
    let startChatWidth = 50
    
    const onMouseDown = (e) => {
      isDragging = true
      startX = e.clientX
      
      // Find current chat width
      const chatPanel = document.querySelector('div[style*="width:"][class*="flex-col"]')
      if (chatPanel && chatPanel.style.width) {
        const match = chatPanel.style.width.match(/(\d+(?:\.\d+)?)%/)
        if (match) {
          startChatWidth = parseFloat(match[1])
        }
      }
      
      // Visual feedback
      handle.style.backgroundColor = '#3b82f6'
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
      
      this.pushEvent('start_panel_resize')
      e.preventDefault()
    }
    
    const onMouseMove = (e) => {
      if (!isDragging) return
      
      const deltaX = e.clientX - startX
      const containerWidth = window.innerWidth - 320 - 16 // Sidebar + handle width
      const deltaPercent = (deltaX / containerWidth) * 100
      
      let newChatWidth = startChatWidth + deltaPercent
      newChatWidth = Math.max(20, Math.min(80, newChatWidth))
      
      this.pushEvent('panel_resize', { chat_width: newChatWidth })
      e.preventDefault()
    }
    
    const onMouseUp = () => {
      if (!isDragging) return
      
      isDragging = false
      
      // Reset visual feedback
      handle.style.backgroundColor = ''
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
      
      this.pushEvent('end_panel_resize')
    }
    
    // Attach events
    handle.addEventListener('mousedown', onMouseDown)
    document.addEventListener('mousemove', onMouseMove)
    document.addEventListener('mouseup', onMouseUp)
    
    // Store cleanup function
    this.cleanup = () => {
      handle.removeEventListener('mousedown', onMouseDown)
      document.removeEventListener('mousemove', onMouseMove)
      document.removeEventListener('mouseup', onMouseUp)
    }
  },
  
  destroyed() {
    if (this.cleanup) {
      this.cleanup()
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show())
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
