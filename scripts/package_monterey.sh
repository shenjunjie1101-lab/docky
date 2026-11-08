#!/bin/bash
set -euo pipefail

app="build/Build/Products/Release/Docky.app"
test -f "$app/Contents/MacOS/Docky"
mkdir -p dist
for plist in "$app/Contents/Info.plist" "$app/Contents/Library/LoginItems/DockyDockWatchdog.app/Contents/Info.plist"; do
  /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.9.7' "$plist"
done
revision=$(git rev-parse HEAD)
printf 'Source revision: %s\nhttps://github.com/shenjunjie1101-lab/docky/tree/%s\n' "$revision" "$revision" > "$app/Contents/Resources/Source-Revision.txt"
cp LICENSE "$app/Contents/Resources/GPL-3.0.txt"
cp MONTEREY.md "$app/Contents/Resources/Monterey-Compatibility.md"

python3 - "$app" <<'PY'
import pathlib, plistlib, struct, sys
app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['LSMinimumSystemVersion'] == '12.6', info
assert info['CFBundleShortVersionString'] == '0.9.7', info
for binary in [app / 'Contents/MacOS/Docky',
               app / 'Contents/Library/LoginItems/DockyDockWatchdog.app/Contents/MacOS/DockyDockWatchdog']:
    data = binary.read_bytes()
    magic, cpu, subtype, kind, count, size, flags, reserved = struct.unpack_from('<8I', data)
    assert magic == 0xfeedfacf and cpu == 0x100000c, (binary, hex(magic), hex(cpu))
    offset = 32
    minimums = []
    for _ in range(count):
        command, length = struct.unpack_from('<II', data, offset)
        if command == 0x32:
            platform, minimum = struct.unpack_from('<II', data, offset + 8)
            assert platform == 1
            minimums.append(minimum)
        elif command == 0x24:
            minimums.append(struct.unpack_from('<I', data, offset + 8)[0])
        offset += length
    assert minimums and all(v <= (12 << 16 | 6 << 8) for v in minimums), (binary, minimums)
    print('Validated arm64 macOS 12.6 binary:', binary)
PY

codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
otool -L "$app/Contents/MacOS/Docky" > dist/linked-libraries.txt

package_name="Docky-0.9.7-Monterey-12.6-arm64-zh-CN-fix3"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$package_name.zip"
dmg_root=$(mktemp -d)
trap 'rm -rf "$dmg_root"' EXIT
ditto "$app" "$dmg_root/Docky.app"
ln -s /Applications "$dmg_root/Applications"
cat > "$dmg_root/使用说明.txt" <<'TEXT'
Docky 0.9.7 — macOS 12.6 简体中文兼容测试版 fix3（Apple Silicon）

1. 将 Docky 拖入 Applications（应用程序）。
2. 首次打开时，按住 Control 点击应用并选择“打开”。本版本使用临时签名，未经 Apple 公证。
3. 根据应用提示，在“系统偏好设置 → 安全性与隐私 → 隐私”中允许辅助功能和屏幕录制。
4. 首次运行保留系统 Dock。确认基本操作正常后，再按需开启隐藏系统 Dock。
   入口：Docky 设置 → 系统 → 系统程序坞 → 隐藏系统程序坞。
5. 如需在全屏应用中也一直显示：设置 → 行为 → 可见性，关闭“全屏时隐藏”。

fix3 调整：macOS 12 激活已运行应用时明确请求前台切换；激活失败时重新打开应用。
包含 fix2 的窗口置顶、切换应用时保持显示、旧系统菜单和解组保护。
升级前请退出旧版，再将新版拖入应用程序并替换。

放大程序坞：设置 → 外观 → 图块布局 → 图块大小，建议先尝试 64–80 磅。
应用较多时：设置 → 行为 → 可见性 → 空间不足时，选择“滚动”，避免整条自动缩小。
小组件 1x/2x/3x 主要表示横向占位宽度，不是文字放大倍数。

已知限制：音乐播放小组件暂不支持；启动台采用普通滚动和翻页按钮；
部分小组件采用紧凑排版；原版自动更新已关闭；外部插件需要单独兼容 12.6。

本版本仍需在 macOS 12.6 实机验证。如果无法启动，请保留完整错误提示或崩溃报告。
源码：https://github.com/shenjunjie1101-lab/docky/tree/fix/monterey-window-layer
TEXT
cp LICENSE "$dmg_root/LICENSE.txt"
hdiutil create -volname "Docky for Monterey" -srcfolder "$dmg_root" -ov \
  -format UDZO "dist/$package_name.dmg"
shasum -a 256 "dist/$package_name.zip" "dist/$package_name.dmg" > dist/SHA256SUMS.txt
