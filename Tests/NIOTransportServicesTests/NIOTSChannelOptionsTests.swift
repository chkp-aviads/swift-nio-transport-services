//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Network)
import XCTest
import NIOCore
import NIOConcurrencyHelpers
import NIOTransportServices
import Network
import Logging

@available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
class NIOTSChannelOptionsTests: XCTestCase {
    private var group: NIOTSEventLoopGroup!

    override func setUp() {
        self.group = NIOTSEventLoopGroup()
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
    }

    func testCurrentPath() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let currentPath = try connection.getOption(NIOTSChannelOptions.currentPath).wait()
        XCTAssertEqual(currentPath.status, NWPath.Status.satisfied)
    }

    func testMetadata() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let metadata =
            try connection.getOption(NIOTSChannelOptions.metadata(NWProtocolTCP.definition)).wait()
            as! NWProtocolTCP.Metadata
        XCTAssertEqual(metadata.availableReceiveBuffer, 0)
    }

    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testEstablishmentReport() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let reportFuture = try connection.getOption(NIOTSChannelOptions.establishmentReport).wait()
        let establishmentReport = try reportFuture.wait()

        XCTAssertEqual(establishmentReport!.resolutions.count, 0)
    }

    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testDataTransferReport() throws {
        let syncQueue = DispatchQueue(label: "syncQueue")
        let collectGroup = DispatchGroup()

        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let pendingReport = try connection.getOption(NIOTSChannelOptions.dataTransferReport).wait()

        collectGroup.enter()
        pendingReport.collect(queue: syncQueue) { report in
            XCTAssertEqual(report.pathReports.count, 1)
            collectGroup.leave()
        }

        collectGroup.wait()
    }

    func testMultipathOptions() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .serverChannelOption(NIOTSChannelOptions.multipathServiceType, value: .handover)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .channelOption(NIOTSChannelOptions.multipathServiceType, value: .interactive)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let listenerValue = try assertNoThrowWithValue(
            listener.getOption(NIOTSChannelOptions.multipathServiceType).wait()
        )
        let connectionValue = try assertNoThrowWithValue(
            connection.getOption(NIOTSChannelOptions.multipathServiceType).wait()
        )

        XCTAssertEqual(listenerValue, .handover)
        XCTAssertEqual(connectionValue, .interactive)
    }

    func testMinimumIncompleteReceiveLength() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .channelOption(NIOTSChannelOptions.minimumIncompleteReceiveLength, value: 1)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let connectionValue = try assertNoThrowWithValue(
            connection.getOption(NIOTSChannelOptions.minimumIncompleteReceiveLength).wait()
        )

        XCTAssertEqual(connectionValue, 1)
    }

    func testMaximumReceiveLength() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .channelOption(NIOTSChannelOptions.maximumReceiveLength, value: 8192)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let connectionValue = try assertNoThrowWithValue(
            connection.getOption(NIOTSChannelOptions.maximumReceiveLength).wait()
        )

        XCTAssertEqual(connectionValue, 8192)
    }

    func testSendableStorageOptionOnConnectionChannel() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let expected: ChannelOptions.Types.SendableStorage.Value = [
            "int": 1 as Int,
            "string": "two" as String,
            "bool": true as Bool,
        ]

        XCTAssertNoThrow(try connection.setOption(ChannelOptions.Types.SendableStorage(), value: expected).wait())
        let got = try connection.getOption(ChannelOptions.Types.SendableStorage()).wait()

        XCTAssertEqual(got["int"] as? Int, 1)
        XCTAssertEqual(got["string"] as? String, "two")
        XCTAssertEqual(got["bool"] as? Bool, true)
    }

    func testChannelIDOptionOnConnectionChannel() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection1 = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection1.close().wait())
        }

        let connection2 = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection2.close().wait())
        }

        let id1a = try connection1.getOption(ChannelOptions.Types.ChannelID()).wait()
        let id1b = try connection1.getOption(ChannelOptions.Types.ChannelID()).wait()
        XCTAssertEqual(id1a, id1b)

        let id2 = try connection2.getOption(ChannelOptions.Types.ChannelID()).wait()
        XCTAssertNotEqual(id1a, id2)
    }

    func testLoggerOptionOnConnectionChannel() throws {
        let listener = try NIOTSListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let logger = Logger(label: "NIOTSChannelOptionsTests")
        XCTAssertNoThrow(try connection.setOption(ChannelOptions.Types.LoggerOption(), value: logger).wait())
        let got = try connection.getOption(ChannelOptions.Types.LoggerOption()).wait()
        XCTAssertEqual(got.label, logger.label)
    }

    func testSendableStorageOptionOnDatagramConnectionChannel() throws {
        let listener = try NIOTSDatagramListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSDatagramConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let expected: ChannelOptions.Types.SendableStorage.Value = [
            "int": 42 as Int,
            "string": "hello" as String,
        ]

        XCTAssertNoThrow(try connection.setOption(ChannelOptions.Types.SendableStorage(), value: expected).wait())
        let got = try connection.getOption(ChannelOptions.Types.SendableStorage()).wait()
        XCTAssertEqual(got["int"] as? Int, 42)
        XCTAssertEqual(got["string"] as? String, "hello")
    }

    func testChannelIDAndLoggerOptionsOnDatagramConnectionChannel() throws {
        let listener = try NIOTSDatagramListenerBootstrap(group: self.group)
            .bind(host: "localhost", port: 0).wait()
        defer {
            XCTAssertNoThrow(try listener.close().wait())
        }

        let connection = try NIOTSDatagramConnectionBootstrap(group: self.group)
            .connect(to: listener.localAddress!)
            .wait()
        defer {
            XCTAssertNoThrow(try connection.close().wait())
        }

        let id1 = try connection.getOption(ChannelOptions.Types.ChannelID()).wait()
        let id2 = try connection.getOption(ChannelOptions.Types.ChannelID()).wait()
        XCTAssertEqual(id1, id2)

        let logger = Logger(label: "NIOTSChannelOptionsTests.UDP")
        XCTAssertNoThrow(try connection.setOption(ChannelOptions.Types.LoggerOption(), value: logger).wait())
        let got = try connection.getOption(ChannelOptions.Types.LoggerOption()).wait()
        XCTAssertEqual(got.label, logger.label)
    }
}
#endif
