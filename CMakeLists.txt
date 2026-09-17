cmake_minimum_required(VERSION 3.25)
project(Hands4VR LANGUAGES CXX)

# Hands4VR currently packages the proven HandOfLesser OpenXR/SteamVR runtime.
# The Windows CI workflow obtains the upstream source and performs the real build.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_custom_target(Hands4VR ALL
    COMMAND ${CMAKE_COMMAND} -E echo "Hands4VR is assembled by .github/workflows/build-windows.yml"
)
