cask "office-check-in" do
  version "0.3.1"
  sha256 "fe2c418759566369cffea2a0d693f130b1c2a25922ff4d8d073b80902ba46a44"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
