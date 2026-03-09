cask "office-check-in" do
  version "0.3.5"
  sha256 "6e72d5b20ed2c96771672a8be5e650de3af8f7d847e3977ab49ef303bd64b655"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
