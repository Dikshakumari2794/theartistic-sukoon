# The Artistic Sukoon 🎨

An online art marketplace and drawing-course platform — browse and buy
original artworks, order custom art, download digital art prints, and
enroll in paid video drawing courses.

**Live site:** https://dikshakumari2794.github.io/theartistic-sukoon/

## Features

- **Marketplace** — browse and buy original artworks (`shop.html`, `product.html`)
- **Custom Orders** — request a custom piece of art (`custom order.html`)
- **Digital Art Prints** — buy and instantly download digital artwork files (`digital-products.html`)
- **Paid Courses** — enroll in video drawing courses; videos unlock only after payment is verified (`courses.html`, `course-player.html`)
- **My Orders** — buyers can track all their orders (marketplace, custom, digital, courses) in one place (`my-orders.html`)
- **Admin Dashboard** — manage artworks, custom orders, digital products, and courses (add/edit/delete, upload thumbnails and videos) (`admin.html`)
- **Payments** — secure checkout via Razorpay, with signature verification done server-side
- **Email notifications** — buyers get a "payment successful" email via EmailJS right after a verified payment

## Tech stack

- **Frontend:** Plain HTML, CSS, JavaScript (no framework/build step)
- **Backend:** [Supabase](https://supabase.com) — Postgres database, Auth, Storage, and Edge Functions
- **Payments:** [Razorpay](https://razorpay.com) — order creation + payment verification via Supabase Edge Functions
- **Email:** [EmailJS](https://www.emailjs.com) — client-side order/payment confirmation emails
- **Hosting:** Netlify (primary) and GitHub Pages

## Project structure

```
├── index.html, shop.html, product.html      → Marketplace
├── custom order.html                        → Custom art orders
├── digital-products.html                    → Digital art prints
├── courses.html, course-player.html         → Paid video courses
├── my-orders.html, profile.html             → Buyer account pages
├── login.html, signup.html                  → Auth pages
├── admin.html                               → Admin dashboard
├── sql/                                      → Supabase database setup scripts
└── edge-functions/                           → Supabase Edge Function source (Razorpay order + verification)
```

## Database & backend setup

The SQL scripts in `sql/` set up the tables, Row Level Security policies,
and storage buckets this site depends on. Run them in the Supabase SQL
Editor (in order, they are safe to re-run). The code in `edge-functions/`
needs to be deployed to the matching Supabase Edge Function from the
Supabase Dashboard.
