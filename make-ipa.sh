#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────
#  产出未签名 IPA（Sideloadly / AltStore / SideStore 可直接重签安装）
#
#  用法：bash make-ipa.sh
#  依赖：macOS + Xcode 26（本项目需要 iOS 26 SDK）
#
#  为什么出未签名包：签名必须用**你自己的** Apple ID / 证书，这里没有也不该有。
#  重签工具会把整包（含 EhDownloadWidget.appex）用你的证书重签后安装，
#  所以这里只负责把 .app 编译出来、按 Payload/ 结构打成 zip。
# ────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")"

PROJECT="ehviewer apple.xcodeproj"
SCHEME="ehviewer apple"
ARCHIVE="build/EhViewer.xcarchive"
APP="$ARCHIVE/Products/Applications/ehviewer apple.app"
OUT="build/ipa/EhViewer-unsigned.ipa"

command -v xcodebuild >/dev/null || { echo "❌ 没有 xcodebuild：这一步必须在 macOS + Xcode 上跑"; exit 1; }
xcodebuild -version

echo
echo "== 1/4 解析 SPM 依赖 =="
xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME"

echo
echo "== 2/4 归档（不签名）=="
rm -rf build/EhViewer.xcarchive
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO

[ -d "$APP" ] || { echo "❌ 归档里找不到 .app：$APP"; exit 1; }

echo
echo "== 3/4 组装 Payload =="
rm -rf build/Payload build/ipa
mkdir -p build/Payload build/ipa
cp -R "$APP" build/Payload/

# 未签名包不需要任何签名材料；残留反而会让重签工具判断错
find build/Payload -name "_CodeSignature" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find build/Payload -name "embedded.mobileprovision" -delete 2>/dev/null || true
xattr -cr build/Payload 2>/dev/null || true

# -y 保留符号链接（框架里的版本链接断了会启动即崩），-X 去掉多余的扩展属性
(cd build && zip -qryX "ipa/EhViewer-unsigned.ipa" Payload)

echo
echo "== 4/4 产物 =="
ls -lh "$OUT"

echo
echo "== 产物最低版本（应为 17.0）=="
plutil -p "$APP/Info.plist" | grep -i MinimumOSVersion || true
plutil -p "$APP/PlugIns/EhDownloadWidget.appex/Info.plist" | grep -i MinimumOSVersion || true

cat <<'TIP'

下一步：把 build/ipa/EhViewer-unsigned.ipa 拷到装 iOS 的电脑上，用下面任一工具重签安装
  · Sideloadly（Windows / macOS 都行）：连数据线 → 拖入 ipa → 填 Apple ID → Start
  · AltStore / SideStore：装一次后可在设备上自助续签
免费 Apple ID 签出的包 7 天后失效，重签即可，App 内数据不丢。
TIP
