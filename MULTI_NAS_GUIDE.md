# Multi-NAS Support Guide

The Annex 2.0 now supports managing multiple NAS devices simultaneously, with automatic discovery and per-folder NAS assignment.

## Features

### ✅ Multiple NAS Devices
- Configure unlimited NAS devices
- Each device has its own credentials (stored in Keychain)
- Set one device as default
- Star icon indicates default NAS

### ✅ NAS Discovery
- **Scan Network** button automatically finds NAS devices on your local network
- Detects common NAS hostnames:
  - MyNAS.local
  - synology.local
  - qnap.local
  - freenas.local / truenas.local
  - nas.local
- Uses Bonjour/mDNS for SMB service discovery
- Click discovered device to auto-fill hostname and name

### ✅ Per-Folder NAS Assignment
- Each sync folder can target a different NAS device
- Mix and match: Pictures → NAS1, Movies → NAS2, etc.
- Flexible configuration for complex setups

## How to Use

### Adding Your First NAS

1. **Open The Annex** from menu bar
2. Go to **General** tab
3. Click **"Add NAS"** button
4. Click **"Scan Network"** to discover devices
5. Select a discovered device or manually enter:
   - Name (e.g., "MyNAS")
   - Hostname (e.g., "MyNAS.local")
   - Username (e.g., "admin")
   - Password (stored securely in Keychain)
   - Shares (comma-separated: "home, Plex, Public")
6. Click **"Add"**

### Adding Additional NAS Devices

Repeat the same process for each NAS device you want to manage. You can have:
- Home NAS for personal files
- Media NAS for Plex/Movies
- Backup NAS for archives
- Office NAS for work files

### Setting Default NAS

Click the **star icon** next to any NAS device to set it as default. The default NAS is used for:
- Connection quality monitoring
- Disk space display in menu bar
- Default selection when creating new sync folders

### Managing NAS Devices

**Edit a NAS:**
- Click the pencil icon
- Update name, hostname, username, password, or shares
- Click "Save"

**Delete a NAS:**
- Click the trash icon (red)
- Confirm deletion
- Note: Sync folders using this NAS will need to be reconfigured

**View NAS Status:**
- Menu bar shows total configured devices
- Connection quality for default NAS
- Disk space for default NAS

## Use Cases

### Single NAS Setup
Perfect for most users:
- One NAS device
- All folders sync to same NAS
- Simple and straightforward

### Multi-NAS Home Setup
For users with multiple NAS devices:
```
Home NAS (MyNAS.local)
├── Documents → /Volumes/home/Documents
├── Pictures → /Volumes/home/Pictures
└── Downloads → /Volumes/home/Downloads

Media NAS (MediaServer.local)
├── Movies → /Volumes/Plex/Movies
├── TV Shows → /Volumes/Plex/TV
└── Music → /Volumes/Music/Library
```

### Office + Home Setup
Separate work and personal:
```
Home NAS
├── Personal Pictures
├── Family Videos
└── Personal Documents

Office NAS
├── Work Documents
├── Projects
└── Client Files
```

### Backup Strategy
Primary + backup NAS:
```
Primary NAS (fast SSD)
├── Active Projects
└── Current Work

Backup NAS (large HDD)
├── Archives
├── Backups
└── Long-term Storage
```

## Network Discovery Details

### How It Works

1. **Bonjour/mDNS Discovery**: Scans for `_smb._tcp` services
2. **Common Hostname Ping**: Tests well-known NAS hostnames
3. **Results**: Shows discovered devices with name and hostname

### Troubleshooting Discovery

**No devices found:**
- Ensure NAS is powered on and connected to network
- Check that SMB/CIFS is enabled on NAS
- Verify you're on the same network/subnet
- Try manual entry if discovery fails

**Partial discovery:**
- Some NAS devices may not broadcast Bonjour
- Use "Scan Network" for ping-based discovery
- Manual entry always works

## Technical Details

### Data Model

Each NAS device stores:
- **ID**: Unique identifier (UUID)
- **Name**: Display name (e.g., "MyNAS")
- **Hostname**: Network address (e.g., "MyNAS.local")
- **Username**: SMB username
- **Shares**: List of SMB shares to mount
- **isDefault**: Boolean flag for default NAS

### Password Storage

Passwords are stored per-NAS in macOS Keychain:
- Key format: `nas_{UUID}`
- Service: `com.ry4nolson.theannex`
- Secure, encrypted storage
- Separate password for each NAS

### Sync Folder Assignment

Each sync folder has optional `nasDeviceId`:
- If set: Uses specific NAS device
- If nil: Uses default NAS
- Allows flexible per-folder targeting

### Monitoring

Health checks monitor all configured NAS devices:
- Pings each hostname
- If any NAS is online → Status: Connected
- If all NAS offline → Status: Offline
- Connection quality uses default NAS

## Migration from Single NAS

If you're upgrading from the old single-NAS version:

1. **No automatic migration** - old settings are not preserved
2. **Add your NAS** using the new "Add NAS" button
3. **Configure sync folders** in the Sync Folders tab
4. **Previous Downloads symlink** is not automatically created

This gives you a clean slate to organize your multi-NAS setup.

## Best Practices

### Naming Convention
Use descriptive names:
- ✅ "Home NAS", "Media Server", "Backup NAS"
- ❌ "NAS1", "NAS2", "Server"

### Share Organization
Keep shares organized by purpose:
- Personal: home, documents, pictures
- Media: plex, movies, tv, music
- Work: projects, clients, archives

### Default NAS
Set your most-used NAS as default:
- Fastest connection
- Most frequently accessed
- Best uptime

### Credentials
Use strong passwords:
- Stored securely in Keychain
- Different password per NAS recommended
- Consider using NAS-specific accounts

## FAQ

**Q: Can I sync the same folder to multiple NAS devices?**
A: Not directly. Create separate sync folders with different local paths or use the same local path with different schedules.

**Q: What happens if a NAS goes offline during sync?**
A: The sync will fail gracefully. Check Activity Log for details. Sync will retry on next cycle when NAS is back online.

**Q: Can I have different credentials for different shares on the same NAS?**
A: No, credentials are per-NAS device. All shares on a NAS use the same username/password.

**Q: How do I know which NAS a sync folder is using?**
A: In the Sync Folders tab, the NAS path shows the target location. Future update will show NAS name.

**Q: Can I use IP addresses instead of hostnames?**
A: Yes! Enter the IP address (e.g., "192.168.1.100") in the hostname field.

**Q: Does discovery work across VLANs?**
A: Bonjour/mDNS typically doesn't cross VLANs. Use manual entry for cross-VLAN NAS devices.

## Future Enhancements

Planned improvements:
- Show NAS name in sync folder list
- Per-NAS connection status in menu
- NAS-specific statistics
- Automatic failover between NAS devices
- NAS health dashboard
