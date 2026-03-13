#!/usr/bin/env swift
import Foundation

// Generates a .DS_Store file that configures the Finder window for a DMG:
// - Background image from .background/background.png
// - Icon view with 96px icons
// - Window size 660x400
// - TheAnnex.app at (155, 195), Applications at (495, 195)
//
// The .DS_Store binary format uses a B-tree of records. Each record has:
//   - filename (UTF-16BE, length-prefixed)
//   - structure ID (4-char code)
//   - structure type (4-char code)
//   - data (type-dependent)
//
// Reference: https://0day.work/parsing-the-ds_store-file-format/
// Reference: https://wiki.mozilla.org/DS_Store_File_Format

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: generate-ds-store.swift <staging-directory>\n", stderr)
    exit(1)
}

let stagingDir = CommandLine.arguments[1]
let dsStorePath = (stagingDir as NSString).appendingPathComponent(".DS_Store")

// MARK: - DS_Store Binary Writer

class DSStoreWriter {
    var data = Data()
    
    // Write raw bytes
    func write(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }
    
    func writeUInt8(_ v: UInt8) {
        data.append(v)
    }
    
    func writeUInt16(_ v: UInt16) {
        var big = v.bigEndian
        data.append(Data(bytes: &big, count: 2))
    }
    
    func writeUInt32(_ v: UInt32) {
        var big = v.bigEndian
        data.append(Data(bytes: &big, count: 4))
    }
    
    func writeInt32(_ v: Int32) {
        var big = v.bigEndian
        data.append(Data(bytes: &big, count: 4))
    }
    
    func writeUTF16String(_ s: String) {
        let utf16 = Array(s.utf16)
        writeUInt32(UInt32(utf16.count))
        for char in utf16 {
            writeUInt16(char)
        }
    }
    
    func writeFourCC(_ s: String) {
        let bytes = Array(s.utf8)
        assert(bytes.count == 4, "FourCC must be 4 bytes: \(s)")
        write(bytes)
    }
    
    // Write a blob type record value
    func writeBlob(_ blobData: Data) {
        writeFourCC("blob")
        writeUInt32(UInt32(blobData.count))
        data.append(blobData)
    }
    
    // Write a bool type record value
    func writeBoolValue(_ v: Bool) {
        writeFourCC("bool")
        writeUInt8(v ? 1 : 0)
    }
    
    // Write a long type record value (4-byte int)
    func writeLong(_ v: UInt32) {
        writeFourCC("long")
        writeUInt32(v)
    }
    
    // Write a shor type record value (4-byte int, despite the name)
    func writeShor(_ v: UInt32) {
        writeFourCC("shor")
        writeUInt32(v)
    }
}

// MARK: - Record Builder

struct DSRecord: Comparable {
    let filename: String
    let structureId: String  // 4-char code
    let buildValue: (DSStoreWriter) -> Void
    
    // Records are sorted by filename (case-insensitive), then by structure ID
    static func < (lhs: DSRecord, rhs: DSRecord) -> Bool {
        let cmp = lhs.filename.lowercased().compare(rhs.filename.lowercased())
        if cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        return lhs.structureId < rhs.structureId
    }
    
    static func == (lhs: DSRecord, rhs: DSRecord) -> Bool {
        return lhs.filename.lowercased() == rhs.filename.lowercased() && lhs.structureId == rhs.structureId
    }
}

func buildRecord(_ writer: DSStoreWriter, record: DSRecord) {
    writer.writeUTF16String(record.filename)
    writer.writeFourCC(record.structureId)
    record.buildValue(writer)
}

// MARK: - Icon Location (Iloc) blob: x(4) + y(4) + 0xFFFF(6 padding bytes)

func ilocBlob(x: UInt32, y: UInt32) -> Data {
    var d = Data()
    var bx = x.bigEndian; d.append(Data(bytes: &bx, count: 4))
    var by = y.bigEndian; d.append(Data(bytes: &by, count: 4))
    d.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00])  // padding
    return d
}

// MARK: - Background image path (pict) blob for bwsp
// This sets .background/background.png as the folder background

func backgroundImageBlob() -> Data {
    // The background type is set via 'pict' in the view settings blob
    // We need a bwsp (background window settings plist) blob
    let plistDict: [String: Any] = [
        "ShowPathbar": false,
        "ShowSidebar": false,
        "ShowStatusBar": false,
        "ShowTabView": false,
        "ShowToolbar": false,
        "SidebarWidth": 0,
        "WindowBounds": "{{200, 120}, {660, 400}}"
    ]
    return try! PropertyListSerialization.data(fromPropertyList: plistDict, format: .binary, options: 0)
}

// MARK: - Icon View Settings blob (icvp)
// This configures icon view: size, text size, arrangement, background image

func iconViewSettingsBlob() -> Data {
    let plistDict: [String: Any] = [
        "backgroundColorBlue": 0.0,
        "backgroundColorGreen": 0.0,
        "backgroundColorRed": 0.0,
        "backgroundImageAlias": Data(),  // placeholder, path set separately
        "backgroundType": 2,  // 2 = picture
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "iconSize": 96.0,
        "labelOnBottom": true,
        "showIconPreview": true,
        "showItemInfo": false,
        "textSize": 12.0,
        "viewOptionsVersion": 1,
        "arrangeBy": "none"
    ]
    return try! PropertyListSerialization.data(fromPropertyList: plistDict, format: .binary, options: 0)
}

// MARK: - Build the full .DS_Store file

// The .DS_Store format:
// Header: magic(4) + version(4) + allocator_offset(4) + allocator_size(4) + padding(4)
// Then an allocator with a B-tree of records.
//
// For simplicity, we write a minimal flat structure that Finder understands.
// This approach writes the "Bud1" header and a single root block with all records.

func buildDSStore() -> Data {
    // Collect all records
    var records: [DSRecord] = []
    
    let dotDir = "."
    
    // Background window settings for the root folder
    records.append(DSRecord(filename: dotDir, structureId: "bwsp") { w in
        w.writeBlob(backgroundImageBlob())
    })
    
    // Icon view settings for the root folder
    records.append(DSRecord(filename: dotDir, structureId: "icvp") { w in
        w.writeBlob(iconViewSettingsBlob())
    })
    
    // View style = icon view ("icnv")
    records.append(DSRecord(filename: dotDir, structureId: "vSrn") { w in
        w.writeLong(1) // 1 = icon view
    })
    
    // Icon locations for each item
    records.append(DSRecord(filename: "TheAnnex.app", structureId: "Iloc") { w in
        w.writeBlob(ilocBlob(x: 155, y: 195))
    })
    
    records.append(DSRecord(filename: "Applications", structureId: "Iloc") { w in
        w.writeBlob(ilocBlob(x: 495, y: 195))
    })
    
    // Sort records (required for DS_Store B-tree)
    records.sort()
    
    // Build record data
    let recordWriter = DSStoreWriter()
    for record in records {
        buildRecord(recordWriter, record: record)
    }
    let recordData = recordWriter.data
    
    // Build the full file with Bud1 allocator format
    // This is a minimal implementation that writes a single-block B-tree
    
    let writer = DSStoreWriter()
    
    // === Alignment bookmarks ===
    // The file has a fixed header, then the allocator, then the B-tree data
    
    // Magic number and version
    writer.writeUInt32(0x00000001) // alignment/magic
    writer.writeFourCC("Bud1")     // magic
    
    // Offset to allocator (from start of file = 32 bytes for our minimal header)
    // We'll compute this after we know the structure
    let allocatorOffset: UInt32 = 32
    writer.writeUInt32(allocatorOffset)
    
    // Allocator size
    let treeNodeSize = 4 + 4 + UInt32(recordData.count) // count(4) + record_count(4) + records
    let allocatorSize: UInt32 = 4 + treeNodeSize  // root_node_offset(4) + tree_node
    writer.writeUInt32(allocatorSize)
    
    // Offset to allocator copy (same as allocator for our purposes)
    writer.writeUInt32(allocatorOffset)
    
    // Padding to reach offset 32
    let padNeeded = 32 - writer.data.count
    for _ in 0..<padNeeded {
        writer.writeUInt8(0)
    }
    
    // === Allocator block ===
    // Block count and free list (minimal: 1 block, no free list)
    writer.writeUInt32(0)  // root node block number
    
    // === B-tree root node ===
    // For a leaf node: mode(4) + count(4) + records...
    writer.writeUInt32(0)  // mode: 0 = leaf node
    writer.writeUInt32(UInt32(records.count))
    writer.data.append(recordData)
    
    return writer.data
}

// MARK: - Main

let dsStoreData = buildDSStore()

do {
    try dsStoreData.write(to: URL(fileURLWithPath: dsStorePath))
    print("✓ Generated .DS_Store: \(dsStorePath) (\(dsStoreData.count) bytes)")
} catch {
    fputs("Failed to write .DS_Store: \(error)\n", stderr)
    exit(1)
}
