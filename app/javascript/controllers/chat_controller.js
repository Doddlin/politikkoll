import { Controller } from "@hotwired/stimulus"

// Drives the chat thread's "feels alive" behavior around a plain Turbo
// form submission: an instant thinking indicator (removed by the server's
// turbo_stream response once the real reply lands), auto-scroll on any new
// message, and re-enabling the input afterward. No fetch/XHR of our own —
// Turbo already handles the actual request/response.
export default class extends Controller {
  static targets = ["thread", "input", "submit", "emptyState"]
  static values = { thinkingLabel: String }

  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.threadTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  thinking() {
    if (!this.inputTarget.value.trim()) return

    this.submitTarget.disabled = true
    if (this.hasEmptyStateTarget) this.emptyStateTarget.remove()

    const bubble = document.createElement("div")
    bubble.className = "bubble assistant thinking"
    bubble.id = "thinking-bubble"
    bubble.innerHTML = `<p class="who">${this.thinkingLabelValue}</p><div class="thinking-dots"><span></span><span></span><span></span></div>`
    this.threadTarget.appendChild(bubble)

    this.inputTarget.value = ""
  }

  done() {
    this.submitTarget.disabled = false
    this.inputTarget.focus()
  }

  // .thread doesn't actually have a bounded height in this layout (.page
  // only sets min-height: 100vh), so it never becomes its own scroll
  // container — the window scrolls instead.
  scrollToBottom() {
    window.scrollTo(0, document.body.scrollHeight)
  }
}
