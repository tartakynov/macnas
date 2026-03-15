cask "macnas" do
  version "0.1.0"
  sha256 "d2708bcc5ca63b537cc0d4187e372a5f1a58fa04a62db0b1d32d2ccb0150b767"

  url "https://github.com/tartakynov/macnas/releases/download/v#{version}/MacNAS-#{version}.zip"
  name "MacNAS"
  desc "Menu bar app for managing NFS mounts to a NAS"
  homepage "https://github.com/tartakynov/macnas"

  depends_on macos: ">= :sonoma"

  app "MacNAS.app"

  uninstall launchctl: "com.macnas.helper",
            delete:    "/usr/local/bin/com.macnas.helper"

  zap trash: "~/Library/Application Support/MacNAS"
end
