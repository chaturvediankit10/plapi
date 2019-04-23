class Bank < ApplicationRecord
  has_many :programs
  has_many :sheets

  SHEET_LINKS = %w(
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=8570
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=10742
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=7575
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=11098
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=7019
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=3571
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=5907
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=4892
    https://www.loansifter.com/DownloadFile.aspx?RateSheetID=2982
  )
end