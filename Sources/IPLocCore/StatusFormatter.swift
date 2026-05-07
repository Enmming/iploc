import Foundation

public enum StatusFormatter {
    public static func statusBarTitle(for snapshot: IPSnapshot, isBusy: Bool, spinnerFrame: String) -> String {
        if isBusy {
            return "Loading"
        }

        if let countryCode = snapshot.location?.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !countryCode.isEmpty {
            return countryCode
        }

        return "IP"
    }

    public static func menuBarTitle(for snapshot: IPSnapshot) -> String {
        guard let publicIP = snapshot.publicIP, !publicIP.isEmpty else {
            if let message = snapshot.message, !message.isEmpty {
                return "IPLoc \(message)"
            }
            return "IPLoc"
        }

        let locationParts = [
            snapshot.location?.countryName,
            snapshot.location?.cityName
        ].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        if locationParts.isEmpty {
            return publicIP
        }

        return ([publicIP] + locationParts).joined(separator: " ")
    }
}

public enum CountryFlagFormatter {
    public static func flag(for countryCode: String?) -> String? {
        guard let countryCode else {
            return nil
        }

        let scalars = countryCode
            .uppercased()
            .unicodeScalars
            .filter { ("A"..."Z").contains(Character($0)) }

        guard scalars.count == 2 else {
            return nil
        }

        let flagScalars = scalars.compactMap { scalar -> UnicodeScalar? in
            UnicodeScalar(127_397 + Int(scalar.value))
        }

        guard flagScalars.count == 2 else {
            return nil
        }

        return String(String.UnicodeScalarView(flagScalars))
    }
}
