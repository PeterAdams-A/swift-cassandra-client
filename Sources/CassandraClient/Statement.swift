@_implementationOnly import CDataStaxDriver
import Foundation // for date and uuid

public extension CassandraClient {
    final class Statement: CustomStringConvertible {
        internal let query: String
        internal let parameters: [Value]
        internal let options: Options
        internal let rawPointer: OpaquePointer

        public init(query: String, parameters: [Value] = [], options: Options = .init()) throws {
            self.query = query
            self.parameters = parameters
            self.options = options
            self.rawPointer = cass_statement_new(query, parameters.count)

            for (index, parameter) in parameters.enumerated() {
                let result: CassError
                switch parameter {
                case .null:
                    result = cass_statement_bind_null(self.rawPointer, index)
                case .int8(let value):
                    result = cass_statement_bind_int8(self.rawPointer, index, value)
                case .int16(let value):
                    result = cass_statement_bind_int16(self.rawPointer, index, value)
                case .int32(let value):
                    result = cass_statement_bind_int32(self.rawPointer, index, value)
                case .int64(let value):
                    result = cass_statement_bind_int64(self.rawPointer, index, cass_int64_t(value))
                case .float32(let value):
                    result = cass_statement_bind_float(self.rawPointer, index, value)
                case .double(let value):
                    result = cass_statement_bind_double(self.rawPointer, index, value)
                case .bool(let value):
                    result = cass_statement_bind_bool(self.rawPointer, index, value ? cass_bool_t(1) : cass_bool_t(0))
                case .string(let value):
                    result = cass_statement_bind_string(self.rawPointer, index, value)
                case .uuid(let value):
                    let uuid = CassUuid(value.uuid)
                    result = cass_statement_bind_uuid(self.rawPointer, index, uuid)
                case .timeuuid(let value):
                    let timeuuid = CassUuid(value.uuid)
                    result = cass_statement_bind_uuid(self.rawPointer, index, timeuuid)
                case .date(let value):
                    let timestamp = Int64(value.timeIntervalSince1970 * 1000)
                    result = cass_statement_bind_int64(self.rawPointer, index, cass_int64_t(timestamp))
                case .rawDate(let value):
                    result = cass_statement_bind_uint32(self.rawPointer, index, value)
                case .rawTimestamp(let value):
                    result = cass_statement_bind_int64(self.rawPointer, index, cass_int64_t(value))
                case .bytes(let value):
                    let this = self
                    result = value.withUnsafeBufferPointer { buffer in
                        cass_statement_bind_bytes(this.rawPointer, index, buffer.baseAddress, buffer.count)
                    }
                case .bytesUnsafe(let buffer):
                    result = cass_statement_bind_bytes(self.rawPointer, index, buffer.baseAddress, buffer.count)
                }

                guard result == CASS_OK else {
                    throw CassandraClient.Error(result)
                }
            }

            if let consistency = options.consistency {
                let cassConsistency: CassConsistency
                switch consistency {
                case .any:
                    cassConsistency = CASS_CONSISTENCY_ANY
                case .one:
                    cassConsistency = CASS_CONSISTENCY_ONE
                case .two:
                    cassConsistency = CASS_CONSISTENCY_TWO
                case .three:
                    cassConsistency = CASS_CONSISTENCY_THREE
                case .quorum:
                    cassConsistency = CASS_CONSISTENCY_QUORUM
                case .all:
                    cassConsistency = CASS_CONSISTENCY_ALL
                case .localQuorum:
                    cassConsistency = CASS_CONSISTENCY_LOCAL_QUORUM
                case .eachQuorum:
                    cassConsistency = CASS_CONSISTENCY_EACH_QUORUM
                case .serial:
                    cassConsistency = CASS_CONSISTENCY_SERIAL
                case .localSerial:
                    cassConsistency = CASS_CONSISTENCY_LOCAL_SERIAL
                case .localOne:
                    cassConsistency = CASS_CONSISTENCY_LOCAL_ONE
                }

                try checkResult { cass_statement_set_consistency(self.rawPointer, cassConsistency) }
            }
        }

        func setPagingSize(_ pagingSize: Int32) throws {
            try checkResult { cass_statement_set_paging_size(self.rawPointer, pagingSize) }
        }

        deinit {
            cass_statement_free(self.rawPointer)
        }

        public var description: String {
            "\(self.query) \(self.parameters)"
        }

        public enum Value {
            case null
            case int8(Int8)
            case int16(Int16)
            case int32(Int32)
            case int64(Int64)
            case float32(Float32)
            case double(Double)
            case bool(Bool)
            case string(String)
            case uuid(Foundation.UUID)
            case timeuuid(TimeBasedUUID)
            case date(Foundation.Date)
            case rawDate(daysSinceEpoch: UInt32)
            case rawTimestamp(millisecondsSinceEpoch: Int64)
            case bytes([UInt8])
            case bytesUnsafe(UnsafeBufferPointer<UInt8>)
        }

        public enum Consistency {
            case any
            case one
            case two
            case three
            case quorum
            case all
            case localQuorum
            case eachQuorum
            case serial
            case localSerial
            case localOne
        }

        public struct Options: CustomStringConvertible {
            public var consistency: Consistency?

            public init(consistency: Consistency? = nil) {
                self.consistency = consistency
            }

            public var description: String {
                "Options { consistency: \(String(describing: self.consistency)) }"
            }
        }
    }
}

private func checkResult(body: () -> CassError) throws {
    let result = body()
    guard result == CASS_OK else {
        throw CassandraClient.Error(result, message: "Failed to configure Statement")
    }
}
