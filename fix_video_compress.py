#!/usr/bin/env python3
import re

files = [
    '/home/paolice-mylze/oli-core/oli_app/lib/features/feed/presentation/create_post_page.dart',
    '/home/paolice-mylze/oli-core/oli_app/lib/features/live_shopping/pages/video_upload_page.dart',
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove import
    content = content.replace(
        "import 'package:video_compress/video_compress.dart';",
        "// video_compress removed — package no longer in pubspec"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'✅ Import removed from {filepath}')

# Now fix the VideoCompress usage in create_post_page
filepath = files[0]
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the VideoCompress block - find it by line patterns
lines = content.split('\n')
new_lines = []
skip_until = None
i = 0
while i < len(lines):
    line = lines[i]
    # Detect start of VideoCompress block
    if 'VideoCompress.compressVideo' in line and 'MediaInfo' in lines[i-1]:
        # Remove the MediaInfo declaration line (already added to new_lines, pop it)
        new_lines.pop()  # remove "MediaInfo? info = "
        # Add replacement
        new_lines.append('          // video_compress removed — using original file directly')
        # Skip lines until we find the closing ");' of compressVideo
        while i < len(lines) and ');' not in lines[i]:
            i += 1
        i += 1  # skip the ");"
        # Now fix the setState that uses info?.file
        continue
    elif "info?.file ?? File(pickedFile.path)" in line:
        new_lines.append(line.replace("info?.file ?? File(pickedFile.path)", "File(pickedFile.path)"))
    elif "mediaInfo != null && mediaInfo.file != null" in line:
        # In video_upload_page, replace mediaInfo conditional
        new_lines.append(line.replace("mediaInfo != null && mediaInfo.file != null", "false"))
    else:
        new_lines.append(line)
    i += 1

content = '\n'.join(new_lines)
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('✅ create_post_page.dart VideoCompress block fixed')

# Fix video_upload_page — replace MediaInfo? mediaInfo block
filepath = files[1]
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace: MediaInfo? mediaInfo; try { mediaInfo = await VideoCompress... } catch(e) { ... }
# and then: mediaInfo != null && mediaInfo.file != null ? await mediaInfo.file!.readAsBytes() : await _videoFile!.readAsBytes()
content = re.sub(
    r'MediaInfo\? mediaInfo;\s*try \{.*?VideoCompress\.compressVideo\(.*?\);\s*\} catch \(e\) \{\s*debugPrint\("Erreur de compression: \$e"\);\s*\}',
    '// VideoCompress removed — skipping compression, using original file directly',
    content,
    flags=re.DOTALL
)
content = content.replace(
    "mediaInfo != null && mediaInfo.file != null \n          ? await mediaInfo.file!.readAsBytes() \n          : await _videoFile!.readAsBytes();",
    "await _videoFile!.readAsBytes();"
)
content = content.replace(
    "mediaInfo != null && mediaInfo.file != null\n          ? await mediaInfo.file!.readAsBytes()\n          : await _videoFile!.readAsBytes();",
    "await _videoFile!.readAsBytes();"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('✅ video_upload_page.dart VideoCompress block fixed')
