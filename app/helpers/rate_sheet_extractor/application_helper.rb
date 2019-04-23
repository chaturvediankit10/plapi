module RateSheetExtractor::ApplicationHelper
  def display_error_link sheet
    return "<td class='error-button'><a class='btn btn-info btn-xs' href='/error_logs/#{sheet.name}'><span class='glyphicon glyphicon-edit'></span> Sheet Errors</a></td>"
  end
end
