import Foundation
import Shared

// MountDefinition and MacNASConfig are in Shared/MountDefinition.swift
// This file provides convenience extensions for the app side.

extension MacNASConfig {
    /// Whether the config has a server and at least one mount.
    var isConfigured: Bool {
        !serverIP.isEmpty && !mounts.isEmpty
    }
}

extension MountDefinition {
    /// Validate the mount definition.
    var validationErrors: [String] {
        var errors: [String] = []
        if exportPath.isEmpty {
            errors.append("Export path is required")
        } else if !exportPath.hasPrefix("/") {
            errors.append("Export path must start with /")
        }
        if mountName.isEmpty {
            errors.append("Mount name is required")
        } else if mountName.contains("/") || mountName.contains(" ") {
            errors.append("Mount name cannot contain / or spaces")
        }
        return errors
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }
}
