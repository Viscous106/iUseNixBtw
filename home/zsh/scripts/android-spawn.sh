#To load a google pixel phone:
function android-spawn(){
export ANDROID_SDK_ROOT=/opt/android-sdk
  xhost +local:
  DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 \
    /opt/android-sdk/emulator/emulator -avd CakePhone -gpu swiftshader_indirect &
}
