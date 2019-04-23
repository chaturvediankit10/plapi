require "google_drive"
class GoogleDriveService
	def initialize file_name
		@file_name   = file_name
		@access_data = {
		  "client_id": "727107967186-tscujmc7gbosj88omd81e69q27ft1pss.apps.googleusercontent.com",
		  "client_secret": "n88wJRQYND7XftnvE3aZP8RT"
		}
	end

	def access_file
		if @file_name
			google_session = GoogleDrive::Session.from_config("config.json")
			spreadsheet    = google_session.spreadsheet_by_title(@file_name.split(".").first)
			edit_link      = spreadsheet.web_view_link
			file_id        = edit_link.split("/")[5]
			ws = google_session.spreadsheet_by_key(file_id).worksheets[0]
		else
		end
	end
end