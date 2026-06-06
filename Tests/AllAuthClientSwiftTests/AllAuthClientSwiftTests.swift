import Testing
@testable import AllAuthClientSwift

@Test func clientExists() async throws {
    #expect(AllAuthClient.shared != nil)
}
