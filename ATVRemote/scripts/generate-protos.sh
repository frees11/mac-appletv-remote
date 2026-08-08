#!/bin/bash

# Regenerates the MRP protobuf bindings.
#
# Field numbers below are the canonical ones used by Apple's MediaRemote
# protocol, cross-checked against pyatv's .proto definitions
# (tools/fake-atv/.pyatv/pyatv/protocols/mrp/protobuf). They are NOT
# interchangeable with the ProtocolMessage.Type enum values: the type enum
# identifies the message, the field number carries its payload.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DEST="$PROJECT_DIR/Packages/ATVRemoteCore/Sources/ATVRemoteCore/Protocol/Protobuf"

if ! command -v protoc &> /dev/null; then
    echo "Error: protoc not found. Install with: brew install protobuf"
    exit 1
fi

if ! command -v protoc-gen-swift &> /dev/null; then
    echo "Error: swift-protobuf plugin not found. Install with: brew install swift-protobuf"
    exit 1
fi

mkdir -p "$PROTO_DEST"
rm -f "$PROTO_DEST"/*.pb.swift

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/atv_combined.proto" << 'PROTO_EOF'
syntax = "proto2";

package atvremote;

message PlaybackState {
  enum Enum {
    Unknown = 0;
    Playing = 1;
    Paused = 2;
    Stopped = 3;
    Interrupted = 4;
    Seeking = 5;
  }
}

message ContentItemMetadata {
  optional string title = 1;
  optional string subtitle = 2;
  optional float playbackProgress = 5;
  optional string albumName = 6;
  optional string trackArtistName = 7;
  optional string albumArtistName = 8;
  optional int32 seasonNumber = 10;
  optional int32 episodeNumber = 11;
  optional double duration = 14;
  optional double elapsedTime = 35;
  optional float playbackRate = 39;
  optional double elapsedTimeTimestamp = 74;
}

message ContentItem {
  optional string identifier = 1;
  optional ContentItemMetadata metadata = 2;
  optional bytes artworkData = 3;
  optional int32 artworkDataWidth = 13;
  optional int32 artworkDataHeight = 14;
}

message PlaybackQueue {
  optional int32 location = 1;
  repeated ContentItem contentItems = 2;
}

message NowPlayingInfo {
  optional string album = 1;
  optional string artist = 2;
  optional double duration = 3;
  optional double elapsedTime = 4;
  optional float playbackRate = 5;
  optional double timestamp = 8;
  optional string title = 9;
}

message SetStateMessage {
  optional NowPlayingInfo nowPlayingInfo = 1;
  optional PlaybackQueue playbackQueue = 3;
  optional string displayID = 4;
  optional string displayName = 5;
  optional PlaybackState.Enum playbackState = 6;
}

message DeviceInfoMessage {
  optional string uniqueIdentifier = 1;
  optional string name = 2;
  optional string localizedModelName = 3;
  optional string systemBuildVersion = 4;
  optional string applicationBundleIdentifier = 5;
  optional int32 protocolVersion = 7;
  optional uint32 lastSupportedMessageType = 8;
  optional bool supportsSystemPairing = 9;
  optional bool allowsPairing = 10;
  optional bool connected = 11;
}

message CryptoPairingMessage {
  optional bytes pairingData = 1;
  optional int32 status = 2;
  optional bool isRetrying = 3;
  optional bool isUsingSystemPairing = 4;
  optional int32 state = 5;
}

message SendHIDEventMessage {
  optional bytes hidEventData = 1;
}

message SetConnectionStateMessage {
  enum ConnectionState {
    None = 0;
    Connecting = 1;
    Connected = 2;
    Disconnected = 3;
  }
  optional ConnectionState state = 1;
}

message ClientUpdatesConfigMessage {
  optional bool artworkUpdates = 1;
  optional bool nowPlayingUpdates = 2;
  optional bool volumeUpdates = 3;
  optional bool keyboardUpdates = 4;
  optional bool outputDeviceUpdates = 5;
}

message SendCommandMessage {
  optional int32 command = 1;
}

message ProtocolMessage {
  enum Type {
    SEND_COMMAND_MESSAGE = 1;
    SEND_COMMAND_RESULT_MESSAGE = 2;
    GET_STATE_MESSAGE = 3;
    SET_STATE_MESSAGE = 4;
    SET_ARTWORK_MESSAGE = 5;
    SEND_HID_EVENT_MESSAGE = 8;
    DEVICE_INFO_MESSAGE = 15;
    CLIENT_UPDATES_CONFIG_MESSAGE = 16;
    KEYBOARD_MESSAGE = 23;
    GET_KEYBOARD_SESSION_MESSAGE = 24;
    CRYPTO_PAIRING_MESSAGE = 34;
    SET_CONNECTION_STATE_MESSAGE = 38;
    SET_NOW_PLAYING_CLIENT_MESSAGE = 46;
  }

  optional Type type = 1;
  optional string identifier = 2;
  optional uint64 timestamp = 5;

  optional SendCommandMessage sendCommandMessage = 6;
  optional SetStateMessage setStateMessage = 9;
  optional SendHIDEventMessage sendHIDEventMessage = 13;
  optional DeviceInfoMessage deviceInfoMessage = 20;
  optional ClientUpdatesConfigMessage clientUpdatesConfigMessage = 21;
  optional CryptoPairingMessage cryptoPairingMessage = 39;
  optional SetConnectionStateMessage setConnectionStateMessage = 42;
}
PROTO_EOF

protoc \
    --proto_path="$WORK_DIR" \
    --swift_out="$PROTO_DEST" \
    --swift_opt=Visibility=Public \
    "$WORK_DIR/atv_combined.proto"

echo "Generated:"
ls -la "$PROTO_DEST"
