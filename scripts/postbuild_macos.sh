#/bin/sh
cd build/macos
unzip -oq PngApp-macos.zip
mkdir -p PngApp.app/Contents/Resources/libs/macos-x86_64/
cp ../../libs/macos-x86_64/* PngApp.app/Contents/Resources/libs/macos-x86_64/
zip -q PngApp-macos.zip PngApp.app
rm -rf PngApp.app
echo "Done copying libs to MacOS App"
