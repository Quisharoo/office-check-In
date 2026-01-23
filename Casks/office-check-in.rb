cask "office-check-in" do
  version "0.3.0"
  sha256 "b694fc569483b5329d01a04b94ab3199ede914f97a7fb240bf432ea15b11b5e9"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
