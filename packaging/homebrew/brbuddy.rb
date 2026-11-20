# Homebrew cask for BRBuddy. Tools/release.sh fills in @VERSION@ and @SHA256@ and writes the result to
# build/release/brbuddy.rb, for the dhaataalimited-hub/homebrew-tap repository (Casks/brbuddy.rb).
cask "brbuddy" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/dhaataalimited-hub/brbuddy/releases/download/v#{version}/BRBuddy-#{version}.dmg"
  name "BRBuddy"
  desc "Keeps your Mac awake and guards the screen while your AI agent works"
  homepage "https://github.com/dhaataalimited-hub/brbuddy"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "BRBuddy.app"

  uninstall quit: "com.dhaataalimited.brbuddy"

  zap trash: [
    "~/Library/Application Support/BRBuddy",
    "~/Library/Preferences/com.dhaataalimited.brbuddy.plist",
  ]
end
