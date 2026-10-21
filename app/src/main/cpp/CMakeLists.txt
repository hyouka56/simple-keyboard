cmake_minimum_required(VERSION 3.22.1)
project(arm64_only_abi_marker C)

# A minimal native marker forces Android package ABI compatibility to ARM64.
add_library(arm64_only_abi_marker SHARED arm64_only_abi_marker.c)
