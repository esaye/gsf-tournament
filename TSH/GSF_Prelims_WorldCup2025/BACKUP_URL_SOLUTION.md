# 🎯 SOLUTION: Fix scrabble.ebrimasaye.com/tournament

## 🔍 Problem Identified
- ✅ Domain works: `scrabble.ebrimasaye.com` 
- ❌ SSH disabled: Cannot connect via SSH/rsync/scp
- ❌ Files missing: `/tournament` returns 404
- ✅ Files ready: Local HTML files exist in `html/` directory

## 🚀 IMMEDIATE SOLUTION (Choose One)

### Method 1: Hosting Control Panel (RECOMMENDED)

1. **Log into your hosting provider's control panel**
   - cPanel, Plesk, or similar web interface
   - Usually accessible at: `scrabble.ebrimasaye.com:2083` or similar

2. **Navigate to File Manager**
   - Look for "File Manager" or "Files" section
   - Go to `public_html/` or `htdocs/` directory

3. **Create tournament directory**
   ```
   htdocs/
     tournament/  ← Create this folder
   ```

4. **Upload tournament files**
   - Upload all files from your local `html/` directory:
     - `index.html`
     - `players.html` 
     - `pairings.html`
     - `standings.html`
     - `about.html`
     - `tsh.css`
     - `pix/` folder (if exists)

5. **Set correct permissions**
   - Files: 644 (readable by web server)
   - Directories: 755 (accessible by web server)

### Method 2: FTP/SFTP Upload

1. **Use FTP client** (FileZilla, WinSCP, etc.)
   ```
   Host: scrabble.ebrimasaye.com
   Port: 21 (FTP) or 22 (SFTP) 
   Username: [your hosting username]
   Password: [your hosting password]
   ```

2. **Navigate to web directory**
   - Usually `public_html/` or `htdocs/`

3. **Create and upload to tournament folder**
   ```
   /htdocs/tournament/
   ```

4. **Upload all files from local html/ directory**

### Method 3: Alternative Hosting (Quick Fix)

If the above doesn't work, use GitHub Pages as immediate backup:

```bash
cd /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025/html
git init
git add .
git commit -m "GSF Tournament Website"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/gsf-tournament.git
git push -u origin main
```

Then enable GitHub Pages → Result: `https://YOUR_USERNAME.github.io/gsf-tournament`

## 📋 File Checklist

Ensure these files are uploaded to `/tournament/` directory:

```
tournament/
├── index.html          ← Landing page
├── players.html        ← Player list  
├── pairings.html       ← Round pairings
├── standings.html      ← Current standings
├── about.html          ← Tournament info
├── tsh.css            ← Styling
└── pix/               ← Images folder
    └── (any images)
```

## 🧪 Testing Steps

After upload, test these URLs:

```bash
# 1. Main tournament page
curl -I https://scrabble.ebrimasaye.com/tournament
# Expected: 200 OK

# 2. Landing page
curl -I https://scrabble.ebrimasaye.com/tournament/index.html  
# Expected: 200 OK

# 3. Player list
curl -I https://scrabble.ebrimasaye.com/tournament/players.html
# Expected: 200 OK

# 4. Pairings
curl -I https://scrabble.ebrimasaye.com/tournament/pairings.html
# Expected: 200 OK
```

Or simply visit in browser:
- `https://scrabble.ebrimasaye.com/tournament`

## 🎯 Quick Test Command

Run this to verify the fix:

```bash
echo "Testing backup URL fix..."
echo "Main site: $(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com)"
echo "Tournament: $(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament)"
echo "Index: $(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/index.html)"
echo "Players: $(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/players.html)"
echo ""
echo "All should return '200' for success!"
```

## 🚨 If Still Not Working

### Check Common Issues:

1. **Wrong directory**: Ensure files are in `htdocs/tournament/` not `htdocs/` 
2. **Permissions**: Files need 644, directories need 755
3. **Case sensitivity**: Use exact filenames (lowercase)
4. **Missing index**: Some servers need `index.html` or will show directory listing

### Alternative Paths:
If `/tournament` doesn't work, try:
- `/gsf/`
- `/prelims/` 
- `/scrabble/`

### Server Configuration:
May need to add to `.htaccess`:
```apache
DirectoryIndex index.html
Options +Indexes
```

## ✅ Success Indicators

When fixed, you should see:
- ✅ No more 404 error
- ✅ Tournament landing page displays
- ✅ Navigation links work
- ✅ Player data loads
- ✅ CSS styling applies

## 📞 Emergency Contacts

If hosting control panel access is needed:
1. Check email for hosting provider login details
2. Contact hosting provider support
3. Use "forgot password" on hosting control panel

## 🎉 Expected Result

After successful fix:
```
https://scrabble.ebrimasaye.com/tournament
```
Will show the beautiful GSF tournament landing page with:
- Tournament title and Gambian flag
- Live stats and player counts  
- Navigation to all tournament sections
- Mobile-friendly responsive design

The backup URL will be fully functional! 🇬🇲
