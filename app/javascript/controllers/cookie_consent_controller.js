import { Controller } from "@hotwired/stimulus"

// Default-deny cookie consent: nothing from Google loads — not even the
// gtag.js script tag itself — until the visitor explicitly clicks Accept.
// No pre-ticked boxes, no "continuing to browse counts as consent"; Decline
// is the same size/weight as Accept, not a buried afterthought. The choice
// persists in localStorage (no cookie needed just to remember "no
// cookies"), and a small corner link lets you reopen the banner and change
// your mind later — declining also sweeps any _ga* cookies already set
// from an earlier "accept", so withdrawing consent actually withdraws it.
export default class extends Controller {
  static targets = ["banner", "reopenLink"]
  static values = { measurementId: String }

  connect() {
    const consent = localStorage.getItem("cookie-consent")

    if (consent === "granted") {
      this.loadGtag()
      this.showReopenLink()
    } else if (consent === "denied") {
      this.showReopenLink()
    } else {
      this.showBanner()
    }
  }

  accept() {
    localStorage.setItem("cookie-consent", "granted")
    this.hideBanner()
    this.showReopenLink()
    this.loadGtag()
  }

  decline() {
    localStorage.setItem("cookie-consent", "denied")
    this.hideBanner()
    this.showReopenLink()
    this.clearGoogleCookies()
  }

  reopen(event) {
    event.preventDefault()
    this.hideReopenLink()
    this.showBanner()
  }

  showBanner() { this.bannerTarget.hidden = false }
  hideBanner() { this.bannerTarget.hidden = true }
  showReopenLink() { this.reopenLinkTarget.hidden = false }
  hideReopenLink() { this.reopenLinkTarget.hidden = true }

  loadGtag() {
    if (window.gtagLoaded) return
    window.gtagLoaded = true

    window.dataLayer = window.dataLayer || []
    window.gtag = function gtag() { window.dataLayer.push(arguments) }
    window.gtag("js", new Date())
    window.gtag("config", this.measurementIdValue)

    const script = document.createElement("script")
    script.async = true
    script.src = `https://www.googletagmanager.com/gtag/js?id=${this.measurementIdValue}`
    document.head.appendChild(script)
  }

  clearGoogleCookies() {
    document.cookie.split(";").forEach((entry) => {
      const name = entry.split("=")[0].trim()
      if (name === "_gid" || name.startsWith("_ga")) {
        document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/`
        document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=.${location.hostname}`
      }
    })
  }
}
