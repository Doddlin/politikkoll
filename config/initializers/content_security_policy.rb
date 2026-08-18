# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self

    # No inline <script> written by this app (verified) — but
    # javascript_importmap_tags itself renders two inline blocks (the
    # importmap JSON and the module bootstrap), which is exactly what
    # nonces below are for, rather than a blanket 'unsafe-inline'. The two
    # external hosts: gtag.js itself (only ever loaded after cookie
    # consent — see cookie_consent_controller.js) and Cloudflare's Web
    # Analytics beacon, if that's enabled on the zone (harmless to allow
    # if it isn't).
    policy.script_src :self,
      "https://www.googletagmanager.com",
      "https://static.cloudflareinsights.com"

    # Inline style="" is used in a handful of views for dynamic values
    # (party colors, gradient widths on the geography bars) — real
    # attacker-controlled-CSS risk is low since script-src is what actually
    # stops XSS, but be aware this directive isn't providing much on its
    # own. The @font-face block in the layout's <style> tag needs this too.
    policy.style_src :self, :unsafe_inline

    policy.font_src :self
    policy.img_src :self, :data

    # GA4's collect calls land on a regional google-analytics.com
    # subdomain that varies — wildcarded rather than guessing the exact one.
    policy.connect_src :self,
      "https://www.googletagmanager.com",
      "https://*.google-analytics.com"

    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :self
  end

  # Must be a value that's stable across multiple calls within the same
  # request (the header and each inline script tag all call this
  # independently and need to agree) — SecureRandom.base64 generates a
  # fresh value per call, which silently produces a mismatched nonce that
  # blocks the very script it was meant to allow. session.id is what
  # Rails' own guide recommends for exactly this reason.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Flip to true to log violations without blocking anything, if you want
  # to sanity-check a future change before it can break something live.
  # config.content_security_policy_report_only = true
end
