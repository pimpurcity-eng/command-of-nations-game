# Command of Nations website

Static pages for the game's domain: home, privacy policy (required by Google Play because the game
has accounts) and account deletion (Google Play requires a web deletion page).

Before publishing, replace the placeholders everywhere:

    SUPPORT_EMAIL   e.g. support@your-domain.com
    EMAIL_PROVIDER  the email service chosen (e.g. Resend or Postmark)
    EFFECTIVE_DATE  the date the policy goes live

    sed -i 's/SUPPORT_EMAIL/support@your-domain.com/g; s/EMAIL_PROVIDER/Resend/g; s/EFFECTIVE_DATE/1 November 2026/g' site/*.html

Hosting: Cloudflare Pages or GitHub Pages (free) with the domain pointed at it. In Play Console,
use https://your-domain/privacy.html as the privacy policy URL and
https://your-domain/delete-account.html as the account deletion URL.
