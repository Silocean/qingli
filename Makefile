APP = Qingli.app
BIN = .build/release/Qingli

.PHONY: run build icon check

icon:
	sips -s format png Assets/icon.png --out Assets/icon.png >/dev/null
	mkdir -p AppIcon.iconset
	sips -z 16 16     Assets/icon.png --out AppIcon.iconset/icon_16x16.png >/dev/null
	sips -z 32 32     Assets/icon.png --out AppIcon.iconset/icon_16x16@2x.png >/dev/null
	sips -z 32 32     Assets/icon.png --out AppIcon.iconset/icon_32x32.png >/dev/null
	sips -z 64 64     Assets/icon.png --out AppIcon.iconset/icon_32x32@2x.png >/dev/null
	sips -z 128 128   Assets/icon.png --out AppIcon.iconset/icon_128x128.png >/dev/null
	sips -z 256 256   Assets/icon.png --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
	sips -z 256 256   Assets/icon.png --out AppIcon.iconset/icon_256x256.png >/dev/null
	sips -z 512 512   Assets/icon.png --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
	sips -z 512 512   Assets/icon.png --out AppIcon.iconset/icon_512x512.png >/dev/null
	sips -z 1024 1024 Assets/icon.png --out AppIcon.iconset/icon_512x512@2x.png >/dev/null
	iconutil -c icns AppIcon.iconset -o AppIcon.icns
	rm -rf AppIcon.iconset

build: icon
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Qingli
	cp Info.plist $(APP)/Contents/Info.plist
	cp AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns

run: build
	open $(APP)
