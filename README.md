# Expense Manager

A single-page expense tracker (`index.html`) that you can install as an app. Without logging in, data stays in the browser. After you log in, your data is **encrypted in the browser** and saved to your **Supabase** project. From there you can use it on any device and share expense books with friends. You don't have to run a server of your own.

## Run locally

```
node server.js
```

Open http://localhost:8000. Login does not work when `index.html` is opened directly as a file.

---

## One-time Supabase setup (about 10 minutes)

### Step 1: Create a free Supabase project
1. Go to https://supabase.com and click **Start your project**. Sign up with GitHub or email.
2. Click **New project**.
   - **Name:** `expense-manager` (any name works)
   - **Database password:** click **Generate a password** and save it somewhere. The app doesn't need it.
   - **Region:** the one closest to you, for example *Mumbai (ap-south-1)*.
   - **Plan:** Free
3. Click **Create new project** and wait about 1 minute until the dashboard is ready.

### Step 2: Create the tables and security rules
1. In the left sidebar, open **SQL Editor** and click **New query**.
2. Open `supabase-setup.sql` from this folder, copy **all** of it, and paste it into the editor.
3. Click **Run**. You should see *Success. No rows returned*.
   This creates three tables (`vaults`, `shared_books`, `book_members`), the rules that let each person see only their own data and the books shared with them, and live updates.

### Step 3: Set up email login
1. Open **Authentication → Sign In / Providers** (called **Providers** in some versions).
2. Make sure **Email** is **enabled**. Leave "Confirm email" on.
3. Open **Authentication → URL Configuration**:
   - **Site URL:** `http://localhost:8000`
   - **Redirect URLs:** click **Add URL** and add `http://localhost:8000/**`
   - When you put the app online later, add that address too, for example `https://yourname.github.io/**`.
4. Click **Save**.

> The free plan sends a limited number of login emails per hour (a few), which is fine for you and your friends. For more, set up your own SMTP under **Authentication → Emails → SMTP Settings**.

### Step 4: Copy your project URL and key into the app
1. Open **Project Settings** (gear icon) **→ Data API**, or **API** in older versions.
2. Copy the **Project URL**, which looks like `https://abcdxyz.supabase.co`. Use only this part, **not** the longer "RESTful endpoint" ending in `/rest/v1/`. The app now removes that ending automatically anyway.
3. Open **Project Settings → API Keys** and copy the **anon / public** key (a long text starting with `eyJ…`, or `sb_publishable_…` in newer projects).
   - It's safe to put this key in the web page; the security rules from Step 2 protect the data.
   - **Never** use the `service_role` / secret key in the app.
4. In `index.html`, find these lines and paste your values:
   ```js
   const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
   const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
   ```
5. In the same place, change `APP_SECRET` to your own long random string. **Do this before first use and never change it afterwards**, because all saved data is encrypted with it.

### Step 5: Try it
1. Run `node server.js` and open http://localhost:8000.
2. Click **🔑 Log in / Sign up**, enter your email, and click **Email me a sign-in link**.
3. Open the email and tap **Log In** (the sign-in link). You come back to the app, logged in. Anything you entered before logging in is moved into your account.
4. The header shows your name and **☁️ Saved · 🔒 encrypted**.

### Step 6 (optional): "Continue with Google"
1. Create a Google OAuth client at https://console.cloud.google.com/apis/credentials (**Web application**).
   - **Authorized redirect URI:** the **Callback URL** shown in Supabase under **Authentication → Providers → Google**.
2. In Supabase, open **Authentication → Providers → Google**, turn it on, and paste the Google *Client ID* and *Client secret*.
3. In `index.html`, set `const SUPABASE_GOOGLE_LOGIN = true;`.

---

## Install as an app (PWA) and link previews

**Install:** once the app is online (https) or at http://localhost:8000:
- Android / Chrome / Edge: tap **📲 Install app** on the home screen, or use the browser menu → *Install app*.
- iPhone (Safari): **Share** → **Add to Home Screen**.

It then opens full-screen with its own icon, and it opens even without internet. Your data still syncs once you're back online.

**Logo and title in WhatsApp and other apps:** the page has link-preview tags (`og:*`, `twitter:*`) and a share image `icons/og-image.jpg` (1200×630). WhatsApp only reads them from a **public https address** (not localhost), and it needs the **full** image address. After you put the app online, run this once with your site's address:
```
node set-site-url.js https://yourname.github.io/expense-manager/
```
Then upload the changed `index.html` again. WhatsApp caches previews, so if you shared the link before, test with a new link, for example add `?v=2`.

Files: `manifest.webmanifest` (app name, colours, icons), `sw.js` (offline copy), `icons/` (app icons and share image).

## Sharing with friends
1. Open **📋 View Your Expenses** and tap **🔗** on any book, including **My Monthly Expenses**. Once it's shared, its **Quick access** card on the home screen opens the shared copy. Others see it as *"yourname's Monthly Expenses"*.
2. Type your friend's email and choose **✏️ Can edit** or **👁 Can view**, then tap **Share**.
3. Tap **📋 Copy invite message** and send it to them on WhatsApp or by email. Supabase does not email invites itself.
4. Your friend opens the app and logs in **with that same email**. The book appears under **👥 Shared with you** on its own. There's nothing to pick or accept.
5. Edits show up for everyone within a second or two (live updates).
6. Tap **♡** on any book, your own or a shared one, to add it to **⚡ Quick access** on the home screen. Tap **♥** to remove it. **My Monthly Expenses** is always first in Quick access and can't be removed.
7. Your shared books show who they're shared with (e.g. *Shared with bob ✏️, carol 👁*). **👥 Shared with you** groups books by the person who shared them.
8. **People with access** on the share screen lets you switch someone between *Can view* and *Can edit*, or remove them (✕). **⏏ Stop sharing** takes everyone's access away and makes the book private again, with all entries and notes kept.
9. **🗑** on the card deletes the book for everyone. A friend can leave a shared book with **✕** on their card.

## How data is stored

| Item | Where |
|------|-------|
| Your books, entries, month notes, payment options, card cycles, Quick access stars | Table `vaults`: one row per user, the whole thing **encrypted** (AES-256-GCM). The key comes from `APP_SECRET` plus your account id through PBKDF2 (310,000 rounds). |
| Shared books | Table `shared_books`: one encrypted row per shared book. Table `book_members` lists who it's shared with (email + can view / can edit). |
| Before logging in | Browser localStorage. It moves into your account on first login. |

The database only ever sees encrypted text. Row Level Security makes sure people can read only their own vault and the books shared with their email, and only editors can change a shared book.

`APP_SECRET` is in the page code, so someone who has both that code **and** access to your database rows could decrypt them. For a personal and friends app this is a reasonable trade-off. Keep your Supabase dashboard login safe.

## Free-plan notes
- 500 MB database, which is far more than expense data needs.
- A free project **pauses after 7 days with no activity**. Open the dashboard and click **Restore** if that happens; no data is lost.
- If the same entry is edited on two devices at the same moment, the last save wins.
