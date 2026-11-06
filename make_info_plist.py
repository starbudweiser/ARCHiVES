#!/usr/bin/env python3
"""Génère Info.plist : types de documents, UTI, Services du Finder. Usage : make_info_plist.py <sortie> <version>"""
import plistlib, sys

out, version = sys.argv[1], sys.argv[2]
exts = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst", "lz", "lzma", "cab", "cpio", "xar"]
exts += [f"r{n:02d}" for n in range(0, 100)] + [f"{n:03d}" for n in range(1, 21)] + [f"z{n:02d}" for n in range(1, 10)]
plist = {
    "CFBundleIdentifier": "fr.stephan.archives",
    "CFBundleName": "ARCHiVES", "CFBundleDisplayName": "ARCHiVES", "CFBundleExecutable": "ARCHiVES",
    "CFBundleIconFile": "icon.icns", "CFBundlePackageType": "APPL", "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleShortVersionString": version, "CFBundleVersion": version,
    "CFBundleDevelopmentRegion": "en", "CFBundleLocalizations": ["fr", "en", "it", "es"],
    "LSMinimumSystemVersion": "15.0", "LSUIElement": True, "NSHighResolutionCapable": True,
    "NSPrincipalClass": "NSApplication",
    "CFBundleDocumentTypes": [{
        "CFBundleTypeName": "Archive", "CFBundleTypeRole": "Viewer", "LSHandlerRank": "Alternate",
        "LSItemContentTypes": ["public.zip-archive", "org.7-zip.7-zip-archive", "com.rarlab.rar-archive", "public.tar-archive",
                               "org.gnu.gnu-zip-archive", "org.gnu.gnu-zip-tar-archive", "public.archive"],
        "CFBundleTypeExtensions": exts,
    }],
    "UTImportedTypeDeclarations": [
        {"UTTypeIdentifier": "com.rarlab.rar-archive", "UTTypeDescription": "RAR archive",
         "UTTypeConformsTo": ["public.data", "public.archive"],
         "UTTypeTagSpecification": {"public.filename-extension": ["rar"], "public.mime-type": ["application/vnd.rar"]}},
        {"UTTypeIdentifier": "org.7-zip.7-zip-archive", "UTTypeDescription": "7-Zip archive",
         "UTTypeConformsTo": ["public.data", "public.archive"],
         "UTTypeTagSpecification": {"public.filename-extension": ["7z"], "public.mime-type": ["application/x-7z-compressed"]}},
    ],
    "NSServices": [
        {"NSMenuItem": {"default": "Extract"}, "NSMessage": "extractService", "NSPortName": "ARCHiVES",
         "NSSendFileTypes": ["public.archive"]},
        {"NSMenuItem": {"default": "Create an ARCHiVE"}, "NSMessage": "createService", "NSPortName": "ARCHiVES",
         "NSSendFileTypes": ["public.item"]},
        {"NSMenuItem": {"default": "Create a protected ARCHiVE…"}, "NSMessage": "createProtectedService", "NSPortName": "ARCHiVES",
         "NSSendFileTypes": ["public.item"]},
    ],
}
plistlib.dump(plist, open(out, "wb"))
