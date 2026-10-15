# Launch images: source

`posters.html` draws the launch images (cover, AI scanner, AI summaries, offline, square social post) with the app's font and colours. `?p=cover|scan|summary|offline|social` picks one.

To regenerate: put these next to it, then screenshot each at 1600×900 (social: 1080×1080) with device scale 2:
- `logo_mark.png` from `lifeflow_app/assets/images/`
- `phone-dashboard.png`, `phone-ai-summary.png`, `phone-login-offline.png`, `desktop-ai-summary.png` from `Screenshots/`
- `p-receipt-review.png`, `p-wish-review.png`: the scan review screens (`Screenshots/phone-scan-*.jpg`)
- `receipt.png`, `wishlist-note.png`: screenshots of `receipt.html` (600×760) and `wishlist.html` (420×640)

`receipt.json` and `wishlist.json` are the scan results used for the review screens; they match the API's `POST /scan` reply format, so the screens are the real app.
