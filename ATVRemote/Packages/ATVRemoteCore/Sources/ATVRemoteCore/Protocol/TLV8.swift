import Foundation

public enum TLV8Tag: UInt8, Sendable {
    case method = 0x00
    case identifier = 0x01
    case salt = 0x02
    case publicKey = 0x03
    case proof = 0x04
    case encryptedData = 0x05
    case sequence = 0x06
    case errorCode = 0x07
    case backOff = 0x08
    case signature = 0x0A
    case permissions = 0x0B
    case fragmentData = 0x0C
    case fragmentLast = 0x0D
}

public struct TLV8 {
    public var items: [UInt8: Data]

    public init() {
        self.items = [:]
    }

    public init(items: [UInt8: Data]) {
        self.items = items
    }

    public subscript(tag: TLV8Tag) -> Data? {
        get { items[tag.rawValue] }
        set { items[tag.rawValue] = newValue }
    }

    public subscript(tag: UInt8) -> Data? {
        get { items[tag] }
        set { items[tag] = newValue }
    }

    public static func encode(_ items: [UInt8: Data]) -> Data {
        var result = Data()

        for (tag, value) in items.sorted(by: { $0.key < $1.key }) {
            let normalizedValue = Data(value)
            var offset = 0

            while offset < normalizedValue.count {
                let chunkSize = min(255, normalizedValue.count - offset)
                result.append(tag)
                result.append(UInt8(chunkSize))
                result.append(normalizedValue[offset..<(offset + chunkSize)])
                offset += chunkSize
            }

            if normalizedValue.isEmpty {
                result.append(tag)
                result.append(0)
            }
        }

        return result
    }

    public static func decode(_ data: Data) -> TLV8 {
        var items: [UInt8: Data] = [:]
        var offset = 0

        while offset + 1 < data.count {
            let tag = data[offset]
            let length = Int(data[offset + 1])
            offset += 2

            guard offset + length <= data.count else { break }

            let value = data[offset..<(offset + length)]
            offset += length

            if var existing = items[tag] {
                existing.append(contentsOf: value)
                items[tag] = existing
            } else {
                items[tag] = Data(value)
            }
        }

        return TLV8(items: items)
    }

    public func encode() -> Data {
        TLV8.encode(items)
    }

    public var sequence: UInt8? {
        guard let data = self[.sequence], !data.isEmpty else { return nil }
        return data[0]
    }

    public var method: UInt8? {
        guard let data = self[.method], !data.isEmpty else { return nil }
        return data[0]
    }

    public var errorCode: UInt8? {
        guard let data = self[.errorCode], !data.isEmpty else { return nil }
        return data[0]
    }

    public var backOff: Int? {
        guard let data = self[.backOff], !data.isEmpty else { return nil }
        var value: Int = 0
        for byte in data {
            value = (value << 8) | Int(byte)
        }
        return value
    }

    public mutating func set(_ tag: TLV8Tag, value: UInt8) {
        items[tag.rawValue] = Data([value])
    }

    public mutating func set(_ tag: TLV8Tag, value: Data) {
        items[tag.rawValue] = value
    }
}

extension TLV8: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        for (tag, value) in items.sorted(by: { $0.key < $1.key }) {
            let tagName = TLV8Tag(rawValue: tag).map { "\($0)" } ?? "0x\(String(tag, radix: 16))"
            parts.append("\(tagName): \(value.count) bytes")
        }
        return "TLV8[\(parts.joined(separator: ", "))]"
    }
}
