cask "office-check-in" do
  version "0.3.4"
  sha256 "fa55a8ce42e8e744230b2aa52329c18eeee732153613018f8e3f26640325690b"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v#{version}/OfficeCheckIn-#{version}.zip"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "OfficeCheckIn.app"
end
