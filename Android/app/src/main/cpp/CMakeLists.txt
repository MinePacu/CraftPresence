cmake_minimum_required(VERSION 3.22.1)
project(craftpresence_discord)

add_library(craftpresence_discord SHARED DiscordBridge.cpp)

find_package(discord_partner_sdk REQUIRED CONFIG)

target_link_libraries(
    craftpresence_discord
    discord_partner_sdk::discord_partner_sdk
    log
)
