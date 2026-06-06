import CryptoKit
import Foundation
import Security

struct SyncEncryptionEnvelope: Codable {
    let schemaVersion: Int
    let algorithm: String
    let kdf: String
    let salt: String
    let nonce: String
    let ciphertext: String
    let tag: String
}

enum SyncEncryptionError: Error {
    case missingPassword
    case invalidEnvelope
}

enum SyncFileEncryption {
    private static let algorithm = "AES.GCM"
    private static let kdf = "HKDF-SHA256"
    private static let info = Data("KKBookkeep sync file encryption v1".utf8)

    static func encrypt(_ data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw SyncEncryptionError.missingPassword
        }

        let salt = try makeRandomData(byteCount: 16)
        let key = deriveKey(password: password, salt: salt)
        let sealedBox = try AES.GCM.seal(data, using: key)
        let envelope = SyncEncryptionEnvelope(
            schemaVersion: 1,
            algorithm: algorithm,
            kdf: kdf,
            salt: salt.base64EncodedString(),
            nonce: sealedBox.nonce.data.base64EncodedString(),
            ciphertext: sealedBox.ciphertext.base64EncodedString(),
            tag: sealedBox.tag.base64EncodedString()
        )

        return try encoder.encode(envelope)
    }

    static func decryptIfNeeded(_ data: Data, password: String) throws -> Data {
        guard let envelope = try? decoder.decode(SyncEncryptionEnvelope.self, from: data) else {
            return data
        }

        guard !password.isEmpty else {
            throw SyncEncryptionError.missingPassword
        }

        guard
            envelope.schemaVersion == 1,
            envelope.algorithm == algorithm,
            envelope.kdf == kdf,
            let salt = Data(base64Encoded: envelope.salt),
            let nonceData = Data(base64Encoded: envelope.nonce),
            let ciphertext = Data(base64Encoded: envelope.ciphertext),
            let tag = Data(base64Encoded: envelope.tag)
        else {
            throw SyncEncryptionError.invalidEnvelope
        }

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: deriveKey(password: password, salt: salt))
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(password.utf8)),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private static func makeRandomData(byteCount: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw SyncEncryptionError.invalidEnvelope
        }

        return Data(bytes)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}

private extension AES.GCM.Nonce {
    var data: Data {
        withUnsafeBytes { Data($0) }
    }
}
