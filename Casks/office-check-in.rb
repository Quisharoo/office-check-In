cask "office-check-in" do
  version "0.3.2"
  sha256 "a38a2762fe600aefea0c3f236f699f209b5358248becb6b1f57e087fc03f7b73"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
