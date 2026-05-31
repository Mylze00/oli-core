filepath = '/home/paolice-mylze/oli-core/oli_app/lib/features/chat/call_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Remove the bad stub block (it's before the remaining imports)
bad_stub = """
// === Stub classes replacing flutter_webrtc (package removed) ===
class RTCVideoRenderer {
  RTCVideoRenderer();
  void dispose() {}
}
class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final dynamic objectFit;
  const RTCVideoView(this.renderer, {super.key, this.mirror = false, this.objectFit});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
class RTCVideoViewObjectFit {
  static const RTCVideoViewObjectFitCover = null;
}
// === End stubs ===

"""
content = content.replace(bad_stub, '')

# Good stubs (placed after all imports)
good_stub = """

// === Stub classes replacing flutter_webrtc (package removed from pubspec) ===
class RTCVideoRenderer {
  RTCVideoRenderer();
  Future<void> initialize() async {}
  void dispose() {}
}

class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final dynamic objectFit;
  const RTCVideoView(this.renderer, {super.key, this.mirror = false, this.objectFit});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class RTCVideoViewObjectFit {
  static const dynamic RTCVideoViewObjectFitCover = null;
}
// === End stubs ===

"""

# Insert after the last import
anchor = "import 'socket_service.dart';"
content = content.replace(anchor, anchor + good_stub, 1)

with open(filepath, 'w') as f:
    f.write(content)
print('call_screen.dart fixed')

# Fix create_post_page.dart — VideoCompress block still present
filepath2 = '/home/paolice-mylze/oli-core/oli_app/lib/features/feed/presentation/create_post_page.dart'
with open(filepath2, 'r') as f:
    lines = f.readlines()

out = []
i = 0
while i < len(lines):
    line = lines[i]
    # Skip the MediaInfo + VideoCompress block
    if 'MediaInfo?' in line and 'info' in line:
        # Skip forward until we've consumed the compressVideo call closure
        out.append('          // VideoCompress removed — using original file directly\n')
        while i < len(lines) and ');' not in lines[i]:
            i += 1
        i += 1  # skip closing ");"
        continue
    # Fix the setState that references info?.file
    if 'info?.file ??' in line:
        line = line.replace('info?.file ?? File(pickedFile.path)', 'File(pickedFile.path)')
    out.append(line)
    i += 1

with open(filepath2, 'w') as f:
    f.writelines(out)
print('create_post_page.dart fixed')
