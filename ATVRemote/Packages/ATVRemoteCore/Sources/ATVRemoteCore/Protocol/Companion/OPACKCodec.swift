import Foundation

public enum OPACKError: Error {
    case invalidData
    case unsupportedType
    case unexpectedEndOfData
}

public struct OPACKCodec {

    public static func encode(_ value: Any) throws -> Data {
        var data = Data()
        try encodeValue(value, into: &data)
        return data
    }

    public static func decode(_ data: Data) throws -> Any {
        var offset = 0
        NSLog("[OPACK] Decoding %d bytes: %@", data.count, data.prefix(50).map { String(format: "%02x", $0) }.joined(separator: " "))
        do {
            return try decodeValue(from: data, offset: &offset)
        } catch {
            NSLog("[OPACK] Decode error at offset %d, marker 0x%02x", offset > 0 ? offset - 1 : 0, offset > 0 && offset <= data.count ? data[offset - 1] : 0)
            throw error
        }
    }

    private static func encodeValue(_ value: Any, into data: inout Data) throws {
        switch value {
        case is NSNull:
            data.append(0x04)

        case let bool as Bool:
            data.append(bool ? 0x01 : 0x02)

        case let int as Int:
            encodeInteger(int, into: &data)

        case let int as Int64:
            encodeInteger(Int(int), into: &data)

        case let uint as UInt:
            encodeInteger(Int(uint), into: &data)

        case let uint as UInt8:
            encodeInteger(Int(uint), into: &data)

        case let uint as UInt64:
            encodeInteger(Int(uint), into: &data)

        case let double as Double:
            data.append(0x36)
            var value = double.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })

        case let string as String:
            try encodeString(string, into: &data)

        case let bytes as Data:
            try encodeData(bytes, into: &data)

        case let array as [Any]:
            let arrayCount = array.count
            if arrayCount <= 15 {
                data.append(UInt8(0xD0 + arrayCount))
            } else {
                data.append(0x60)
            }
            for item in array {
                try encodeValue(item, into: &data)
            }
            if arrayCount > 15 {
                data.append(0x03)
            }

        case let dict as [String: Any]:
            let dictCount = dict.count
            if dictCount <= 15 {
                data.append(UInt8(0xE0 + dictCount))
            } else {
                data.append(0x50)
            }
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                try encodeString(key, into: &data)
                try encodeValue(val, into: &data)
            }
            if dictCount > 15 {
                data.append(0x03)
            }

        default:
            throw OPACKError.unsupportedType
        }
    }

    private static func encodeInteger(_ value: Int, into data: inout Data) {
        if value >= 0 && value <= 39 {
            data.append(UInt8(0x08 + value))
        } else if value >= -128 && value <= 127 {
            data.append(0x30)
            data.append(UInt8(bitPattern: Int8(value)))
        } else if value >= -32768 && value <= 32767 {
            data.append(0x31)
            var be = Int16(value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        } else if value >= -2147483648 && value <= 2147483647 {
            data.append(0x32)
            var be = Int32(value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        } else {
            data.append(0x33)
            var be = Int64(value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        }
    }

    private static func encodeString(_ string: String, into data: inout Data) throws {
        let bytes = Data(string.utf8)
        let length = bytes.count

        if length <= 0x20 {
            data.append(UInt8(0x40 + length))
        } else if length <= 0xFF {
            data.append(0x61)
            data.append(UInt8(length))
        } else if length <= 0xFFFF {
            data.append(0x62)
            var be = UInt16(length).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        } else if length <= 0xFFFFFFFF {
            data.append(0x63)
            var be = UInt32(length).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        } else {
            throw OPACKError.unsupportedType
        }
        data.append(bytes)
    }

    private static func encodeData(_ bytes: Data, into data: inout Data) throws {
        let length = bytes.count

        if length <= 0x20 {
            data.append(UInt8(0x70 + length))
        } else if length <= 0xFF {
            data.append(0x91)
            data.append(UInt8(length))
        } else if length <= 0xFFFF {
            data.append(0x92)
            var le = UInt16(length).littleEndian
            data.append(contentsOf: withUnsafeBytes(of: &le) { Array($0) })
        } else if length <= 0xFFFFFFFF {
            data.append(0x93)
            var le = UInt32(length).littleEndian
            data.append(contentsOf: withUnsafeBytes(of: &le) { Array($0) })
        } else {
            throw OPACKError.unsupportedType
        }
        data.append(bytes)
    }

    private static func decodeValue(from data: Data, offset: inout Int) throws -> Any {
        guard offset < data.count else {
            throw OPACKError.unexpectedEndOfData
        }

        let marker = data[offset]
        offset += 1

        switch marker {
        case 0x01:
            return true

        case 0x02:
            return false

        case 0x04:
            return NSNull()

        case 0x05:
            guard offset + 16 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let uuidBytes = Data(data[offset..<offset+16])
            offset += 16
            return NSUUID(uuidBytes: [UInt8](uuidBytes)) as UUID

        case 0x06:
            guard offset + 8 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let timestamp = Int64(bigEndian: data[offset..<offset+8].withUnsafeBytes { $0.load(as: Int64.self) })
            offset += 8
            return Date(timeIntervalSince1970: Double(timestamp))

        case 0x08...0x2F:
            return Int(marker) - 0x08

        case 0x30:
            guard offset < data.count else { throw OPACKError.unexpectedEndOfData }
            let value = Int8(bitPattern: data[offset])
            offset += 1
            return Int(value)

        case 0x31:
            guard offset + 2 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let value = Int16(bigEndian: data[offset..<offset+2].withUnsafeBytes { $0.load(as: Int16.self) })
            offset += 2
            return Int(value)

        case 0x32:
            guard offset + 4 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let value = Int32(bigEndian: data[offset..<offset+4].withUnsafeBytes { $0.load(as: Int32.self) })
            offset += 4
            return Int(value)

        case 0x33:
            guard offset + 8 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let value = Int64(bigEndian: data[offset..<offset+8].withUnsafeBytes { $0.load(as: Int64.self) })
            offset += 8
            return Int(value)

        case 0x35:
            guard offset + 4 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bits = UInt32(bigEndian: data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) })
            offset += 4
            return Float(bitPattern: bits)

        case 0x36:
            guard offset + 8 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bits = UInt64(bigEndian: data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self) })
            offset += 8
            return Double(bitPattern: bits)

        case 0x40...0x60:
            let length = Int(marker) - 0x40
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let string = String(data: data[offset..<offset+length], encoding: .utf8) ?? ""
            offset += length
            return string

        case 0x61:
            guard offset < data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(data[offset])
            offset += 1
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let string = String(data: data[offset..<offset+length], encoding: .utf8) ?? ""
            offset += length
            return string

        case 0x62:
            guard offset + 2 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(UInt16(bigEndian: data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }))
            offset += 2
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let string = String(data: data[offset..<offset+length], encoding: .utf8) ?? ""
            offset += length
            return string

        case 0x63:
            guard offset + 4 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(UInt32(bigEndian: data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }))
            offset += 4
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let string = String(data: data[offset..<offset+length], encoding: .utf8) ?? ""
            offset += length
            return string

        case 0x50:
            var dict: [String: Any] = [:]
            while offset < data.count && data[offset] != 0x03 {
                let key = try decodeValue(from: data, offset: &offset)
                guard let keyString = key as? String else {
                    throw OPACKError.invalidData
                }
                let value = try decodeValue(from: data, offset: &offset)
                dict[keyString] = value
            }
            if offset < data.count && data[offset] == 0x03 {
                offset += 1
            }
            return dict

        case 0x60:
            var array: [Any] = []
            while offset < data.count && data[offset] != 0x03 {
                let value = try decodeValue(from: data, offset: &offset)
                array.append(value)
            }
            if offset < data.count && data[offset] == 0x03 {
                offset += 1
            }
            return array

        case 0x70...0x90:
            let length = Int(marker) - 0x70
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bytes = Data(data[offset..<offset+length])
            offset += length
            return bytes

        case 0x91:
            guard offset < data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(data[offset])
            offset += 1
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bytes = Data(data[offset..<offset+length])
            offset += length
            return bytes

        case 0x92:
            guard offset + 2 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(UInt16(littleEndian: data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }))
            offset += 2
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bytes = Data(data[offset..<offset+length])
            offset += length
            return bytes

        case 0x93:
            guard offset + 4 <= data.count else { throw OPACKError.unexpectedEndOfData }
            let length = Int(UInt32(littleEndian: data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }))
            offset += 4
            guard offset + length <= data.count else { throw OPACKError.unexpectedEndOfData }
            let bytes = Data(data[offset..<offset+length])
            offset += length
            return bytes

        case 0xD0...0xDF:
            let count = Int(marker) - 0xD0
            var array: [Any] = []
            for _ in 0..<count {
                let value = try decodeValue(from: data, offset: &offset)
                array.append(value)
            }
            return array

        case 0xE0...0xEF:
            let count = Int(marker) - 0xE0
            var dict: [String: Any] = [:]
            for _ in 0..<count {
                let key = try decodeValue(from: data, offset: &offset)
                guard let keyString = key as? String else {
                    throw OPACKError.invalidData
                }
                let value = try decodeValue(from: data, offset: &offset)
                dict[keyString] = value
            }
            return dict

        default:
            throw OPACKError.invalidData
        }
    }
}
