extension String {
    var isValidTTY: Bool {
        !isEmpty && self != "??" && allSatisfy { $0.isLetter || $0.isNumber }
    }
}
