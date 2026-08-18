import { Controller } from "@hotwired/stimulus"

// A one-time "don't treat this as the final word" notice — separate from
// cookie consent (different topic entirely: this is about content
// reliability, not tracking) and shown regardless of environment, since
// it's not privacy-sensitive like the GA gate is. Dismissed state persists
// in localStorage so it only interrupts a first visit, not every one.
export default class extends Controller {
  static targets = ["modal"]

  connect() {
    if (!localStorage.getItem("disclaimer-seen")) {
      this.modalTarget.hidden = false
    }
  }

  dismiss() {
    localStorage.setItem("disclaimer-seen", "true")
    this.modalTarget.hidden = true
  }
}
