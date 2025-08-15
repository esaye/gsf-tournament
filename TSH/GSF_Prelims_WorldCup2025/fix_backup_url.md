# 🔧 Fix Backup URL: scrabble.ebrimasaye.com/tournament

## 📊 Current Diagnosis

✅ **Domain accessible**: `scrabble.ebrimasaye.com` responds (301 redirect to HTTPS)  
✅ **Server responding**: Ping successful  
✅ **Files exist locally**: Tournament HTML files ready in `/html/` directory  
❌ **404 Error**: `/tournament` path returns 404 Not Found  

## 🎯 Root Cause
The tournament files have not been uploaded to the `htdocs/tournament/` directory on the web server.

## 🚀 Solution Options

### Option 1: Quick Upload via Archive (Recommended)

```bash
# 1. Create archive of tournament files
cd /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025
tar -czf tournament_files.tar.gz -C html/ .

# 2. Test SSH connection
ssh ebrimasaye@scrabble.ebrimasaye.com "echo 'Connection test successful'"

# 3. Upload archive
scp tournament_files.tar.gz ebrimasaye@scrabble.ebrimasaye.com:~/

# 4. SSH and extract
ssh ebrimasaye@scrabble.ebrimasaye.com
cd htdocs
mkdir -p tournament
cd tournament
tar -xzf ~/tournament_files.tar.gz
rm ~/tournament_files.tar.gz
chmod -R 644 *.html *.css
chmod 755 .
exit

# 5. Test
curl -I https://scrabble.ebrimasaye.com/tournament
```

### Option 2: Direct rsync (If SSH works)

```bash
rsync -avz --progress html/ ebrimasaye@scrabble.ebrimasaye.com:htdocs/tournament/
```

### Option 3: FTP/SFTP (Most reliable)

```bash
# Using SFTP
sftp ebrimasaye@scrabble.ebrimasaye.com
cd htdocs
mkdir tournament
cd tournament
put html/*
quit
```

### Option 4: Web Control Panel (Easiest)

1. Log into your hosting provider's control panel
2. Navigate to File Manager
3. Go to `htdocs/` directory
4. Create `tournament/` folder if it doesn't exist
5. Upload all files from local `html/` directory

## 🔍 Troubleshooting Steps

### 1. Check SSH Access
```bash
ssh ebrimasaye@scrabble.ebrimasaye.com "ls -la htdocs/"
```

### 2. Verify Directory Structure
The correct structure should be:
```
htdocs/
  tournament/
    index.html
    pairings.html
    players.html
    standings.html
    about.html
    tsh.css
    pix/
```

### 3. Check File Permissions
```bash
ssh ebrimasaye@scrabble.ebrimasaye.com "chmod -R 644 htdocs/tournament/*.html && chmod 755 htdocs/tournament"
```

### 4. Test Specific Files
```bash
curl -I https://scrabble.ebrimasaye.com/tournament/index.html
curl -I https://scrabble.ebrimasaye.com/tournament/players.html
```

## 🎯 Quick Test Script

Create and run this test:

```bash
#!/bin/bash
echo "🔍 Testing backup URL fix..."

# Test main domain
echo "1. Testing main domain..."
curl -s -o /dev/null -w "%{http_code}" https://scrabble.ebrimasaye.com
echo

# Test tournament path
echo "2. Testing tournament path..."
curl -s -o /dev/null -w "%{http_code}" https://scrabble.ebrimasaye.com/tournament
echo

# Test with index.html
echo "3. Testing with index.html..."
curl -s -o /dev/null -w "%{http_code}" https://scrabble.ebrimasaye.com/tournament/index.html
echo

echo "✅ If all return 200, the fix worked!"
```

## 🚨 If All Else Fails: Alternative Solutions

### 1. Use Subdomain
Instead of `/tournament`, set up a subdomain:
- `tournament.ebrimasaye.com` or `gsf.ebrimasaye.com`

### 2. Use Different Path
- Try `/gsf/` or `/prelims/` instead of `/tournament/`

### 3. Use GitHub Pages
Upload files to GitHub and use GitHub Pages as backup:
```bash
git init
git add html/*
git commit -m "GSF Tournament files"
git branch -M main
git remote add origin https://github.com/yourusername/gsf-tournament.git
git push -u origin main
```

Then enable GitHub Pages pointing to the repository.

## ⚡ Emergency Backup Plan

If the main backup URL can't be fixed quickly, use these alternatives:

1. **Local server with ngrok**: Already working on port 8090
2. **TSH web interface**: Working on localhost:8088  
3. **Google Drive/Dropbox**: Upload HTML files and share publicly
4. **Alternative hosting**: Upload to Netlify, Vercel, or similar

## 📞 Next Steps

1. Try Option 1 (Archive upload) first
2. If that fails, use web control panel (Option 4)
3. Test the URL: `https://scrabble.ebrimasaye.com/tournament`
4. Verify all pages load correctly
5. Set up auto-sync for future updates

## 🔗 Expected Result

After successful deployment:
- ✅ `https://scrabble.ebrimasaye.com/tournament` → Shows landing page
- ✅ `https://scrabble.ebrimasaye.com/tournament/players.html` → Player list
- ✅ `https://scrabble.ebrimasaye.com/tournament/pairings.html` → Round pairings
- ✅ `https://scrabble.ebrimasaye.com/tournament/standings.html` → Current standings

The backup URL will then be fully functional for the tournament!
