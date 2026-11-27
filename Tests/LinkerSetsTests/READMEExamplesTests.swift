// The README's examples, verbatim, so the README cannot drift from the code.

import LinkerSets
import Testing

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage")
    func usage() throws {
        let greeting = try Greeting(name: "Ada").formal().punctuated(with: "!")
        #expect(greeting.text == "Good day, Ada!")
    }
}
