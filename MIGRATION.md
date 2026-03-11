# Migration Guide: NASManager 1.0 → 2.0

This guide helps you migrate from the original single-file NASManager to the new modular version 2.0.

## What's Changed

### Architecture
- **Before**: Single 616-line Swift file
- **After**: Modular architecture with 20+ files organized by purpose

### Features Added
- Multi-folder sync (not just Downloads)
- Full window interface with 6 tabs
- Enhanced activity logging (1000 entries vs 20)
- Statistics tracking with charts
- Bandwidth controls
- Keychain password storage
- Pause/resume functionality
- Connection quality monitoring
- Disk space monitoring

### Settings Preservation

Your existing settings will be automatically preserved:
- ✅ NAS hostname
- ✅ NAS username
- ✅ NAS shares list
- ✅ Downloads path
- ✅ Check interval

**Note**: You'll need to re-enter your NAS password (it will now be stored securely in Keychain).

## Migration Steps

### 1. Backup Your Current Setup (Optional)

```bash
# Backup your current settings
defaults read com.ryanas.nasmanager > ~/nasmanager-backup.plist
```

### 2. Quit the Old Version

If the old NASManager is running:
1. Click the menu bar icon
2. Select "Quit"

### 3. Build and Install Version 2.0

```bash
cd /Users/rolson/Developer/NASManager
./build.sh
```

The new version will:
- Automatically install to `~/Applications/NASManager.app`
- Replace the old version
- Launch automatically

### 4. First Launch Configuration

1. **Open the Main Window**
   - Click the NASManager menu bar icon
   - Select "Open NASManager"

2. **Verify General Settings** (General Tab)
   - Your hostname, username, shares should already be populated
   - **Re-enter your NAS password** (for Keychain storage)
   - Click "Save Settings"

3. **Configure Sync Folders** (Sync Folders Tab)
   - The old Downloads sync is NOT automatically migrated
   - Click "Add Folder"
   - Select "Downloads" from presets (or customize)
   - Add other folders: Pictures, Movies, Documents, Music, etc.
   - Click "Add" for each folder

4. **Review Advanced Settings** (Advanced Tab)
   - Set bandwidth limit if desired (0 = unlimited)
   - Configure WiFi restrictions (optional)
   - Enable "Only sync on AC power" for laptops (optional)

5. **Enable Launch at Login** (General Tab)
   - Check "Launch at Login" if you want NASManager to start automatically

## Key Differences in Behavior

### Downloads Folder Handling

**Version 1.0**:
- Automatically created symlink: `~/Downloads` → `/Volumes/home/Downloads`
- Synced on every check cycle
- Removed symlink when NAS offline

**Version 2.0**:
- Downloads is just one of many sync folders
- No automatic symlink creation/removal
- Sync on-demand or scheduled
- More control over when and how it syncs

**Migration Note**: If you relied on the automatic symlink behavior, you'll need to:
1. Add Downloads as a sync folder
2. Manually create the symlink if desired: `ln -s /Volumes/home/Downloads ~/Downloads`

### Sync Behavior

**Version 1.0**:
- Automatic sync every check interval
- Only Downloads folder

**Version 2.0**:
- Manual sync (click "Sync All" or sync individual folders)
- Multiple folders supported
- Queue-based system
- Pause/resume capability

**To get automatic sync**: You can still trigger syncs from the menu bar or set up a scheduled task.

## New Features to Explore

### 1. Multi-Folder Sync
Add all your media folders:
- Pictures → `/Volumes/home/Pictures`
- Movies → `/Volumes/Plex/Movies`
- Documents → `/Volumes/home/Documents`
- Music → `/Volumes/home/Music`

### 2. Activity Log
- View detailed logs of all operations
- Search and filter by level/category
- Export logs for troubleshooting

### 3. Statistics
- Track total data transferred
- View sync success rates
- See historical charts (macOS 13+)

### 4. Bandwidth Control
- Limit transfer speed to avoid saturating network
- Set in Advanced tab (KB/s)

### 5. Connection Monitoring
- Real-time connection quality metrics
- Disk space monitoring
- Health checks

## Troubleshooting Migration Issues

### Settings Not Preserved

If your settings didn't carry over:

```bash
# Check if old settings exist
defaults read com.ryanas.nasmanager

# Manually set if needed
defaults write com.ryanas.nasmanager nasHostname "RyaNAS.local"
defaults write com.ryanas.nasmanager nasUsername "admin"
defaults write com.ryanas.nasmanager nasShares "home, Plex, Public"
```

### Downloads Symlink Missing

If you need the old symlink behavior:

```bash
# Remove existing Downloads folder (backup first!)
mv ~/Downloads ~/Downloads.backup

# Create symlink
ln -s /Volumes/home/Downloads ~/Downloads

# Sync the backup to NAS
rsync -a ~/Downloads.backup/ /Volumes/home/Downloads/
```

### App Won't Launch

```bash
# Check for errors
open ~/Applications/NASManager.app

# View logs
log show --predicate 'process == "NASManager"' --last 5m
```

### Build Errors

Ensure you have:
- macOS 12.0 or later
- Xcode Command Line Tools: `xcode-select --install`
- All source files in correct directories

## Reverting to Version 1.0

If you need to revert:

1. Quit NASManager 2.0
2. Restore the old single-file version:
   ```bash
   cd /Users/rolson/Developer/NASManager
   git checkout <old-commit-hash> NASManager.swift
   ```
3. Build the old version:
   ```bash
   swiftc NASManager.swift -o NASManager \
       -framework Cocoa -framework UserNotifications
   ```

## Getting Help

### Check Activity Log
The Activity Log (in the main window) shows detailed information about what's happening.

### Export Logs
In the Activity Log tab, click "Export" to save logs for analysis.

### Common Issues

**"NAS: Offline" in menu bar**
- Check hostname is correct
- Verify NAS is powered on and accessible
- Try pinging: `ping RyaNAS.local`

**Sync not starting**
- Ensure folder is enabled (toggle in Sync Folders tab)
- Check that NAS is connected
- Verify paths exist and are writable

**Password not saving**
- Re-enter password in General tab
- Click "Save Settings"
- Check Keychain Access app for entry

## Recommended Post-Migration Setup

1. **Add all your media folders** (Sync Folders tab)
2. **Set bandwidth limit** if on slow network (Advanced tab)
3. **Enable launch at login** (General tab)
4. **Test sync** with one folder first
5. **Monitor Activity Log** for any errors
6. **Review Statistics** after first successful sync

## Questions?

The new version is designed to be more powerful and flexible while maintaining the simplicity of the original. Take time to explore the new features in the main window!
