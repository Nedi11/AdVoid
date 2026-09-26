import Testing
import Foundation
@testable import Shield

/// A real query for `ads.example.com`, type A, with an EDNS OPT record.
private func makeQuery(_ name: String, type: UInt16 = DNSQuery.typeA, id: UInt16 = 0xBEEF) -> [UInt8] {
    var q: [UInt8] = []
    q.appendUInt16(id)
    q.appendUInt16(0x0100) // RD
    q.appendUInt16(1)
    q.appendUInt16(0)
    q.appendUInt16(0)
    q.appendUInt16(1)      // ARCOUNT (OPT)
    for label in name.split(separator: ".") {
        q.append(UInt8(label.utf8.count))
        q.append(contentsOf: label.utf8)
    }
    q.append(0)
    q.appendUInt16(type)
    q.appendUInt16(1)
    q += [0x00, 0x00, 0x29, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] // OPT RR
    return q
}

@Suite struct DNSQueryTests {
    @Test func parsesQuestion() throws {
        let query = try #require(DNSQuery(makeQuery("Ads.Example.COM")))
        #expect(query.id == 0xBEEF)
        #expect(query.name == "ads.example.com")
        #expect(query.type == DNSQuery.typeA)
    }

    @Test func rejectsResponsesAndTruncatedPackets() {
        var response = makeQuery("a.com")
        response[2] |= 0x80
        #expect(DNSQuery(response) == nil)
        #expect(DNSQuery(Array(makeQuery("a.com").prefix(14))) == nil)
        #expect(DNSQuery([0, 1, 2]) == nil)
    }

    @Test func blockedAResponseAnswersZeroAddress() throws {
        let query = try #require(DNSQuery(makeQuery("ads.example.com")))
        let r = query.blockedResponse()
        #expect(r.uint16(at: 0) == 0xBEEF)
        #expect(r.uint16(at: 2) == 0x8180)   // response, RD, RA, NOERROR
        #expect(r.uint16(at: 4) == 1)
        #expect(r.uint16(at: 6) == 1)        // one answer
        #expect(r.uint16(at: 10) == 0)       // OPT dropped
        let answer = query.questionEnd
        #expect(Array(r[answer..<answer + 2]) == [0xC0, 0x0C])
        #expect(r.uint16(at: answer + 2) == DNSQuery.typeA)
        #expect(r.uint16(at: answer + 10) == 4)
        #expect(Array(r.suffix(4)) == [0, 0, 0, 0])
        #expect(r.count == answer + 16)
    }

    @Test func blockedAAAAResponseAnswersUnspecifiedAddress() throws {
        let query = try #require(DNSQuery(makeQuery("ads.example.com", type: DNSQuery.typeAAAA)))
        let r = query.blockedResponse()
        #expect(r.uint16(at: 6) == 1)
        #expect(r.uint16(at: query.questionEnd + 10) == 16)
        #expect(r.count == query.questionEnd + 12 + 16)
    }

    @Test func blockedHTTPSResponseHasNoAnswers() throws {
        let query = try #require(DNSQuery(makeQuery("ads.example.com", type: 65)))
        let r = query.blockedResponse()
        #expect(r.uint16(at: 6) == 0)
        #expect(r.count == query.questionEnd)
    }
}

@Suite struct UDPPacketTests {
    let packet = UDPPacket(sourceAddress: [10, 13, 37, 2], destinationAddress: [10, 13, 37, 1],
                           sourcePort: 51000, destinationPort: 53, payload: makeQuery("example.com"))

    @Test func roundTripsThroughIPv4() throws {
        let data = packet.ipv4Data()
        let parsed = try #require(UDPPacket(ipv4: data))
        #expect(parsed == packet)
    }

    @Test func headerAndUDPChecksumsVerify() {
        let bytes = [UInt8](packet.ipv4Data())
        #expect(UDPPacket.checksum(Array(bytes[0..<20])) == 0)
        var pseudo = Array(bytes[12..<20]) + [0, 17]
        pseudo.appendUInt16(UInt16(bytes.count - 20))
        #expect(UDPPacket.checksum(pseudo + bytes[20...]) == 0)
    }

    @Test func replySwapsEndpoints() {
        let reply = packet.reply(with: [1, 2, 3])
        #expect(reply.sourceAddress == [10, 13, 37, 1])
        #expect(reply.destinationPort == 51000)
        #expect(reply.sourcePort == 53)
        #expect(reply.payload == [1, 2, 3])
    }

    @Test func ignoresTCPAndFragments() {
        var tcp = [UInt8](packet.ipv4Data())
        tcp[9] = 6
        #expect(UDPPacket(ipv4: Data(tcp)) == nil)

        var fragment = [UInt8](packet.ipv4Data())
        fragment[6] = 0x20 // more fragments
        #expect(UDPPacket(ipv4: Data(fragment)) == nil)
    }
}

@Suite struct DomainMatcherTests {
    let matcher = DomainMatcher(hashes: ["ads.example.com", "tracker.net"].map(DomainHash.hash))

    @Test func matchesDomainAndSubdomains() {
        #expect(matcher.matches("ads.example.com"))
        #expect(matcher.matches("x.y.ads.example.com"))
        #expect(matcher.matches("TRACKER.net."))
        #expect(matcher.matches("cdn.tracker.net"))
    }

    @Test func doesNotMatchParentsOrLookalikes() {
        #expect(!matcher.matches("example.com"))
        #expect(!matcher.matches("www.example.com"))
        #expect(!matcher.matches("badads.example.com"))
        #expect(!matcher.matches("nottracker.net"))
        #expect(!DomainMatcher.empty.matches("tracker.net"))
    }

    @Test func survivesDiskRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        let hashes = (0..<10_000).map { DomainHash.hash("host\($0).example.org") }
        try DomainMatcher.write(hashes + hashes, to: url)
        let loaded = DomainMatcher(contentsOf: url)
        #expect(loaded.count == 10_000)
        #expect(loaded.matches("host1234.example.org"))
        #expect(loaded.matches("a.host9999.example.org"))
        #expect(!loaded.matches("host10000.example.org"))
    }
}

@Suite struct BlocklistParserTests {
    @Test func parsesAllFormats() {
        let text = """
        # comment
        ! adblock comment
        [Adblock Plus 2.0]
        0.0.0.0 ads.one.com
        127.0.0.1 localhost
        127.0.0.1 two.com three.com # trailing comment
        ::1 ip6-localhost
        four.com
        *.five.com
        ||six.com^
        ||seven.com^$important
        ||eight.com^$third-party
        @@||allowed.com^
        ||path.com/ads^
        not a domain
        1.2.3.4
        nodot
        """
        #expect(BlocklistParser.domains(in: text) ==
                ["ads.one.com", "two.com", "three.com", "four.com", "five.com", "six.com", "seven.com"])
    }

    @Test func validatesDomains() {
        #expect(BlocklistParser.validated("Ads.Example.com.") == "ads.example.com")
        #expect(BlocklistParser.validated("_dmarc.example.com") == "_dmarc.example.com")
        #expect(BlocklistParser.validated("bad domain.com") == nil)
        #expect(BlocklistParser.validated("a..b.com") == nil)
        #expect(BlocklistParser.validated("10.0.0.1") == nil)
    }
}

@Suite struct StatsTests {
    @Test func countsAndRollsOverDays() {
        var stats = Stats()
        let today = Date()
        stats.record(domain: "a.com", blocked: true, at: today)
        stats.record(domain: "b.com", blocked: false, at: today)
        #expect(stats.queriesToday == 2)
        #expect(stats.blockedToday == 1)
        #expect(stats.recent.first?.domain == "b.com")

        stats.record(domain: "c.com", blocked: true, at: today.addingTimeInterval(86_400 * 2))
        #expect(stats.queriesToday == 1)
        #expect(stats.blockedToday == 1)
        #expect(stats.blockedAllTime == 2)
    }

    @Test func capsRecentLog() {
        var stats = Stats()
        for i in 0..<(Stats.recentLimit + 50) { stats.record(domain: "d\(i).com", blocked: false) }
        #expect(stats.recent.count == Stats.recentLimit)
    }
}

@Suite struct StatsInsightTests {
    @Test func tracksHoursHistoryAndTopDomains() throws {
        var stats = Stats()
        let calendar = Calendar.current
        let nineAM = try #require(calendar.date(bySettingHour: 9, minute: 5, second: 0, of: Date()))
        for _ in 0..<3 { stats.record(domain: "ads.x.com", blocked: true, at: nineAM) }
        stats.record(domain: "t.y.com", blocked: true, at: nineAM)
        stats.record(domain: "apple.com", blocked: false, at: nineAM)
        #expect(stats.hourlyQueries[9] == 5)
        #expect(stats.hourlyBlocked[9] == 4)
        #expect(stats.topBlocked(1).first?.domain == "ads.x.com")
        #expect(stats.topBlocked(5).map(\.count) == [3, 1])
        #expect(stats.topAllowed(5).first?.domain == "apple.com")

        let tomorrow = nineAM.addingTimeInterval(86_400)
        stats.record(domain: "a.com", blocked: false, at: tomorrow)
        #expect(stats.history.count == 1)
        #expect(stats.history[0].blocked == 4)
        #expect(stats.history[0].queries == 5)
        #expect(stats.hourlyQueries[9] == 1)
        #expect(stats.days.count == 2)
        #expect(stats.queriesAllTime == 6)
    }

    @Test func prunesDomainCounters() {
        var stats = Stats()
        stats.record(domain: "top.com", blocked: true)
        stats.record(domain: "top.com", blocked: true)
        for i in 0..<Stats.domainLimit { stats.record(domain: "d\(i).com", blocked: true) }
        #expect(stats.blockedCounts.count <= Stats.domainLimit)
        #expect(stats.topBlocked(1).first?.domain == "top.com")
    }

    @Test func groupsCompanies() {
        #expect(TrackerCompanies.company(for: "securepubads.g.doubleclick.net") == "Google")
        #expect(TrackerCompanies.company(for: "graph.facebook.com") == "Meta")
        #expect(TrackerCompanies.company(for: "example.com") == nil)
        let top = TrackerCompanies.top(from: ["a.doubleclick.net": 5, "google-analytics.com": 2, "pixel.facebook.com": 4, "x.org": 9], limit: 5)
        #expect(top.map(\.company) == ["Google", "Meta"])
        #expect(top.first?.count == 7)
    }
}
